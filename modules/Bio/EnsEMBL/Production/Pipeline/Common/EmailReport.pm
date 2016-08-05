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

=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::Common::EmailReport;

=head1 DESCRIPTION

 Format query results from a database.

=head1 AUTHOR/MAINTAINER

 jallen@ebi.ac.uk, ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::Common::EmailReport;
#package Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EmailReport;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Hive::RunnableDB::NotifyByEmail',
	  'Bio::EnsEMBL::Production::Pipeline::Base',
          #'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base',
          );

sub fetch_input {
    my ($self) = @_;
    # To send an email, three parameters are required, 'email', 'subject',
    # and 'text'. For 'email', you can pass in the default address, which
    # is set to '$USER@ebi.ac.uk', if your conf file inherits from
    # EGGeneric_conf.pm. You will need to pass in the other parameters
    # as well, or set them by overriding this method.
  
return;
}

# Present data in a nice table, like what mySQL does.
sub format_table {
    my ($self, $title, $columns, $results) = @_;
  
    my @lengths;
    foreach (@$columns) {
      push @lengths, length($_) + 2;
    }
  
    foreach (@$results) {
      for (my $i=0; $i < scalar(@$_); $i++) {
        my $len = length($$_[$i]) + 2;
        $lengths[$i] = $len if $len > $lengths[$i];
      } 
    }
  
    my $table = "\n$title\n";
    $table .= '+'.join('+', map {'-' x $_ } @lengths).'+'."\n";
  
    for (my $i=0; $i < scalar(@lengths); $i++) {
      my $column = $$columns[$i];
      my $padding = $lengths[$i] - length($column) - 2;
      $table .= '| '.$column.(' ' x $padding).' ';
    }
  
    $table .= '|'."\n".'+'.join('+', map {'-' x $_ } @lengths).'+'."\n";
  
    foreach (@$results) {
      for (my $i=0; $i < scalar(@lengths); $i++) {
        my $value = $$_[$i];
        my $padding = $lengths[$i] - length($value) - 2;
        $table .= '| '.$value.(' ' x $padding).' ';
      }
      $table .= '|'."\n"
    }
  
    $table .= '+'.join('+', map {'-' x $_ } @lengths).'+'."\n";
  
return $table;
}

1;
