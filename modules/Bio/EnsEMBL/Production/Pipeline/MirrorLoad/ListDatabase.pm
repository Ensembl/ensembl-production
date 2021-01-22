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

        #process division names 
        my $all_divisions = $self->get_divisions();
	
	#list grch37 bds
	if( $self->param('process_grch37') || $self->param('run_all') ){

		my $division_databases = $self->get_all_functional_dbs('multi_grch37', $all_divisions, $self->param('release') );
		$self->set_output_flow($division_databases, 'multi_grch37');
        } 
	
	#list only mart
        if( $self->param('process_mart') || $self->param('run_all') ){
                #we retain only 2 release for marts which includes current one 
                #delete previous release mart
                my $ens_release = $self->param('release') + 1 ;  
		my $division_databases = $self->get_all_mart_and_pan_db('multi', $all_divisions, $ens_release, 1, 0);
		$self->set_output_flow($division_databases, 'multi');
	}

	#list all functional dbs
	if( !( $self->param('process_grch37') || $self->param('process_mart') ) || $self->param('run_all') ){


                my $division_databases = $self->get_all_functional_dbs('multi', $all_divisions, $self->param('release') );
                $self->set_output_flow($division_databases, 'multi');

		#list pan dbs
		$division_databases = $self->get_all_mart_and_pan_db('multi', $all_divisions, $self->param('release'), 0, 1);
		$self->set_output_flow($division_databases, 'multi');
		
		#get compara db
		$division_databases = $self->get_all_compara_db('multi', $all_divisions, $self->param('release'));
                $self->set_output_flow($division_databases, 'multi');	
        }
        
}

sub get_divisions{

        my ($self) = @_; 
        my $all_divisions = [];
	my $all_processed_divsions = [];

        my ($rdba,$gdba,$release,$release_info) = $self->get_metadata_db('multi', $self->param('release'));

        if ( scalar(@{$self->param('division')}) ) {
                $all_divisions = $self->param('division');
        }
        else {
                $all_divisions = $gdba->list_divisions();
        }

	foreach my $div (@{$all_divisions}){
		my ($division,$division_name)=process_division_names($div);
		push(@{$all_processed_divsions}, $division_name)
	}

	return $all_processed_divsions

}

sub get_metadata_db{

        my ( $self, $species, $ens_release ) = @_;

        my $metadata_dba =  Bio::EnsEMBL::Registry->get_DBAdaptor( $species , "metadata" );

        my $gcdba = $metadata_dba->get_GenomeComparaInfoAdaptor();
        my $gdba = $metadata_dba->get_GenomeInfoAdaptor();
        my $dbdba = $metadata_dba->get_DatabaseInfoAdaptor();
        my $rdba = $metadata_dba->get_DataReleaseInfoAdaptor();
        my ($release,$release_info);
        ($rdba,$gdba,$release,$release_info) = fetch_and_set_release( $ens_release, $rdba,$gdba);
        
        return ($rdba,$gdba,$release,$release_info,$dbdba,$gcdba)         

} 

sub get_all_functional_dbs{

	my ( $self, $species, $all_divisions, $ens_release ) = @_;
        my ($rdba,$gdba,$release,$release_info) = $self->get_metadata_db($species, $ens_release);
        my %division_databases ; 
        foreach my $division_name (@{$all_divisions}){
                my $genomes = $gdba->fetch_all_by_division($division_name);
        	foreach my $genome (@$genomes){
        		foreach my $database (@{$genome->databases()}){
                		$self->warning($database->dbname);
                        	push (@{$division_databases{$division_name} },$database->dbname);
			}
		}
	}

	return \%division_databases;	
}


sub get_all_mart_and_pan_db{

        my ( $self, $species, $all_divisions, $ens_release, $only_marts, $only_pan ) = @_;
        my ($rdba,$gdba,$release,$release_info, $dbdba) = $self->get_metadata_db($species, $ens_release);
        my %division_databases ;
        foreach my $division_name (@{$all_divisions}){
                my $genomes = $gdba->fetch_all_by_division($division_name);
               foreach my $mart_database (@{$dbdba->fetch_databases_DataReleaseInfo($release_info,$division_name)}){
                       my $division_type = $division_name;
                       if( $mart_database->dbname =~ /mart/g){
                           if($only_marts){
                                $division_type = 'mart';
                                push (@{$division_databases{$division_type}},$mart_database->dbname);
                           }
                       }else{
			  if($only_pan){
	                         push (@{$division_databases{$division_type}},$mart_database->dbname);
	                  }    	
                       }
                }

        }

        return \%division_databases;

}

sub get_all_compara_db{

        my ( $self, $species, $all_divisions, $ens_release ) = @_;
	my ($rdba,$gdba,$release,$release_info, $dbdba, $gcdba) = $self->get_metadata_db($species, $ens_release);
	my %division_databases ;
        foreach my $division_name (@{$all_divisions}){
        	foreach my $compara_database (@{$gcdba->fetch_division_databases($division_name,$release_info)}){
			push (@{$division_databases{$division_name}},$compara_database);
                        #$self->warning($compara_database);
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
                                division =>  ( $type eq 'multi_grch37' ) ?  $keys.'_grch37':  $keys,
                                'db_name' =>  $division_database,
				'type'   => $type,
                        }, 2);
                }
        }		

} 

1;


                           
