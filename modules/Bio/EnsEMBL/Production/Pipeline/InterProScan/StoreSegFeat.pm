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

 Bio::EnsEMBL::Production::Pipeline::InterProScan::StoreSegFeat;

=head1 DESCRIPTION


=head1 MAINTAINER/AUTHOR

 ckong@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::InterProScan::StoreSegFeat;

use strict;
use Bio::EnsEMBL::DBSQL::AnalysisAdaptor;
use base ('Bio::EnsEMBL::Production::Pipeline::InterProScan::Base');

sub fetch_input {
    my $self = shift @_;

    my $species             = $self->param_required('species');
    my $analysis_logic_name = $self->param_required('seg_logic_name');
    my $seg_outfile         = $self->param_required('file');

    $self->get_logger->info("Storing low complexity regions from file: $seg_outfile");

    #if (-s $seg_outfile == 0) {
    if (-z $seg_outfile) {
        $self->warning("File $seg_outfile is empty, so not running seg analysis on it.");
        return;
    }

    my $analysis_adaptor        = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'Analysis');
    my $analysis                = $analysis_adaptor->fetch_by_logic_name($analysis_logic_name);
    my $protein_feature_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'ProteinFeature');
#    my $transcript_adaptor      = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'transcript');
#    my $translation_adaptor     = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'translation');

    confess('Type error!') unless($analysis->isa('Bio::EnsEMBL::Analysis'));
    confess('Type error!') unless($analysis_adaptor->isa('Bio::EnsEMBL::DBSQL::AnalysisAdaptor'));
    confess('Type error!') unless($protein_feature_adaptor->isa('Bio::EnsEMBL::DBSQL::ProteinFeatureAdaptor'));
#    confess('Type error!') unless($transcript_adaptor->isa('Bio::EnsEMBL::DBSQL::TranscriptAdaptor'));
#    confess('Type error!') unless($translation_adaptor->isa('Bio::EnsEMBL::DBSQL::TranslationAdaptor'));

    if (!defined $analysis) {
	die(
      		"Can't find an analysis of type '" . $analysis_logic_name
      		. "' in the core database. Probably the analysis table in "
      		. $self->database_string_for_user . " has to"
      		. " be populated with this type of analysis."
    	);
    }

    $self->param('seg_outfile', $seg_outfile);
    $self->param('analysis', $analysis);
    $self->param('protein_feature_adaptor', $protein_feature_adaptor);

return;
}

sub run {
    my $self = shift @_;

    my $seg_outfile             = $self->param_required('seg_outfile');
    my $analysis                = $self->param_required('analysis');
    my $protein_feature_adaptor = $self->param_required('protein_feature_adaptor');

    open FILE, "$seg_outfile";

    LINE: while (my $line = <FILE>) {
        # Skip unrelevant lines  '>3(36-43)'
        next LINE if ($line !~ /^\>/);

        $line=~/\>(\d+)\((\d+)\-(\d+)/;
        
        my $translation_id = $1;
        my $start          = $2;
        my $end            = $3;

        my $feature = Bio::EnsEMBL::ProteinFeature->new(
                -start    => $start,
                -end      => $end,
	        -hstart   => 0,
	        -hend     => 0,
                -hseqname => 'seg',  
                -analysis => $analysis,
  	    );
        $protein_feature_adaptor->store($feature, $translation_id);
    }
    close FILE;

    $protein_feature_adaptor->dbc->disconnect_if_idle();

    return;
}

sub write_output {
  my $self = shift @_;

return;
}

1;
