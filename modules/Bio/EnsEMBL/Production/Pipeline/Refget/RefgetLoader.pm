=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2024] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=pod


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::Refget::RefgetLoader

=head1 DESCRIPTION

A module for loading sequences from a core-like database into the 
Perl reference implementation of refget (https://github.com/andrewyatz/refget-server-perl). 

The code will load all proteins, cds and cDNA, and can optionally load toplevel
sequences if missing from ENA's refget instance (https://www.ebi.ac.uk/ena/cram/).

Allowed parameters are:

=over 8

=item species - The species to fetch the genomic sequence

=item release - A required parameter for the version of Ensembl we are dumping for

=item db_types - Array reference of the database groups to use. Defaults to core

=item check_refget - Ping a refget for MD5 existence before attempting to load a toplevel sequence. Defaults to true

=item refget_ping_url - URL to ping when checking for pre-existing sequences. Defaults to ENA's implementation

=item verify_checksums - If set to true this module will double check the recorded checksum. Defaults to true

=item source - Annotation source. Defaults to Ensembl

=back

The database connection for DBIx::Class is assumed to be in the registry under the species name B<multi>
and the group of B<refget>. DBIx::Class then can take the underlying DBI handle to connect. Adding
a C<-DRIVER> attribute of type C<"Pg"> to a C<Bio::EnsEMBL::DBSQL::DBAdaptor> constructor will make
the magic happen (assuming the underlying Refget is in PostgreSQL).

=cut

package Bio::EnsEMBL::Production::Pipeline::Refget::RefgetLoader;

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Refget::Schema;
use HTTP::Tiny;
use Refget::Util qw/trunc512_digest ga4gh_to_trunc512 ga4gh_digest/;
use Digest::MD5 qw/md5_hex/;
use Mojo::URL;

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

sub param_defaults {
    my ($self) = @_;
    return {
        check_refget => 0,
        refget_ping_url => 'https://www.ebi.ac.uk/ena/cram',
        verify_checksums => 1,
        attrib_keys => {
            toplevel => {
                md5 => 'md5_toplevel',
                sha512t24u => 'sha512t24u_toplevel',
            },
            cdna => {
                md5 => 'md5_cdna',
                sha512t24u => 'sha512t24u_cdna',
            },
            cds => {
                md5 => 'md5_cds',
                sha512t24u => 'sha512t24u_cds',
            },
            pep => {
                md5 => 'md5_pep',
                sha512t24u => 'sha512t24u_pep',
            },
        },
        refget_dba_name => 'multi',
        refget_dba_group => 'refget',
        source => 'Ensembl',
        sequence_type => [qw/toplevel cdna cds pep/],
	    max_allowed_packet => '1G',
    };
}

sub run {
	    
    my ($self) = @_;
    my $group = $self->param('group');
    my $dba = $self->get_DBAdaptor($group);
    #set sequence and hash
    $self->{'subseq'}={};

    $self->throw("Cannot find adaptor for type $group") unless $dba;
    ## Assumes refget is available from the multi name & refget type
    my $refget_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($self->param('refget_dba_name'), $self->param('refget_dba_group'));
    my $extra_attributes = {};
    my $db_conn_string = "dbi:mysql:database=". $refget_dba->dbc()->dbname .";host=". $refget_dba->dbc()->host . ";port=". $refget_dba->dbc()->port . ";max_allowed_packet=" . $self->param('max_allowed_packet');

    $extra_attributes->{quote_char} = '`';

    my $refget_schema = Refget::Schema->connect($db_conn_string,
      $refget_dba->dbc()->user, $refget_dba->dbc()->pass, $extra_attributes);


    #Setup refget objects
    $self->create_basic_refget_objects($dba, $refget_schema);

    my $slice_adaptor = $dba->get_SliceAdaptor();
    my $attribute_adaptor = $dba->get_AttributeAdaptor();
    my $sequence_adaptor = $dba->get_SequenceAdaptor();
    my @slices = reverse @{$slice_adaptor->fetch_all('toplevel', undef, 1, undef, undef)};

    # Get the checksum lookups
        my $checksum_lookup = {};
    if($self->param('verify_checksums')) {
        foreach my $type (@{$self->param('sequence_type')}) {
            foreach my $checksum (qw/md5 sha512t24u/) {
                $checksum_lookup->{$type}->{$checksum} = $self->_get_checksums_from_db($dba, $type, $checksum);
            }
        }
     }

    while(my $slice = shift @slices) {
        # Transaction block is left at just one per toplevel region. 
        # Sometimes it'll be fine and others it won't be
        # Rows only inserted into molecule if there's a new id+seq+release+type
	$refget_schema->txn_do(sub {
	    $self->generate_and_load_toplevel($slice, $checksum_lookup, $sequence_adaptor, $refget_schema);
	    $self->generate_and_load_transcripts_and_proteins($slice, $checksum_lookup, $refget_schema);
	});
    }

    # cleanup
    #$refget_dba->dbc()->db_handle()->{'AutoCommit'} = 1; 
    $dba->dbc->disconnect_if_idle();
    $refget_schema->txn_commit;

    #$refget_schema->storage->disconnect();
    
    #$refget_dba->dbc->disconnect_if_idle();
}

##### DBIX::Class/Ensembl object loading methods

# Responsible for setting up the basic bits of information required to load a record
# into a refget instance.
sub create_basic_refget_objects {
    my ($self, $dba, $refget_schema) = @_;
    print($dba->dbc->dbname);
    print("\n", $dba->dbc->host);
    my $mc = $dba->get_MetaContainer();
    my $csa = $dba->get_CoordSystemAdaptor();
    my ($cs) = @{$csa->fetch_all()};

    my $species_name = $mc->get_scientific_name();
    my $species_assembly = $cs->version();
    my $species_division = $mc->single_value_by_key('species.division');
    
    #check species stain group and select assembly version name 
    my $strain_group = $mc->single_value_by_key('species.strain_group');
    if(defined $strain_group){
      $species_assembly =  $mc->single_value_by_key('assembly.name');
    }


    my $species_release = $self->param('release');
    my $source = $self->param('source');

    # Done in a transaction but everything here is addative and doesn't create new records
    # unless needed
    $refget_schema->txn_do(sub {
        my $species_obj = $refget_schema->resultset('Species')->create_entry($species_name, $species_assembly);
        my $division_obj = $refget_schema->resultset('Division')->create_entry($species_division);
        $self->param('species_obj', $species_obj);
        $self->param('division_obj', $division_obj);
        $self->param('release_obj', $refget_schema->resultset('Release')->create_entry($species_release, $division_obj, $species_obj));
        my $mol_types = {};
        foreach my $mol_type (qw/dna cds cdna protein/) {
            my $mol_obj = $refget_schema->resultset('MolType')->find_entry($mol_type);
            if(! $mol_obj) {
                $self->throw("No mol object found for mol type '${mol_type}'. Is the DB pre-populated?");
            }
            $mol_types->{$mol_type} = $mol_obj;
        }
        $self->param('mol_type_objs', $mol_types);
        my $source_obj = $refget_schema->resultset('Source')->find_entry($self->param('source'));
        if(! $source_obj) {
            $self->throw("No source object found for source '${source}'. Is the DB pre-populated?");
        }
        $self->param('source_obj', $source_obj);
	$refget_schema->txn_commit;
    });
    return;
}

sub generate_and_load_toplevel {
    my ($self, $slice, $checksum_lookup, $sequence_adaptor, $refget_schema) = @_;

    # Skip if we were not to process this type
    if(! $self->_process_sequence_type('toplevel')) {
        return;
    }

    # Generate the checksums from the sequence in the DB
    my $seq_ref = $sequence_adaptor->fetch_by_Slice_start_end_strand($slice, 1, undef, 1);
    my $slice_checksums = $self->_generate_checksums_from_seq_ref($seq_ref);

    # Verify means fetch the DB stored checksums and make sure there isn't any drift
    # Die if there is drift
    if($self->param('verify_checksums')) {
        my $seq_region_id = $slice->get_seq_region_id();
        foreach my $checksum (qw/md5 sha512t24u/) {
            my $existing_checksum = $checksum_lookup->{'toplevel'}->{$checksum}->{$seq_region_id};
            if($slice_checksums->{$checksum} ne $existing_checksum) {
                my $seq_region_name =  $slice->seq_region_name();
                my $error_string = sprintf(
                    'The stored %s checksum (%s) for seq_region_name %s seq_region_id %d does not match the calculated checksum (%s)',
                    $checksum, $existing_checksum, $seq_region_name, $seq_region_id, $slice_checksums->{$checksum}
                );
		print($slice->seq_region_name(), "\n");
		$self->throw($error_string);
            }
        }
    }

    # Check if it is in refget at ENA. Otherwise we need to load this
    my $exists_in_refget = 0;
    if($self->param('check_refget')) {
        my $md5 = $slice_checksums->{md5};
        $exists_in_refget = $self->sequence_exists($md5);
    }

    # Load if it wasn't found in refget
    my $seq_region_id = $slice->get_seq_region_id(); #remove it 
    if(! $exists_in_refget) {
        my $seq_hash = {
            trunc512 => $slice_checksums->{trunc512},
            md5 => $slice_checksums->{md5},
            ga4gh => $slice_checksums->{ga4gh},
            size => length(${$seq_ref}),
            circular => 0,
        };
        my $id = $slice->seq_region_name();
        $self->insert_molecule($refget_schema, $seq_ref, $seq_hash, $id, 'dna');
    }

    return;
}

sub generate_and_load_transcripts_and_proteins {
    my ($self, $slice, $checksum_lookup, $refget_schema) = @_;
    my $transcripts = $slice->get_all_Transcripts();
    my $is_circular = 0;
    my $verify_checksums = $self->param('verify_checksums');

    my $process_cdna = $self->_process_sequence_type('cdna');
    my $process_cds = $self->_process_sequence_type('cds');
    my $process_pep = $self->_process_sequence_type('pep');

    while(my $transcript = shift @{$transcripts}) {

        # Skip if we were not to process this type
        my $transcript_id = $transcript->stable_id_version();
        if($process_cdna) {
            my $cdna = $transcript->seq()->seq();
            my $cdna_seq_hash = $self->create_seq_hash(\$cdna);

            if($verify_checksums) {
                my $cdna_checksums = $checksum_lookup->{cdna};
                $self->_verify_checksums_match($cdna_seq_hash, $cdna_checksums, 'cdna', $transcript_id, $transcript->dbID());
            }

            $self->insert_molecule($refget_schema, \$cdna, $cdna_seq_hash, $transcript_id, 'cdna');
        }

        my $translation = $transcript->translation();
        if($translation) {
            # We only have a CDS when it is a translation. Perl API will return an empty string
            # if there is no translation associcated with a transcript record
            if($process_cds) {
                my $cds = $transcript->translateable_seq();
                my $cds_seq_hash = $self->create_seq_hash(\$cds);

                if($verify_checksums) {
                    my $cds_checksums = $checksum_lookup->{cds};
                    $self->_verify_checksums_match($cds_seq_hash, $cds_checksums, 'cds', $transcript_id, $transcript->dbID());
                }
                $self->insert_molecule($refget_schema, \$cds, $cds_seq_hash, $transcript_id, 'cds');
            }

            # Now process protein
            if($process_pep) {
                my $protein = $translation->seq();
                my $protein_seq_hash = $self->create_seq_hash(\$protein);
                my $protein_id = $translation->stable_id_version();
                if($verify_checksums) {
                    my $protein_checksums = $checksum_lookup->{pep};
                    $self->_verify_checksums_match($protein_seq_hash, $protein_checksums, 'pep', $protein_id, $translation->dbID());
                }
                $self->insert_molecule($refget_schema, \$protein, $protein_seq_hash, $protein_id, 'protein');
            }
        }
    }
    return;
}

##### Hashes etc... generation

sub create_seq_hash {
    my ($self, $seq_ref, $is_circular) = @_;
    my $checksums = $self->_generate_checksums_from_seq_ref($seq_ref);
    my $length = length(${$seq_ref});
    $is_circular = 0 unless defined $is_circular;
    return {
        md5 => $checksums->{md5}, 
        trunc512 => $checksums->{trunc512},
        ga4gh => $checksums->{ga4gh},
        sha512t24u => $checksums->{sha512t24u},
        size => $length, 
        circular => $is_circular
    };
}

sub _generate_checksums_from_seq_ref {
    my ($self, $seq_ref) = @_;
    my $md5 = md5_hex(${$seq_ref});
    my $ga4gh = ga4gh_digest(${$seq_ref});
    my $trunc512 = ga4gh_to_trunc512($ga4gh);
    my $sha512t24u = $ga4gh;
    $sha512t24u =~ s/^ga4gh:SQ.//g;
    return {
        md5 => $md5,
        ga4gh => $ga4gh,
        trunc512 => $trunc512,
        sha512t24u => $sha512t24u
    };
}

sub _process_sequence_type {
    my ($self, $type) = @_;
    if(! $self->param_exists('sequence_type_lookup')) {
        my $sequence_type = $self->param('sequence_type');
        my %lookup = map { $_, 1 } @{$sequence_type};
        $self->param('sequence_type_lookup', \%lookup);
    }
    return exists $self->param('sequence_type_lookup')->{$type} ? 1 : 0;
}

##### Sequence existence methods

sub sequence_exists {
    my ($self, $md5) = @_;
    my $url = $self->param('refget_ping_url');
    my $full_url = "${url}/sequence/${md5}/metadata";
    my $headers = {};
    # ENA server issue. Does not accept application/json but does return correct
    # data if you omit this.
    if($url !~ /www\.ebi\.ac\.uk\/ena\/cram/) {
        $headers->{Accept} = 'application/json';
    }
    my $res = HTTP::Tiny->new()->get($full_url, { headers => $headers } );
    return ($res->{success}) ? 1 : 0;
}

##### DBIX::Class methods

sub insert_molecule {
    my ($self, $refget_schema, $seq_ref, $seq_hash, $id, $mol_type) = @_;
    print($mol_type, "\n");
    my $molecule_type_obj = $self->param('mol_type_objs')->{$mol_type};
    my $release_obj = $self->param('release_obj');
    my $species_obj = $self->param('species_obj');
    # This is an option to insert but we don't do it in refget main ...
    # my $division_obj = $self->param('division_obj');
    my $source_obj = $self->param('source_obj');

    my ($seq_obj, $first_seen) = $self->insert_sequence($refget_schema, $seq_ref, $seq_hash);
    my $molecule_obj = $seq_obj->find_or_create_related(
        'molecules',
        {
            id => $id,
            first_seen => $first_seen,
            release => $release_obj,
            mol_type => $molecule_type_obj,
            source => $source_obj,
        }
    );
    return $molecule_obj;
}

sub insert_sequence {
    my ($self, $refget_schema, $seq_ref, $seq_hash) = @_;
    my $rs = $refget_schema->resultset('Seq');
    my $ga4gh_id = $seq_hash->{ga4gh};
    my %seq_hash_clone = %{$seq_hash};
    delete $seq_hash_clone{ga4gh};
    delete $seq_hash_clone{sha512t24u};
    # Logic taken from Refget::Schema::ResultSet::Seq so there is logic bleed here
    # Could be moved up
    print("$ga4gh_id\n......\n");
    my $seq_obj = $rs->find_or_new(\%seq_hash_clone, {key => 'seq_trunc512_uniq'});
    my $first_seen = 0;
    if(!$seq_obj->in_storage()) {
        $first_seen = 1;
        $seq_obj->insert();
        $self->insert_raw_sequence($refget_schema, $seq_ref, $ga4gh_id);
    }
    return ($seq_obj, $first_seen);
}

sub insert_raw_sequence {
    my ($self, $refget_schema, $seq_ref, $ga4gh_id) = @_;
    my $hash = ga4gh_to_trunc512($ga4gh_id);
    my $rs = $refget_schema->resultset('RawSeq');
    my $row = $rs->search(
        { checksum => $hash },
        { columns => [qw/ checksum /] }
    )->single();
    if($row) {
        return $row;
    }

    $row = { checksum => $hash, seq => ${$seq_ref} };
    my $raw_seq = $rs->new_result($row);
    return $raw_seq->insert();
}

##### Batch checksum attribute retrieval and checking

sub _verify_checksums_match {
    my ($self, $generated_checksums, $retreived_checksums, $type, $id, $db_id) = @_;
    foreach my $checksum (qw/md5 sha512t24u/) {
        my $calculated_checksum = $generated_checksums->{$checksum};
        my $stored_checksum = $retreived_checksums->{$checksum}->{$db_id};
        if($calculated_checksum ne $stored_checksum) {
            my $error_string = sprintf(
                'The stored %s %s checksum (%s) for ID %s dbID %d does not match the calculated checksum (%s)',
                $type, $checksum, $stored_checksum, $id, $db_id, $calculated_checksum
            );
            $self->throw($error_string);
        }
    }
    return 1;
}

sub _get_checksums_from_db {
    my ($self, $dba, $type, $checksum) = @_;
    my ($sql, $params) = $self->_get_attribute_sql_and_params($dba, $type, $checksum);
    my $lookup = $dba->dbc()->sql_helper()->execute_into_hash(-SQL => $sql, -PARAMS => $params);
    return $lookup;
}

sub _get_attribute_sql_and_params {
    my ($self, $dba, $type, $checksum) = @_;
    my $sql = q{};
    if($type eq 'toplevel') {
      $sql = << 'EOF';
SELECT sr.seq_region_id, att.value
FROM seq_region sr
JOIN coord_system cs on cs.coord_system_id = sr.coord_system_id
JOIN seq_region_attrib att ON sr.seq_region_id = att.seq_region_id
JOIN attrib_type at on att.attrib_type_id = at.attrib_type_id
WHERE cs.species_id =?
AND at.code =?
EOF
    }
    elsif ($type eq q{cdna} || $type eq q{cds}) {
      $sql = << 'EOF';
SELECT t.transcript_id, att.value
FROM transcript t
JOIN seq_region sr ON t.seq_region_id = sr.seq_region_id
JOIN coord_system cs on cs.coord_system_id = sr.coord_system_id
JOIN transcript_attrib att ON t.transcript_id = att.transcript_id
JOIN attrib_type at on att.attrib_type_id = at.attrib_type_id
WHERE cs.species_id =?
AND at.code =?
EOF
    }
    elsif ($type eq q{pep}) {
      $sql = << 'EOF';
SELECT tr.translation_id, att.value
FROM transcript t
JOIN seq_region sr ON t.seq_region_id = sr.seq_region_id
JOIN coord_system cs on cs.coord_system_id = sr.coord_system_id
JOIN translation tr ON t.transcript_id = tr.transcript_id
JOIN translation_attrib att ON tr.translation_id = att.translation_id
JOIN attrib_type at on att.attrib_type_id = at.attrib_type_id
WHERE cs.species_id =?
AND at.code =?
EOF
    }
    else {
        $self->throw("Given unknown sequence type '${type}'");
    }

    # Params set to the species id for the species and the attrib key for a checksum e.g. sha512t24u or md5
    my $params = [$dba->species_id(), $self->param('attrib_keys')->{$type}->{$checksum}];
    return ($sql, $params);
}

1;
