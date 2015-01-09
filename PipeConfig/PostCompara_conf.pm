package Bio::EnsEMBL::EGPipeline::PostCompara::PipeConfig::PostCompara_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');

sub default_options {
    my ($self) = @_;

    return {
        # inherit other stuff from the base class
        %{ $self->SUPER::default_options() },

		registry  		=> '',
	    # division for GO & GeneName projection
		division_name   => '', # Eg: protists, fungi, plants, metazoa
        pipeline_name   => 'PostCompara_'.$self->o('ensembl_release'),
        output_dir      => '/nfs/nobackup/ensembl_genomes/'.$self->o('ENV', 'USER').'/workspace/'.$self->o('pipeline_name'),     
		
	## Flags controlling sub-pipeline to run
	    # '0' by default, set to '1' if this sub-pipeline is needed to be run
    	flag_GeneNames    => '0',     
    	flag_GO           => '0',     
    	flag_GeneCoverage => '0',     

    ## analysis_capacity values for some analyses:
       geneNameproj_capacity  =>  '20',
       goproj_capacity        =>  '20',
       genecoverage_capacity  =>  '100',

	## GeneName/Description Projection 
        # Tables to dump
        gn_dump_tables => ['gene', 'xref'],

		# source species 
		gn_from_species  => undef, # Eg: 'arabidopsis_thaliana'

		# target species
	    gn_species       => [], # Eg: ['vitis_vinifera']
	    gn_antispecies   => [],
        gn_division 	 => [], # ['EnsemblMetazoa', 'EnsemblProtists', 'EnsemblFungi', 'EnsemblPlants']
	    gn_run_all       => 0,

        # flowering group of your target species
        taxon_filter     => undef, # Eg: 'Liliopsida' OR 'eudicotyledons'
		geneName_source  => ['UniProtKB/Swiss-Prot', 'TAIR_SYMBOL'],
		geneDesc_rules   => ['hypothetical', 'putative'] , 

		# only certain types of homology are considered
		gn_method_link_type       => 'ENSEMBL_ORTHOLOGUES',
		gn_homology_types_allowed => ['ortholog_one2one', 'ortholog_one2many'],
		
        # Percentage identify filter for the homology
        gn_percent_id_filter      => '10',

		# Email Report subject
        gn_subject       => $self->o('pipeline_name').' subpipeline GeneNamesProjection has finished',

	## GO Projection  
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

		# source species 
		go_from_species  => 'drosophila_melanogaster', # Eg: 'arabidopsis_thaliana'

		# target species
	    go_species       => ['drosophila_ananassae','drosophila_erecta','drosophila_grimshawi','drosophila_mojavensis','drosophila_persimilis','drosophila_pseudoobscura','drosophila_sechellia','drosophila_simulans','drosophila_virilis','drosophila_willistoni','drosophila_yakuba'], # Eg: ['vitis_vinifera']
	    go_antispecies   => [],
        go_division 	 => [], # ['EnsemblMetazoa', 'EnsemblProtists', 'EnsemblFungi', 'EnsemblPlants']
	    go_run_all       => 0,

		# only certain types of homology are considered
		go_method_link_type       => 'ENSEMBL_ORTHOLOGUES',
		go_homology_types_allowed => ['ortholog_one2one','apparent_ortholog_one2one'],
		
        # Percentage identify filter for the homology
        go_percent_id_filter      => '10',

		# ensembl object type of source GO annotation, default 'Translation', options 'Transcript'
		ensemblObj_type           => 'Transcript', 
		# ensembl object type to attach GO projection, default 'Translation', options 'Transcript'
		ensemblObj_type_target    => 'Translation', 

        # GOA webservice parameters
        goa_webservice   => 'http://www.ebi.ac.uk/QuickGO/',
		goa_params       => 'GValidate?service=taxon&action=getBlacklist&taxon=',

		# only these evidence codes will be considered for GO term projection
		# See https://www.ebi.ac.uk/panda/jira/browse/EG-974
		evidence_codes         => ['IDA','IC','IGI','IMP','IPI','ISS','NAS','ND','RCA','TAS'],
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
		flag_store_projections => '0', #  Off by default. Control the storing of projections into database. 

       #'pipeline_db' => {  
		   #  -host   => $self->o('hive_host'),
       # 	 -port   => $self->o('hive_port'),
       # 	 -user   => $self->o('hive_user'),
       # 	 -pass   => $self->o('hive_password'),
	     #    -dbname => $self->o('hive_dbname'),
       # 	 -driver => 'mysql',
       #	},
		
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

# Ensures species output parameter gets propagated implicitly
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

  	if ($self->o('flag_GeneNames') && $self->o('flag_GO') && $self->o('flag_GeneCoverage')) {
    	$pipeline_flow  = ['backbone_fire_GeneNamesProjectionFactory', 'backbone_fire_GOProjectionFactory', 'backbone_fire_GeneCoverageFactory'];
		$pipeline_flow_factory_waitfor = ['GeneNamesProjectionFactory', 'GOProjectionFactory'];
  	} elsif ($self->o('flag_GeneNames') && $self->o('flag_GO')) {
    	$pipeline_flow  = ['backbone_fire_GeneNamesProjectionFactory', 'backbone_fire_GOProjectionFactory'];
  	} elsif ($self->o('flag_GeneNames') && $self->o('flag_GeneCoverage')) {
    	$pipeline_flow  = ['backbone_fire_GeneNamesProjectionFactory', 'backbone_fire_GeneCoverageFactory'];
		$pipeline_flow_factory_waitfor = ['GeneNamesProjectionFactory'];
  	} elsif ($self->o('flag_GO') && $self->o('flag_GeneCoverage')) {
    	$pipeline_flow  = ['backbone_fire_GOProjectionFactory', 'backbone_fire_GeneCoverageFactory'];
		$pipeline_flow_factory_waitfor = ['GOProjectionFactory'];
  	} elsif ($self->o('flag_GeneNames')) {
  	    $pipeline_flow  = ['backbone_fire_GeneNamesProjectionFactory'];
  	} elsif ($self->o('flag_GO')) {
    	$pipeline_flow  = ['backbone_fire_GOProjectionFactory'];
  	} elsif ($self->o('flag_GeneCoverage')) {
    	$pipeline_flow  = ['backbone_fire_GeneCoverageFactory'];
	}  	
 
    return [
    {  -logic_name    => 'backbone_fire_PostCompara',
       -module        => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
       -input_ids     => [ {} ], # Needed to create jobs
       -hive_capacity => -1,
       -flow_into 	=> { 
						 '1'=> $pipeline_flow,
       				   },
    },   
########################
### GeneNamesProjection
    {  -logic_name    => 'backbone_fire_GeneNamesProjectionFactory',
       -module        => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
       -hive_capacity => -1,
       -flow_into     => {
		                       '1->A' => ['GeneNamesProjectionFactory'],
		                       'A->1' => ['GeneNamesEmailReport'],
                          },
    },

    {  -logic_name    => 'GeneNamesProjectionFactory',
        -module       => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
        -parameters   => {
                              species     => $self->o('gn_species'),
                              antispecies => $self->o('gn_antispecies'),
                              division    => $self->o('gn_division'),
                              run_all     => $self->o('gn_run_all'),
                            },
       -max_retry_count => 1,
       -flow_into     => {
							 '2->A'	=> [ 'GeneNamesDumpTables'],
				             'A->2' => [ 'GeneNamesProjection' ],
                           },
       -rc_name       => 'default',
    },

    {  -logic_name    => 'GeneNamesDumpTables',
       -module        => 'Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::DumpTables',
       -parameters    => {
		    'dump_tables' => $self->o('gn_dump_tables'),
            'output_dir'  => $self->o('output_dir'),
        },
       -rc_name       => 'default',
    },     

    {  -logic_name    => 'GeneNamesProjection',
       -module        => 'Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GeneNamesProjection',
       -parameters    => {
   		    'from_species'            => $self->o('gn_from_species'),
		    'compara'                 => $self->o('division_name'),
   		    'release'                 => $self->o('ensembl_release'),
   		    'method_link_type'        => $self->o('gn_method_link_type'),
   		    'homology_types_allowed ' => $self->o('gn_homology_types_allowed'),
            'percent_id_filter'       => $self->o('gn_percent_id_filter'),
            'output_dir'              => $self->o('output_dir'),		

			'geneName_source'		  => $self->o('geneName_source'),  
			'geneDesc_rules'		  => $self->o('geneDesc_rules'),
		    'taxon_filter'			  => $self->o('taxon_filter'),  

            'flag_store_projections'  => $self->o('flag_store_projections'),
   	   },
       -rc_name       => 'default',
       -batch_size    =>  10, 
       -analysis_capacity => $self->o('geneNameproj_capacity'),
    },

    {  -logic_name    => 'GeneNamesEmailReport',
       -module        => 'Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GeneNamesEmailReport',
       -parameters    => {
          	'email'      => $self->o('email'),
          	'subject'    => $self->o('gn_subject'),
          	'output_dir' => $self->o('output_dir'),
			'species'    => $self->o('gn_species'),
       },
    },

################
### GOProjection
    {  -logic_name    => 'backbone_fire_GOProjectionFactory',
       -module        => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
       -hive_capacity => -1,
       -flow_into     => {
		                       '1->A' => ['GOProjectionFactory'],
		                       'A->1' => ['GOEmailReport'],
                          },
    },

    {  -logic_name    => 'GOProjectionFactory',
        -module       => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
        -parameters   => {
                              species     => $self->o('go_species'),
                              antispecies => $self->o('go_antispecies'),
                              division    => $self->o('go_division'),
                              run_all     => $self->o('go_run_all'),
                            },
       -max_retry_count => 1,
       -flow_into     => {
		                       '2' => ['GOAnalysisSetupFactory', 'GODumpTables'],
                           },
       -rc_name       => 'default',
    },

    { -logic_name     => 'GOAnalysisSetupFactory',
      -module         => 'Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::AnalysisSetupFactory',
      -parameters     => {
							required_analysis  => $self->o('required_analysis'),
                          },
      -flow_into  => {
                       '2->A' => ['GOAnalysisSetup'],
                       'A->1' => ['GOProjection'],
                     },
      -wait_for      => ['GODumpTables'],
      -rc_name       => 'default',
    },

    {  -logic_name   => 'GODumpTables',
       -module       => 'Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::DumpTables',
       -parameters   => {
		    'dump_tables' => $self->o('go_dump_tables'),
            'output_dir'  => $self->o('output_dir'),
        },
       -rc_name      => 'default',
    },     

    { -logic_name    => 'GOAnalysisSetup',
      -module        => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisSetup',
      -max_retry_count => 0,
      -parameters    => {
                            db_backup_required => 0,
                            delete_existing    => $self->o('delete_existing'),
							linked_tables      => $self->o('linked_tables'),
                            production_lookup  => $self->o('production_lookup'),
                            production_db      => $self->o('production_db'),
                          },
      -rc_name       => 'default',
    },

    {  -logic_name   => 'GOProjection',
       -module       => 'Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GOProjection',
       -parameters   => {
		    'from_species'            => $self->o('go_from_species'),
		    'compara'                 => $self->o('division_name'),
   		    'release'                 => $self->o('ensembl_release'),
   		    'method_link_type'        => $self->o('go_method_link_type'),
   		    'homology_types_allowed ' => $self->o('go_homology_types_allowed'),
   		    'percent_id_filter'       => $self->o('go_percent_id_filter'),
            'output_dir'              => $self->o('output_dir'),

   		    'evidence_codes'		  => $self->o('evidence_codes'),
		    'ensemblObj_type'		  => $self->o('ensemblObj_type'),
		    'ensemblObj_type_target'  => $self->o('ensemblObj_type_target'),
   		    'goa_webservice'          => $self->o('goa_webservice'),
   		    'goa_params'              => $self->o('goa_params'),

            'flag_store_projections' => $self->o('flag_store_projections'),
            'flag_go_check'          => $self->o('flag_go_check'),
            'flag_full_stats'        => $self->o('flag_full_stats'),
       		'flag_delete_go_terms'   => $self->o('flag_delete_go_terms'),
     	 },
       -batch_size  =>  10, 
       -rc_name     => 'default',
       -analysis_capacity => $self->o('goproj_capacity'),
	 },

    {  -logic_name  => 'GOEmailReport',
       -module      => 'Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GOEmailReport',
       -parameters  => {
          	'email'      => $self->o('email'),
          	'subject'    => $self->o('go_subject'),
          	'output_dir' => $self->o('output_dir'),
			'species'    => $self->o('go_species'),
        },
    },

################
### GeneCoverage
    {  -logic_name  => 'backbone_fire_GeneCoverageFactory',
       -module      => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
       -flow_into   => {
		                       '1->A' => ['GeneCoverageFactory'],
		                       'A->1' => ['GeneCoverageEmailReport'],
                          },
       -hive_capacity => -1,
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
       -analysis_capacity => $self->o('genecoverage_capacity'),
    },

    {  -logic_name  => 'GeneCoverageEmailReport',
       -module      => 'Bio::EnsEMBL::EGPipeline::PostCompara::RunnableDB::GeneCoverageEmailReport',
       -parameters  => {
          	'email'      => $self->o('email'),
          	'subject'    => $self->o('gcov_subject'),
          	'output_dir' => $self->o('output_dir'),
		    'compara'    => $self->o('division_name'),
       },
	},

  ];
}

1;
