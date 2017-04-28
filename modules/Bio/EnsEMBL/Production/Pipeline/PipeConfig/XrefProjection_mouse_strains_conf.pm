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
	email => $self->o('ENV', 'USER').'@ebi.ac.uk',
	## Flags controlling sub-pipeline to run
	    # '0' by default, set to '1' if this sub-pipeline is needed to be run
    	flag_GeneNames    => '1',
    	flag_GeneDescr    => '1',
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
    ## analysis_capacity values for some analyses:
        geneNameproj_capacity  =>  '20',
        geneDescproj_capacity  =>  '20',
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
                                'species'     => [], # ['puccinia graminis', 'aspergillus_nidulans']
                                # target species to exclude
                                'antispecies' => ['mus_musculus','mus_spretus_spreteij'],
                                # target species division to project to
                                'division'    => [],
                                # project all the xrefs instead of display xref only. This is mainly used for the mouse strains at the moment.
                                # Taxon name of species to project to
                                'taxons'      => ['Mus'],
                                # Taxon name of species to exclude 
                                'antitaxons' => [],
                                'project_xrefs' =>  1,
                                # Project all white list. Only the following xrefs will be projected from source to target. This doesn't affect display xref
                                'white_list'  => ['RefSeq_mRNA', 'RefSeq_mRNA_predicted','RefSeq_ncRNA','RefSeq_ncRNA_predicted','RefSeq_peptide','RefSeq_peptide_predicted','EntrezGene','EntrezGene_trans_name','WikiGene','Uniprot/SPTREMBL','Uniprot/SWISSPROT','Uniprot_gn','protein_id','UniParc','ArrayExpress','RNACentral','MGI','MGI_trans_name','miRBase','miRBase_trans_name','RFAM','RFAM_trans_name'],
                                # Run the pipeline on all the species 
                                'run_all'     =>  0, # 1/0
                                # source species GeneName filter
                                'geneName_source'                => ['MGI', 'MGI_trans_name'],
                                # homology types filter
                                'method_link_type'       => 'ENSEMBL_ORTHOLOGUES',
                                'homology_types_allowed' => ['ortholog_one2one'],
                                # homology percentage identity filter
                                'percent_id_filter'      => '30',
                                'percent_cov_filter'     => '66',
                       },
		},

	## GeneDescription Projection 
 	    gd_config => { 
                     '1'=>{
                                 # source species to project from
                                 'source'      => 'mus_musculus', # 'schizosaccharomyces_pombe'
                                 # target species to project to
                                 'species'     => ['mus_musculus','mus_spretus_spreteij'], # ['puccinia graminis', 'aspergillus_nidulans']
                                 # target species to exclude
                                 'antispecies' => [],
                                 # target species division to project to
                                 'division'    => [],
                                 # Taxon name of species to project to
                                 'taxons'      => ['Mus'],
                                 # Taxon name of species to exclude 
                                 'antitaxons' => [],
                                 'run_all'     =>  0, # 1/0
                                 # source species GeneName filter for GeneDescription
                                 'geneName_source'                => ['MGI', 'MGI_trans_name'],
                                 # source species GeneDescription filter
                                 'geneDesc_rules'         => [],
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

	    
	## For all pipelines
	   #  Off by default. Control the storing of projections into database. 
       flag_store_projections => '1',
		
    };
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
