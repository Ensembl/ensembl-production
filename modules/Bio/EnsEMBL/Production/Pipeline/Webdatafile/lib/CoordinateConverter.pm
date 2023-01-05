=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2023] EMBL-European Bioinformatics Institute

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


package Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::CoordinateConverter;

##########################################################################
#
# Just a fancy place to keep a functions for converting 0-based coordinate to 1-based
# and 1-based coordinate to 0-based
#
##########################################################################

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT = qw( to_zero_based to_one_based );

sub to_zero_based {
  my ( $one_based_coordinate ) = @_;
  return $one_based_coordinate - 1;
}

sub to_one_based {
  my ( $zero_based_coordinate ) = @_;
  return $zero_based_coordinate + 1;
}
