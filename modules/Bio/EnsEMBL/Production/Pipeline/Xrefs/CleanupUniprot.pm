=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License..

=cut

package Bio::EnsEMBL::Production::Pipeline::Xrefs::CleanupUniprot;

use strict;
use warnings;
use File::Path qw(make_path);
use Array::Utils qw(:all);

use parent qw/Bio::EnsEMBL::Production::Pipeline::Xrefs::Base/;

sub run {
  my ($self) = @_;

  my $base_path    = $self->param_required('base_path');
  my $db_url       = $self->param_required('db_url');
  my $name         = $self->param_required('name');
  my $version_file = $self->param('version_file');
  my $clean_files  = $self->param('clean_files');
  my $clean_dir    = $self->param_required('clean_dir');

  # Exit if not cleaning files or not a uniprot source
  if (!$clean_files) {return;}
  if ($name !~ /^Uniprot/) {return;}

  # Remove last '/' character if it exists
  if ($base_path =~ /\/$/) {chop($base_path);}

  # Remove / char from source name to access directory
  my $clean_name = $name;
  $clean_name =~ s/\///g;

  # Create needed directories
  my $output_path = $clean_dir."/".$clean_name;
  make_path($output_path);

  # Get xref sources
  my ($user, $pass, $host, $port, $source_db) = $self->parse_url($db_url);
  my $dbi = $self->get_dbi($host, $port, $user, $pass, $source_db);
  my %sources = get_source_names($dbi);

  # Set sources to skip
  my @source_names = (
    # Skipped in parsing step
    'GO', 'UniGene', 'RGD', 'CCDS', 'IPI', 'UCSC', 'SGD', 'HGNC', 'MGI', 'VGNC', 'Orphanet',
    'ArrayExpress', 'GenomeRNAi', 'EPD', 'Xenbase', 'Reactome', 'MIM_GENE', 'MIM_MORBID', 'MIM',
  );
  my $sources_to_remove = join("|", @source_names);

  # Get all files for source
  my $files_path = $base_path."/".$clean_name;
  my @files = `ls $files_path`;
  foreach my $file_name (@files) {
    $file_name =~ s/\n//;
    my $file = $files_path."/".$file_name;
    if (defined($version_file) && $file eq $version_file) {next;}

    my ($in_fh, $out_fh);
    my $output_file = $file_name;

    # Open file normally or with zcat for zipped filed
    if ($file_name =~ /\.(gz|Z)$/x) {
      open($in_fh, "zcat $file |")
        or die "Couldn't call 'zcat' to open input file '$file' $!";

      $output_file =~ s/\.[^.]+$//;
    } else {
      open($in_fh, '<', $file)
        or die "Couldn't open file input '$file' $!";
    }

    # Only start cleaning up if could get filehandle
    if (defined($in_fh)) {
      local $/ = "//\n";

      $output_file = $output_path."/".$output_file;
      open($out_fh, '>', $output_file)
        or die "Couldn't open output file '$output_file' $!";

      # Read full records
      while ($_ = $in_fh->getline()) {
        # Remove unused data
        $_ =~ s/R(N|P|X|A|T|R|L|C|G)\s{3}.*\n//g; # Remove references lines
        $_ =~ s/CC\s{3}.*\n//g; # Remove comments
        $_ =~ s/DR\s{3}($sources_to_remove);.*\n//g; # Remove sources skipped at processing

        # Added lines that we do need into output
        print $out_fh $_;
      }

      close($in_fh);
      close($out_fh);
    }
  }

  # Save the clean files directory in source db
  $dbi = $self->get_dbi($host, $port, $user, $pass, $source_db);
  my $update_version_sth = $dbi->prepare("UPDATE IGNORE version set clean_uri=? where source_id=(SELECT source_id FROM source WHERE name=?)");
  $update_version_sth->execute($output_path, $name);
  $update_version_sth->finish();
}

sub get_source_names {
  my $dbi = shift;
  my %source_names;

  my $sth = $dbi->prepare('SELECT name FROM source');
  $sth->execute();

  while (my @row = $sth->fetchrow_array()) {
    $source_names{$row[0]} = 1;
  }
  $sth->finish;

  return %source_names;
}

1;
