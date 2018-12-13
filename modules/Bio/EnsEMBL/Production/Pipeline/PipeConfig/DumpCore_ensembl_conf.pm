=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpCore_ensembl_conf;

=head1 DESCRIPTION

=head1 AUTHOR 

 ckong@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpCore_ensembl_conf;

use strict;
use warnings;
use File::Spec;
use Data::Dumper;
use Bio::EnsEMBL::ApiVersion qw/software_version/;
use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpCore_conf');     
   
sub default_options {
    my ($self) = @_;
    
    return {
       # inherit other stuff from the base class
       %{ $self->SUPER::default_options() }, 

       ## Indexing parameters
       'skip_blat'              => 0,
       'skip_ncbiblast'         => 0,
       'skip_blat_masking'      => 1,
       'skip_ncbiblast_masking' => 0,

       'division'    => 'Ensembl',

#'exe_dir'       => '/nfs/panda/ensemblgenomes/production/compara/binaries/',
       'gt_exe'       => '/nfs/software/ensembl/RHEL7/linuxbrew/Cellar/genometools/1.5.8/bin/gt',
        # create BLAST databases, version 2.2.27+
#'ncbiblast_exe' => $self->o('exe_dir').'ncbi-blast/makeblastdb',
       'ncbiblast_exe' => 'makeblastdb',
        # convert DNA from fasta to 2bit format
#'blat_exe' => $self->o('exe_dir').'faToTwoBit',
       'blat_exe' => 'faToTwoBit',
	};
}

sub pipeline_analyses {
    my ($self) = @_;

    ## Get analyses defined in the base class
    my $super_analyses   = $self->SUPER::pipeline_analyses;

    my %analyses_by_name = map {$_->{'-logic_name'} => $_} @$super_analyses;
    $self->tweak_analyses(\%analyses_by_name);
    
    return [
       @$super_analyses,

       ### INDEXING
      { -logic_name => 'index_BlatDNAIndex',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::FASTA::BlatIndexer',
        -parameters => {
          program => $self->o('blat_exe'),
          'index' => 'dna',
          skip => $self->o('skip_blat'),
          index_masked_files => $self->o('skip_blat_masking'),
        },
        -can_be_empty => 1,
        -hive_capacity => 5,
        -rc_name => 'default',
      },

      { -logic_name => 'index_ncbiblastDNA',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::FASTA::NcbiBlastIndexer',
        -parameters => {
                          molecule           => 'dna', 
                          type               => 'genomic', 
                          program            => $self->o('ncbiblast_exe'), 
                          skip               => $self->o('skip_ncbiblast'), 
                          index_masked_files => $self->o('skip_ncbiblast_masking'),
                        },
       -hive_capacity => 10,
       -can_be_empty  => 1,
       -rc_name 	   => 'default',     
      },  

      { -logic_name => 'index_ncbiblastPEP',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::FASTA::NcbiBlastIndexer',
        -parameters => {
                          molecule => 'pep', 
                          type     => 'genes', 
                          program  => $self->o('ncbiblast_exe'), 
                          skip     => $self->o('skip_ncbiblast'),
        },
        -hive_capacity => 5,
        -can_be_empty  => 1,
      },
      
      { -logic_name => 'index_ncbiblastGENE',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::FASTA::NcbiBlastIndexer',
        -parameters => {          
                          molecule => 'dna', 
                          type     => 'genes', 
                          program  => $self->o('ncbiblast_exe'), 
                          skip     => $self->o('skip_ncbiblast'),
        },
        -hive_capacity => 5,
        -can_be_empty => 1,
      },

    ];
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    ## Extend this section to redefine portion some analysis
    $analyses_by_name->{'concat_fasta'}->{'-flow_into'}   = { 1 => [qw/index_ncbiblastDNA index_BlatDNAIndex primary_assembly/] };
    $analyses_by_name->{'dump_fasta_pep'}->{'-flow_into'} = { 2 => ['index_ncbiblastPEP'], 3 => ['index_ncbiblastGENE'] };
}


1;

