
=head1 LICENSE

Copyright [1999-2015] EMBL-European Bioinformatics Institute
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

Bio::EnsEMBL::EGPipeline::PipeConfig::Xref_conf

=head1 DESCRIPTION

Assign UniParc and UniParc-derived xrefs.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::Xref_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'xref_' . $self->o('ensembl_release'),

    species      => [],
    division     => [],
    run_all      => 0,
    antispecies  => [],
    meta_filters => {},
    
    oracle_home => '/sw/arch/dbtools/oracle/product/11.1.0.6.2/client',
    
    local_uniparc_db => {
      -driver => 'mysql',
      -host   => 'mysql-eg-pan-1.ebi.ac.uk',
      -port   => 4276,
      -user   => 'ensrw',
      -pass   => 'writ3rpan1',
      -dbname => 'uniparc',
    },
    reload_local_uniparc => 1,
    
    remote_uniparc_db => {
      -driver => 'Oracle',
      -host   => 'ora-vm-004.ebi.ac.uk',
      -port   => 1551,
      -user   => 'uniparc_read',
      -pass   => 'uniparc',
      -dbname => 'UAPRO',
    },
    
    remote_uniprot_db => {
      -driver => 'Oracle',
      -host   => 'ora-dlvm5-026.ebi.ac.uk',
      -port   => 1521,
      -user   => 'spselect',
      -pass   => 'spselect',
      -dbname => 'SWPREAD',
    },
    
    load_uniparc => 1,
    
    load_uniprot         => 1,
    uniprot_replace_all  => 0,
    uniprot_gene_names   => 0,
    uniprot_descriptions => 0,
    
    load_uniprot_go        => 1,
    uniprot_go_replace_all => 0,
    
    load_uniprot_xrefs  => 1,
    uniprot_xref_source => ['ArrayExpress', 'EMBL', 'MEROPS', 'PDB'],
    
    # Retrieve analysis descriptions from the production database;
    # the supplied registry file will need the relevant server details.
    production_lookup => 1,
    
    # By default, an email is sent for each species when the pipeline
    # is complete, showing the breakdown of xrefs assigned.
    email_repeat_report => 1,
  }
}

# Force an automatic loading of the registry in all workers.
sub beekeeper_extra_cmdline_options {
  my ($self) = @_;

  my $options = join(' ',
    $self->SUPER::beekeeper_extra_cmdline_options,
    "-reg_conf ".$self->o('registry')
  );
  
  return $options;
}

# Switch on implicit parameter propagation.
sub hive_meta_table {
  my ($self) = @_;

  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack'  => 1,
  };
}

