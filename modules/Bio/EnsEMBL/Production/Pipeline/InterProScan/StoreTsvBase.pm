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

 Bio::EnsEMBL::Production::Pipeline::InterProScan::StoreTsvBase;

=head1 DESCRIPTION

=head1 MAINTAINER/AUTHOR

 ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::InterProScan::StoreTsvBase;

use strict;
use Carp;
use base ('Bio::EnsEMBL::Production::Pipeline::InterProScan::StoreResultsBase');

sub init {
    die('Abstract method, must be overridden by subclasses!');
}

sub store_domain {
    die('Abstract method, must be overridden by subclasses!');
}

sub run {
    my $self = shift;

    $self->init();

    my $protein_file = $self->param('interpro_tsv_file')  || die "'interpro_tsv_file' is an obligatory parameter";
    $self->validating_parser($self->param('validating_parser'));

    open IN, "$protein_file";

    $self->warning("Reading from " . $protein_file);

    LINE: while (my $current_tsv_line = <IN>) {

	    # Skip empty lines
	    #
	    next LINE if ($current_tsv_line =~ /^\s*$/);

	    my $parsed_line;

	    eval {
		$parsed_line = $self->parse_interproscan_line($current_tsv_line);
	    };
	    if ($@) {
		confess(
		    "\n\nThe following problem occurred when parsing the file\n$protein_file:\n\n"
		    . $@
		);
	    }

	    # Skip buggy lines
	    #
	    next LINE if ($self->line_is_forgiveable_error({

		parsed_line  => $parsed_line,
		protein_file => $protein_file,
	    }));

	    $parsed_line = $self->rename_analysis_from_i5_to_eg_nomenclature($parsed_line);

	    $self->store_domain($parsed_line);

    }
    close IN;
}


sub line_is_forgiveable_error {
    my $self         = shift;
    my $param        = shift;
    my $parsed_line  = $param->{parsed_line};
    my $protein_file = $param->{protein_file};

    # A bug in InterProScan beta, should never happen now
    #
    if ($parsed_line->{score} =~ /Infinity/) {
      $self->warning("Score was Infinity for in " . $protein_file);
    return 1;
    } 
    if ($parsed_line->{score} =~ /NaN/) {
      $self->warning("Score was NaN for in " . $protein_file);
    return 1;
    }
return;
}

1;



