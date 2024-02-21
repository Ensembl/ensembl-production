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

Bio::EnsEMBL::Production::Pipeline::Ga4ghChecksum::ChecksumGenerator

=head1 DESCRIPTION

This module calculates checksums for sequence data and inserts it into the
corresponding attrib tables.
This covers genomic sequence data as well as sequence for cDNA, CDS and peptides.
Currently, MD5 and SHA512 hashes are supported.

Allowed parameters are:

=over 8

=item species - The species to fetch the genomic sequence

=item sequence_type - The data to fetch. I<toplevel>, I<dna>, I<cdna> and I<pep> are allowed

=item release - A required parameter for the version of Ensembl we are dumping for

=item db_types - Array reference of the database groups to use. Defaults to core

=item hash_types - Array of all the hash types we want to calculate.
      Only I<md5> and I<sha512t24u> are supported

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::Ga4ghChecksum::ChecksumGenerator;

use strict;
use warnings;

use Digest::SHA;
use Digest::MD5;
use MIME::Base64 qw/encode_base64url/;
use Encode;
use Bio::EnsEMBL::Attribute;
use Bio::EnsEMBL::Registry;

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;


sub param_defaults {
    my ($self) = @_;

    return {
        digest_size => 24,
        chunk_size  => 100000,
    };
}


sub fetch_input {
    my ($self) = @_;

    my $sequence_types = $self->param('sequence_types');
    my $hash_types = $self->param('hash_types');

    # allowed sequence types
    my %ast = ('toplevel' => 1, 'cdna' => 1, 'cds' => 1, 'pep' => 1);
    # allowed hash types
    my %aht = ('md5' => 1, 'sha512t24u' => 1);

    my @disallowed = grep {! $ast{$_}} @$sequence_types;
    die "Sequence type unknown: @disallowed" if @disallowed;
    @disallowed = grep {! $aht{$_}} @$hash_types;
    die "Hash type unknown: @disallowed" if @disallowed;

    if (defined $sequence_types && scalar(@$sequence_types) > 0) {
        my @temp_array = grep (!/toplevel/, @{$sequence_types});
        @{$sequence_types} = grep (/toplevel/, @{$sequence_types});
        push @{$sequence_types}, \@temp_array if @temp_array;
    } else {
        $sequence_types = ['toplevel', ['cdna', 'cds', 'pep']];
    }
    $hash_types = ['sha512t24u', 'md5'] unless $hash_types;
    $self->param('sequence_types', $sequence_types);
    $self->param('hash_types',     $hash_types);
    
    return;
}


sub run {
    my ($self) = @_;
    
    my $type = $self->param('group');
    my $dba = $self->get_DBAdaptor($type);
    if (!$dba) {
        die("Cannot find adaptor for type $type");
    }

    $self->delete_checksums($dba);

    my $sequence_types = $self->param('sequence_types');
    my $slice_adaptor = $dba->get_SliceAdaptor();
    foreach my $seq_type (@{$sequence_types}) {
        $self->all_hashes($slice_adaptor, $seq_type);
    }
}


