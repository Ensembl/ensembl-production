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

        #read list of staging server 
	my $hosts_config = $self->param('hosts_config');
        my $host_servers = $hosts_config->{'DeleteFrom'};

        #set src uri 
        foreach my $division  ( keys %{ $host_servers }){
		foreach my $i ( 0..scalar( @{$host_servers->{$division}} ) - 1 ){
			
			my $srv = $host_servers->{$division}->[$i];
			my $src_uri = `echo \$($srv details url)`;
			$host_servers->{$division}->[$i] = $src_uri;

		}	
        } 

        #get list of uniqu division to copy 
        my @uniq_divisions = ();
 
	#list grch37 bds
	if( $self->param('process_grch37') || $self->param('run_all') ){

		my $division_databases = $self->get_all_functional_dbs('multi_grch37', $all_divisions, $self->param('release') );
		$self->set_output_flow($division_databases, 'multi_grch37', $host_servers);
                push(@uniq_divisions, keys %{$division_databases});
        } 
	#list only grch37 marts
        if( $self->param('process_grch37_mart') || $self->param('run_all') ){
                my $ens_release = $self->param('release');
		my $division_databases = $self->get_all_mart_and_pan_db('multi_grch37', $all_divisions, $ens_release, 1, 0);
		$self->set_output_flow($division_databases, 'multi_grch37', $host_servers);
		push(@uniq_divisions, keys %{$division_databases});
	}
	

	#list only mart
        if( $self->param('process_mart') || $self->param('run_all') ){
                my $ens_release = $self->param('release');
               #we retain only 2 release for marts so we delete previous release mart 
                #if( ! $self->param('tocopy' ) ){ $ens_release = $self->param('release') + 1 ;}

		my $division_databases = $self->get_all_mart_and_pan_db('multi', $all_divisions, $ens_release, 1, 0);
		$self->set_output_flow($division_databases, 'multi', $host_servers);
                push(@uniq_divisions, keys %{$division_databases});
	}

	#list all functional dbs
	if( !( $self->param('process_grch37') || $self->param('process_mart') || $self->param('process_grch37_mart') ) || $self->param('run_all') ){


                my $division_databases = $self->get_all_functional_dbs('multi', $all_divisions, $self->param('release') );
                $self->set_output_flow($division_databases, 'multi', $host_servers);
                push(@uniq_divisions, keys %{$division_databases});

		#list pan dbs
		$division_databases = $self->get_all_mart_and_pan_db('multi', $all_divisions, $self->param('release'), 0, 1);
		$self->set_output_flow($division_databases, 'multi', $host_servers);
                push(@uniq_divisions, keys %{$division_databases});
		
		#get compara db
		$division_databases = $self->get_all_compara_db('multi', $all_divisions, $self->param('release'));
                $self->set_output_flow($division_databases, 'multi', $host_servers);
                push(@uniq_divisions, keys %{$division_databases});	
        }

	

        if($self->param('tocopy')){
			
                @uniq_divisions = uniq(@uniq_divisions);
	        $self->set_outflow_for_copy(\@uniq_divisions);
		
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
                		#$self->warning($database->dbname);
                        	push (@{$division_databases{$division_name} },$database->dbname);
			}
		}
	}

	return \%division_databases;	
}


