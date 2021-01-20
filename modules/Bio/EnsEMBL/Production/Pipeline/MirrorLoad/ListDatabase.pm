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

package Bio::EnsEMBL::Production::Pipeline::MirrorLoad::ListDatabase;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor;
use Bio::EnsEMBL::MetaData::Base qw(process_division_names fetch_and_set_release);
use List::MoreUtils qw(uniq);
use Data::Dumper;

sub run {

	my ( $self ) = @_;
        $self->warning($self->param('release'));
        $self->warning($self->param('division'));
        #my $metadata_dba = Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor->new(
        #                   -division =>  $self->param('division'),
        #                   -release  => $self->param('release'),
        #                   -dbname   => 'ensembl_metadata',
        #                   -host     => 'mysql-ens-meta-prod-1.ebi.ac.uk',
        #                   -port     => 4483,                 
        #                   -user     => 'ensro'  
        #);
        #my $metadata_dba =  Bio::EnsEMBL::Registry->get_DBAdaptor( "multi_grch37", "metadata" );

        # get all the database name per division 
	my $division_databases = $self->get_database('multi');
        $self->set_output_flow($division_databases, 'multi'); 

        if( $self->param('process_grch37')){
		#$division_databases = $self->get_database('multi_grch37');
                #$self->set_output_flow($division_databases, 'multi_grch37'); 
        } 
}

sub get_database{

	my ( $self, $species ) = @_;

	my $metadata_dba =  Bio::EnsEMBL::Registry->get_DBAdaptor( $species , "metadata" );

        my $gcdba = $metadata_dba->get_GenomeComparaInfoAdaptor();
        my $gdba = $metadata_dba->get_GenomeInfoAdaptor();
        my $dbdba = $metadata_dba->get_DatabaseInfoAdaptor();
        my $rdba = $metadata_dba->get_DataReleaseInfoAdaptor();
        my ($release,$release_info);
        ($rdba,$gdba,$release,$release_info) = fetch_and_set_release( $self->param('release'), $rdba,$gdba);

        my $all_divisions = [];

        if ( scalar(@{$self->param('division')}) ) {
                $all_divisions = $self->param('division');
                $self->warning(scalar(@{$self->param('division')}));
        }
        else {
                $all_divisions = $gdba->list_divisions();
        }

        $self->warning($release_info->ensembl_genomes_version);

        my %division_databases ;

        foreach my $div (@{$all_divisions}){
                my ($division,$division_name)=process_division_names($div);
                my $division_databases;
                my $genomes = $gdba->fetch_all_by_division($division_name);

                foreach my $genome (@$genomes){
                        foreach my $database (@{$genome->databases()}){
                                #$self->warning($database->dbname);
                                push (@{$division_databases{$division_name} },$database->dbname);
                        }
                }
                foreach my $compara_database (@{$gcdba->fetch_division_databases($division_name,$release_info)}){
                        push (@{$division_databases{$division_name}},$compara_database);
                        #$self->warning($compara_database);
                }

                if($self->param('process_mart')){
                        #mart databases
                        foreach my $mart_database (@{$dbdba->fetch_databases_DataReleaseInfo($release_info,$division_name)}){
				my $division_type = $division_name;	
				if( $mart_database->dbname =~ /mart/g){
					 $division_type = 'mart';
				}    			
                              push (@{$division_databases{$division_type}},$mart_database->dbname);
                        }

                }

        }
	return \%division_databases;

}

sub set_output_flow{
	my ( $self, $division_databases, $type ) = @_;

	#print Dumper($division_databases);
        foreach my $keys (keys %{$division_databases}){
                
               foreach my $division_database (sort(uniq(@{$division_databases->{$keys}}))){
                        $self->dataflow_output_id( {
                                division => $keys,
                                'db_name' => $division_database,
				'type'   => $type,
                        }, 2);
                }
        }		

} 

1;


                           
