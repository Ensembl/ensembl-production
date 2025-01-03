=head1 LICENSE

 Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 Copyright [2016-2025] EMBL-European Bioinformatics Institute

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.

=head1 CONTACT

 Please email comments or questions to the public Ensembl
 developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

 Questions may also be sent to the Ensembl help desk at
 <http://www.ensembl.org/Help/Contact>.

=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::AlphaFold::InsertProteinFeatures

=head1 DESCRIPTION

 This module inserts protein features into an Ensembl core database based on
 GIFTS data or the UniParc accessions that are present in the core DB. The
 protein features link to an Alphafold accession.

 For species where we have data in the GIFTS DB, we use this, because we assume
 this to be of higher quality. In this case we fetch a mapping from Ensembl
 stable ID of the transcript (ENST...) to UniProt accession for the protein
 (Q98C45).

 For species not in GIFTS, we fetch the UniParc IDs (UPI00...) from the core DB,
 where we have them as xrefs. We then use a DB to map the UniParc IDs to UniProt
 IDs.

 The next steps are now the same for both cases. With the UniProt accession, we
 select the matching Alphafold accession and associated information and insert
 new protein features based on this data.

 For multispecies DBs, this may only be run for one species. This can be any
 species from the collection. The analysis will cover the protein features for
 everything in the DB. Running it a second time would delete the analysis and
 then recreate it with identical features. Running the runnable in parallel
 would delete the analysis and might lead to an inconsistent DB with unlinked
 protein features.

=head1 OPTIONS

 -species        Production name of species to process. For a collection DB, any species from the DB
 -species_list   List of species production names. For a single species, a list
                 with just this species. For a collection DB, list of all species in the DB
 -db_dir         Path to the uniparc-to-uniprot DB and the uniprot-to-alpha DB, both in KyotoCabinet format
 -cs_version     Needed for GIFTS, otherwise optional. Name of assembly, like 'GRCh38'.
 - gifts_host    The GIFTS DB hostname
 - gifts_db      The GIFTS DB schema name
 - gifts_user    The GIFTS DB user name
 - gifts_pass    The GIFTS DB password

=head1 EXAMPLE USAGE

 standaloneJob.pl Bio::EnsEMBL::Production::Pipeline::AlphaFold::InsertProteinFeatures
  -cs_version GRCh38
  -species homo_sapiens
  -species_list "['homo_sapiens']"
  -db_dir /hps/scratch/...
  -registry my_reg.pm
  -gifts_pass 'ThePassword'

=cut

package Bio::EnsEMBL::Production::Pipeline::AlphaFold::InsertProteinFeatures;

use strict;
use warnings;

use parent 'Bio::EnsEMBL::Production::Pipeline::Common::Base';

use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::ProteinFeature;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw info);
use DBD::Pg; # For GIFTS
use KyotoCabinet;

sub fetch_input {
    my $self = shift;

    $self->param_required('species');
    $self->param_required('db_dir');
    $self->param_required('species_list');
    $self->param_required('gifts_pass');

    return 1;
}

