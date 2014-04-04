=head1 LICENSE

Copyright [1999-2014] EMBL-European Bioinformatics Institute
and Wellcome Trust Sanger Institute

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

=head1 NAME

Bio::EnsEMBL::EGPipeline::Common::EGSpeciesFactory

=head1 DESCRIPTION

An extension of the ClassSpeciesFactory code, for use with
EnsemblGenomes, which uses the production database differently
and thus needs simpler 'run' and 'is_run' functions.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Production::ClassSpeciesFactory/;

sub param_defaults {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::param_defaults},
    antispecies => []
  };
}

sub run {
  my ($self) = @_;
  my @dbs;
  foreach my $dba (@{$self->param('dbas')}) {
    if(!$self->process_dba($dba)) {
      $self->fine('Skipping %s', $dba->species());
      next;
    }
    
    my $all = $self->production_flow($dba, 'all');
    if ($self->param('run_all')) {
      $all = 2;
    }
    
    if($all) {
      my $variation = $self->production_flow($dba, 'variation');
      if ($variation) {
        push(@dbs, [$self->input_id($dba), $variation]);
      }

      my $karyotype = $self->production_flow($dba, 'karyotype');
      if ($karyotype) {
        push(@dbs, [$self->input_id($dba), $karyotype]);
      }
      
      push(@dbs, [$self->input_id($dba), $all]);
    }
    
  }
  $self->param('dbs', \@dbs);
  
  return;
}

sub is_run {
	my ( $self, $dba, $class ) = @_;
  
	if ( $class =~ 'karyotype' ) {
		return $self->has_karyotype($dba);
	}
  if ($class =~ 'vega') {
    return 0;
  }
  if ($class =~ 'variation') {
    return $self->has_variation($dba);
  }
	$dba->dbc()->disconnect_if_idle();
	return 1;
}

sub process_dba {
	my ( $self, $dba ) = @_;
	my $result = $self->SUPER::process_dba($dba);
	if ( $result == 1 && @{$self->param('division')} ) {
		$result = 0;
		for my $division (@{$self->param('division')}) {
			if($dba->get_MetaContainer()->get_division() eq $division) {
				$result = 1;
				last;
			}
		}
	}
  if ( $result == 1 && @{$self->param('antispecies')} ) {
    for my $antispecies (@{$self->param('antispecies')}) {
      if ($dba->species() eq $antispecies) {
        $result = 0;
        last;
      }
    }
  }
	return $result;
}

sub has_variation {
	my ( $self, $dba ) = @_;
	my $production_name = $dba->get_MetaContainer()->get_production_name();
  my $dbva = Bio::EnsEMBL::Registry->get_DBAdaptor($production_name, 'variation');
  if ($dbva) {
    return 1;
  } else {
    return 0;
  }
}

1;
