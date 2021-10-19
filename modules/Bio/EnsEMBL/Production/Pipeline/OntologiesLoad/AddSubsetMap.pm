=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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


package Bio::EnsEMBL::Production::Pipeline::OntologiesLoad::AddSubsetMap;

use strict;
use warnings FATAL => 'all';

use Bio::EnsEMBL::Hive::DBSQL::DBConnection;
use base ('Bio::EnsEMBL::Production::Pipeline::Common::Base');

sub fetch_input {
}

sub run {
    my $self = shift @_;

}

sub write_output {
    my $self = shift @_;

    my $statement = q(
        SELECT DISTINCT
                ontology.name,
                subset.name
        FROM    ontology,
                term,
                subset
        WHERE   ontology.ontology_id = term.ontology_id
          AND   is_obsolete = 0
          AND   FIND_IN_SET(subset.name, term.subsets) > 0
    );

    my $table_template = q(
        CREATE TABLE %s (
          term_id           INT UNSIGNED NOT NULL,
          subset_term_id    INT UNSIGNED NOT NULL,
          distance          TINYINT UNSIGNED NOT NULL,
          UNIQUE INDEX map_idx (term_id, subset_term_id)
        ) ENGINE=MyISAM
        SELECT  child_term.term_id AS term_id,
                parent_term.term_id AS subset_term_id,
                MIN(distance) AS distance
        FROM    ontology
          JOIN  term parent_term
            ON  (parent_term.ontology_id = ontology.ontology_id)
          JOIN  closure
            ON  (closure.parent_term_id = parent_term.term_id)
          JOIN  term child_term
            ON  (child_term.term_id = closure.child_term_id)
        WHERE   ontology.name = %s
          AND   FIND_IN_SET(%s, parent_term.subsets) > 0
          AND   parent_term.ontology_id = closure.ontology_id
          AND   child_term.ontology_id = closure.ontology_id
          AND   parent_term.is_obsolete = 0
          AND   child_term.is_obsolete = 0
        GROUP BY child_term.term_id, parent_term.term_id
    );

    my $drop_statement = q(
        SHOW TABLES LIKE 'aux_%'
    );

    my $dbc = Bio::EnsEMBL::Hive::DBSQL::DBConnection->new(-url => $self->param_required('db_url'));
    $dbc->connect();
    my $dbh = $dbc->db_handle();

    my $droph = $dbc->prepare($drop_statement);

    # drop all previous auxiliary table
    $droph->execute();
    while (my $drop_table_name = $droph->fetchrow_array()) {
        $self->warning('Dropping: ' . $drop_table_name);
        $dbh->do('DROP TABLE `'. $drop_table_name.'`');
    }

    my $sth = $dbc->prepare($statement);

    $sth->execute();

    my ($ontology_name, $subset_name);

    $sth->bind_columns(\($ontology_name, $subset_name));

    while ($sth->fetch()) {

        my $aux_table_name = $dbh->quote_identifier(
            sprintf("aux_%s_%s_map", uc($ontology_name), $subset_name));

        printf("Creating and populating %s...\n", $aux_table_name);

        $dbc->do(sprintf($table_template,
            $aux_table_name, $dbh->quote($ontology_name),
            $dbh->quote($subset_name)));

        if ($dbh->err()) {
            printf("MySQL error, \"%s\", skipping...\n", $dbc->errstr());
            next;
        }

    }
}
1;
