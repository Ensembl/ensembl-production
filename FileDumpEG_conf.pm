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

Bio::EnsEMBL::EGPipeline::PipeConfig::FileDumpEG_conf

=head1 DESCRIPTION

Dump GFF3 files.

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::PipeConfig::FileDumpEG_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.3;
use base ('Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf');
use File::Spec::Functions qw(catdir);

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'file_dump_'.$self->o('eg_release'),

    species      => [],
    division     => [],
    run_all      => 0,
    antispecies  => [],
    meta_filters => {},

    db_type => 'core',

    dump_type          => [],
    results_dir        => $self->o('ENV', 'PWD'),
    eg_toplevel_dir    => catdir($self->o('results_dir'), 'release-'.$self->o('eg_release')),
    eg_dir_structure   => 1,
    eg_filename_format => $self->o('eg_dir_structure'),
    compress_files     => 1,

    gff3_db_type          => 'core',
    gff3_feature_type     => [],
    gff3_per_chromosome   => 1,
    gff3_include_scaffold => 0,
    gff3_logic_name       => [],

    gt_exe        => '/nfs/panda/ensemblgenomes/external/genometools/bin/gt',
    gff3_tidy     => $self->o('gt_exe').' gff3 -tidy -sort -retainids',
    gff3_validate => $self->o('gt_exe').' gff3validator',

  };
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

# Ensures that species output parameter gets propagated implicitly.
sub hive_meta_table {
  my ($self) = @_;

  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack'  => 1,
  };
}

sub pipeline_create_commands {
  my ($self) = @_;

  return [
    @{$self->SUPER::pipeline_create_commands},
    'mkdir -p '.$self->o('results_dir'),
  ];
}

sub pipeline_analyses {
  my ($self) = @_;

  my $flow_into_compress = $self->o('compress_files') ? ['CompressFile'] : [];

  return [
    {
      -logic_name        => 'SpeciesFactory',
      -module            => 'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
      -input_ids         => [ {} ],
      -parameters        => {
                              species         => $self->o('species'),
                              antispecies     => $self->o('antispecies'),
                              division        => $self->o('division'),
                              run_all         => $self->o('run_all'),
                              meta_filters    => $self->o('meta_filters'),
                              chromosome_flow => 0,
                              variation_flow  => 0,
                            },
      -max_retry_count   => 1,
      -flow_into         => {
                              '2' => $self->o('dump_type'),
                            },
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'gff3',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -parameters        => {},
      -flow_into         => {
                              '1->A' => ['gff3Dump'],
                              'A->1' => ['gff3Readme'],
                            },
      -meadow_type     => 'LOCAL',
    },

    {
      -logic_name        => 'gff3Dump',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::GFF3Dumper',
      -parameters        => {
                              db_type            => $self->o('gff3_db_type'),
                              feature_type       => $self->o('gff3_feature_type'),
                              per_chromosome     => $self->o('gff3_per_chromosome'),
                              include_scaffold   => $self->o('gff3_include_scaffold'),
                              logic_name         => $self->o('gff3_logic_name'),
                              results_dir        => $self->o('eg_toplevel_dir'),
                              eg_dir_structure   => $self->o('eg_dir_structure'),
                              eg_filename_format => $self->o('eg_filename_format'),
                            },
      -analysis_capacity => 10,
      -max_retry_count   => 0,
      -rc_name           => 'normal',
      -flow_into         => ['gff3Tidy'],
    },

    {
      -logic_name        => 'gff3Tidy',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 10,
      -batch_size        => 10,
      -parameters        => {
                              cmd => $self->o('gff3_tidy').' #out_file# > #out_file#.sorted',
                            },
      -rc_name           => 'normal',
      -flow_into         => ['gff3Move'],
    },

    {
      -logic_name        => 'gff3Move',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 10,
      -parameters        => {
                              cmd => 'mv #out_file#.sorted #out_file#',
                            },
      -rc_name           => 'normal',
      -flow_into         => ['gff3Validate'],
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name        => 'gff3Validate',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 10,
      -batch_size        => 10,
      -parameters        => {
                              cmd => $self->o('gff3_validate').' #out_file#',
                            },
      -rc_name           => 'normal',
      -flow_into         => $flow_into_compress,
    },

    {
      -logic_name        => 'gff3Readme',
      -module            => 'Bio::EnsEMBL::EGPipeline::FileDump::ReadmeDumper',
      -parameters        => {
                              readme_template  => gff_readme(),
                              results_dir      => $self->o('eg_toplevel_dir'),
                              eg_dir_structure => $self->o('eg_dir_structure'),
                              file_type        => 'gff3',
                              filename         => 'README',
                            },
      -analysis_capacity => 10,
      -max_retry_count   => 0,
      -rc_name           => 'normal',
    },

    {
      -logic_name        => 'CompressFile',
      -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -analysis_capacity => 10,
      -batch_size        => 10,
      -parameters        => {
                              cmd => 'gzip -f #out_file#',
                            },
      -rc_name           => 'normal',
    },

  ];
}

sub gff_readme {
  return <<README;
#### README ####

IMPORTANT: Please note you can download correlation data tables, 
supported by Ensembl, via the highly customisable BioMart data mining tool. 
See http://DIVISION.ensembl.org/biomart/martview 
or http://www.ebi.ac.uk/biomart/ for more information. Not available for
Ensembl Bacteria. 

-----------------------
GFF FLATFILE DUMPS
-----------------------
This directory contains GFF flatfile dumps. All files are compressed
using GNU Zip.

Ensembl Genomes provides an automatic reannotation of genomic data as well
as imports of existing genomic data. These data will be dumped in a number 
of forms - one of them being GFF flat files. As the annotation of this
form comes from Ensembl Genomes, and not the original sequence entry, 
the two annotations are likely to be different.

GFF flat file format dumping provides all the sequence features known by 
Ensembl Genomes, including protein coding genes, ncRNA, repeat features etc. 
Considerably more information is stored in  Ensembl Genomes: the flat file 
just gives a representation which is compatible with existing tools.

We are considering other information that should be made dumpable. In 
general we would prefer people to use database access over flat file 
access if you want to do something serious with the data.

-----------
FILE NAMES
------------
The files are consistently named following this pattern:
   <species>.<assembly>.<eg_version>.gff3.gz

<species>:       The systematic name of the species. 
<assembly>:      The assembly build name.
<eg_version>: The version of Ensembl Genomes from which the data was exported.
gff3 : All files in these directories are in GFF3 format
gz : All files are compacted with GNU Zip for storage efficiency.

e.g. 
Drosophila_melanogaster.BDGP6.21.gff3.gz

Where the genome has a chromosome-level assembly, individual files are provided
for each chromosome, named following this pattern:
   <species>.<assembly>.<eg_version>.chromosome.<chromosome_name>.gff3.gz
Where the assembly also contains additional non-chromosomal that are not present
in the chromosomes, these are all available in a file with the pattern:
   <species>.<assembly>.<eg_version>.non_chromosomal.gff3.gz

e.g. 
Drosophila_melanogaster.BDGP6.21.74.chromosome.2L.gff3.gz 
Drosophila_melanogaster.BDGP6.21.nonchromosomal.gff3.gz

README
}

1;
