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

=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::InterProScan::LoadMd5;

=head1 DESCRIPTION

=head1 MAINTAINER/AUTHOR 

 ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::InterProScan::LoadMd5;

use strict;
use Carp;
use File::Spec;
use Data::Dumper;
use Bio::EnsEMBL::Utils::SqlHelper;
use base ('Bio::EnsEMBL::Production::Pipeline::InterProScan::Base');

sub pre_cleanup {
    my $self = shift;

    my $cleanup_sql = 'drop table if exists checksum;';
    my $helper      = Bio::EnsEMBL::Utils::SqlHelper->new( -DB_CONNECTION => $self->hive_dbc() );

    eval {
        $helper->execute_update(-SQL => $cleanup_sql);
    };
    if ($@) {
        $self->warning("Error executing:\n\n$cleanup_sql\n\non ".($self->hive_database_string_for_user)."\n\n$@");
    }

}

sub run {
    my $self = shift;

    my $md5_checksum_file = $self->param('md5_checksum_file')  || die "'md5_checksum_file' is an obligatory parameter";
    confess("Md5 checksum file ($md5_checksum_file) doesn't exist!") unless(-e $md5_checksum_file);
    my $helper            = Bio::EnsEMBL::Utils::SqlHelper->new( -DB_CONNECTION => $self->hive_dbc() );

    my @create_table_sql = (
    	q(
      	     create table if not exists checksum (

				-- Using latin1_swedish_ci makes lookups case insensitive, this is 
				-- important, because the md5 checksums from interpro use uppercase hex 
				-- digits and the one generated using perl are lower case.
				--
    			md5sum char(32) collate latin1_swedish_ci
    		);
    	),
		q(CREATE INDEX md5_lookup ON checksum (md5sum) using hash;)
	);

   foreach my $current_statement (@create_table_sql) {
      eval {
             $helper->execute_update(-SQL => $current_statement);
      };
      confess("Error executing:\n\n$current_statement\n\non ".($self->hive_database_string_for_user)."\n\n$@") if ($@);
   }

   my $load_file_sql = q(load data local infile ? into table checksum(md5sum));
   use DBI qw(:sql_types);
   $helper->execute_update(-SQL => $load_file_sql, -PARAMS => [$md5_checksum_file]);

}

1;