sub pipeline_analyses {
  my ($self) = @_;

  my $transitive_xrefs = [];
  if ($self->o('load_uniprot_go')) {
    push @$transitive_xrefs, 'LoadUniProtGO';
  }
  if ($self->o('load_uniprot_xrefs')) {
    push @$transitive_xrefs, 'LoadUniProtXrefs';
  }
  
  my $species_factory_flow = {'2' => 'LoadXrefs'};
  my $load_xrefs_flow;
  my $load_uniparc_flow;
  my $load_uniprot_flow;
  my $load_uniparc_wait = [];
  
  if ($self->o('load_uniparc')) {
    if ($self->o('reload_local_uniparc')) {
      $species_factory_flow = {
        '1' => 'ReloadLocalUniparc',
        '2' => 'LoadXrefs',
      };
      $load_uniparc_wait = ['ReloadLocalUniparc'],
    }
    
    if ($self->o('email_repeat_report')) {
      $load_xrefs_flow = {
        '1->A' => 'LoadUniParc',
        'A->1' => 'EmailXrefReport',
      };
    } else {
      $load_xrefs_flow = ['LoadUniParc'];
    }
    
    if ($self->o('load_uniprot')) {
      $load_uniparc_flow = ['LoadUniProt'];
      if (scalar @$transitive_xrefs > 0) {
        $load_uniprot_flow = $transitive_xrefs;
      }
    } elsif (scalar @$transitive_xrefs > 0) {
      $load_uniparc_flow = $transitive_xrefs;
    }
    
  } elsif ($self->o('load_uniprot')) {
    if ($self->o('email_repeat_report')) {
      $load_xrefs_flow = {
        '1->A' => 'LoadUniProt',
        'A->1' => 'EmailXrefReport',
      };
    } else {
      $load_xrefs_flow = ['LoadUniProt'];
    }
    
    if (scalar @$transitive_xrefs > 0) {
      $load_uniprot_flow = $transitive_xrefs;
    }
    
  } elsif (scalar @$transitive_xrefs > 0) {
    if ($self->o('email_repeat_report')) {
      $load_xrefs_flow = {
        '1->A' => $transitive_xrefs,
        'A->1' => 'EmailXrefReport',
      };
    } else {
      $load_xrefs_flow = $transitive_xrefs;
    }
    
  }

  return [
    {
      -logic_name      => 'SpeciesFactory',
      -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
      -parameters      => {
                            species         => $self->o('species'),
                            antispecies     => $self->o('antispecies'),
                            division        => $self->o('division'),
                            run_all         => $self->o('run_all'),
                            meta_filters    => $self->o('meta_filters'),
                            chromosome_flow => 0,
                            variation_flow  => 0,
                          },
      -input_ids       => [ {} ],
      -max_retry_count => 1,
      -flow_into       => $species_factory_flow,
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name      => 'LoadXrefs',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -parameters      => {
                            oracle_home => $self->o('oracle_home'),
                          },
      -max_retry_count => 0,
      -meadow_type     => 'LOCAL',
      -flow_into       => $load_xrefs_flow,
    },

    {
      -logic_name      => 'ReloadLocalUniparc',
      -module          => 'Bio::EnsEMBL::EGPipeline::Xref::ReloadLocalUniParc',
      -parameters      => {
                            uniparc_db => $self->o('local_uniparc_db'),
                          },
      -max_retry_count => 1,
      -rc_name         => '4Gb_mem_4Gb_tmp',
    },

    {
      -logic_name      => 'LoadUniParc',
      -module          => 'Bio::EnsEMBL::EGPipeline::Xref::LoadUniParc',
      -parameters      => {
                            uniparc_db         => $self->o('local_uniparc_db'),
                            logic_name         => 'xrefchecksum',
                            module             => 'Bio::EnsEMBL::EGPipeline::Xref::LoadUniParc',
                            production_lookup  => $self->o('production_lookup'),
                            production_db      => $self->o('production_db'),
                            db_backup_required => 0,
                          },
      -max_retry_count => 1,
      -hive_capacity   => 10,
      -rc_name         => 'normal',
      -wait_for        => $load_uniparc_wait,
      -flow_into       => $load_uniparc_flow,
    },

    {
      -logic_name      => 'LoadUniProt',
      -module          => 'Bio::EnsEMBL::EGPipeline::Xref::LoadUniProt',
      -parameters      => {
                            uniparc_db         => $self->o('remote_uniparc_db'),
                            uniprot_db         => $self->o('remote_uniprot_db'),
                            replace_all        => $self->o('uniprot_replace_all'),
                            gene_names         => $self->o('uniprot_gene_names'),
                            descriptions       => $self->o('uniprot_descriptions'),
                            logic_name         => 'xrefuniparc',
                            module             => 'Bio::EnsEMBL::EGPipeline::Xref::LoadUniProt',
                            production_lookup  => $self->o('production_lookup'),
                            production_db      => $self->o('production_db'),
                            db_backup_required => 0,
                          },
      -max_retry_count => 1,
      -hive_capacity   => 10,
      -rc_name         => 'normal',
      -flow_into       => $load_uniprot_flow,
    },

    {
      -logic_name      => 'LoadUniProtGO',
      -module          => 'Bio::EnsEMBL::EGPipeline::Xref::LoadUniProtGO',
      -parameters      => {
                            uniprot_db         => $self->o('remote_uniprot_db'),
                            replace_all        => $self->o('uniprot_go_replace_all'),
                            logic_name         => 'xrefuniprot',
                            module             => 'Bio::EnsEMBL::EGPipeline::Xref::LoadUniProt*',
                            production_lookup  => $self->o('production_lookup'),
                            production_db      => $self->o('production_db'),
                            db_backup_required => 0,
                          },
      -max_retry_count => 1,
      -hive_capacity   => 10,
      -rc_name         => 'normal',
    },

    {
      -logic_name      => 'LoadUniProtXrefs',
      -module          => 'Bio::EnsEMBL::EGPipeline::Xref::LoadUniProtXrefs',
      -parameters      => {
                            uniprot_db         => $self->o('remote_uniprot_db'),
                            xref_source        => $self->o('uniprot_xref_source'),
                            logic_name         => 'xrefuniprot',
                            module             => 'Bio::EnsEMBL::EGPipeline::Xref::LoadUniProt*',
                            production_lookup  => $self->o('production_lookup'),
                            production_db      => $self->o('production_db'),
                            db_backup_required => 0,
                          },
      -max_retry_count => 1,
      -hive_capacity   => 10,
      -rc_name         => 'normal',
    },

    {
      -logic_name      => 'EmailXrefReport',
      -module          => 'Bio::EnsEMBL::EGPipeline::Xref::EmailXrefReport',
      -parameters      => {
                            email              => $self->o('email'),
                            subject            => 'Xref pipeline report for #species#',
                            load_uniparc       => $self->o('load_uniparc'),
                            load_uniprot       => $self->o('load_uniprot'),
                            load_uniprot_go    => $self->o('load_uniprot_go'),
                            load_uniprot_xrefs => $self->o('load_uniprot_xrefs'),
                          },
      -max_retry_count => 1,
      -rc_name         => 'normal',
    },

 ];
}

1;
