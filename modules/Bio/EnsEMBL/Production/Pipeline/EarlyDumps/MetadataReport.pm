=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2023] EMBL-European Bioinformatics Institute

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

=pod


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::EarlyDumps::MetadataReport

=head1 DESCRIPTION

Generate metadata file for Early dump
=over 8

=item type - The format to parse

=back

=cut

package Bio::EnsEMBL::Production::Pipeline::EarlyDumps::MetadataReport;

use strict;
use warnings;
use Bio::EnsEMBL::Registry;
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use File::Path qw(make_path);
use Capture::Tiny qw/capture/;
use File::Spec::Functions qw(catdir);

sub fetch_input {
  my ($self) = @_;
  return;
}

sub param_defaults {
  my ($self) = @_;
  return {
    %{$self->SUPER::param_defaults},
  };
}



sub run {
  my ($self) = @_;
  my $ens_version    =  $self->param('ens_version');
  my $metadata_host  =  $self->param('metadata_host');
  my $dump_script    =  $self->param('dump_script');
  my $dump_path      =  $self->param('dump_path');

  if(! -e $dump_path ){
  	make_path($dump_path) or $self->throw("Failed to create output directory '$dump_path'");
  }

  $self->generate_metadata_report($dump_path, $dump_script, $metadata_host, $ens_version);
  $self->species_wise_metadata_files($dump_path);
  return;
}


sub generate_metadata_report {

    my ( $self, $dump_path, $dump_script, $metadata_host, $ens_version ) = @_; 
    my @cmd=("perl $dump_script \$($metadata_host details script) -release $ens_version -output json -dump_path $dump_path");
    my ($stdout, $stderr, $exit) = capture {
      system(@cmd);
    };

    $self->warning("genome report generate at : $dump_path\n");
    $self->warning("${stdout}\n");
    if($exit != 0) {
      die "Return code was ${exit}. Failed to execute command : $!";
    }

}	

sub species_wise_metadata_files {

	my ( $self, $dump_path) = @_;

	my @division_list = @{$self->param('division_list')};
	
	if(@{$self->param('division')}){
	  @division_list = @{$self->param('division')};
	}
	my @non_vert_combine_files = ();
	my $cmd_str = "";
	my $division_specific_param = {    'ftp_dir'          => $self->param('ens_ftp_dir'),
                                           'base_path'        => $self->param('base_path'), 
                                           'dump_dir'         => $self->param('base_path'),
                                           'release'          => $self->param('ens_version'),
                                           'server_url'       => $self->param('server_url_vert'),
					   'dump_division'    => 'vertebrates',
				   };
	foreach my $each_division (@division_list){

		$self->warning("Writing to  : $each_division.txt\n");

		$cmd_str = "jq -r '.$each_division | .[\"new_genomes\", \"updated_assemblies\", \"renamed_genomes\", \"updated_annotations\"][] | .database' $dump_path/report_updates.json | sort -u > $dump_path/$each_division.txt";
		
		my @cmd=("module load jq-1.6-gcc-9.3.0-rhubpos ;  $cmd_str");

		my ($stdout, $stderr, $exit) = capture {
      			system(@cmd);
    		};

    		if($exit != 0) {
      			die "Return code was ${exit}. Failed to execute command : $!";
    		
		}

		#get species list
		$cmd_str = "jq -r '.$each_division | .[\"new_genomes\", \"updated_assemblies\", \"renamed_genomes\", \"updated_annotations\"][] | .name'  $dump_path/report_updates.json ";
		@cmd = ("module load jq-1.6-gcc-9.3.0-rhubpos ;  $cmd_str");
                ($stdout, $stderr, $exit) = capture {
                        system(@cmd);
                };

                if($exit != 0) {
                        die "Return code was ${exit}. Failed to execute command : $!";

                }
		my @species_list = split("\n", $stdout);
		my $analysis_flow = 1; #set to default
		if($each_division ne 'vertebrates' ){
			$analysis_flow = 2;
			$division_specific_param->{'release_version'}=$self->param('eg_version');
			$division_specific_param->{'release'}=$self->param('eg_version');
			$division_specific_param->{'server_url'}=$self->param('server_url_nonvert');
			$division_specific_param->{'dump_division'}=$each_division;

		}elsif($each_division eq 'bacteria'){
			$analysis_flow = 3;
			$division_specific_param->{'server_url'}=$self->param('server_url_bacteria');
		}

		$division_specific_param->{'species'}	= \@species_list;
		
	        if(scalar @species_list > 0){	
                    $self->dataflow_output_id($division_specific_param, $analysis_flow);
		}

	}

        #concatenate all nonvert into single file 
	my @nonvert_list = grep(!/(vertebrates|bacteria)/, @division_list);
	
        my $combine_nonvert_file = $dump_path . '/non_vertebrates.txt';
	if( -e $combine_nonvert_file){
		unlink($combine_nonvert_file) or die "unable to delete existing file $combine_nonvert_file";
	}	
	open my $out, '>>', $combine_nonvert_file or die "Could not open '$combine_nonvert_file' for appending\n";
	foreach my $each_file (@nonvert_list) {
            my $file = $dump_path . "/$each_file.txt";		
    	    if (open my $in, '<', $file) {
                while (my $line = <$in>) {
            	    print $out $line;
        	}
                close $in;
    	    } else {
       	        warn "Could not open '$file' for reading\n";
    	    }
	}
	close $out;
}

1;
