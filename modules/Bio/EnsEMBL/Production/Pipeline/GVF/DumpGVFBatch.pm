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


=head1 NAME

 Bio::EnsEMBL::Production::Pipeline::GVF::DumpGVFBatch;

=head1 DESCRIPTION

=head1 MAINTAINER 

 ckong@ebi.ac.uk 

=cut

package Bio::EnsEMBL::Production::Pipeline::GVF::DumpGVFBatch;
#package EGVar::FTP::RunnableDB::GVF::DumpGVFBatch;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Production::Pipeline::Common::SystemCmdRunner;
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;
#use base ('EGVar::FTP::RunnableDB::GVF::Base');
use Carp;

=head1 fetch_input

    Using this for type checking only.

=cut
sub fetch_input {
    my $self = shift;

#{"batch" => [{"seq_region_id" => 4,"seq_region_length" => 5137561,"seq_region_name" => "supercont1.4"}],"gvf_type" => "default","species" => "phytophthora_infestans"}

=pod
    my $registry         = $self->param_required('registry');
    my $species 	 = $self->param_required('species');
    my $batch   	 = $self->param_required('batch');
    my $ftp_gvf_file_dir = $self->param_required('ftp_gvf_file_dir');
    my $temp_dir 	 = $self->param_required('temp_gvf_file_dir');
    my $dump_gvf_script  = $self->param('dump_gvf_script');
    
    confess('Type error!') unless (ref $batch eq 'ARRAY');

    use Hash::Util qw( lock_hash );

    foreach my $current_batch (@$batch) {
	confess('Type error!') unless (ref $current_batch eq 'HASH');
	lock_hash(%$current_batch);
	confess('Missing key "seq_region_id"!')     unless (exists $current_batch->{seq_region_id});
	confess('Missing key "seq_region_length"!') unless (exists $current_batch->{seq_region_length});
	confess('Missing key "seq_region_name"!')   unless (exists $current_batch->{seq_region_name});
    }
=cut
}

sub run {
    my $self = shift;

    my $registry        = $self->param_required('registry');
    my $species         = $self->param_required('species');
    my $batch           = $self->param_required('batch');
    my $gvf_dir         = $self->param_required('ftp_gvf_file_dir');
    my $temp_dir        = $self->param_required('temp_gvf_file_dir');
    my $gvf_type        = $self->param_required('gvf_type');
    my $dump_gvf_script = $self->param_required('dump_gvf_script');

    confess('Type error!') unless (ref $batch eq 'ARRAY');

    use Hash::Util qw( lock_hash );

    foreach my $current_batch (@$batch) {
        confess('Type error!') unless (ref $current_batch eq 'HASH');
        lock_hash(%$current_batch);
        confess('Missing key "seq_region_id"!')     unless (exists $current_batch->{seq_region_id});
        confess('Missing key "seq_region_length"!') unless (exists $current_batch->{seq_region_length});
        confess('Missing key "seq_region_name"!')   unless (exists $current_batch->{seq_region_name});
    }

    my ($gvf_type_basename_suffix, $gvf_type_extra_options, $gvf_type_legal);

    if ($gvf_type eq 'default') {
	$gvf_type_basename_suffix = '';
	$gvf_type_extra_options   = '';
	$gvf_type_legal           = 1;
    }
    if ($gvf_type eq 'failed') {
	$gvf_type_basename_suffix = 'failed';
	$gvf_type_extra_options   = '--just_failed';
	$gvf_type_legal           = 1;
    }
    if ($gvf_type eq 'incl_consequences') {
	$gvf_type_basename_suffix = 'incl_consequences';
	$gvf_type_extra_options   = '--include_consequences';
	$gvf_type_legal           = 1;
    }
    if ($gvf_type eq 'structural_variations') {
	$gvf_type_basename_suffix = 'structural_variations';
	$gvf_type_extra_options   = '--just_structural_variations';
	$gvf_type_legal           = 1;
    }
    confess("Unknown gvf_type $gvf_type!") unless($gvf_type_legal);

    my $file_name = $self->create_file_name_for_batch({
	batch   => $batch,
	species => $species,
	gvf_type_basename_suffix => $gvf_type_basename_suffix,
    });

    my $species_and_batch_specific_temp_dir = $self->create_temp_dir_name_for_batch({ batch => $batch });
    $species_and_batch_specific_temp_dir = File::Spec->join($species, $species_and_batch_specific_temp_dir);
    $species_and_batch_specific_temp_dir = File::Spec->join($temp_dir, $species_and_batch_specific_temp_dir);

    $file_name = File::Spec->join($species_and_batch_specific_temp_dir, $file_name);

    #use Bio::EnsEMBL::Production::Common::Pipeline::SystemCmdRunner;
    my $runner = Bio::EnsEMBL::Production::Pipeline::Common::SystemCmdRunner->new();

    $runner->run_cmd(
        "mkdir -p ${species_and_batch_specific_temp_dir}",
        [{
            test     => sub { return -d ${species_and_batch_specific_temp_dir} },
            fail_msg => "Unable to create directory ${species_and_batch_specific_temp_dir}!"
        },]
    );

    my $seq_region_parameter = join " ", map { '--seq_region ' . $_->{seq_region_name} } @$batch;
    my $gvf_default_cmd      = "perl $dump_gvf_script --chunk_size 1000 --species ${species} --registry ${registry} $seq_region_parameter --output $file_name $gvf_type_extra_options";
    my $species_entry        = $self->fetch_species($species);
    my $species_id           = $species_entry->{species_id};

    if ($self->debug) {
	my $total_files   = $species_entry->{total_files};
	print "species_id=$species_id, total_files=$total_files\n";
	print "command: $gvf_default_cmd\n";
    }

    # May be different, if the --compress parameter is used. We are not using
    # compress here, because these are only partial dumps which still have to
    # be merged.
    #
    # The merged file will be compressed later.
    my $expected_file_name = "${file_name}";

    # For now
    #
    if (!-f $expected_file_name) {
	$runner->run_cmd(
	    $gvf_default_cmd,
	    [{
		test     => sub { return -f $expected_file_name },
		fail_msg => "$expected_file_name was not created!"
	    },]
	);
    }

    # Tell the database that this file has been done.
    #
    $self->dataflow_output_id({
        species_id  => $species_id,
        file        => $expected_file_name,
        type        => $gvf_type,
    }, 2);

    # Create a job for the merge job factory. This will check, if all batches
    # have been dumped for a species.
    #
    # No parameters are necessary at a moment. The species id is added for
    # debugging purposes only.
    #
    $self->dataflow_output_id({
	species_id  => $species_id,
	worker_id => $self->worker->dbID
    }, 3);
}

