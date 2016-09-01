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

Bio::EnsEMBL::Production::Pipeline::PipeConfig::XrefProjection_mouse_strains_conf

=head1 DESCRIPTION

Configuration for running the Post Compara pipeline, which
run the Gene name, description and GO projections as well as Gene coverage for the 
mouse strains

=head1 Author

Thomas Maurel

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::XrefProjection_mouse_strains_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::PostCompara_conf');
use Bio::EnsEMBL::ApiVersion qw/software_version/;

sub default_options {
    my ($self) = @_;

    return {
        # inherit other stuff from the base class
        %{ $self->SUPER::default_options() },
        
	# division for GO & GeneName projection
	division_name     => '', # Eg: protists, fungi, plants, metazoa
        pipeline_name     => $self->o('ENV','USER').'_XrefProjections_mouse_strains_'.$self->o('ensembl_release'),
        output_dir      => '/lustre/scratch109/ensembl/'.$self->o('ENV', 'USER').'/workspace/'.$self->o('pipeline_name'),
	email => $self->o('ENV', 'USER').'@sanger.ac.uk',
	## Flags controlling sub-pipeline to run
	    # '0' by default, set to '1' if this sub-pipeline is needed to be run
    	flag_GeneNames    => '1',
    	flag_GeneDescr    => '1',
    	flag_GO           => '1',     
    	flag_GeneCoverage => '0',

    ## Flags controlling dependency between GeneNames & GeneDescr projections
        # '0' by default, 
        #  set to '1' to ensure GeneDescr starts after GeneNames completed
        flag_Dependency   => '1',     

    ## Flag controlling the way the projections will run
        # If the parallel flag is on, all the projections will run at the same time
        # If the parallel flag is off, the projections will run sequentially, one set of projections at the time.
        # Default value is 1
        parallel_GeneNames_projections => '0',
        parallel_GO_projections       => '0',
    ## analysis_capacity values for some analyses:
        geneNameproj_capacity  =>  '20',
        geneDescproj_capacity  =>  '20',
        goProj_capacity        =>  '20',
        geneCoverage_capacity  =>  '100',

    ## Flag controling the use of the is_tree_compliant flag from the homology table of the Compara database
    ## If this flag is on (=1) then the pipeline will exclude all homologies where is_tree_compliant=0 in the homology table of the Compara db
    ## This flag should be enabled for EG and disable for e! species.

        is_tree_compliant => '0',

        ## GeneName Projection
                gn_config => {
                  '1'=>{
                                # source species to project from
                                'source'      => 'mus_musculus', # 'schizosaccharomyces_pombe'
                                # target species to project to
                                'species'     => ['mus_musculus_129s1svimj', 'mus_musculus_aj', 'mus_musculus_akrj', 'mus_musculus_balbcj', 'mus_musculus_c3hhej', 'mus_musculus_c57bl6nj', 'mus_musculus_casteij', 'mus_musculus_cbaj', 'mus_musculus_dba2j', 'mus_musculus_fvbnj', 'mus_musculus_lpj', 'mus_musculus_nodshiltj', 'mus_musculus_nzohlltj', 'mus_musculus_pwkphj', 'mus_musculus_wsbeij', 'mus_spretus_spreteij'], # ['puccinia graminis', 'aspergillus_nidulans']
                                # target species to exclude
                                'antispecies' => [],
                                # target species division to project to
                                'division'    => [],
                                'project_all' => '1',
                                'run_all'     =>  0, # 1/0
                                # flowering group of your target species
                                'taxon_filter'                   => undef, # Eg: 'Liliopsida'/'eudicotyledons'
                                # source species GeneName filter
                                'geneName_source'                => [],
                                # homology types filter
                                'method_link_type'       => 'ENSEMBL_ORTHOLOGUES',
                                'homology_types_allowed' => ['ortholog_one2one'],
                                # homology percentage identity filter
                                'percent_id_filter'      => '30',
                                'percent_cov_filter'     => '60',
                       },
		},

	## GeneDescription Projection 
 	    gd_config => { 
                     '1'=>{
                                 # source species to project from
                                 'source'      => 'mus_musculus', # 'schizosaccharomyces_pombe'
                                 # target species to project to
                                 'species'     => ['mus_musculus_129s1svimj', 'mus_musculus_aj', 'mus_musculus_akrj', 'mus_musculus_balbcj', 'mus_musculus_c3hhej', 'mus_musculus_c57bl6nj', 'mus_musculus_casteij', 'mus_musculus_cbaj', 'mus_musculus_dba2j', 'mus_musculus_fvbnj', 'mus_musculus_lpj', 'mus_musculus_nodshiltj', 'mus_musculus_nzohlltj', 'mus_musculus_pwkphj', 'mus_musculus_wsbeij', 'mus_spretus_spreteij'], # ['puccinia graminis', 'aspergillus_nidulans']
                                 # target species to exclude
                                 'antispecies' => [],
                                 # target species division to project to
                                 'division'    => [],
                                 'run_all'     =>  0, # 1/0
                                 # flowering group of your target species
                                 'taxon_filter'                   => undef, # Eg: 'Liliopsida'/'eudicotyledons'
                                 # source species GeneName filter for GeneDescription
                                 'geneName_source'                => [],
                                 # source species GeneDescription filter
                                 'geneDesc_rules'         => [],
                                 # target species GeneDescription filter
                                 'geneDesc_rules_target'  => ['Uncharacterized protein', 'Predicted protein', 'Gene of unknown', 'hypothetical protein'] ,
                                 # homology types filter
                                 'method_link_type'       => 'ENSEMBL_ORTHOLOGUES',
                                 'homology_types_allowed' => ['ortholog_one2one'],
                                 # homology percentage identity filter
                                 'percent_id_filter'      => '30',
                                 'percent_cov_filter'     => '60',
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
                flag_delete_gene_names   => '1',
                #  Off by default.
                #  Setting descriptions that were projected to NULL
                #  before doing projection
                flag_delete_gene_descriptions   => '1',
        # Tables to dump for GeneNames & GeneDescription projections subpipeline
        g_dump_tables => ['gene', 'xref','transcript'],
        
 	    # Email Report subject
        gd_subject    => $self->o('pipeline_name').' subpipeline GeneDescriptionProjection has finished',
        gn_subject    => $self->o('pipeline_name').' subpipeline GeneNamesProjection has finished',

	## GO Projection  
	 	go_config => 
		{ 
                  '1'=>{
                                # source species to project from
                                'source'      => 'mus_musculus', # 'schizosaccharomyces_pombe'
                                # target species to project to
                                'species'     => ['mus_musculus_129s1svimj', 'mus_musculus_aj', 'mus_musculus_akrj', 'mus_musculus_balbcj', 'mus_musculus_c3hhej', 'mus_musculus_c57bl6nj', 'mus_musculus_casteij', 'mus_musculus_cbaj', 'mus_musculus_dba2j', 'mus_musculus_fvbnj', 'mus_musculus_lpj', 'mus_musculus_nodshiltj', 'mus_musculus_nzohlltj', 'mus_musculus_pwkphj', 'mus_musculus_wsbeij', 'mus_spretus_spreteij'],
                                # target species to exclude
                                'antispecies' => [],
                                # target species division to project to
                                'division'    => [],
                                'run_all'     =>  0, # 1/0
                                # homology types filter
                                'go_method_link_type'       => 'ENSEMBL_ORTHOLOGUES',
                            'go_homology_types_allowed' => ['ortholog_one2one'],
                        # homology percentage identity filter
                        'go_percent_id_filter'      => '30',
                                # object type of GO annotation (source)
                                'ensemblObj_type'           => 'Translation', # 'Translation'/'Transcript'
                                # object type to attach GO projection (target)
                                'ensemblObj_type_target'    => 'Translation', # 'Translation'/'Transcript'
                       },
            },                  
		
	    # This Array of hashes is supplied to the 'AnalysisSetup' Runnable to 
	    # update analysis & analysis_description table
#		required_analysis =>
#   	[
#     		{
#       	 'logic_name'    => 'go_projection',
#       	 'db'            => 'GO',
#       	 'db_version'    => undef,
#     		},     	
#		],
                required_analysis =>[],
    	# Remove existing analyses; 
    	# On '1' by default, if =0 then existing analyses will remain, 
		#  with the logic_name suffixed by '_bkp'.
    	delete_existing => 0,
    
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
                 taxon_params     => 'GValidate?service=taxon&action=getConstraints',
	
                # only these evidence codes will be considered for GO term projection
		# See https://www.ebi.ac.uk/panda/jira/browse/EG-974
                evidence_codes => ['IDA', 'IEP', 'IGI', 'IMP', 'IPI', 'EXP'],
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


	    
	## For all pipelines
	   #  Off by default. Control the storing of projections into database. 
       flag_store_projections => '1',

    ## Access to the ncbi taxonomy db
	    'taxonomy_db' =>  {
     	  	  -host   => 'ens-livemirror',
       	  	  -port   => '3306',
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


sub resource_classes {
    my $self = shift;
    return {
      'default'                 => {'LSF' => '-q normal -M500 -R"select[mem>500] rusage[mem=500]"'},
      'mem'                     => {'LSF' => '-q normal -M1000 -R"select[mem>1000] rusage[mem=1000]"'},
      '2Gb_mem'         => {'LSF' => '-q normal -M2000 -R"select[mem>2000] rusage[mem=2000]"' },
      '24Gb_mem'        => {'LSF' => '-q normal -M24000 -R"select[mem>24000] rusage[mem=24000]"' },
      '250Mb_mem'       => {'LSF' => '-q normal -M250   -R"select[mem>250]   rusage[mem=250]"' },
      '500Mb_mem'       => {'LSF' => '-q normal -M500   -R"select[mem>500]   rusage[mem=500]"' },
      '1Gb_mem'             => {'LSF' => '-q normal -M1000  -R"select[mem>1000]  rusage[mem=1000]"' },
      '8Gb_mem'             => {'LSF' => '-q normal -M8000  -R"select[mem>8000]  rusage[mem=8000]"' },
      '24Gb_mem'            => {'LSF' => '-q normal -M24000 -R"select[mem>24000] rusage[mem=24000]"' },
      'urgent_hcluster' => {'LSF' => '-q yesterday' },
    }
}

1;
