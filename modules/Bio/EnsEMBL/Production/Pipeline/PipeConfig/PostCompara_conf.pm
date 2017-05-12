=head1 LICENSE

Copyright [1999-2016] EMBL-European Bioinformatics Institute
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

Bio::EnsEMBL::Production::Pipeline::PipeConfig::PostCompara_conf

=head1 DESCRIPTION

Base configuration for running the Post Compara pipeline, which
run the Gene name, description projections as well as Gene coverage.

=head1 Author

ckong

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::PostCompara_conf;

use strict;
use warnings;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
 # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly
use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');
use Bio::EnsEMBL::ApiVersion qw/software_version/;

sub default_options {
    my ($self) = @_;

    return {
        # inherit other stuff from the base class
        %{ $self->SUPER::default_options() },
        
	    # division for GeneName projection
            division     => undef, # Eg: protists, fungi, plants, metazoa
            output_dir        => '/nfs/nobackup/ensemblgenomes/'.$self->o('ENV', 'USER').'/workspace/'.$self->o('pipeline_name'),

            email => $self->o('ENV', 'USER').'@ebi.ac.uk',
            
            ## Flags controlling sub-pipeline to run
	    # '0' by default, set to '1' if this sub-pipeline is needed to be run
            flag_GeneNames    => '0',
            flag_GeneDescr    => '0',
            flag_GeneCoverage => '0',
            
            ## Flags controlling dependency between GeneNames & GeneDescr projections
	    # '0' by default, 
	    #  set to '1' to ensure GeneDescr starts after GeneNames completed
            flag_Dependency   => '0',     
            
            ## Flag controlling the way the projections will run
            # If the parallel flag is on, all the projections will run at the same time
            # If the parallel flag is off, the projections will run sequentially, one set of projections at the time.
            # Default value is 1
            
            parallel_GeneNames_projections => '1',
            
            ## Flag controling the use of the is_tree_compliant flag from the homology table of the Compara database
            ## If this flag is on (=1) then the pipeline will exclude all homologies where is_tree_compliant=0 in the homology table of the Compara db
            ## This flag should be enabled for EG and disable for e! species.
            
            is_tree_compliant => '1',
                       
            #  Off by default. 
            #   Filtering of target species GeneDescription
            #   If flag turn 'ON' Configure 'geneDesc_rules_target' parameter
            #   (See JIRA EG-2676 for details)
            #   eg. solanum_tuberosum genes with description below SHOULD receive projections
            #		 "Uncharacterized protein" from UniProt
            #		 "Predicted protein" from UniProt
            #		 "Gene of unknown function" from PGSC
            flag_filter   => '0', 
            #  Off by default.
            #  Setting projected transcript statuses to NOVEL
            #  Setting gene display_xrefs that were projected to NULL and status to NOVEL
            #  Deleting projected xrefs, object_xrefs and synonyms
            #  before doing projection
            flag_delete_gene_names   => '0',
            #  Off by default.
            #  Setting descriptions that were projected to NULL
                #  before doing projection
            flag_delete_gene_descriptions   => '0',
            # Tables to dump for GeneNames & GeneDescription projections subpipeline
            g_dump_tables => ['gene', 'xref','object_xref','external_db','external_synonym'],
            
 	    # Email Report subject
            gd_subject    => $self->o('pipeline_name').' subpipeline GeneDescriptionProjection has finished',
            gn_subject    => $self->o('pipeline_name').' subpipeline GeneNamesProjection has finished',

            ## Gene Coverage
	    gcov_division          => $self->o('division'), 
            
            # Email Report subject
            gcov_subject           => $self->o('pipeline_name').' subpipeline GeneCoverage has finished',
	    
            ## For all pipelines
            #  on by default. Control the storing of projections into database.
            flag_store_projections => '1',

            ## GeneName Projection setting - override for each division
            gn_config => { 
          '1'=>{
                # source species to project from 
                'source'      => '', # 'schizosaccharomyces_pombe'
                # target species to project to
                'species'     => [], # ['puccinia graminis', 'aspergillus_nidulans']
                # target species to exclude 
                'antispecies' => [],
	 			        # target species division to project to
	 			        'division'    => [],
                # Taxon name of species to project to
                'taxons'      => [],
                # Taxon name of species to exclude 
                'antitaxons' => [],
	 			        # project all the xrefs instead of display xref only. This is mainly used for the mouse strains at the moment.
                'project_xrefs' =>  0,
                # Project all white list. Only the following xrefs will be projected from source to target. This doesn't affect display xref
                'white_list'  => [],
	 			        # Run the pipeline on all the species 
	 			        'run_all'     =>  0, # 1/0
				        # source species GeneName filter
				        'geneName_source' 		 => ['UniProtKB/Swiss-Prot', 'Uniprot_gn', 'TAIR_SYMBOL'],
		  		      # homology types filter
 				        'method_link_type'       => 'ENSEMBL_ORTHOLOGUES',
			          'homology_types_allowed' => ['ortholog_one2one'],
		            # homology percentage identity filter 
        		    'percent_id_filter'      => '30', 
				        'percent_cov_filter'     => '66',
	 	            }, 
                          #'2'=>{
                          #   'source'	   => '',
                          #   'species'	   => [],
                          #   'antispecies'  => [],
                          #   'division'     => [],
                          #   'run_all'      =>  0,
                          #   'taxon_filter' => undef,
                          #   'geneName_source' 		    => ['UniProtKB/Swiss-Prot', 'TAIR_SYMBOL'],
                          #   'geneDesc_rules'   		    => ['hypothetical', 'putative', 'unknown protein'] , 
                          #   'geneDesc_rules_target'     => ['Uncharacterized protein', 'Predicted protein', 'Gene of unknown'] , 
                          #   'gn_method_link_type'       => 'ENSEMBL_ORTHOLOGUES',
                          #   'gn_homology_types_allowed' => ['ortholog_one2one'], 
                          #   'gn_percent_id_filter'      => '30', 
                          #   'gn_percent_cov_filter'     => '66',
                          #	  }, 
                         },
            ## GeneDescription Projection - override for each division
            'gd_config' => { 
                            '1'=>{
                                  # source species to project from 
                                'source'      => '', # 'schizosaccharomyces_pombe'
                                  # target species to project to
                                'species'     => [], # ['puccinia graminis', 'aspergillus_nidulans']
                                # target species to exclude 
                                'antispecies' => [],
                                # target species division to project to
                                'division'    => [], 
                                 # Taxon name of species to project to
                                'taxons'      => [],
                                # Taxon name of species to exclude 
                                'antitaxons' => [],
                                'run_all'     =>  0, # 1/0
                                # source species GeneName filter for GeneDescription
                                'geneName_source'                => ['UniProtKB/Swiss-Prot', 'Uniprot_gn', 'TAIR_SYMBOL'],
                                # source species GeneDescription filter
				                        'geneDesc_rules'   	  => ['hypothetical', 'putative', 'unknown protein'] , 
                                # target species GeneDescription filter
				                        'geneDesc_rules_target'  => ['Uncharacterized protein', 'Predicted protein', 'Gene of unknown', 'hypothetical protein'] ,
                                # homology types filter
                                'method_link_type'       => 'ENSEMBL_ORTHOLOGUES',
                                'homology_types_allowed' => ['ortholog_one2one'],
                                # homology percentage identity filter 
                                'percent_id_filter'      => '30', 
                                'percent_cov_filter'     => '66',
                               }, 
                           },

    };
}


