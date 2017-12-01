
=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::FtpChecker::CheckFtp;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Data::Dumper;

use Log::Log4perl qw/:easy/;



sub check_files {
  my ($self, $species, $type, $base_path, $expected_files, $vals) = @_;
  my $n = 0;
  $DB::single = 1;
  while( my($format) = each %$expected_files) { 
    for my $file (@{$expected_files->{$format}->{expected}}) {
      my $path =  _expand_str($base_path.'/'.$expected_files->{$format}->{dir}.'/'.$file, $vals);
      if ($format eq "vep" and $vals->{division} eq ""){
        $path = _expand_str($base_path.'/variation/'.$expected_files->{$format}->{dir}.'/'.$file, $vals);
        $path =~ s/vep/VEP/;
      }
      else{
        $path = _expand_str($base_path.'/'.$expected_files->{$format}->{dir}.'/'.$file, $vals);
      }
      my @files = glob($path);
      if(scalar(@files) == 0) {
	$self->{logger}->error("Could not find $path");
	$self->dataflow_output_id(   
				  {
				   species => $species,
           division => $vals->{division},
				   type => $type,
           format => $format,
				   file_path=>$path
				  }
				  , 2);
	$n++;
      }
    }
  }    
  return $n;
}

sub _expand_str {
  my ($template, $vals) = @_;
  my $str = $template;
  while(my ($k,$v) = each %$vals) {
    $str =~ s/\{$k\}/$v/g;
  }
  return $str;
}

1;
