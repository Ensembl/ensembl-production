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

=cut

package Bio::EnsEMBL::Production::Pipeline::OntologiesLoad::MartLoad;
use strict;
use warnings FATAL => 'all';
use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

sub fetch_input {
}

sub run {
    my $self = shift @_;

}

sub write_output {
    my ($self) = @_;

    my $mart = $self->param_required('mart');
    my $srv = $self->param_required('srv');
    my $dbname = $self->param_required('db_name');
    my $templatefile = $self->param_required('base_dir') . "/ensembl-production/modules/Bio/EnsEMBL/Production/Pipeline/OntologiesLoad/build_ontology_mart.sql";

    $self->log("Creating mart $srv:$mart");
    $self->run_system_command("$srv -e \"DROP database IF EXISTS $mart\"");
    $self->run_system_command("$srv -e \"CREATE database $mart\"");
    $self->log("Building mart database $mart");
    my $TMP_SQL = "/scratch/mart.sql";
    $self->run_system_command("sed -e \"s/%MART_NAME%/$mart/g\" $templatefile | sed -e \"s/%ONTOLOGY_DB%/$dbname/g\" > $TMP_SQL");
    $self->run_system_command("$srv $mart < $TMP_SQL");
    $self->log("Cleaning up and optimizing tables in $mart");
    my $optimize = <<"OPTIMIZE_TABLE";
for table in \$($srv --skip-column-names $mart -e "show tables like 'closure%'"); do
echo Test Message inside
cnt=\$($srv $mart -e "SELECT COUNT(*) FROM \$table")
d=\$(date +"[%Y/%m/%d %H:%M:%S]")
if [ "\$cnt" == "0" ]; then
    echo "\$d Dropping table \$table from $mart"
    $srv $mart -e \"drop table \$table\"
else
    echo "\$d Optimizing table \$table from $mart"
    $srv $mart -e "optimize table \$table"
fi
done
OPTIMIZE_TABLE

    $self->run_system_command($optimize);

    $self->log("Creating the dataset_name table for mart database $mart");
    my $BASE_DIR=$self->param_required("base_dir");
    if ($self->run_system_command("perl $BASE_DIR/ensembl-biomart/scripts/generate_names.pl \$($srv details script) -mart $mart -div vertebrates") != 0) {
        $self->error("Failed to create dataset_name table");
        
    }
    $self->log("Populating meta tables for mart database $mart");
    if ($self->run_system_command("perl $BASE_DIR/ensembl-biomart/scripts/generate_meta.pl \$($srv details script) -dbname $mart -template $BASE_DIR/ensembl-biomart/scripts/templates/ontology_template_template.xml -template_name ontology") != 0) {
        $self->error("Failed to populate meta table for mart database $mart");
        
    }
    $self->log("Populating meta tables for mart database $mart SO mini template");
    if ($self->run_system_command("perl $BASE_DIR/ensembl-biomart/scripts/generate_meta.pl \$($srv details script) -dbname $mart -template $BASE_DIR/ensembl-biomart/scripts/templates/ontology_mini_template_template.xml -template_name ontology_mini -ds_basename mini") != 0) {
        $self->error("Failed to populate meta table for mart database $mart");
        
    }
    $self->log("Populating meta tables for mart database $mart SO regulation template");
    if ($self->run_system_command("perl $BASE_DIR/ensembl-biomart/scripts/generate_meta.pl \$($srv details script) -dbname $mart -template $BASE_DIR/ensembl-biomart/scripts/templates/ontology_regulation_template_template.xml -template_name ontology_regulation -ds_basename regulation") != 0) {
        $self->error("Failed to populate meta table for mart database $mart");
        
    }
    $self->log("Populating meta tables for mart database $mart SO motif template");
    if ($self->run_system_command("perl $BASE_DIR/ensembl-biomart/scripts/generate_meta.pl \$($srv details script) -dbname $mart -template $BASE_DIR/ensembl-biomart/scripts/templates/ontology_motif_template_template.xml -template_name ontology_motif -ds_basename motif") != 0) {
        $self->error("Failed to populate meta table for mart database $mart");
        
    }
    $self->log("Building mart database $mart complete");

}
1;
