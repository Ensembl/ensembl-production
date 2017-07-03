
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

package Bio::EnsEMBL::Production::Search::VariationSolrFormatter;

use warnings;
use strict;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Data::Dumper;
use Log::Log4perl qw/get_logger/;
use List::MoreUtils qw/natatime/;

use Bio::EnsEMBL::Production::Search::JSONReformatter;
use Bio::EnsEMBL::Production::Search::SolrFormatter;

use JSON;
use Carp;
use File::Slurp;

use base qw/Bio::EnsEMBL::Production::Search::SolrFormatter/;
sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
  return $self;
}

sub reformat_variants {
	my ( $self, $infile, $outfile ) = @_;
	return;
}

sub reformat_somatic_variants {
	my ( $self, $infile, $outfile ) = @_;
	return;
}

sub reformat_structural_variants {
	my ( $self, $infile, $outfile ) = @_;
	return;
}

sub reformat_phenotypes {
	my ( $self, $infile, $outfile ) = @_;
	return;
}

1;
