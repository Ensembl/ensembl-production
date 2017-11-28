
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

package Bio::EnsEMBL::Production::Pipeline::Search::DumpFactory;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

use Bio::EnsEMBL::Utils::Exception qw(throw);

use JSON;
use File::Path qw(make_path);

use Log::Log4perl qw/:easy/;

sub run {
	my ($self) = @_;

	my $species = $self->param_required('species');
	my $type = $self->param_required('type');
	my $table = $self->param_required('table');
	my $column = $self->param_required('column');

	$self->log()->debug("Fetching $type DBA for $species");
	my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor( $species, $type );

	throw "No $type database found for $species" unless defined $dba;

	my $length = $self->param_required('length');
	
	my $cnt = $dba->dbc()->sql_helper()
	  ->execute(
							-SQL => 'select '.$column.' from '.$table.' limit 1' );
	if(!scalar @$cnt) {
		$self->log()->info("$table is empty - not spawning any jobs");
		return;
	}

	my $min_id =
	  $dba->dbc()->sql_helper()
	  ->execute_single_result(
							-SQL => 'select min('.$column.') from '.$table );
	my $max_id =
	  $dba->dbc()->sql_helper()
	  ->execute_single_result(
							-SQL => 'select max('.$column.') from '.$table );

	my $offset = $min_id;
	my $n      = 0;
	while ( $offset < $max_id ) {
		$self->log()->debug("Writing slice job for $offset,$length");
		$self->dataflow_output_id( {  'species' => $species,
									  'offset'  => $offset,
									  'length'  => $length },
								   2 );
		$offset += $length;
		$n++;
	}
	$self->log()->debug("Wrote $n slice jobs");

	return;
} ## end sub run

1;