sub get_all_mart_and_pan_db{

        my ( $self, $species, $all_divisions, $ens_release, $only_marts, $only_pan ) = @_;
        my ($rdba,$gdba,$release,$release_info, $dbdba) = $self->get_metadata_db($species, 102); #$ens_release);
        my %division_databases ;
        foreach my $division_name (@{$all_divisions}){
                my $genomes = $gdba->fetch_all_by_division($division_name);
               foreach my $mart_database (@{$dbdba->fetch_databases_DataReleaseInfo($release_info,$division_name)}){
                       my $division_type = $division_name;
                       if( $mart_database->dbname =~ /mart/g){
                           if($only_marts){
                                $division_type = ($division_name eq 'EnsemblVertebrates') ? ($species eq 'multi_grch37' ) ? 'EnsemblVertebrates' : 'vert_mart' : 'nonvert_mart';
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

	my ( $self, $division_databases, $type, $host_servers  ) = @_;

	if($self->param('tocopy')){
		return;
	}

        foreach my $keys (keys %{$division_databases}){
                
               foreach my $division_database (sort(uniq(@{$division_databases->{$keys}}))){
			my $division = ( $type eq 'multi_grch37' ) ?  $keys.'_grch37':  $keys;
			foreach my $host (@{ $host_servers->{$division} }){

                                $host =~ s/\s+$//;  
	                        $self->dataflow_output_id( {
        	                        division => $division, # ( $type eq 'multi_grch37' ) ?  $keys.'_grch37':  $keys,
                	                'db_name' =>  $division_database,
                        	        'type'   => $type,
					'src_uri' => $host.$division_database,
                        	}, 2);
			
                        }       

                }
        }		

} 


sub set_outflow_for_copy{

	my ( $self, $divisions  ) = @_;

        my $hosts_config = $self->param('hosts_config');
        my $host_servers = $hosts_config->{'CopyTo'};

	#select staging server based on release version	
	
	foreach my $div (@$divisions){
		if($div !~ /EnsemblPan/){
			if( $self->param('release') % 2 != 0 ){

				$host_servers->{$div}->[0]=~s/sta-(\d)/sta-$1-b/g;
			}
			$host_servers->{$div}->[0] = `echo \$($host_servers->{$div}->[0] details url)`;
			$host_servers->{$div}->[1] = `echo \$($host_servers->{$div}->[1] details url)`;
			$host_servers->{$div}->[0] =~ s/\s+$//;
			$host_servers->{$div}->[1] =~ s/\s+$//;
		}		
	}
	
	if( $self->param('run_all') ){

		$self->copy_division_dbs( $divisions, $host_servers );
		$self->copy_grch37( $divisions, $host_servers, '%homo_sapiens%37' );
                $self->copy_grch37( $divisions, $host_servers, '%mart%' );
		$self->copy_marts( $divisions, $host_servers );
		$self->copy_ensemblpan( $divisions, $host_servers );	
		return ;
	}

	if(  $self->param('process_grch37') ){
		$self->copy_grch37( $divisions, $host_servers, '%homo_sapiens%37');
	}

	if( $self->param('process_grch37_mart')){
		$self->copy_grch37( $divisions, $host_servers, '%mart%' );
        }		

	if($self->param('process_mart')){
		$self->copy_marts( $divisions, $host_servers );
	}

	if( $self->param('copy_vert_dbs') ){
		$self->copy_division_dbs($divisions, $host_servers, 'EnsemblVertebrates' );
	}
	if($self->param('copy_nonvert_dbs')){
		$self->copy_division_dbs($divisions, $host_servers, 'EnsemblPlants' ); #can pass any nonvert division all have same src and dest mysql servers 
	}

}

sub copy_division_dbs{

	my ( $self, $divisions, $host_servers, $division ) = @_;

	#copy all vert/nonvert  dbs
	my $dbname='%core%,%funcgen%,%otherfeatures%,%rnaseq%cdna%variation';
	$self->dataflow_output_id( {
                'source_db_uri' =>  $host_servers->{$division}->[0] . $dbname,
                'target_db_uri' =>  $host_servers->{$division}->[1],
        }, 2);

}

sub copy_grch37{
	my ( $self, $divisions, $host_servers, $db_name ) = @_;

        $host_servers->{'EnsemblVertebrates_grch37'}->[0] = `echo \$($host_servers->{'EnsemblVertebrates_grch37'}->[0] details url)`;
        $host_servers->{'EnsemblVertebrates_grch37'}->[1] = `echo \$($host_servers->{'EnsemblVertebrates_grch37'}->[1] details url)`;
	$host_servers->{'EnsemblVertebrates_grch37'}->[0] =~ s/\s+$//;
        $host_servers->{'EnsemblVertebrates_grch37'}->[1] =~ s/\s+$//;
		
		
	$self->dataflow_output_id( {
        	'source_db_uri' =>  $host_servers->{'EnsemblVertebrates_grch37'}->[0] . $db_name,
                'target_db_uri' =>  $host_servers->{'EnsemblVertebrates_grch37'}->[1],
        }, 2);	
}

sub copy_marts{

	my ( $self, $divisions, $host_servers ) = @_;
        my %marts = ('EnsemblPlants' => 'plants_%mart%', 'EnsemblMetazoa'=>'metazoa_%mart%',
                      'EnsemblFungi' => 'fungi_%mart%', 'EnsemblProtists' => 'protists_%mart%',
                      'EnsemblVertebrates' => '%marts%',
                     ); #ontology_mart is copied from vert divsion %mart%

        foreach my $division (@{$self->get_divisions()}){
                my $div = '';
                if($division =~ /(EnsemblPlants|EnsemblMetazoa|EnsemblFungi|EnsemblProtists)/){
        	        $div = 'nonvert_mart';

                }
                if( $division =~ /EnsemblVertebrates/){
                        $div = 'vert_mart';
                 }
                if( exists $marts{$division} && $div){
                        $self->dataflow_output_id( {
                        	'source_db_uri' =>  $host_servers->{$div}->[0] . $marts{$division},
                                'target_db_uri' => $host_servers->{$div}->[1],
                        }, 2);
                }
       }

	

}

sub copy_ensemblpan{

	my ( $self, $divisions, $host_servers ) = @_;	

        my $division='EnsemblPan';
        my @src = split(',', $host_servers->{$division}->[0]);
        my @target_host = split(',', $host_servers->{$division}->[1]);
        foreach my $i (0..$#src){
        	if( $self->param('release') % 2 != 0 ){
                	$src[$i] =~ s/sta-(\d)/sta-$1-b/g;
                 }
                 my $src_uri = `echo \$($src[$i] details url)`;
                 $src_uri = $src_uri . 'ensembl%_'.$self->param('release');
                 my $target_host = `echo \$($target_host[$i] details url)`;
                 $self->dataflow_output_id( {
                 	'source_db_uri' =>  $src_uri,
                        'target_db_uri' => $target_host,
                 }, 2);

        }

}


1;


                           
