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
