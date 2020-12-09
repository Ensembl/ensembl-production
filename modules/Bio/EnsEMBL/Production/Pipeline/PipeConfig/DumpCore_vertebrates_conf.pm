=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpCore_vertebrates_conf;

=head1 DESCRIPTION

=head1 AUTHOR 

 ckong@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpCore_vertebrates_conf;

use strict;
use warnings;
use File::Spec;
use Data::Dumper;
use Bio::EnsEMBL::ApiVersion qw/software_version/;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::DumpCore_conf');
   
sub default_options {
    my ($self) = @_;
    
    return {
       # inherit other stuff from the base class
       %{ $self->SUPER::default_options() },

       'ncbiblast_exe' => 'makeblastdb',
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
          blat_species => $self->o('blat_species'),
        },
        -can_be_empty => 1,
        -analysis_capacity => 10,
        -priority => 5,
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
       -analysis_capacity => 10,
       -priority => 5,
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
        -analysis_capacity => 10,
        -priority => 5,
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
        -analysis_capacity => 10,
        -priority => 5,
        -can_be_empty => 1,
      },
      {
          -logic_name        => 'ChecksumGeneratorBLASTGENE',
          -parameters => {
                            dir => $self->o('ftp_dir')."/vertebrates/ncbi_blast/genes/"
          },
          -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::ChecksumGenerator',
          -flow_into       => { '1' => 'ChecksumGeneratorBLASTGENOMIC', },
          -analysis_capacity => 10,
          -priority => 5,
      },
            {
          -logic_name        => 'ChecksumGeneratorBLASTGENOMIC',
          -parameters => {
                            dir => $self->o('ftp_dir')."/vertebrates/ncbi_blast/genomic/"
          },
          -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::ChecksumGenerator',
          -analysis_capacity => 10,
          -priority => 5,
      },
      {
          -logic_name        => 'copy_ncbiblastDNA',
          -parameters => {
                          ftp_dir => $self->o('prev_rel_dir'),
                          dir => $self->o('ftp_dir')."/vertebrates/ncbi_blast/genomic/",
                          release => $self->o('release'),
                          type    => 'genomic',
                          blast_dir => 'ncbi_blast',
          },
          -module            => 'Bio::EnsEMBL::Production::Pipeline::FASTA::CopyNCBIBlastDNA',
          -analysis_capacity => 10,
          -priority => 5,
      },
    ];
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    ## Extend this section to redefine portion some analysis
    if (not $self->o('skip_blat')){
        if ($self->o('skip_ncbiblast')){
          $analyses_by_name->{'concat_fasta'}->{'-flow_into'}   = { 1 => WHEN( '#blat_species#->{#species#}' => [qw/index_BlatDNAIndex primary_assembly/], ELSE ['primary_assembly'],)};
        }
        else{
          $analyses_by_name->{'concat_fasta'}->{'-flow_into'}   = { 1 => WHEN( '#blat_species#->{#species#}' => [qw/index_ncbiblastDNA index_BlatDNAIndex primary_assembly/], ELSE [qw/index_ncbiblastDNA primary_assembly/],)};
        }
    }
    if (not $self->o('skip_ncbiblast')){
        if ($self->o('skip_blat')){
          $analyses_by_name->{'concat_fasta'}->{'-flow_into'}   = { 1 => [qw/index_ncbiblastDNA primary_assembly/]};
        }
        $analyses_by_name->{'fasta_pep'}->{'-flow_into'} = { 2 => ['index_ncbiblastPEP'], 3 => ['index_ncbiblastGENE'] };
        $analyses_by_name->{'job_factory'}->{'-flow_into'} = { '2->A' => ['backbone_job_pipeline'], 'A->1' => 'ChecksumGeneratorBLASTGENE', };
        $analyses_by_name->{'copy_dna'}->{'-flow_into'} = { 1 => ['copy_ncbiblastDNA']};
    }
}

1;