sub all_hashes {
    my ($self, $slice_adaptor, $seq_type) = @_;

    my @slices = @{$slice_adaptor->fetch_all('toplevel', undef, 1, undef, undef)};
    my $species = $self->param('species');
    my $type = $self->param('group');
    my $hash_types = $self->param('hash_types');
    my $count = 0;

    my $dba = $self->get_DBAdaptor($type);
    my $registry = 'Bio::EnsEMBL::Registry';
    if (!$dba) {
        die("Cannot find adaptor for type $type");
    }
    my $attribute_adaptor = $dba->get_adaptor('Attribute');

    # generate all hashes and keep them in memory, then submit them as batches
    # to the DB.
    # This will update the attrib tables
    # (seq_region_attrib, transcript_attrib, translation_attrib)

    # Data is structured like: {$seq_type => {$attrib_table => [obj_dbid, attrib_type, hash]}}
    my $batch;

    foreach my $slice (@slices) {
        my $seq_region_id = $slice->get_seq_region_id();

        if ($seq_type eq 'toplevel') {
            my $genome_ad = $registry->get_adaptor($species, $type, "Slice");
            my $attrib_table = "seq_region";
            my $genome_feature_id = $slice->get_seq_region_id();
            my $sequence_obj = $genome_ad->fetch_by_seq_region_id($seq_region_id);

            my $hashes = $self->do_sum($attribute_adaptor, $hash_types, $seq_type, $sequence_obj);
            push @{$batch->{$seq_type}->{$attrib_table}->{$genome_feature_id}}, @$hashes;
            $count += @$hashes;
        } else {
            # get all transcript from slice
            my $genome_ad = $registry->get_adaptor($species, $type, "Transcript");
            my @transcripts = @{$slice->get_all_Transcripts()};

            foreach my $transcript (@transcripts) {
                my $transcript_dbid = $transcript->dbID();
                my $genome_feature = $genome_ad->fetch_by_dbID($transcript_dbid);

                foreach my $trans_seq_type (@$seq_type) {
                    if ($trans_seq_type eq 'pep') {
                        my $translation_ad = $transcript->translation();
                        if (defined $translation_ad) {
                            my $sequence_obj = $genome_feature->translate;
                            my $attrib_table = "translation";
                            my $genome_feature_id = $translation_ad->dbID();

                            my $hashes = $self->do_sum($attribute_adaptor, $hash_types, $trans_seq_type, $sequence_obj);
                            push @{$batch->{$seq_type}->{$attrib_table}->{$genome_feature_id}}, @$hashes;
                            $count += @$hashes;
                        }
                    } else {
                        # $trans_seq_type is cds / cdna

                        # create a seq object
                        my $sequence_obj = $genome_feature->seq;
                        my $attrib_table = "transcript";
                        my $genome_feature_id = $transcript_dbid;

                        if ($trans_seq_type eq 'cds') {
                            $sequence_obj->seq($genome_feature->translateable_seq);
                        }

                        # Only add if we have an actual sequence. We don't have translatable_seq if we don't have a 
                        # translation. MD5 checksums of d41d8cd98f00b204e9800998ecf8427e and sha512t24u of
                        # z4PhNX7vuL3xVChQ1m2AB9Yg5AULVxXc are smells of creating sequence checksums
                        # with zero content
                        if($sequence_obj->seq() ne q{}) {
                            my $hashes = $self->do_sum($attribute_adaptor, $hash_types, $trans_seq_type, $sequence_obj);
                            push @{$batch->{$seq_type}->{$attrib_table}->{$genome_feature_id}}, @$hashes;
                            $count += @$hashes;
                        }
                    }
                }
            }
        }
    } ## end foreach my $slice (@slices)

    for my $seq_type (keys %$batch) {
        for my $attrib_table (keys $batch->{$seq_type}) {
            $attribute_adaptor->store_batch_on_Object($attrib_table, $batch->{$seq_type}->{$attrib_table}, 1000);
        }
    }

    # Write statistics to the hive DB
    my $status = "Inserted $count hashes (" .
        (ref $seq_type ? "@$seq_type" : $seq_type) .
        ")(@$hash_types) for species $species";
    $self->warning($status);
} ## end sub all_hashes


my %attr_type;
sub do_sum {
    my ($self, $attribute_adaptor, $hash_types, $seq_type, $sequence_obj) = @_;

    my @hashes;
    foreach my $hash_method (@$hash_types) {
        my $at_code = $hash_method . "_" . $seq_type;
        # generate hash for a single object and hash type
        my $sequence_hash = $self->generate_sequence_hash($sequence_obj, $hash_method);

        unless (exists $attr_type{$at_code}) {
            # This fetches just the attrib type info
            $attr_type{$at_code} = $attribute_adaptor->fetch_by_code($at_code);
        }
        my $attrib_obj = $attr_type{$at_code};

        my $attrib = Bio::EnsEMBL::Attribute->new(
            -NAME => $attrib_obj->[2],
            -CODE => $attrib_obj->[1],
            -VALUE => $sequence_hash,
            -DESCRIPTION => $attrib_obj->[3]
        );
        push @hashes, $attrib;
    }

    return \@hashes;
} ## end sub do_sum


