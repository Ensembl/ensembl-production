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

package Bio::EnsEMBL::Production::Pipeline::FileDump::Base;

use strict;
use warnings;
use feature 'say';
use base ('Bio::EnsEMBL::Hive::Process');

use File::Spec::Functions qw/catdir splitdir/;

sub param_defaults {
  my ($self) = @_;

  return {
    %{$self->SUPER::param_defaults},
    db_type             => 'core',
    species_dirname     => 'species',
    timestamped_dirname => 'timestamped',
    web_dirname         => 'web',
    genome_dirname      => 'genome',
    geneset_dirname     => 'geneset',
    rnaseq_dirname      => 'rnaseq',
    variation_dirname   => 'variation',
    homology_dirname    => 'homology',
    stats_dirname       => 'statistics'
  };
}

sub dba {
  my ($self, $species, $db_type) = @_;
  $species = $self->param_required('species') unless defined $species;
  $db_type = $self->param_required('db_type') unless defined $db_type;

  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species, $db_type);
  unless (defined $dba) {
    $self->throw("Could not find $species $db_type database in registry");
  }

  return $dba;
}

sub assembly {
  my ($self, $dba) = @_;
  $self->throw("Missing dba parameter: assembly method") unless defined $dba;

  my $mca = $dba->get_adaptor('MetaContainer');
  my $assembly = $mca->single_value_by_key('assembly.accession');

  return $assembly;
}

sub geneset {
  my ($self, $dba) = @_;
  $self->throw("Missing dba parameter: geneset method") unless defined $dba;

  my $mca = $dba->get_adaptor('MetaContainer');
  my $geneset = $mca->single_value_by_key('genebuild.last_geneset_update');
  if (! defined $geneset) {
    $geneset = $mca->single_value_by_key('genebuild.start_date');
    $geneset =~ s/(\d+\-\d+).*/$1/;
  }
  $geneset =~ s/[\-\s]/_/g;

  return $geneset;
}

sub annotation_source {
  my ($self, $dba) = @_;
  $self->throw("Missing dba parameter: annotation_source method") unless defined $dba;

  my $mca = $dba->get_adaptor("MetaContainer");
  my $annotation_source = $mca->single_value_by_key('species.annotation_source');
  if (!defined $annotation_source || $annotation_source eq '') {
    return 'ensembl';
  }

  return lc $annotation_source;
}


sub species_name {
  my ($self, $dba) = @_;
  $self->throw("Missing dba parameter: species_name method") unless defined $dba;

  my $mca = $dba->get_adaptor("MetaContainer");
  my $species_name = $mca->single_value_by_key('species.display_name');
  if (defined $species_name and $species_name ne '') {
    $species_name =~ s/^([\w ]+) [\-\(].+/$1/;
    $species_name =~ s/ /_/g;
  } else {
    $self->throw("No species.display_name");
  }

  return $species_name;
}

sub repeat_mask_date {
  my ($self, $dba) = @_;
  $self->throw("Missing dba parameter: repeat_mask_date method") unless defined $dba;

  my $sql = qq/
    SELECT MAX(DATE_FORMAT(created, "%Y%m%d")) FROM
      analysis a INNER JOIN
      meta m ON a.logic_name = m.meta_value
    WHERE
      m.meta_key = 'repeat.analysis'
  /;
  my $result = $dba->dbc->sql_helper->execute_simple(-SQL => $sql);

  if (scalar(@$result)) {
    return $result->[0];
  } else {
    return '00000000';
  }
}

sub get_slices {
  my ($self, $dba) = @_;
  $self->throw("Missing dba parameter: get_slices method") unless defined $dba;

  my $sa = $dba->get_adaptor('Slice');
  my @slices = @{ $sa->fetch_all('toplevel', undef, 1, undef, undef) };

  if ($dba->species eq 'homo_sapiens') {
    my $mca = $dba->get_adaptor('MetaContainer');
    my $assembly = $mca->single_value_by_key('assembly.default');
    if ($assembly eq 'GRCh38') {
      @slices = grep {
        if ( $_->seq_region_name() eq 'Y' &&
             ( $_->end() < 2781480 || $_->start() > 56887902 ) )
        {
          0;
        } else {
          1;
        }
      } @slices;
    } else {
      $self->throw("Cannot filter PAR region for Human assembly $assembly");
    }
  }
  $dba->dbc->disconnect_if_idle();

  my @chr     = ();
  my @non_chr = ();
  my @non_ref = ();
  foreach my $slice (sort { $b->length <=> $a->length } @slices) {
    if ($slice->is_reference) {
      if ($slice->is_chromosome) {
        push @chr, $slice;
      } else {
        push @non_chr, $slice;
      }
    } else {
      push @non_ref, $slice;
    }
  }

  return (\@chr, \@non_chr, \@non_ref);
}

sub has_chromosomes {
  my ($self, $dba) = @_;

  return $self->has_seq_region_attribs($dba, 'karyotype_rank');
}

sub has_non_refs {
  my ($self, $dba) = @_;

  return $self->has_seq_region_attribs($dba, 'non_ref');
}

sub has_seq_region_attribs {
  my ($self, $dba, $code) = @_;
  $self->throw("Missing dba parameter: has_seq_region_attribs method") unless defined $dba;

  my $sql = q/
    SELECT COUNT(*) FROM
      attrib_type at INNER JOIN
      seq_region_attrib sra USING (attrib_type_id) INNER JOIN
      seq_region sr USING (seq_region_id) INNER JOIN
      coord_system cs USING (coord_system_id)
    WHERE cs.species_id = ? AND at.code = ?
  /;

  my $count = $dba->dbc()->sql_helper()->execute_single_result
  (
    -SQL => $sql,
    -PARAMS => [$dba->species_id(), $code]
  );

  return $count;
}

sub assert_executable {
  my ($self, $exe) = @_;

  $exe =~ s/\s+.+//;

  if ( !-x $exe ) {
    my $output = `which $exe 2>&1`;
    chomp $output;
    my $rc = $? >> 8;

    if ( $rc != 0 ) {
      my $possible_location = `locate -l 1 $exe 2>&1`;
      my $loc_rc = $? >> 8;

      if ( $loc_rc != 0 ) {
        $self->throw("Cannot find the executable '$exe'");
      }
    }
  }

  return 1;
}

sub run_cmd {
  my ($self, $cmd) = @_;

  my $output = `$cmd 2>&1`;
  my $rc     = $? >> 8;
  $self->throw(
    "Cannot run program '$cmd'. Return code: ${rc}. Output: $output"
  ) if $rc;

  return ($rc, $output);
}

sub create_symlink {
  my ($self, $from, $to) = @_;

  # Most efficient approach is to try to create the link,
  # and delete then recreate if it exists.
  my $success = symlink($from, $to);
  unless ($success) {
    if ($!{EEXIST}) {
      unlink($to) or $self->throw("Failed to remove symlink at $to");
      $success = symlink($from, $to);
      unless ($success) {
        $self->throw("Failed to create symlink from $from to $to");
      }
    } else {
      $self->throw("Failed to create symlink from $from to $to");
    }
  }
}

sub repo_location {
  my ($self) = @_;

  my $repo_name = 'ensembl-production';

  foreach my $location (@INC) {
    my @dirs = splitdir($location);
    if (scalar(@dirs) >= 2) {
      if ($dirs[-2] eq $repo_name) {
        pop @dirs;
        return catdir(@dirs);
      }
    }
  }

  die "$repo_name was not found in \@INC:\n" . join("\n", @INC);
}

1;
