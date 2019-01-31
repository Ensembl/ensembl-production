
=head1 LICENSE

Copyright [2009-2019] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::FtpChecker::ReportFailures;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

use Carp;

sub run {
  my ($self) = @_;
  my $outfile = $self->param_required('failures_file');
  open my $out, ">", $outfile || croak "Could not open $outfile for writing";
  my $n = 0;
  $self->hive_dbc()->sql_helper()->execute_no_return(
						     -SQL=>q/select * from failures/,
						     -CALLBACK => sub {
						       my $row = shift;
						       print $out join("\t", @$row);
						       print $out "\n";
							 $n++;
						       return;	       
						     } 	    	       
						    );
  close $out;
  return;
}

1;