sub generate_sequence_hash {
    my ($self, $sequence_obj, $hash_method) = @_;

    my $sequence_hash;
    if ($hash_method eq 'sha512t24u') {
        $sequence_hash = $self->sha512t24u($sequence_obj);
    } elsif ($hash_method eq "md5") {
        $sequence_hash = $self->md5($sequence_obj);
    } else {
        die "Unknown hash method $hash_method, valid hash methods ex: 'sha512t24u', 'md5'";
    }

    return $sequence_hash;
}


sub sha512t24u {
    my ($self, $sequence_obj) = @_;

    my $digest_size = 24;
    my $sha = Digest::SHA->new(512);
    $sha = $self->sequence_stream_digest($sequence_obj, $sha);
    my $digest = $sha->digest;
    my $base64 = encode_base64url($digest);
    my $substr_offset = int($digest_size/3)*4;

    return substr($base64, 0, $substr_offset);
}


sub md5 {
    my ($self, $sequence_obj) = @_;

    my $md5 = Digest::MD5->new;
    $md5 = $self->sequence_stream_digest($sequence_obj, $md5);
    my $digest = $md5->hexdigest;

    return $digest;
}


sub sequence_stream_digest {
    my ($self, $sequence_obj, $hash_obj) = @_;

    my $chunk_size = $self->param('chunk_size');
    my $start = 1;
    my $end = $sequence_obj->length();
    my $seek = $start;
    while ($seek <= $end) {
        my $seek_upto = $seek + $chunk_size - 1;
        $seek_upto = $end if ($seek_upto > $end);
        my $seq = encode("utf8", $sequence_obj->subseq($seek, $seek_upto));
        $hash_obj->add($seq);
        $seek = $seek_upto + 1;
    }

    return $hash_obj;
}



# Clean up checksums. This will delete the checksums matching the supplied
# parameters for the current species.
sub delete_checksums {
    my $self = shift;
    my $dba = shift;

    my $sequence_types = $self->param('sequence_types');
    my $hash_types = $self->param('hash_types');
    my $species = $self->param('species');

    # We have to flatten the list again
    my @st = map { ref eq 'ARRAY' ? @$_ : $_ } @$sequence_types;

    foreach my $seq_type (@st) {

        my $sql;
        my $attrib_name;
        if ($seq_type eq 'toplevel') {
            $attrib_name = "seq_region";
            $sql = "
                delete seq_region_attrib from seq_region_attrib
                    inner join seq_region using (seq_region_id)
                    inner join coord_system using (coord_system_id)
                    inner join meta using (species_id)
                    inner join attrib_type using (attrib_type_id)
                    where coord_system.species_id = ?
                        and code = ?
            ";
        } elsif ($seq_type eq 'cdna' or $seq_type eq 'cds') {
            $attrib_name = "transcript";
            $sql = "
                delete transcript_attrib from transcript_attrib
                    inner join transcript using (transcript_id)
                    inner join seq_region using (seq_region_id)
                    inner join coord_system using (coord_system_id)
                    inner join meta using (species_id)
                    inner join attrib_type using (attrib_type_id)
                    where coord_system.species_id = ?
                        and code = ?
            ";
        } elsif ($seq_type eq 'pep') {
            $attrib_name = "translation";
            $sql = "
                delete translation_attrib from translation_attrib
                    inner join translation using (translation_id)
                    inner join transcript using (transcript_id)
                    inner join seq_region using (seq_region_id)
                    inner join coord_system using (coord_system_id)
                    inner join meta using (species_id)
                    inner join attrib_type using (attrib_type_id)
                    where coord_system.species_id = ?
                        and code = ?
            ";
        }
        my $attrib_table = $attrib_name . '_attrib';

        my $hash_types = $self->param('hash_types');
        foreach my $hash_type (@$hash_types) {
            my $at_code = $hash_type . "_" . $seq_type;

            my $sth = $dba->dbc->db_handle->prepare($sql);
            my $records = $sth->execute($dba->species_id(), $at_code);
            $self->warning("Deleted $records for species $species, type $at_code from table $attrib_table");
        }
    }
}

1;
