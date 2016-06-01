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

Bio::EnsEMBL::EGPipeline::PostCompara::PipeConfig::PostCompara_conf

=head1 DESCRIPTION

Configuration for running the Post Compara pipeline, which
run the Gene name, description and GO projections as well as Gene coverage.

=head1 Author

ckong

=cut

package Bio::EnsEMBL::EGPipeline::PostCompara::PipeConfig::PostCompara_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');
use Bio::EnsEMBL::ApiVersion qw/software_version/;

sub default_options {
    my ($self) = @_;

    return {
        # inherit other stuff from the base class
        %{ $self->SUPER::default_options() },
        
	    # division for GO & GeneName projection
		division_name     => '', # Eg: protists, fungi, plants, metazoa
        pipeline_name     => $self->o('ENV','USER').'_PostCompara_'.$self->o('ensembl_release'),
        output_dir        => '/nfs/nobackup/ensemblgenomes/'.$self->o('ENV', 'USER').'/workspace/'.$self->o('pipeline_name'),     
		
	## Flags controlling sub-pipeline to run
	    # '0' by default, set to '1' if this sub-pipeline is needed to be run
        flag_GeneNames    => '0',
        flag_GeneDescr    => '0',
        flag_GO           => '0',
        flag_GeneCoverage => '0',

	## Flags controlling dependency between GeneNames & GeneDescr projections
	    # '0' by default, 
	    #  set to '1' to ensure GeneDescr starts after GeneNames completed
    	flag_Dependency   => '0',     

    ## analysis_capacity values for some analyses:
        geneNameproj_capacity  =>  '20',
        geneDescproj_capacity  =>  '20',
        goProj_capacity        =>  '20',
        geneCoverage_capacity  =>  '100',

    ## Flag controlling the way the projections will run
       # If the parallel flag is on, all the projections will run at the same time
       # If the parallel flag is off, the projections will run sequentially, one set of projections at the time.
       # Default value is 1

        parallel_GeneNames_projections => '1',
        parallel_GO_projections       => '1',

       ## Flag controling the use of the is_tree_compliant flag from the homology table of the Compara database
       ## If this flag is on (=1) then the pipeline will exclude all homologies where is_tree_compliant=0 in the homology table of the Compara db
       ## This flag should be enabled for EG and disable for e! species.

        is_tree_compliant => '1',

	## GeneName Projection 
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
	 			'run_all'     =>  0, # 1/0
        		# flowering group of your target species
		        'taxon_filter'    		 => undef, # Eg: 'Liliopsida'/'eudicotyledons'
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

	## GeneDescription Projection 
 	    gd_config => { 
	 	   '1'=>{
 	 	  		 # source species to project from 
	 	  		 'source'      => '', # 'schizosaccharomyces_pombe'
				 # target species to project to
	 			 'species'     => [], # ['puccinia graminis', 'aspergillus_nidulans']
	 			 # target species to exclude 
	 			 'antispecies' => [],
	 			 # target species division to project to
	 			 'division'    => [], 
	 			 'run_all'     =>  0, # 1/0
        		         # flowering group of your target species
		                 'taxon_filter'    		  => undef, # Eg: 'Liliopsida'/'eudicotyledons'
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
        g_dump_tables => ['gene', 'xref'],
        
 	    # Email Report subject
        gd_subject    => $self->o('pipeline_name').' subpipeline GeneDescriptionProjection has finished',
        gn_subject    => $self->o('pipeline_name').' subpipeline GeneNamesProjection has finished',

	## GO Projection  
	 	go_config => 
		{ 
	 	  '1'=>{
	 	  		# source species to project from 
	 	  		'source'      => '', # 'schizosaccharomyces_pombe'
				# target species to project to
	 			'species'     => [], # ['puccinia graminis', 'aspergillus_nidulans']
				# target species to exclude 
	 			'antispecies' => [],
	 			# target species division to project to
	 			'division'    => [], 
	 			'run_all'     =>  0, # 1/0
		  		# homology types filter
 				'go_method_link_type'       => 'ENSEMBL_ORTHOLOGUES',
			    'go_homology_types_allowed' => ['ortholog_one2one'],
		        # homology percentage identity filter 
        		'go_percent_id_filter'      => '10', 
				# object type of GO annotation (source)
				'ensemblObj_type'           => 'Translation', # 'Translation'/'Transcript'
				# object type to attach GO projection (target)
				'ensemblObj_type_target'    => 'Translation', # 'Translation'/'Transcript'  
	 	       }, 

		 #'2'=>{
		  #	   'source'		 => '',
		  #	   'species'	 => [],
		  #	   'antispecies' => [],
		  #	   'division'    => [],
		  #	   'run_all'     =>  0,
 		  #	   'go_method_link_type'       => 'ENSEMBL_ORTHOLOGUES',
		  #	   'go_homology_types_allowed' => ['ortholog_one2one'],
          #	   'go_percent_id_filter'      => '10', 
		  #	   'ensemblObj_type'           => 'Translation', 
		  #	   'ensemblObj_type_target'    => 'Translation',   
	 	 #	  }, 		 	   
    	},
		
	    # This Array of hashes is supplied to the 'AnalysisSetup' Runnable to 
	    # update analysis & analysis_description table
		required_analysis =>
    	[
      		{
        	 'logic_name'    => 'go_projection',
        	 'db'            => 'GO',
        	 'db_version'    => undef,
      		},     	
		],

    	# Remove existing analyses; 
    	# On '1' by default, if =0 then existing analyses will remain, 
		#  with the logic_name suffixed by '_bkp'.
    	delete_existing => 1,
    
		# Delete rows in tables connected to the existing analysis (via analysis_id)
    	linked_tables => [], 
  	        
	    # Retrieve analsysis descriptions from the production database;
    	# the supplied registry file will need the relevant server details.
	    production_lookup => 1,

        # Tables to dump
        go_dump_tables => ['xref', 'object_xref', 'ontology_xref', 'external_synonym'],

        # GOA webservice parameters
        goa_webservice => 'http://www.ebi.ac.uk/QuickGO/',
	goa_params     => 'GValidate?service=taxon&action=getBlacklist&taxon=',
						  #GValidate?service=taxon&action=getConstraints&taxon=
        # Taxon param in case Oracle database doen't work
        taxon_params     => 'GValidate?service=taxon&action=getConstraints',

                # only these evidence codes will be considered for GO term projection

		# only these evidence codes will be considered for GO term projection
		# See https://www.ebi.ac.uk/panda/jira/browse/EG-974
		evidence_codes => ['IDA','IGI','IMP','IPI'],
		#  IC Inferred by curator
		#  IDA Inferred from direct assay
		#  IEA Inferred from electronic annotation
		#  IGI Inferred from genetic interaction
		#  IMP Inferred from mutant phenotype
		#  IPI Inferred from physical interaction
		#  ISS Inferred from sequence or structural similarity
		#  NAS Non-traceable author statement
		#  ND No biological data available
		#  RCA Reviewed computational analysis
		#  TAS Traceable author statement
	
		# Email Report subject
        go_subject       	   => $self->o('pipeline_name').' subpipeline GOProjection has finished',

		# GO Projection flags
		#  Off by default. 
		#  Check if GO term is already assigned, and don't project if it is.
		flag_go_check          => '0', 
		#  On by default.  
		#  Control the printing of full statistics, i.e.:  
		#   - number of terms per evidence type for projected GO terms
		flag_full_stats        => '1', 
		#  On by default. 
		#  Delete existing projected (info_type='PROJECTION') GO terms in the target species, 
		#  before doing projection   
		flag_delete_go_terms   => '1', 

	## Gene Coverage
	    gcov_division          => $self->o('division_name'), 
	
		# Email Report subject
        gcov_subject           => $self->o('pipeline_name').' subpipeline GeneCoverage has finished',
	    
	## For all pipelines
	   #  Off by default. Control the storing of projections into database. 
       flag_store_projections => '0', 

    ## Access to the ncbi taxonomy db
	    'taxonomy_db' =>  {
     	  	  -host   => 'mysql-eg-mirror.ebi.ac.uk',
       	  	  -port   => '4157',
       	  	  -user   => 'ensro',
       	  	  -dbname => 'ncbi_taxonomy',      	
       	},

       'pipeline_db' => {  
		     -host   => $self->o('hive_host'),
        	 -port   => $self->o('hive_port'),
        	 -user   => $self->o('hive_user'),
        	 -pass   => $self->o('hive_password'),
	         -dbname => $self->o('hive_dbname'),
        	 -driver => 'mysql',
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

sub pipeline_analyses {
    my ($self) = @_;
 
 	# Control which pipelines to run
   	my $pipeline_flow;
    my $pipeline_flow_factory_waitfor;

  	if ($self->o('flag_GeneNames') && $self->o('flag_GeneDescr') && $self->o('flag_GO') && $self->o('flag_GeneCoverage')) {
    	$pipeline_flow  = ['backbone_fire_GNProj', 'backbone_fire_GDProj' , 'backbone_fire_GOProj', 'backbone_fire_GeneCoverage'];
		$pipeline_flow_factory_waitfor = ['GNProjSourceFactory', 'GDProjSourceFactory', 'GOProjSourceFactory'];
  	} elsif ($self->o('flag_GeneNames') && $self->o('flag_GeneDescr') && $self->o('flag_GO')) {
    	$pipeline_flow  = ['backbone_fire_GNProj', 'backbone_fire_GDProj', 'backbone_fire_GOProj'];
  	} elsif ($self->o('flag_GeneDescr') && $self->o('flag_GO') && $self->o('flag_GeneCoverage')) {
    	$pipeline_flow  = ['backbone_fire_GDProj', 'backbone_fire_GOProj', 'backbone_fire_GeneCoverage'];
		$pipeline_flow_factory_waitfor = ['GDProjSourceFactory', 'GOProjSourceFactory'];
  	} elsif ($self->o('flag_GeneNames') && $self->o('flag_GeneDescr')) {
    	$pipeline_flow  = ['backbone_fire_GNProj', 'backbone_fire_GDProj'];
  	} elsif ($self->o('flag_GeneNames') && $self->o('flag_GO')) {
    	$pipeline_flow  = ['backbone_fire_GNProj', 'backbone_fire_GOProj'];
  	} elsif ($self->o('flag_GeneNames') && $self->o('flag_GeneCoverage')) {
    	$pipeline_flow  = ['backbone_fire_GNProj', 'backbone_fire_GeneCoverage'];
		$pipeline_flow_factory_waitfor = ['GNProjSourceFactory'];
  	} elsif ($self->o('flag_GeneDescr') && $self->o('flag_GO')) {
    	$pipeline_flow  = ['backbone_fire_GDProj', 'backbone_fire_GOProj'];
  	} elsif ($self->o('flag_GeneDescr') && $self->o('flag_GeneCoverage')) {
    	$pipeline_flow  = ['backbone_fire_GDProj', 'backbone_fire_GeneCoverage'];
		$pipeline_flow_factory_waitfor = ['GDProjSourceFactory'];
  	} elsif ($self->o('flag_GO') && $self->o('flag_GeneCoverage')) {
    	$pipeline_flow  = ['backbone_fire_GOProj', 'backbone_fire_GeneCoverage'];
		$pipeline_flow_factory_waitfor = ['GOProjSourceFactory'];
  	} elsif ($self->o('flag_GeneNames')) {
  	    $pipeline_flow  = ['backbone_fire_GNProj'];
  	} elsif ($self->o('flag_GeneDescr')) {
  	    $pipeline_flow  = ['backbone_fire_GDProj'];
  	} elsif ($self->o('flag_GO')) {
    	$pipeline_flow  = ['backbone_fire_GOProj'];
  	} elsif ($self->o('flag_GeneCoverage')) {
    	$pipeline_flow  = ['backbone_fire_GeneCoverage'];
	}  	
 
    return [
########################
### DumpingCleaning

    {  -logic_name      => 'DumpingCleaning',
       -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
       -input_ids     => [ {} ], # Needed to create jobs
       -flow_into       => {                 '1->A' => ['DumpingCleaningSetup'],
                                             'A->1' => ['backbone_fire_PostCompara'],
                                          },
       -meadow_type   => 'LOCAL',
    },

    { -logic_name     => 'DumpingCleaningSetup',
      -module         => 'Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::DumpingCleaningSetup',
      -parameters     => {
                                                'g_config'  => $self->o('gn_config'),
                                                'gd_config'  => $self->o('gd_config'),
                                                'go_config'  => $self->o('go_config'),
                                                'flag_GeneNames' => $self->o('flag_GeneNames'),
                                                'flag_GeneDescr' => $self->o('flag_GeneDescr'),
                                                'flag_GO'        => $self->o('flag_GO'),
                                                'flag_delete_gene_names' => $self->o('flag_delete_gene_names'),
                                                'flag_delete_gene_descriptions' => $self->o('flag_delete_gene_descriptions'),
                                                'flag_delete_go_terms'        => $self->o('flag_delete_go_terms'),
                                                'output_dir'  => $self->o('output_dir'),
                                                'g_dump_tables' => $self->o('g_dump_tables'),
                                                'go_dump_tables' => $self->o('go_dump_tables'),
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
       -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
       -max_retry_count => 1,
       -flow_into       => {
                                             '2->A' => ['DumpTables'],
                                             'A->2' => ['TblCleanup'],
                                          },
       -rc_name         => 'default',
    },

    {  -logic_name    => 'DumpTables',
       -module        => 'Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::DumpTables',
       -rc_name       => '2Gb_mem',
    },

    { -logic_name     => 'TblCleanup',
      -module         => 'Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::TblCleanup',
    },
    {  -logic_name    => 'backbone_fire_PostCompara',
       -module        => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
       -hive_capacity => -1,
       -flow_into 	=> { 
						 '1'=> $pipeline_flow,
       				   },
    },   
########################
### GeneNamesProjection
    {  -logic_name    => 'backbone_fire_GNProj',
       -module        => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
       -hive_capacity => -1,
       -flow_into     => {
							'1' => ['GNProjSourceFactory'] ,
                          },
       -meadow_type   => 'LOCAL',
    },
    
    {  -logic_name    => 'GNProjSourceFactory',
       -module        => 'Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GeneNamesProjectionSourceFactory',
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
       -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
       -max_retry_count => 1,
       -flow_into      => {
                              2 => ['GNProjection']
                           },
       -rc_name         => 'default',
    },

    {  -logic_name    => 'GNProjection',
       -module        => 'Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GeneNamesProjection',
       -parameters    => {
						    'compara'                 => $self->o('division_name'),
				   		    'release'                 => $self->o('ensembl_release'),
				            'output_dir'              => $self->o('output_dir'),		
				            'flag_store_projections'  => $self->o('flag_store_projections'),
				            'taxonomy_db'			  => $self->o('taxonomy_db'),
                                            'is_tree_compliant'       => $self->o('is_tree_compliant'),
   	   					  },
       -rc_name       => 'default',
       -batch_size    =>  2, 
       -analysis_capacity => $self->o('geneNameproj_capacity'),
    },

    {  -logic_name    => 'GNEmailReport',
       -module        => 'Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GeneNamesEmailReport',
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
    {  -logic_name    => 'backbone_fire_GDProj',
       -module        => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
       -hive_capacity => -1,
       -flow_into     => {
							'1' => ['GDProjSourceFactory'] ,
                          },
       -meadow_type   => 'LOCAL',
    },
    
    {  -logic_name    => 'GDProjSourceFactory',
       -module        => 'Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GeneNamesProjectionSourceFactory',
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
       -module          => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
       -max_retry_count => 1,
       -flow_into      => {
                               2 => ['GDProjection']
                          },
       -rc_name         => 'default',
    },

    {  -logic_name    => 'GDProjection',
       -module        => 'Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GeneDescProjection',
       -parameters    => {
						    'compara'                 => $self->o('division_name'),
				   		    'release'                 => $self->o('ensembl_release'),
				            'output_dir'              => $self->o('output_dir'),		
				            'flag_store_projections'  => $self->o('flag_store_projections'),
				            'flag_filter'             => $self->o('flag_filter'),
				            'taxonomy_db'			  => $self->o('taxonomy_db'),
                                            'is_tree_compliant'       => $self->o('is_tree_compliant'),
   	   					  },
       -rc_name       => 'default',
       -batch_size    =>  2, 
       -analysis_capacity => $self->o('geneNameproj_capacity'),
       -wait_for      => [$self->o('flag_Dependency') ? 'GNProjection' : ()],
    },

    {  -logic_name    => 'GDEmailReport',
       -module        => 'Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GeneNamesEmailReport',
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
### GOProjection
    {  -logic_name    => 'backbone_fire_GOProj',
       -module        => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
       -hive_capacity => -1,
       -flow_into     => {
							'1' => ['GOProjSourceFactory'] ,
                          },
       -meadow_type   => 'LOCAL',
    },
    
    {  -logic_name    => 'GOProjSourceFactory',
       -module        => 'Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GOProjectionSourceFactory',
       -parameters    => {
							go_config  => $self->o('go_config'),
                                                        parallel_GO_projections => $self->o('parallel_GO_projections'),
                          }, 
       -flow_into     => {
		                    '2->A' => ['GOProjTargetFactory'],
		                    'A->1' => ['GOEmailReport'],		                       
                          },          
    },    
   
    {  -logic_name    => 'GOProjTargetFactory',
       -module        => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
       -max_retry_count => 1,
       -flow_into     => {  
		                    '2' => ['GOAnalysisSetupFactory'],
       					  },
       -rc_name       => 'default',
    },

    { -logic_name     => 'GOAnalysisSetupFactory',
      -module         => 'Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::AnalysisSetupFactory',
      -parameters     => {
							required_analysis  => $self->o('required_analysis'),
                          },
      -flow_into      => {
                      	 	'2->A' => ['GOAnalysisSetup'],
                                'A->1' => ['GOProjection'],
                          },
      -rc_name        => 'default',
    },

    { -logic_name     => 'GOAnalysisSetup',
      -module         => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisSetup',
      -max_retry_count => 0,
      -parameters     => {
                            db_backup_required => 0,
                            delete_existing    => $self->o('delete_existing'),
							linked_tables      => $self->o('linked_tables'),
                            production_lookup  => $self->o('production_lookup'),
                            production_db      => $self->o('production_db'),
                          },
      -rc_name        => 'default',
    },

    {  -logic_name    => 'GOProjection',
       -module        => 'Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GOProjection',
       -parameters    => {
						    'compara'                => $self->o('division_name'),
				   		    'release'                => $self->o('ensembl_release'),
				                    'output_dir'             => $self->o('output_dir'),
				   		    'evidence_codes'		 => $self->o('evidence_codes'),
				   		    'goa_webservice'         => $self->o('goa_webservice'),
				   		    'goa_params'             => $self->o('goa_params'),
                                                    'taxon_params'           => $self->o('taxon_params'),
				                    'flag_store_projections' => $self->o('flag_store_projections'),
				                    'flag_go_check'          => $self->o('flag_go_check'),
				                    'flag_full_stats'        => $self->o('flag_full_stats'),
                                                    'is_tree_compliant'      => $self->o('is_tree_compliant'),
     	 				},
       -batch_size    =>  1,
       -rc_name       => 'default',
       -analysis_capacity => $self->o('goProj_capacity'),
	 },

    {  -logic_name    => 'GOEmailReport',
       -module        => 'Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GOEmailReport',
       -parameters    => {
          					'email'      			 => $self->o('email'),
          					'subject'    			 => $self->o('go_subject'),
				          	'output_dir' 			 => $self->o('output_dir'),
				            'flag_store_projections' => $self->o('flag_store_projections'),				          	
        				  },
       -flow_into     => {
                                  1 => ['GOProjSourceFactory']
             },
       -meadow_type    => 'LOCAL',
    },

################
### GeneCoverage
    {  -logic_name  => 'backbone_fire_GeneCoverage',
       -module      => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
       -flow_into   => {
		                       '1->A' => ['GeneCoverageFactory'],
		                       'A->1' => ['GeneCoverageEmailReport'],
                          },
       -hive_capacity => -1,
       -meadow_type   => 'LOCAL',
    },

    {  -logic_name  => 'GeneCoverageFactory',
       -module      => 'Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GeneCoverageFactory',
       -parameters  => {
            			    division      => $self->o('gcov_division'),
   	    		       },
       -flow_into 	=> { 
						 '2'=> [ 'GeneCoverage' ],
      				   },
	   -wait_for    =>  $pipeline_flow_factory_waitfor,
       -rc_name     => 'default',
    },

    {  -logic_name  => 'GeneCoverage',
       -module      => 'Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GeneCoverage',
       -parameters  => {
        			   'division'     => $self->o('gcov_division'),
   	   				  },
       -batch_size  => 100,
       -rc_name     => 'default',
       -analysis_capacity => $self->o('geneCoverage_capacity'),
    },

    {  -logic_name  => 'GeneCoverageEmailReport',
       -module      => 'Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GeneCoverageEmailReport',
       -parameters  => {
          	'email'      => $self->o('email'),
          	'subject'    => $self->o('gcov_subject'),
          	'output_dir' => $self->o('output_dir'),
		    'compara'    => $self->o('division_name'),
       },
       -meadow_type      => 'LOCAL',
	},

  ];
}

1;
