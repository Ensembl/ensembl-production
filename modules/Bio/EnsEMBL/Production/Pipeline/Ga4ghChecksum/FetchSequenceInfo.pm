=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2023] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::Ga4ghChecksum::FetchSequence

=head1 DESCRIPTION

Fetch the toplevel genomic sequences  chromosomes, super contigs  and other sequence cDNA, CDS and Peptide


=over 8 

=item 1 - Fetch Toplevel sequences

=item 2 - Fetch cDNA, CDS and Peptide sequences

=back

The script is responsible for genomic sequences for given sequence type

Allowed parameters are:

=over 8

=item species - The species to fetch the genomic sequence

=item sequence_type - The data to cetch. T<toplevel>, I<dna>, I<cdna> and I<pep> are allowed

=item release - A required parameter for the version of Ensembl we are dumping for

=item db_types - Array reference of the database groups to use. Defaults to core

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::Ga4ghChecksum::FetchSequenceInfo;

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
    my %flow = ('toplevel' => 2, 'cdna' => 3, 'cds' => 4, 'pep' => 5);

    $self->param('flow', \%flow);
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
    my $sequence_types = $self->param('sequence_types');
    my $slice_adaptor = $dba->get_SliceAdaptor();
    foreach my $seq_type (@{$sequence_types}) {
        $self->all_hashes($slice_adaptor, $seq_type);
    }
}


sub all_hashes {
    my ($self, $slice_adaptor, $seq_type) = @_;

    my $flow = $self->param('flow');
    my @slices = @{$slice_adaptor->fetch_all('toplevel', undef, 1, undef, undef)};
    my $species = $self->param('species');
    my $count = 0;
    my $hash_types = $self->param('hash_types');

    foreach my $slice (@slices) {
        my $flow_data = {
            'species'       => $species,
            'cs_name'       => $slice->coord_system()->name(),
            'seq_region_id' => $slice->get_seq_region_id(),
            'seq_type'      => $seq_type,
            'hash_types'    => $hash_types,
            'group'         => $self->param('group'),
        };
        if ($seq_type eq 'toplevel') {
            $self->do_sum($flow_data);
            $count++;
        } else {
            # get all transcript from slice
            my @transcripts = @{$slice->get_all_Transcripts()};
            foreach my $transcript (@transcripts) {
                foreach my $trans_seq_type (@$seq_type) {
                    $flow_data->{'transcript_id'} = $transcript->stable_id;
                    $flow_data->{'seq_type'} = $trans_seq_type;
                    $flow_data->{'transcript_dbid'} = $transcript->dbID();
                    my $translation_ad = $transcript->translation();
                    if ($trans_seq_type eq 'pep') {
                        if (defined $translation_ad) {
                            $flow_data->{'translation_dbid'} = $translation_ad->dbID();
                            $self->do_sum($flow_data);
                            $count++;
                        }
                    } else {
                        $self->do_sum($flow_data);
                        $count++;
                    }
                }
            }
        }
    } ## end foreach my $slice (@slices)

    # Write statistics to the hive DB
    my $status = "Inserted $count hashes (" .
        (ref $seq_type ? "@$seq_type" : $seq_type) .
        ")(@$hash_types) for species $species";
    $self->warning($status);
} ## end sub all_hashes


sub do_sum {
    my ($self, $flow_data) = @_;

    my ($genome_ad, $genome_feature, $sequence, $attrib_table, $genome_feature_id, $sequence_obj);
    my $hash_types = $flow_data->{'hash_types'};
    my $type = $flow_data->{'group'};
    my $species = $flow_data->{'species'};
    my $seq_type = $flow_data->{'seq_type'};

    my $dba = $self->get_DBAdaptor($type);
    my $registry = 'Bio::EnsEMBL::Registry';
    if (!$dba) {
        die("Cannot find adaptor for type $type");
    }
    my $attribute_adaptor = $dba->get_adaptor('Attribute');
    if ($seq_type eq 'toplevel') {
        $genome_ad = $registry->get_adaptor($species, $type, "Slice");
        $attrib_table = "seq_region";
        $genome_feature_id = $flow_data->{'seq_region_id'};
        $sequence_obj = $genome_ad->fetch_by_seq_region_id($flow_data->{'seq_region_id'});
    } elsif ($seq_type eq 'cdna' || $seq_type eq 'cds' || $seq_type eq 'pep') {
        $genome_ad = $registry->get_adaptor($species, $type, "Transcript");
        $genome_feature = $genome_ad->fetch_by_dbID($flow_data->{'transcript_dbid'});
        # create a seq object
        $sequence_obj = $genome_feature->seq;
        $attrib_table = "transcript";
        $genome_feature_id = $flow_data->{'transcript_dbid'};

        if ($seq_type eq 'cds') {
            $sequence_obj->seq($genome_feature->translateable_seq);
        }
        if ($seq_type eq 'pep') {
            $sequence_obj = $genome_feature->translate;
            $attrib_table = "translation";
            $genome_feature_id = $flow_data->{'translation_dbid'};
        }
    } else {
        die "Unknown $seq_type : valid seq_types are toplevel, cdna, cds, pep";
    }

    # generate hash and update the attrib tables
    # (seq_region_attrib, transcript_attrib, translation_attrib)
    foreach my $hash_method (@$hash_types) {
        my $at_code = $hash_method . "_" . $seq_type;
        my $sequence_hash = $self->generate_sequence_hash($sequence_obj, $hash_method);
        $self->update_attrib_table(
            $attribute_adaptor, $at_code, $sequence_hash, $genome_feature_id, $attrib_table
        );
    }
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


sub update_attrib_table {
    my ($self, $attribute_adaptor, $at_code, $secure_hash, $genome_feature_id, $attrib_table) = @_;

    my $attrib_obj = $attribute_adaptor->fetch_by_code($at_code);
    my $attrib = Bio::EnsEMBL::Attribute->new(
        -NAME => $attrib_obj->[2],
        -CODE => $attrib_obj->[1],
        -VALUE => $secure_hash,
        -DESCRIPTION => $attrib_obj->[3]
    );

    # method store_on_Object do not update the value rather it insert the new row when hashvalue
    # change if sequence changed
    my $attrib_info = $attribute_adaptor->fetch_all_by_Object(
        $genome_feature_id, $attrib_table, $attrib_obj->[1]
    );
    if (scalar @$attrib_info) {
        if (${$attrib_info->[0]}{'value'} ne $secure_hash) {
            $attribute_adaptor->remove_from_Object(
                $genome_feature_id, $attrib_table, $attrib_obj->[1]
            );
        }
    }
    $attribute_adaptor->store_on_Object($genome_feature_id, [$attrib], $attrib_table);
}

1;
