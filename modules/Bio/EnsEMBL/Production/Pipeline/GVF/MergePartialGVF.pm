=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

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

package EGVar::FTP::RunnableDB::GVF::MergePartialGVF;

use strict;
use Data::Dumper;
use base ('EGVar::FTP::RunnableDB::GVF::Base');
use Carp;
use EGUtils::SystemCmdRunner;
use Hash::Util qw( lock_hash );

sub run {

    my $self = shift;

    my $species_id       = $self->param('species_id');
    my $gvf_type         = $self->param('gvf_type');
    
    my $temp_dir         = $self->param('temp_dir');
    my $ftp_gvf_file_dir = $self->param('ftp_gvf_file_dir');

    my $ftp_vcf_file_dir = $self->param('ftp_vcf_file_dir');

    my $logger = $self->get_logger;

    my $adaptor = $self->db->get_NakedTableAdaptor();
    $adaptor->table_name( 'gvf_file' );
    my $gvf_file_hash = $adaptor->fetch_by_species_id_and_type_HASHED_FROM_file_id_TO_file( $species_id, $gvf_type );
    
    lock_hash(%$gvf_file_hash);

    if ($self->debug) {
	$logger->info("gvf_file_hash=\n" . Dumper($gvf_file_hash));
    }

    my @file_id = keys %$gvf_file_hash;

    my $adaptor = $self->db->get_NakedTableAdaptor();
    $adaptor->table_name( 'gvf_species' );
    my $gvf_species_hash = $adaptor->fetch_by_species_id( $species_id );
    
    lock_hash(%$gvf_species_hash);

    my $ftp_this_species_dir = File::Spec->join($ftp_gvf_file_dir, $gvf_species_hash->{species});

    my $merged_file_name;

    if ($gvf_type eq 'default') {
	$merged_file_name = File::Spec->join($ftp_this_species_dir, $gvf_species_hash->{species} . '.gvf');
    } else {
	$merged_file_name = File::Spec->join($ftp_this_species_dir, $gvf_species_hash->{species} .'.'. $gvf_type . '.gvf');
    }

    my $ftp_this_species_vcf_dir = File::Spec->join($ftp_vcf_file_dir, $gvf_species_hash->{species});
    my $vcf_file;
    if ($gvf_type eq 'default') {
	$vcf_file         = File::Spec->join($ftp_this_species_vcf_dir, $gvf_species_hash->{species} . '.vcf');
    } else {
	$vcf_file         = File::Spec->join($ftp_this_species_vcf_dir, $gvf_species_hash->{species} .'.'. $gvf_type . '.vcf');
    }

# $logger->info("gvf file = $merged_file_name");
# $logger->info("vcf file = $vcf_file");


    if (! -d $ftp_this_species_vcf_dir) {
	$logger->info("Creating directory $ftp_this_species_vcf_dir for " . $gvf_species_hash->{species});
	use File::Path qw( make_path );
	make_path($ftp_this_species_vcf_dir);
    }


    use File::Spec;

    my $merged_header      = File::Spec->join($temp_dir, $gvf_species_hash->{species} . ".$gvf_type.header.gvf");
    my $merged_seq_regions = File::Spec->join($temp_dir, $gvf_species_hash->{species} . ".$gvf_type.seq_regions.gvf");
    my $merged_data        = File::Spec->join($temp_dir, $gvf_species_hash->{species} . ".$gvf_type.data.gvf");

    my $runner = EGUtils::SystemCmdRunner->new();

    if ($self->debug) {
	$logger->info("merged_file_name = $merged_file_name");
	$logger->info("merged_header = $merged_header");
	$logger->info("merged_seq_regions = $merged_seq_regions");
	$logger->info("merged_data = $merged_data");
    }

    my $first_file = $gvf_file_hash->{$file_id[0]};

    if ($self->debug) {
	$logger->info("first_file = $first_file\n");
    }

    $runner->run_cmd(
        qq(grep -e "^##" $first_file | grep -v "^##sequence-region" > $merged_header),
        [{
            test     => sub { return -f $merged_header },
            fail_msg => "Couldn't create file $merged_header!"
        },], 1
    );

    unlink($merged_data) if (-f $merged_data);
    unlink($merged_seq_regions) if (-f $merged_seq_regions);

    foreach my $current_file_id (sort @file_id) {

	my $file_name = $gvf_file_hash->{$current_file_id};

	$logger->info("Processing " . $gvf_file_hash->{$current_file_id});

	$runner->run_cmd(
	    qq(grep -e "^##sequence-region" $file_name >> $merged_seq_regions),
	    [{
		test     => sub { return -f $merged_seq_regions },
		fail_msg => "Couldn't create file $merged_seq_regions!"
	    },], 1
	);
	eval {
		$runner->run_cmd(
		    qq(grep -v -e "^##" $file_name >> $merged_data),
		    [{
			test     => sub { return -f $merged_seq_regions },
			fail_msg => "Couldn't create file $merged_seq_regions!"
		    },], 1
		);
	};
    }

    # Create the directory into which the $merged_file_name will be written
    # afterwards.
    # 
    $runner->run_cmd(
	qq(mkdir -p $ftp_this_species_dir),
	[{
	    test     => sub { return -d $ftp_this_species_dir },
	    fail_msg => "Couldn't create directory $ftp_this_species_dir!"
	},]
    );
    $runner->run_cmd(
	qq(cat $merged_header $merged_seq_regions $merged_data > $merged_file_name),
	[{
	    test     => sub { return -f $merged_file_name },
	    fail_msg => "Couldn't create file $merged_file_name!"
	},]
    );

    my $expected_file = $merged_file_name . '.gz';

    unlink($expected_file) if (-f $expected_file);

    # -f is important or gzip will ask, if the file may be overwritten, if it
    # already exists.
    $runner->run_cmd(
	qq(gzip -f $merged_file_name),
	[{
	    test     => sub { return -f $expected_file },
	    fail_msg => "Couldn't create file $expected_file!"
	},]
    );

    $self->dataflow_output_id(
	{
	    gvf_file => $expected_file,
	    vcf_file => $vcf_file,
	    species  => $gvf_species_hash->{species},
	}, 3
    );

    # We only need one tidy job for a directory of gvfs, so picking
    # out default here as the trigger for the tidy job.
    #
    if ($gvf_type eq 'default') {
	$self->dataflow_output_id(
	    {
		gvf_species_dir => $ftp_this_species_dir,
	    }, 2
	);
    }
}

1;