sub run {
    my $self = shift;

    # Uncomment for verbose output - recommended when running standalone
    # Bio::EnsEMBL::Utils::Exception::verbose('INFO');

    my $db_path = $self->param_required('db_dir');
    my $idx_dir_al = $db_path . '/uniprot-to-alphafold/uniprot-to-alphafold.kch';
    my $idx_dir_up = $db_path . '/uniparc-to-uniprot/uniparc-to-uniprot.kch';

    my $species = $self->param_required('species');
    my $species_list = $self->param_required('species_list');

    my $log_species = $species;
    if ($species_list and @$species_list and @$species_list > 1) {
        $log_species = "collection (@$species_list)";
        info("This is a multi-species (collection) DB: $log_species\n");
    }

    # Fetch core adaptor from registry, ignore aliases
    my $core_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'core', 1);
    die "Registry did not return an adaptor for the species: $species" unless $core_dba;
    my $dbc = $core_dba->dbc;

    info("Cleaning up old protein features and analysis for species $species\n");
    $self->cleanup_protein_features('alphafold');

    info("Initiating and creating the analysis object for species $species\n");


    my $alpha_version = 0;
    my $mapsize_gb = 4 << 30;
    my $db = tie(my %db, 'KyotoCabinet::DB', "$idx_dir_al#msiz=$mapsize_gb#opts=l");
    # traverse records by iterator
    while (my ($key, $value) = each(%db)) {
        $alpha_version = (split ',', $value)[-1];
        chomp($alpha_version);
        last;
    }
    untie %db;
    untie $db;
    die "Unable to extract AlphaFold version" unless $alpha_version;

    my $alpha_db = new KyotoCabinet::DB;
    # Set 4 GB mmap size
    $alpha_db->open("$idx_dir_al#msiz=$mapsize_gb#opts=l",
        $alpha_db->OREADER
    ) or die "Error opening DB: " . $alpha_db->error();

    my $gifts_host = $self->param('gifts_host') // 'pgsql-hlvm-051.ebi.ac.uk';
    my $gifts_db = $self->param('gifts_db') // 'gtigftpro';
    my $gifts_user = $self->param('gifts_user') // 'giftsrw';
    my $gifts_pass = $self->param_required('gifts_pass');
    my $gifts_dbh = DBI->connect("dbi:Pg:dbname=$gifts_db;host=$gifts_host", $gifts_user, $gifts_pass,
        {AutoCommit => 0, RaiseError => 1, PrintError => 0}
    );

    my $analysis = new Bio::EnsEMBL::Analysis(
            -logic_name    => 'alphafold',
            -db            => 'alphafold',
            -db_version    => $alpha_version,
            -db_file       => $self->param('db_dir') . '/accession_ids.csv',
            -display_label => 'AFDB-ENSP mapping',
            -displayable   => '1',
            -description   => 'Protein features based on AlphaFold predictions, mapped with GIFTS or UniParc'
    );
    die "Error creating analysis object" unless $analysis;
    my $ana = $core_dba->get_AnalysisAdaptor();
    # We get undef in case of an error. The adaptor does warn, but the error string is not
    # accessible
    $ana->store($analysis) // die "Error storing analysis in DB. Runnable should be restarted";

    my $mappings;

    if (defined $self->param('cs_version')) {
        my $assembly = $self->param('cs_version');
        # grab GIFTS species / assembly data
        my $gifts_data = read_gifts_species($gifts_dbh);
        for my $row (@$gifts_data) {
            my ($g_species_id, $g_species, $g_assembly, $g_release) = @$row;
            info("Found species in GIFTS DB: species: $g_species, assembly: $g_assembly, release: $g_release");
            if ($g_assembly eq $assembly) {
                $mappings = read_gifts_data($gifts_dbh, $g_species_id);
                info("Read data for GIFTS, " . (scalar (keys %$mappings)) . " entries");
                last;
            }
        }
    }
    $gifts_dbh->disconnect();

    my $no_uniparc = 0;
    my $no_dbid = 0;
    my $protein_count = 0;
    my $no_alpha = 0;
    if (! $mappings or ! %$mappings) {

        # If we don't have data in $mappings, this species is not in GIFTS.
        # We'll use the uniparc ids that we have in the core database and map
        # them to the uniprot id and our translation ids (dbid). Then we add the
        # alphafold data using the uniprot id and insert a protein feature using
        # the dbid.

        my $uniprot_db = new KyotoCabinet::DB;
        # Set 4 GB mmap size
        my $mapsize_gb = 4 << 30;
        $uniprot_db->open("$idx_dir_up#msiz=$mapsize_gb#opts=l",
            $uniprot_db->OREADER
        ) or die "Error opening DB: " . $uniprot_db->error();

        # We currently have the same uniparc accession tied to the same
        # translation_id but in different versions (xref pipeline run
        # 'xrefchecksum' and 'uniparc_checksum')
        my $sql = "
            SELECT xr.dbprimary_acc as uniparc_id, tr.stable_id, tr.translation_id
            FROM xref xr, object_xref ox, translation tr
            where external_db_id = (SELECT external_db_id FROM external_db where db_name = 'UniParc')
                and xr.xref_id = ox.xref_id
                and ox.ensembl_id = tr.translation_id
                and ox.ensembl_object_type = 'Translation'
                group by uniparc_id, tr.stable_id, tr.translation_id
        ";

        my $sth = $dbc->prepare($sql);
        $sth->execute;
        while (my @row = $sth->fetchrow_array) {
            $protein_count++;
            my ($uniparc_id, $stable_id, $dbid) = @row;
            my $uniprot_str = $uniprot_db->get($uniparc_id);
            unless ($uniprot_str) {
                $no_uniparc++;
                next;
            }
            my @uniprots = split("\t", $uniprot_str);

            my $at_least_one_alpha_mapping = 0;
            for my $uniprot_id (@uniprots) {
                my $alpha_data = $alpha_db->get($uniprot_id);
                next unless $alpha_data;
                push @{$mappings->{$uniprot_id}},
                    {'uniparc' => $uniparc_id, 'dbid' => $dbid, 'ensid' => $stable_id, 'alpha' => $alpha_data};
                $at_least_one_alpha_mapping = 1;
            }
            unless ($at_least_one_alpha_mapping) {
                $no_alpha++;
                info("No alphafold data for: UniParc acc $uniparc_id, stable_id $stable_id, translation_id $dbid");
            }
        }
        info("Num proteins in DB $protein_count, no uniparc $no_uniparc");

        $uniprot_db->close() or die "Error closing DB: " . $uniprot_db->error();

    } else {

        info("Got mapping data from GIFTS");
        # If we have data in $mappings, we got data from GIFTS for this species.
        # Data will look like:
        # $mappings = {uniprot_id ('Q98C34') => ensid ('ENST0000')}
        # We'll use the stable id (ensid) to map to our translation id (dbid). Then we add the
        # alphafold data using the uniprot id and insert a protein feature using
        # the dbid.

        # rev_mappings = (ensid => [uniprot_id, ...])
        my %rev_mappings;
        while (my ($uniprot, $ensid_ref) = each %$mappings) {
            my @ensids = @$ensid_ref;
            for my $ensid (@ensids) {
                push @{$rev_mappings{$ensid}}, $uniprot;
            }
        }

        $mappings = {};

        my $sql = 'select tl.translation_id, tc.stable_id from translation tl, transcript tc
            where tl.transcript_id = tc.transcript_id';

        my $sth = $dbc->prepare($sql);
        $sth->execute;
        while (my @row = $sth->fetchrow_array) {
            $protein_count++;
            my ($dbid, $stable_id) = @row;

            unless (exists $rev_mappings{$stable_id}) {
                $no_dbid++;
                info("No entry in GIFTS for stable ID $stable_id");
                next;
            }
            my @rmap = @{$rev_mappings{$stable_id}};

            my $at_least_one_alpha_mapping = 0;
            for my $uniprot_id (@rmap) {
                my $alpha_data = $alpha_db->get($uniprot_id);
                next unless $alpha_data;
                push @{$mappings->{$uniprot_id}}, {'dbid' => $dbid, 'ensid' => $stable_id, 'alpha' => $alpha_data};
                $at_least_one_alpha_mapping = 1;
                info("Mapping found for $stable_id: $alpha_data");
            }
            unless (scalar @rmap) {
                $no_dbid++;
                info("No mapping data for stable ID $stable_id");
            }
            if (@rmap and ! $at_least_one_alpha_mapping) {
                $no_alpha++;
                info("No alphafold data for: stable_id $stable_id, translation_id $dbid, uniprot accessions: @rmap");
            }
        }
    }

    unless (scalar(keys %$mappings) > 0) {
        die(sprintf("No matches for species %s found in core DB %s\n", $species, $dbc->dbname()));
    }


    my $pfa = $core_dba->get_ProteinFeatureAdaptor();

    my $good = 0;

    info("Unique UniProt accessions for species after mapping: " . scalar (keys %$mappings));
    for my $uniprot (keys %$mappings) {
        for my $entry (@{$mappings->{$uniprot}}) {

            my $uniparc = $entry->{'uniparc'};
            my $ensid = $entry->{'ensid'};
            my $translation_id = $entry->{'dbid'};
            my $alpha_data = $entry->{'alpha'};

            unless ($alpha_data) {
                die("There is an entry in the mappings hash, but alphafold data is missing for entry: " .
                    "uniprot $uniprot, stable_id $ensid, translation_id $translation_id");
            }
            $good++;

            chomp($alpha_data);
            # A0A2I1PIX0 => 1,200,AF-A0A2I1PIX0-F1,4
            my ($al_start, $al_end, $alpha_accession, $alpha_version) = split(",", $alpha_data);

            my $comment = 'Mapped ';
            if ($uniparc) {
                $comment .= "direct from UniParc $uniparc to UniProt $uniprot, " .
                "Ensembl stable ID $ensid, alpha_version $alpha_version)";
            } else {
                $comment .= "using GIFTS DB (UniProt $uniprot, Ensembl stable ID $ensid), alpha_version $alpha_version)";
            }

            info("Protein feature: start $al_start, end $al_end, $alpha_accession: $comment");

            my $pf = Bio::EnsEMBL::ProteinFeature->new(
                    -start    => $al_start,
                    -end      => $al_end,
                    -hseqname => $alpha_accession,
                    -hstart   => $al_start,
                    -hend     => $al_end,
                    -analysis => $analysis,
                    -hdescription => $comment,
            );

            # We get undef in case of an error. The adaptor does warn, but the error string is not
            # accessible
            $pfa->store($pf, $translation_id) // die "Storing protein feature failed. Runnable should be restarted";
        }
    }
    
    $alpha_db->close() or die "Error closing DB: " . $alpha_db->error();

    # Info line to be stored in the hive DB
    my $covered_proteins = $protein_count - $no_dbid - $no_uniparc - $no_alpha;
    $self->warning(
        "Inserted $good protein features. Num of proteins for species: $protein_count " .
        "with at least one mapping for $covered_proteins. ".
        "No UniParc to UniProt mappings: $no_uniparc; No GIFTS mappings for stable ID: $no_dbid; " .
        "No link from UniProt to Alphafold (for any UniProt accession found through UniParc): $no_alpha. " .
        "Species: $log_species"
    );
}