#############
# SUBROUTINES
############
sub create_file_name_for_batch {
    my $self  = shift;
    my $param = shift;

    my $batch   = $param->{batch};
    my $species = $param->{species};
    confess('Type error!') unless(ref $batch eq 'ARRAY');

    my $gvf_type_basename_suffix            = $param->{gvf_type_basename_suffix};
    my $species_and_batch_specific_temp_dir = $self->create_temp_dir_name_for_batch($param);

    my @seq_region_id = $self->get_seq_region_ids_from_batch($batch);
    (my $min_seq_region_id, my $max_seq_region_id) = $self->get_min_max(@seq_region_id);

    my $file_name;
    if ($gvf_type_basename_suffix) {
	$file_name = "${species}.${min_seq_region_id}-${max_seq_region_id}.${gvf_type_basename_suffix}.gvf";
    } else {
	$file_name = "${species}.${min_seq_region_id}-${max_seq_region_id}.gvf";
    }
    return $file_name;
}

sub create_temp_dir_name_for_batch {
    my $self  = shift;
    my $param = shift;

    my $batch = $param->{batch};
    confess('Type error!') unless(ref $batch eq 'ARRAY');

    my @seq_region_id     = $self->get_seq_region_ids_from_batch($batch);
    my $min_seq_region_id = $self->get_min_max(@seq_region_id);

    my $batch_specific_sub_dir = $self->create_sub_dir_from_seq_id($min_seq_region_id);
    my $species_and_batch_specific_temp_dir = $batch_specific_sub_dir;

return $species_and_batch_specific_temp_dir;
}

sub get_seq_region_ids_from_batch {
    my $self  = shift;
    my $batch = shift;

    confess('Missing parameter!') unless(defined $batch);
    confess('Type error!') unless(ref $batch eq 'ARRAY');

    my @seq_region_id = map { $_->{seq_region_id} } @$batch;
return @seq_region_id;
}

sub get_min_max {
    my $self = shift;
    my @list = @_;

    use List::Util qw(min max);
    use String::Numeric qw( is_int );

    my $min_seq_region_id = min(@list);
    my $max_seq_region_id = max(@list);

    use File::Spec;

    confess('Type error!') unless(is_int($min_seq_region_id));
    confess('Type error!') unless(is_int($max_seq_region_id));

return ($min_seq_region_id, $max_seq_region_id);
}

=head1 create_sub_dir_from_seq_id
   
     Create a subdirectory based on the id of a seq region.

    This is used to prevent directories from overflowing. An species may have
    thousands of toplevel seq regions.

=cut
sub create_sub_dir_from_seq_id {

    my $self = shift;
    my $id   = shift;

    my @digits = split //, $id;

    # Remove the last digit otherwise every file will go in its own directory.
    #
    # This means that some files will not go into a subdirectory at all. No
    # subdirectory will be created for seq regions whose seq region id has
    # only one digit.
    #
    pop @digits;

    use File::Spec;
    my $subdir = File::Spec->join(@digits);

    return $subdir;
}

#### TODO: Can move to GVF/Base.pm
#
=head1 fetch_species

Returns a has for the species like this:

$VAR1 = {
          'total_files' => '13',
          'species' => 'plasmodium_falciparum',
          'species_id' => '1'
        };

=cut
sub fetch_species {
    my $self = shift;
    my $species_name = shift;

    my $adaptor = $self->db->get_NakedTableAdaptor();
    $adaptor->table_name( 'gvf_species' );
    my $hash = $adaptor->fetch_by_species( $species_name );
    lock_hash(%$hash);

return $hash;
}



1;
