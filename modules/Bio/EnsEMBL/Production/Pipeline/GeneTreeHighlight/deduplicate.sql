CREATE TABLE member_xref_copy like member_xref;
INSERT INTO member_xref_copy SELECT DISTINCT `gene_member_id`, `dbprimary_acc`, `external_db_id` FROM member_xref;
DROP TABLE member_xref;
ALTER TABLE member_xref_copy RENAME TO member_xref;
ALTER TABLE member_xref ADD PRIMARY KEY (`gene_member_id`, `dbprimary_acc`, `external_db_id`);
CREATE INDEX external_db_id ON member_xref (`external_db_id`);

