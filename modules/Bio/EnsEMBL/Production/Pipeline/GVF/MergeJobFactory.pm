=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

 Bio::EnsEMBL::Production::Pipeline::GVF::MergeJobFactory;

=head1 DESCRIPTION

    Checks, if for any species all partial dumps have been completed.

    If not, terminates.

    If so, then it will create a merge job for every completed species.

=head1 MAINTAINER 

 ckong@ebi.ac.uk 

=cut
package Bio::EnsEMBL::Production::Pipeline::GVF::MergeJobFactory;
#package EGVar::FTP::RunnableDB::GVF::MergeJobFactory;

use strict;
use Carp;
use Data::Dumper;
use Log::Log4perl qw/:easy/;
use base qw/Bio::EnsEMBL::Production::Pipeline::Base/;
#use base ('EGVar::FTP::RunnableDB::GVF::Base');

sub run {
    my $self = shift;
    my $division = $self->param('division');
    my $logger = $self->get_logger;

    my $gvf_type = [
	    'default',
	    'failed',
	    'incl_consequences',
	    'structural_variations',
    ];

    GVF_TYPE: foreach my $current_gvf_type (@$gvf_type) {
	my $species_id = $self->fetch_species_ids_of_completed_dumps_by_type(
	    $current_gvf_type,
	    $division
	);

    next GVF_TYPE unless($species_id);

    foreach my $current_species_id (@$species_id) {
    # Create a merge job for the files of type $gvf_type of this species
 	$self->dataflow_output_id(
	       {
		    species_id => $current_species_id,
		    gvf_type   => $current_gvf_type,
		}, 2
	    );

	    $logger->info("Created a merge job for the $current_gvf_type gvf files of species $current_species_id") if ($self->debug);

	    my $adaptor = $self->db->get_NakedTableAdaptor();
	    $adaptor->table_name( 'gvf_merge' );
	    my $hash = $adaptor->fetch_by_species_id_and_type( $current_species_id, $current_gvf_type );
	    use Hash::Util qw( lock_keys );
	    lock_keys(%$hash);
	    $hash->{created} = 1;
	    $adaptor->update($hash);
	}
    }
}

=head1 fetch_species_ids_of_completed_dumps_by_type

    Find species ids for all species for which all files of the given
    gvf_type have completed and are ready to be merged.

=cut
sub fetch_species_ids_of_completed_dumps_by_type {
    my $self     = shift;
    my $gvf_type = shift;
    my $division = shift;

    my $logger = $self->get_logger;

    my $sql = qq~
select
	gvf_species.species_id
from
	(select species_id, count(file) as files_done from gvf_file where type='$gvf_type' group by species_id) a
	join gvf_species using (species_id)
	join gvf_merge using(species_id)
where
	files_done=total_files
	and gvf_merge.created=FALSE
	and gvf_species.division='$division'
;
~;

    if ($self->debug) {
	$logger->info("Looking for completed species of type '$gvf_type' by running this sql statement:");
	$logger->info($sql);
    }

    my $dbh = $self->hive_dbh();
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    my $species_id = $sth->fetchall_arrayref;

=head2

Returns a list looking like this:

$VAR1 = [
          [
            '1'
          ],
          [
            '2'
          ]
        ];
=cut

    if ($self->debug) {
	$logger->info("No completed species found.") unless(@$species_id);
    }
    return unless(@$species_id);

    # Flattening the array
    @$species_id = map { $_->[0] } @$species_id;

    if ($self->debug) {
	$logger->info("Found ".(@$species_id)." species.");
    }

return $species_id;
}

1;
