
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

  Bio::EnsEMBL::Production::Search::BaseFetcher

=head1 DESCRIPTION


Base module for Fetchers

=cut

package Bio::EnsEMBL::Production::Search::BaseFetcher;

use strict;
use warnings;

use Log::Log4perl qw/get_logger/;
use Carp qw/croak/;

my $logger = get_logger();

sub calculate_min_max {
  my ($self, $h, $offset, $length, $table, $key) = @_;
  $table ||= 'variation';
  $key ||= 'variation_id';
  if (!defined $offset) {
    $offset =
        $h->execute_single_result(-SQL => qq/select min($key) from $table/);
  }
  if (!defined $length) {
    $length =
        ($h->execute_single_result(-SQL => qq/select max($key) from $table/))
            - $offset + 1;
  }
  $logger->debug("Calculating $offset/$length");
  my $max = $offset + $length - 1;

  $logger->debug("Current ID range $offset -> $max");
  return($offset, $max);
}

1;
