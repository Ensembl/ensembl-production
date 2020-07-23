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

 Bio::EnsEMBL::Production::Pipeline::Webdatafile::WebSpeciesFactory;

=head1 DESCRIPTION
  Compute each step for webdatafile dumps

=cut

package Bio::EnsEMBL::Production::Pipeline::Webdatafile::WebdataFile;

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;
use Path::Tiny qw(path);
use Array::Utils qw(intersect);
use Path::Tiny qw(path);
use Carp qw/croak/;

sub param_defaults {
  my ($self) = @_;
  return {
    %{$self->SUPER::param_defaults},
  };
}


sub run {

  my ($self) = @_;
  my $species = $self->param('species');
  my $step = $self->param('step') ;
  my $output = $self->param('output_path');
  my $app_path = $self->param('app_path'); 
  my $log_file =  "$output/WebFiles_$step.log";
  my $cmd = "$app_path/bin/prepare_all_datafiles.pl $species -output $output -step $step &> $output/Webdatafile_$step.log";
  #my ($rc, $sysoutput)=$self->run_cmd($cmd);
  system($cmd);
  my $status = $? >> 8;
  if($status){
    my $log;
    {
      local($/) = undef;
      open (FILE, "$output/Webdatafile_$step.log");
      $log = <FILE>;
      close FILE;
   }
    croak "$log ";
  }
}

sub write_output {
  my ($self) = @_;
  my $species        = $self->param('species');
  my $group          = $self->param('group');
  my $step           = $self->param('step');
  
  if ($step eq 'bootstrap') {
        my @all_steps = (['transcripts', 1], ['contigs', 2], ['gc', 3], ['variants', 4]);
        for my $each_step (@all_steps){

            $self->dataflow_output_id(
              {
                 species => $species,
                 group   => $group,
                 step    => @{$each_step}[0]
              },@{$each_step}[1] 
            );
        }  
  }
}



1;
