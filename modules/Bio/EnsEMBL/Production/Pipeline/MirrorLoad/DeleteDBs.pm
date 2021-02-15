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

=cut

package Bio::EnsEMBL::Production::Pipeline::MirrorLoad::DeleteDBs;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;
use Bio::EnsEMBL::Registry;
use Carp qw/croak/;

sub run {

	my ( $self ) = @_;

        my %hosts = (
         "EnsemblPlants" => ['m3-w'],
         "EnsemblVertebrates" => ['m1-w'],
         "EnsemblVertebrates_grch37" => ['m2-w'],
         "EnsemblMetazoa" => ['m3-w'],
         "EnsemblProtists" => ['m3-w'],
         "EnsemblBacteria" => ['m4-w'],  
         "EnsemblPan" => ['m1-w', 'm2-w', 'm3-w', 'm4-w'],
         "mart" => ['mysql-ens-mirror-mart-1-ensprod'],       
        );
        
        foreach my $host (@{ $hosts{$self->param('division')} }){
        
		my $dbname = $self->param('db_name');
		my $cmd = "$host -e \" DROP database  $dbname\"  " ;
		if ( $self->run_system_command($cmd) != 0 ) {
		 	croak "cannot delete database $dbname: $!";
		}
		$self->warning($cmd);
        }  
} 

1;


                           
