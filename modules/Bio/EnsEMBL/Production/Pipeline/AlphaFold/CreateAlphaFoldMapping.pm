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

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::AlphaFold::CreateAlphaFoldMapping

=head1 SYNOPSIS

This module prepares the mapping files for the AlphaFold data.

=head1 DESCRIPTION

- finds species from metadata file
- finds associated .tar files with protein predictions
- extracts protein info from contained PDB files

=cut

package Bio::EnsEMBL::Production::Pipeline::AlphaFold::CreateAlphaFoldMapping;

use warnings;
use strict;

use parent 'Bio::EnsEMBL::Production::Pipeline::Common::Base';

use Bio::EnsEMBL::Utils::Exception qw(throw info);

use open qw( :std :encoding(UTF-8) );

use JSON;
use Archive::Tar;
use Gzip::Faster;
use File::Path 'make_path';

sub fetch_input {
    my $self = shift;
    $self->param_required('species');
    $self->param_required('cs_version');
    $self->param_required('core_dbhost');
    $self->param_required('core_dbport');
    $self->param_required('core_dbname');
    $self->param_required('core_dbuser');
    $self->param_required('core_dbpass');
    $self->param_required('alphafold_data_dir');
    $self->param_required('alphafold_mapfile_dir');
    return 1;
}

sub run {
    my ($self) = @_;

    my $species = $self->param_required('species');
    my $alpha_path = $self->param_required('alphafold_data_dir');
    my $outpath = $self->param_required('alphafold_mapfile_dir');

    my $metafile = $alpha_path . '/download_metadata.json';
    my $datapath = $alpha_path . '/latest/';

    throw ("Metadata file not found at alphafold_data_dir/download_metadata.json ($metafile) on host " . `hostname`) unless -f $metafile;
    throw "Path for AlphaFold data not found at alphafold_data_dir/latest ($datapath)" unless -d $datapath;

    if (! -d $outpath) {
        make_path($outpath) or throw "Error creating alphafold_mapfile_dir ($outpath)";
    }

    my $metadata;
    {
        open my $fh, '<', $metafile or throw "Error opening metadata file '$metafile': $!";
        local $/ = undef;
        $metadata = <$fh>;
        close $fh;
    }

    my $meta_array = decode_json($metadata);

    my $done;
    my $outfile;

    foreach my $entry (@$meta_array) {
        my $filename = $entry->{species};
        next unless $filename;
        $filename = lc($filename);
        $filename =~ s/ /_/g;
        next unless $filename eq $species;

        my $archive_path = $datapath . $entry->{archive_name};

        next unless (-f $archive_path);

        $outfile = $outpath . "/" . $filename . ".map";
        open my $fh, '>', $outfile or throw "Error opening output file '$outfile': $!";

        print $fh extract($archive_path);
        close $fh;
        $done = 1;
        last;
    }
    if ($done) {
        my $dataflow_params = {
            species     => $species,
            cs_version  => $self->param('cs_version'),
            core_dbhost => $self->param('core_dbhost'),
            core_dbport => $self->param('core_dbport'),
            core_dbname => $self->param('core_dbname'),
            core_dbuser => $self->param('core_dbuser'),
            core_dbpass => $self->param('core_dbpass'),
            alphafold_mapfile => $outfile,
        };
        $self->dataflow_output_id($dataflow_params, 2);
    } else {
        info ("No AlphaFold data found for species $species.");
        # There is no dataflow if there is no data
    }

    return 1;
}

sub extract {
    my $tarfile = shift;
    my $tar  = Archive::Tar->new;
    $tar->read($tarfile);
    my @items = $tar->get_files;
    my @afdb_info;

    foreach my $file (@items) {
        next unless $file->name =~ /\.pdb\.gz$/;

        my $pdbgz = $file->get_content_by_ref;
        my $unz = gunzip( $$pdbgz );

        open my $pdbdata, '<', \$unz;

        while (my $line = <$pdbdata>) {
            if ($line =~ /^DBREF/) {
                my $clean_afdb = $file->name;
                $clean_afdb =~ s/-model_.*$//;
                my (undef, undef, $chain, $res_beg, $res_end, undef,
                    $sp_primary, undef, $sp_beg, $sp_end) = split(/\s+/, $line);

                push(@afdb_info,{'AFDB' => $clean_afdb,
                    'CHAIN' => $chain,
                    'SP_PRIMARY' => $sp_primary,
                    'RES_BEG' => $res_beg,
                    'RES_END' => $res_end,
                    'SP_BEG' => $sp_beg,
                    'SP_END' => $sp_end,
                    'SIFTS_RELEASE_DATE' => undef
                }) unless ($sp_beg > $sp_end);
                # Skips the entry if the start of the protein is greater than the end as we cannot display it correctly.

                last;
            }
        }
        close $pdbdata;
    }
    return encode_json(\@afdb_info);
}

# Dataflow (dataflow_output_id() happens in "sub run"
# sub write_output {}

1;