sub pipeline_create_commands {
    my ($self) = @_;
    return [
      # inheriting database and hive tables' creation
      @{$self->SUPER::pipeline_create_commands},
      'mkdir -p '.$self->o('output_dir'),
    ];
}

# Ensures output parameters gets propagated implicitly
sub hive_meta_table {
  my ($self) = @_;
  
  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack'  => 1,
  };
}

# override the default method, to force an automatic loading of the registry in all workers
sub beekeeper_extra_cmdline_options {
  my ($self) = @_;
  return 
      ' -reg_conf ' . $self->o('registry'),
  ;
}

sub pipeline_wide_parameters {  # these parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'flag_GeneNames'     => $self->o('flag_GeneNames'),
        'flag_GeneDescr'       => $self->o('flag_GeneDescr'),
        'flag_GeneCoverage'      => $self->o('flag_GeneCoverage')
    };
}

sub pipeline_analyses {
  my ($self) = @_;
  
  return [
          #######################
          ### Backbone to only decide to run DumplingCleaning for
          ### Gene name and GeneDescription projections
           {  -logic_name    => 'backbone_PostCompara',
             -module        => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
             -input_ids     => [ {} ], # Needed to create jobs
             -flow_into   => {
                                1  => WHEN(
                                   '!#flag_GeneCoverage#' => [ 'DumpingCleaning' ],
                                   '#flag_GeneCoverage# and #flag_GeneNames# and #flag_GeneDescr#' => [ 'DumpingCleaning', 'GeneCoverageFactory'],
                                   '#flag_GeneCoverage# and #flag_GeneNames# and !#flag_GeneDescr#' =>  [ 'DumpingCleaning', 'GeneCoverageFactory'],
                                   '#flag_GeneCoverage# and !#flag_GeneNames# and #flag_GeneDescr#' => [ 'DumpingCleaning', 'GeneCoverageFactory'],
                                   '#flag_GeneCoverage# and !#flag_GeneNames# and !#flag_GeneDescr#' => [ 'GeneCoverageFactory'],
                                  ),
                             },
          },

          ########################
          ### DumpingCleaning
          
          {  -logic_name      => 'DumpingCleaning',
             -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
             -flow_into       => {                 '1->A' => ['DumpingCleaningSetup'],
                                                   'A->1' => ['backbone_fire_PostCompara'],
                                 },
             -meadow_type   => 'LOCAL',
          },
          
          { -logic_name     => 'DumpingCleaningSetup',
            -module         => 'Bio::EnsEMBL::Production::Pipeline::PostCompara::DumpingCleaningSetup',
            -parameters     => {
                                'g_config'  => $self->o('gn_config'),
                                'gd_config'  => $self->o('gd_config'),
                                'flag_GeneNames' => $self->o('flag_GeneNames'),
                                'flag_GeneDescr' => $self->o('flag_GeneDescr'),
                                'flag_delete_gene_names' => $self->o('flag_delete_gene_names'),
                                'flag_delete_gene_descriptions' => $self->o('flag_delete_gene_descriptions'),
                                'output_dir'  => $self->o('output_dir'),
                                'g_dump_tables' => $self->o('g_dump_tables'),
                                'parallel_GeneNames_projections' => $self->o('parallel_GeneNames_projections'),

                               },
            -rc_name        => 'default',
            -flow_into       => {
                                 '2->A' => ['SpeciesFactory'],
                                 'A->1' => ['Iterator'],
                                },
          },
          {
           -logic_name      => 'Iterator',
           -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
           -flow_into       => {                 '1' => ['DumpingCleaningSetup'],
                               },
           -meadow_type   => 'LOCAL',
          },
          {  -logic_name      => 'SpeciesFactory',
             -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
             -max_retry_count => 1,
             -flow_into       => {
                                  '2->A' => ['DumpTables'],
                                  'A->2' => ['TblCleanup'],
                                 },
             -rc_name         => 'default',
          },
          
          {  -logic_name    => 'DumpTables',
             -module        => 'Bio::EnsEMBL::Production::Pipeline::Common::DumpTables',
             -rc_name       => '2Gb_mem',
          },
          
          { -logic_name     => 'TblCleanup',
            -module         => 'Bio::EnsEMBL::Production::Pipeline::PostCompara::TblCleanup',
          },
          {  -logic_name    => 'backbone_fire_PostCompara',
             -module        => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
             -hive_capacity => -1,
            -flow_into   => {
                                1  => WHEN(
                                   '#flag_GeneNames# and #flag_GeneDescr#' => [ 'GNProjSourceFactory', 'GDProjSourceFactory'],
                                   '#flag_GeneNames# and !#flag_GeneDescr#' =>  [ 'GNProjSourceFactory'],
                                   '!#flag_GeneNames# and #flag_GeneDescr#' => [ 'GDProjSourceFactory'],
                                  ),
                             },
          },
          ########################
          ### GeneNamesProjection
          
          {  -logic_name    => 'GNProjSourceFactory',
             -module        => 'Bio::EnsEMBL::Production::Pipeline::PostCompara::GeneNamesProjectionSourceFactory',
             -parameters    => {
                                g_config  => $self->o('gn_config'),
                                parallel_GeneNames_projections => $self->o('parallel_GeneNames_projections'),
                               }, 
             -flow_into     => {
                                '2->A' => ['GNProjTargetFactory'],
                                'A->1' => ['GNEmailReport'],
                               },          
          },    
          
          {  -logic_name      => 'GNProjTargetFactory',
             -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
             -max_retry_count => 1,
             -flow_into      => {
                                 2 => ['GNProjection']
                                },
             -rc_name         => 'default',
          },
          
          {  -logic_name    => 'GNProjection',
             -module        => 'Bio::EnsEMBL::Production::Pipeline::PostCompara::GeneNamesProjection',
             -parameters    => {
                                'compara'                 => $self->o('division'),
                                'release'                 => $self->o('ensembl_release'),
                                'output_dir'              => $self->o('output_dir'),		
                                'flag_store_projections'  => $self->o('flag_store_projections'),
                                'is_tree_compliant'       => $self->o('is_tree_compliant'),
                               },
             -rc_name       => 'default',
             -batch_size    =>  2, 
             -analysis_capacity => 20,
          },
          
          {  -logic_name    => 'GNEmailReport',
             -module        => 'Bio::EnsEMBL::Production::Pipeline::PostCompara::GeneNamesEmailReport',
             -parameters    => {
                                'email'      			 => $self->o('email'),
                                'subject'    			 => $self->o('gn_subject'),
                                'output_dir' 			 => $self->o('output_dir'),         	
                                'flag_store_projections' => $self->o('flag_store_projections'),
                                'flag_GeneNames'         => $self->o('flag_GeneNames'),
                               },
             -flow_into     => {
                                1 => ['GNProjSourceFactory']
                               },
             -meadow_type   => 'LOCAL',
          },
          
          ########################
          ### GeneDescProjection
          
          {  -logic_name    => 'GDProjSourceFactory',
             -module        => 'Bio::EnsEMBL::Production::Pipeline::PostCompara::GeneNamesProjectionSourceFactory',
             -parameters    => {
                                g_config  => $self->o('gd_config'),
                                parallel_GeneNames_projections => $self->o('parallel_GeneNames_projections'),
                               }, 
             -flow_into     => {
                                '2->A' => ['GDProjTargetFactory'],
                                'A->1' => ['GDEmailReport'],
                               },
          },

          {  -logic_name      => 'GDProjTargetFactory',
             -module          => 'Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory',
             -max_retry_count => 1,
             -flow_into      => {
                                 2 => ['GDProjection']
                                },
             -rc_name         => 'default',
          },
          
          {  -logic_name    => 'GDProjection',
             -module        => 'Bio::EnsEMBL::Production::Pipeline::PostCompara::GeneDescProjection',
             -parameters    => {
                                'compara'                 => $self->o('division'),
                                'release'                 => $self->o('ensembl_release'),
                                'output_dir'              => $self->o('output_dir'),
                                'flag_store_projections'  => $self->o('flag_store_projections'),
                                'flag_filter'             => $self->o('flag_filter'),
                                'is_tree_compliant'       => $self->o('is_tree_compliant'),
                               },
             -rc_name       => 'default',
             -batch_size    =>  2, 
             -analysis_capacity => 20,
             -wait_for      => [$self->o('flag_Dependency') ? 'GNProjection' : ()],
          },
          
          {  -logic_name    => 'GDEmailReport',
               -module        => 'Bio::EnsEMBL::Production::Pipeline::PostCompara::GeneNamesEmailReport',
               -parameters    => {
                                  'email'      			 => $self->o('email'),
                                  'subject'    			 => $self->o('gd_subject'),
                                  'output_dir' 			 => $self->o('output_dir'),         	
                                  'flag_store_projections' => $self->o('flag_store_projections'),
                                  'flag_GeneDescr'         => $self->o('flag_GeneDescr'),
                                 },
             -flow_into     => {
                                1 => ['GDProjSourceFactory']
                               },
             -meadow_type   => 'LOCAL',
          },
          ################
          ### GeneCoverage
          
          {  -logic_name  => 'GeneCoverageFactory',
             -module      => 'Bio::EnsEMBL::Production::Pipeline::PostCompara::GeneCoverageFactory',
             -parameters  => {
                              division      => $self->o('gcov_division'),
                             },
             -flow_into 	=> { 
                                    '2->A' => ['GeneCoverage'],
                                    'A->1' => ['GeneCoverageEmailReport'],
      				   },
             -rc_name     => 'default',
          },
          
          {  -logic_name  => 'GeneCoverage',
             -module      => 'Bio::EnsEMBL::Production::Pipeline::PostCompara::GeneCoverage',
             -parameters  => {
                              'division'     => $self->o('gcov_division'),
                             },
             -batch_size  => 100,
             -rc_name     => 'default',
             -analysis_capacity => 100,
             -rc_name       => '8Gb_mem',
          },
          
          {  -logic_name  => 'GeneCoverageEmailReport',
             -module      => 'Bio::EnsEMBL::Production::Pipeline::PostCompara::GeneCoverageEmailReport',
             -parameters  => {
                              'email'      => $self->o('email'),
                              'subject'    => $self->o('gcov_subject'),
                              'output_dir' => $self->o('output_dir'),
                              'compara'    => $self->o('division'),
                             },
             -meadow_type      => 'LOCAL',
          },
          
         ];
}

sub resource_classes {
    my $self = shift;
    return {
      'default'                 => {'LSF' => '-q production-rh7 -M 500 -R "rusage[mem=500]"'},
      'mem'                     => {'LSF' => '-q production-rh7 -M 1000 -R "rusage[mem=1000]"'},
      '2Gb_mem'         => {'LSF' => '-q production-rh7 -M 2000 -R "rusage[mem=2000]"' },
      '24Gb_mem'        => {'LSF' => '-q production-rh7 -M 24000 -R "rusage[mem=24000]"' },
      '250Mb_mem'       => {'LSF' => '-q production-rh7 -M 250 -R "rusage[mem=250]"' },
      '500Mb_mem'       => {'LSF' => '-q production-rh7 -M 500 -R "rusage[mem=500]"' },
      '1Gb_mem'             => {'LSF' => '-q production-rh7 -M 1000 -R "rusage[mem=1000]"' },
      '8Gb_mem'             => {'LSF' => '-q production-rh7 -M 8000 -R "rusage[mem=8000]"' },
      'urgent_hcluster' => {'LSF' => '-q production-rh7' },
    }
}

1;
