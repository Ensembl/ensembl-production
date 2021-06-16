=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::ProteinFeatures::AnalysisConfiguration;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

use Path::Tiny;
use POSIX qw(strftime);

sub run {
  my ($self) = @_;
  my $interproscan_exe     = $self->param_required('interproscan_exe');
  my $interproscan_version = $self->param_required('interproscan_version');
  my $pf_analyses          = $self->param_required('protein_feature_analyses');
  my $check_db_version     = $self->param_required('check_interpro_db_version');
  my $run_seg              = $self->param_required('run_seg');
  my $xref_analyses        = $self->param_required('xref_analyses');

  my $aa = $self->core_dba->get_adaptor('Analysis');

  my $db_versions = $self->get_db_versions($interproscan_exe);

  my $filtered_analyses = [];
  foreach my $analysis_config (@{$pf_analyses}) {
    # Set analysis versions
    if (exists $$analysis_config{'program'} && $$analysis_config{'program'} eq 'InterProScan') {
      my $ipscan_name = $$analysis_config{'ipscan_name'};
      if (exists $$db_versions{$ipscan_name}) {
        $$analysis_config{'db_version'} = $$db_versions{$ipscan_name};
        $$analysis_config{'program_version'} = $interproscan_version;
      } else {
        $self->throw("Could not retrieve version for $ipscan_name");
      }
    }
    
    # If the analysis doesn't already exist, then need to create it.
    # For InterPro sources with the current InterProScan version,
    # and for seg, don't re-annotate - it would only reproduce exactly
    # the same results.
    # If 'check_db_version' is true, then we only annotate if the
    # InterPro source database version has changed (InterPro are adding
    # entries with every release, so this leads to slightly less
    # comprehensive annotation, but handling large data volumes would
    # not be possible otherwise
    my $logic_name = $$analysis_config{'logic_name'};
    my $analysis = $aa->fetch_by_logic_name($logic_name);

    if (defined($analysis)) {
      if ($logic_name eq 'seg') {
        $run_seg = 0;
        $self->warning("Skipping $logic_name - annotation exists");
      } elsif ($analysis->program_version eq $interproscan_version) {
        $self->warning("Skipping $logic_name - annotation exists for InterProScan $interproscan_version");
      } elsif ($check_db_version && ($analysis->db_version eq $$analysis_config{'db_version'})) {
        $self->warning("Skipping $logic_name - annotation exists for db version ".$analysis->db_version);
      } else {
        push @$filtered_analyses, $analysis_config;
      }
    } else {
      if ($logic_name ne 'seg' || $run_seg) {
        push @$filtered_analyses, $analysis_config;
      }
    }
  }

  my @all;
  my @lookup;
  my @nolookup;

  foreach my $analysis_config (@{$filtered_analyses}) {
    if (exists $$analysis_config{'ipscan_name'}) {
      if (exists $$analysis_config{'ipscan_lookup'} && $$analysis_config{'ipscan_lookup'}) {
        push @lookup, $$analysis_config{'ipscan_name'};
      } else {
        push @nolookup, $$analysis_config{'ipscan_name'};
      }
    }
  }
  @all = (@lookup, @nolookup);

  foreach my $analysis_config (@{$xref_analyses}) {
    if ($$analysis_config{'annotate'}) {
      if (-e $$analysis_config{'local_file'}) {
        my $timestamp = path($$analysis_config{'local_file'})->stat->mtime;
        my $datestamp = strftime "%Y-%m-%d", localtime($timestamp);
        $$analysis_config{'db_version'} = $datestamp;

        my $logic_name = $$analysis_config{'logic_name'};
        my $analysis = $aa->fetch_by_logic_name($logic_name);

        if (defined($analysis)) {
          # If there are any InterPro sources to process, then we need
          # to re-annotate interpro2go mappings. For other xrefs, only
          # need to re-annotate if there is a more recent release.
          if (scalar(@all) && $logic_name eq 'interpro2go') {
            push @$filtered_analyses, $analysis_config;
          } elsif ($$analysis_config{'db_version'} ne $analysis->db_version) {
            push @$filtered_analyses, $analysis_config;
          } else {
            $self->warning("Skipping $logic_name - annotation exists for db version ".$analysis->db_version);
          }
        } else {
          push @$filtered_analyses, $analysis_config;
        }
      }
    }
  }

  $self->param('filtered_analyses', $filtered_analyses);
  $self->param('run_seg', $run_seg);
  $self->param('lookup', \@lookup);
  $self->param('nolookup', \@nolookup);
  $self->param('all', \@all);
}

sub get_db_versions {
  my ($self, $interproscan_exe) = @_;

  my $interpro_cmd = "$interproscan_exe --help";
  my $info = `$interpro_cmd` or $self->throw("Failed to run ".$interpro_cmd);

  my %db_versions = $info =~ /^\s+(\S+) \((\S+)\) \: /gm;

  return \%db_versions;
}

sub write_output {
  my ($self) = @_;

  my $analyses = $self->param('filtered_analyses');
  my $run_seg  = $self->param('run_seg');
  my $lookup   = $self->param('lookup');
  my $nolookup = $self->param('nolookup');
  my $all      = $self->param('all');

  if ( scalar(@$analyses) ) {
    $self->dataflow_output_id( $analyses, 2 );

    $self->dataflow_output_id(
      {
        run_seg                            => $run_seg,
        interproscan_lookup_applications   => $lookup,
        interproscan_nolookup_applications => $nolookup,
        interproscan_local_applications    => $all,
      }, 3 );
  }
}

1;
