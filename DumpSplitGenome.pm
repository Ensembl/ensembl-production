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

=head1 Bio::EnsEMBL::EGPipeline::Common::DumpSplitSequence
=cut

package Bio::EnsEMBL::EGPipeline::Common::DumpSplitGenome;

use strict;
use base ('Bio::EnsEMBL::EGPipeline::Common::Base');
use IO::File;
use DBI qw(:sql_types);
use Carp;
use String::Numeric qw( is_int );

sub run {
    my $self = shift @_;

    my $nb_files_per_dir = $self->param('num_files_per_folder');
    my $max_length_per_file  = $self->param('max_length_per_file');
    my $dump_dir         = $self->param('dump_dir');
    my $pipeline_dir     = $self->param('pipeline_dir');
    my $masking_required_analysis = $self->param('masking_required_analysis');
    my $length_cutoff = $self->param('cutoff');
    
    warn("length cutoff set to " . $length_cutoff . " bp\n");
    
    # get the list of seq_regions
    
    my $dbh = $self->core_dbh;
    
    my $sth = $dbh->prepare(q{
         SELECT r.seq_region_id, r.length FROM seq_region r, seq_region_attrib ra WHERE r.seq_region_id = ra.seq_region_id AND ra.attrib_type_id = 6 AND length >= ?;
    }) or confess($dbh->errstr);
                        
    $sth->execute($length_cutoff);
    my $seq_regions_aref = [];
    my $cumulated_length = 0;
    my $temp_seq_regions_aref = [];
    my $nb_seq_regions_ids = 0;
    while (my ($seq_region_id, $length) = $sth->fetchrow_array) {
       $length = int($length);
       $nb_seq_regions_ids++;
       if (($length+$cumulated_length) > $max_length_per_file) {

           print STDERR "max_length_per_file exceeded, setting a new index\n";

           push(@$seq_regions_aref, $temp_seq_regions_aref);

	   # Create a new array

           $temp_seq_regions_aref = [];
	   $cumulated_length = $length;
	   push (@$temp_seq_regions_aref, $seq_region_id);
       }
       else {
	   push (@$temp_seq_regions_aref, $seq_region_id);
           $cumulated_length += $length;
       }
    }
    $sth->finish();
    # if any, get the remaninings ones into the array
    if ($cumulated_length > 0) {
        push(@$seq_regions_aref, $temp_seq_regions_aref);
    }
                                                    
    print STDERR "$nb_seq_regions_ids sequences will be dumped into " . @$seq_regions_aref . " files\n";

    my $fh = new IO::File;
    use File::Basename;
    use File::Path qw(make_path);
    my $dir_index  = 1;
    
    my $dir_path = "$pipeline_dir" . '/' . "$dump_dir" . '/' . "$dir_index";
    if (! -d $dir_path) {
        print STDERR "Creating dir, $dir_path\n";
        make_path($dir_path);
    }
    
    my $file_index = 1;
    my $file = undef;

    my $dba = $self->core_dba;
    my $slice_adaptor = $dba->get_SliceAdaptor();
    foreach my $seq_region_ids_set_aref (@$seq_regions_aref) {
        if ($file_index > $nb_files_per_dir) {
           $dir_index++;
           $dir_path = "$pipeline_dir" . '/' . "$dump_dir" . '/' . "$dir_index";
           if (! -d $dir_path) {
               make_path($dir_path);
           }
           $file_index = 1;
        }
        $file = $dir_path . '/' . $file_index . '.fasta';
        confess("Unable to open $file") if (!$fh->open(">$file"));
        
        foreach my $seq_region_id (@$seq_region_ids_set_aref) {
            
            # Dump it
            
            # print STDERR "Fetching seq_region object for seq_region_id, $seq_region_id\n";
	
            my $seq_region = $slice_adaptor->fetch_by_seq_region_id($seq_region_id);
            die "Type error!" unless ($seq_region->isa('Bio::EnsEMBL::Slice'));    
            # my $name = $seq_region->coord_system_name() . ':' . $seq_region->coord_system_version . ';' . $seq_region->seq_region_id() . ':1:' . $seq_region->length() . ':1';
            my $name = $seq_region->name();
	
            $fh->print(">$name\n");
            my $softmask = 1;
            my $sequence_str = $seq_region->get_repeatmasked_seq($masking_required_analysis, $softmask)->seq();
            # Format in FASTA
            $sequence_str =~ s/(.{1,60})/$1\n/g;
            $fh->print($sequence_str);
        }
        $fh->close();
        
        $self->dataflow_output_id({'genome_file' => $file},1);
        $file_index++;
    }
}

1;

