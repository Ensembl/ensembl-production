=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Search::SolrFormatter;

use warnings;
use strict;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Data::Dumper;
use Log::Log4perl qw/get_logger/;
use List::MoreUtils qw/natatime/;

use Bio::EnsEMBL::Production::Search::JSONReformatter;

use JSON;
use Carp;
use File::Slurp;

use Exporter 'import'; 
our @EXPORT = qw(_array_nonempty _id_ver _base);

sub new {
	my ( $class, @args ) = @_;
	my $self = bless( {}, ref($class) || $class );
	$self->{log} = get_logger();
	return $self;
}

sub log {
	my ($self) = @_;
	return $self->{log};
}

sub _id_ver {
	my ($o) = @_;
	return $o->{id} . ( defined $o->{version} ? ".$o->{version}" : "" );
}

sub _base {
	my ( $genome, $db_type, $obj_type ) = @_;
	return {
		ref_boost        => _ref_boost($genome),
		db_boost         => _db_boost($db_type),
		website          => _website($genome),
		feature_type     => $obj_type,
		species          => $genome->{organism}{name},
		species_name     => $genome->{organism}{display_name},
		reference_strain => (
			defined $genome->{is_reference} && $genome->{is_reference} eq 'true'
		  ) ? 1 : 0,
		database_type => $db_type };
}

sub _ref_boost {
	my ($genome) = @_;
	return $genome->{is_reference} ? 10 : 1;
}

sub _db_boost {
	my ($type) = @_;
	return $type eq 'core' ? 40 : 1;
}

my $sites = { EnsemblVertebrates         => "http://www.ensembl.org/",
			  EnsemblBacteria => "http://bacteria.ensembl.org/",
			  EnsemblProtists => "http://protists.ensembl.org/",
			  EnsemblFungi    => "http://fungi.ensembl.org/",
			  EnsemblPlants   => "http://plants.ensembl.org/",
			  EnsemblMetazoa  => "http://metazoa.ensembl.org/", };

sub _website {
	my ($genome) = @_;
	return $sites->{ $genome->{division} };
}

sub _array_nonempty {
	my ($ref) = @_;
	return defined $ref && scalar(@$ref) > 0;
}

1;
