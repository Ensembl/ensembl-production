=head1 LICENSE

Copyright [2009-2019] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Production::Pipeline::GPAD::Base;

=head1 DESCRIPTION

=head1 AUTHOR

maurel@ebi.ac.uk

=cut
package Bio::EnsEMBL::Production::Pipeline::GPAD::Base;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::SqlHelper;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;


sub cleanup_GO {
    my ($self,$dba)  = @_;
    $self->log()->info("Deleting existing terms");
    # Delete by analysis.logic_name='goa_import' for GOs mapped to translation
    my $translation_go_sql=qq/
      DELETE ox.*,onx.*,dx.*  FROM xref x
        JOIN object_xref ox USING (xref_id)
        LEFT JOIN ontology_xref onx USING (object_xref_id)
        LEFT JOIN dependent_xref dx USING (object_xref_id)
        JOIN analysis a USING (analysis_id)
        JOIN translation tl ON (ox.ensembl_id=tl.translation_id)
        JOIN transcript tf USING (transcript_id)
        JOIN seq_region s USING (seq_region_id)
        JOIN coord_system c USING (coord_system_id)
      WHERE x.external_db_id=1000
        AND c.species_id=?
        AND a.logic_name='goa_import'/;
    # Same deletes but for GOs mapped to transcripts                      
    my $transcript_go_sql=qq/
      DELETE ox.*,onx.*,dx.*  FROM xref x
        JOIN object_xref ox USING (xref_id)
        LEFT JOIN ontology_xref onx USING (object_xref_id)
        LEFT JOIN dependent_xref dx USING (object_xref_id)
        JOIN analysis a USING (analysis_id)
        JOIN transcript tf ON (ox.ensembl_id = tf.transcript_id)
        JOIN seq_region s USING (seq_region_id)
        JOIN coord_system c USING (coord_system_id)
      WHERE x.external_db_id=1000
        AND c.species_id=?
        AND a.logic_name='goa_import'/;
    
    $self->log()->debug("Deleting GO mapped to translation");
    $dba->dbc()->sql_helper()->execute_update(-SQL=>$translation_go_sql,-PARAMS=>[$dba->species_id()]);
    $self->log()->debug("Deleting GO mapped to transcript");
    $dba->dbc()->sql_helper()->execute_update(-SQL=>$transcript_go_sql,-PARAMS=>[$dba->species_id()]);
    return;
  }

1;