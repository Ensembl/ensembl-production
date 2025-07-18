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

=cut

package Bio::EnsEMBL::Production::Pipeline::Xrefs::ScheduleSource;

use strict;
use warnings;
use XrefParser::Database;
use File::Basename;
use File::Spec::Functions;
use Carp;

use parent qw/Bio::EnsEMBL::Production::Pipeline::Xrefs::Base/;


sub run {
  my ($self) = @_;

  my $species          = $self->param_required('species');
  my $release          = $self->param_required('release');
  my $sql_dir          = $self->param_required('sql_dir');
  my $order_priority   = $self->param_required('priority');

  my $source_url       = $self->param_required('source_url');
  my $source_xref      = $self->param('source_xref');

  my $db_url           = $self->param('xref_url');
  my $user             = $self->param('xref_user');
  my $pass             = $self->param('xref_pass');
  my $host             = $self->param('xref_host');
  my $port             = $self->param('xref_port');

  my $preparse = 0;

  if ($db_url) {
    ($user, $pass, $host, $port) = $self->parse_url($db_url);
  }
  my ($xref_source_user, $xref_source_pass, $xref_source_host, $xref_source_port, $xref_source_db, $xref_source_dbi);
  if ($source_xref) {
    ($xref_source_user, $xref_source_pass, $xref_source_host, $xref_source_port, $xref_source_db) = $self->parse_url($source_xref);
    $xref_source_dbi = $self->get_dbi($xref_source_host, $xref_source_port, $xref_source_user, $xref_source_pass, $xref_source_db);
    $preparse = 1;
  }

  # Create Xref database
  my $dbname = $species . "_xref_update_" . $release;
  my $dbc = XrefParser::Database->new({
            host    => $host,
            dbname  => $dbname,
            port    => $port,
            user    => $user,
            pass    => $pass });
  if ($order_priority == 1) {
    $dbc->create($sql_dir, 1, 1, $preparse, $xref_source_dbi);

    if ($self->param_exists('pipeline_part')) {
      my $species_sth = $self->dbc->prepare("INSERT INTO updated_species (species_name) VALUES (?)");
      $species_sth->execute($species);
    }
  }
  my $xref_db_url = sprintf("mysql://%s:%s@%s:%s/%s", $user, $pass, $host, $port, $dbname);
  my $xref_dbi = $dbc->dbi();

  my $species_id = $self->get_taxon_id($species);
  my $division_id = $self->get_division_id($species);

  # Retrieve list of sources from versioning database
  my ($source_user, $source_pass, $source_host, $source_port, $source_db) = $self->parse_url($source_url);
  my $dbi = $self->get_dbi($source_host, $source_port, $source_user, $source_pass, $source_db);
  my $select_source_sth = $dbi->prepare("SELECT distinct name, parser, uri, clean_uri, index_uri, count_seen, preparse, revision FROM source s, version v WHERE s.source_id = v.source_id order by name");
  my ($name, $parser, $file_name, $clean_file_name, $dataflow_params, $db, $priority, $release_file);
  $select_source_sth->execute();
  $select_source_sth->bind_columns(\$name, \$parser, \$file_name, \$clean_file_name, \$db, \$priority, \$preparse, \$release_file);

  my $hgnc_path;

  while ($select_source_sth->fetch()) {
    $hgnc_path = $file_name if ($name eq 'HGNC');

    if (defined $db && $db eq 'checksum') { next; }
    if ($priority != $order_priority) { next; }
    if (defined $clean_file_name) { $file_name = $clean_file_name; }

    # Some sources are species-specific
    my $source_id = $self->get_source_id($xref_dbi, $parser, $species_id, $name, $division_id);
    if (!defined $source_id) { next; }

    # Some sources need connection to a species database
    my $dba;
    if (defined $db) {
      my $registry = 'Bio::EnsEMBL::Registry';
      $dba = $registry->get_DBAdaptor($species, $db);
      if (!$dba) {
        # Not all species have an otherfeatures database
        if ($db eq 'otherfeatures') {
          next;
        } else {
          confess("Cannot use $parser for $species, no $db database") unless $dba;
        }
      }
    }

    if ($file_name eq 'Database') {
     $dataflow_params = {
        species       => $species,
        species_id    => $species_id,
        parser        => $parser,
        source        => $source_id,
        xref_url      => $xref_db_url,
        db            => $db,
        release_file  => $release_file,
        file_name     => $file_name
      };
      $self->dataflow_output_id($dataflow_params, 2);
    } else {
      # Create list of files
      opendir(my $dir_handle, $file_name);
      my @temp_list_files = readdir($dir_handle);
      closedir($dir_handle);

      my @list_files;
      foreach my $file (@temp_list_files) {
        next if ($file =~ /^\./);
        push(@list_files, $file_name . "/" . $file);
      }
      if ($preparse) { @list_files = $preparse; }

      # For Uniprot and Refseq, files might have been split by species
      if (!$preparse && ($name =~ /^Uniprot/ || $name =~ /^RefSeq_peptide/ || $name =~ /^RefSeq_dna/)) {
        my $file_prefix = ($name =~ /SPTREMBL/ ? 'uniprot_trembl' : ($name =~ /SWISSPROT/ ? 'uniprot_sprot' : ($name =~ /_dna/ ? 'refseq_rna' : 'refseq_protein')));
        my @species_list_files = glob($file_name . "/**/**/**/**/" . $file_prefix . "-" . $species_id);
        if (scalar(@species_list_files) > 0) {
          @list_files = @species_list_files;
        }
      }

      # For ZFIN, we only need 1 job (parser handles all the files)
      if ($name eq 'ZFIN_ID') {
        @list_files = $list_files[0];
      }

      foreach my $file (@list_files) {
        $file =~ s/\n//;
        if (!-f $file) { next; }
        if (defined $release_file and $file eq $release_file) { next; }
  
        $dataflow_params = {
          species       => $species,
          species_id    => $species_id,
          parser        => $parser,
          source        => $source_id,
          xref_url      => $xref_db_url,
          db            => $db,
          release_file  => $release_file,
          priority      => $priority,
          file_name     => $file
        };
        if ($name =~ /^Uniprot/) {
          my @hgnc_files = glob( $hgnc_path . '/*' );
          $dataflow_params->{hgnc_file} = $hgnc_files[0];
        }
        $self->dataflow_output_id($dataflow_params, 2);
      }
    }
  }
  $dataflow_params = {
    xref_url    => $xref_db_url,
    species     => $species
  };
  $self->dataflow_output_id($dataflow_params, 1);

  $select_source_sth->finish();

}

1;