# Reads info about available species from GIFTS. Will use the latest release for
# which GIFTS data is available. This is probably older than the release the
# pipeline is running with. Since the species in GIFTS are unlikely to see
# updates in the Core DBs, this is likely not an issue.
# Returns an arrayref like: [[ensembl_species_history_id, species, assembly, ensembl_release], ...]
sub read_gifts_species {
    my $dbh = shift;

    my $sql = "
        select ensembl_species_history_id, species, assembly_accession as assembly, ensembl_release as release
        from ensembl_gifts.ensembl_species_history
        where ensembl_release = (select max(ensembl_release) from ensembl_gifts.ensembl_species_history)
        order by ensembl_species_history_id
    ";

    my $sth = $dbh->prepare($sql);
    $sth->execute();
    return $sth->fetchall_arrayref();
}

# Read GIFTS data from DB, return a hash-ref like:
# { 'A0A0G2K0H5' => [ 'ENSRNOT00000083658' ], 'B5DEL8' => [ 'ENSRNOT00000036389' ], ...}
sub read_gifts_data {
    my $dbh = shift;
    my $ensembl_species_history_id = shift;

    my $sql = "
        select et.enst_id, ue.uniprot_acc
        from ensembl_gifts.alignment al
        inner join ensembl_gifts.alignment_run alr ON alr.alignment_run_id = al.alignment_run_id
        inner join ensembl_gifts.release_mapping_history rmh ON rmh.release_mapping_history_id = alr.release_mapping_history_id
        inner join ensembl_gifts.ensembl_species_history esh ON esh.ensembl_species_history_id = rmh.ensembl_species_history_id
        inner join ensembl_gifts.ensembl_transcript et ON et.transcript_id = al.transcript_id
        inner join ensembl_gifts.uniprot_entry ue ON ue.uniprot_id = al.uniprot_id
        where score1_type = 'perfect_match'
            and alr.ensembl_release = esh.ensembl_release
            and rmh.ensembl_species_history_id = ?
    ";

    my $sth = $dbh->prepare($sql);
    $sth->execute($ensembl_species_history_id);

    my %uniprot_ensid;
    while (my $row = $sth->fetchrow_arrayref()) {
        my ($ensid, $uniprot) = @$row;
        # A protein may have isoforms. In Uniprot, their reference looks like
        # e.g. F1RA39-1. Alphafold currently only has data for the canonical
        # sequence. Here, we just remove the isoform reference and always refer
        # to the Alphafold data for the canonical sequence.
        $uniprot =~ s/-\d+//;
        push @{$uniprot_ensid{$uniprot}}, $ensid;
    }
    return \%uniprot_ensid;
}

# cleans up the protein features from the database 'core_dba'
sub cleanup_protein_features {
    my ($self, $analysis_logic_name) = @_;

    my $core_dba = $self->core_dba;
    my $ana      = $core_dba->get_AnalysisAdaptor();

    my $analysis = $ana->fetch_by_logic_name($analysis_logic_name);

    if (defined($analysis)) {
        my $analysis_id = $analysis->dbID();
        info(sprintf(
                "Found alphafold analysis (ID: $analysis_id) for species %s. Deleting it.\n", $self->param('species')
            )
        );

        my $pfa = $core_dba->get_ProteinFeatureAdaptor();
        $pfa->remove_by_analysis_id($analysis_id);
        $ana->remove($analysis);
    }
}

1;
