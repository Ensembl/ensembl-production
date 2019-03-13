package Bio::EnsEMBL::Production::Pipeline::Search::CompressEBeyeXMLFile;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

use Bio::EnsEMBL::Utils::Exception qw(throw);

use JSON;
use File::Slurp qw/read_file/;
use File::Find::Rule; 
use Carp qw(croak);

use Log::Log4perl qw/:easy/;
use Data::Dumper;

sub run {
        my ($self) = @_;
        if ( $self->debug() ) 
		{
                Log::Log4perl->easy_init($DEBUG);
        	}
        else {
                Log::Log4perl->easy_init($INFO);
        	}
        $self->{logger} = get_logger();

        my $division = $self->param_required('division');
        my $release = $self->param_required('release');
        my $bpath = $self->param('base_path');
	my $valid_gene_xml = $self->param('genes_valid_file');
	my $valid_sequences_xml = $self->param('sequences_valid_file');
	if ($valid_gene_xml && (-e $valid_gene_xml))
		{
		# my $valid_gene_xml = $self->param('genes_valid_file');
		my $err_file = $valid_gene_xml . 'compress.err';
                my $cmd = sprintf(q{gzip %s 2> %s},
                        $valid_gene_xml,
                        $err_file);
                my ($rc, $output) = $self->run_cmd($cmd);
                throw sprintf "gzip reports failure(s) for %s EB-eye dump.\nSee error log at file %s", $self->param('species'), $err_file
                        if $rc != 0;
                unlink $err_file;
		}
	if ($valid_sequences_xml && (-e $valid_sequences_xml)) 
		{
		# my $valid_sequences_xml = $self->param('sequences_valid_file');
		my $err_file = $valid_sequences_xml . 'compress.err';
                my $cmd = sprintf(q{gzip %s 2> %s},
                        $valid_sequences_xml,
                        $err_file);
                my ($rc, $output) = $self->run_cmd($cmd);
                throw sprintf "gzip reports failure(s) for %s EB-eye dump.\nSee error log at file %s", $self->param('species'), $err_file
                        if $rc != 0;
                unlink $err_file;
		}
        return;
        } ## end sub run

1;





