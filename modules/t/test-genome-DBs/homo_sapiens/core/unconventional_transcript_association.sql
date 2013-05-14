SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `unconventional_transcript_association` (
  `transcript_id` int(10) unsigned NOT NULL,
  `gene_id` int(10) unsigned NOT NULL,
  `interaction_type` enum('antisense','sense_intronic','sense_overlaping_exonic','chimeric_sense_exonic') DEFAULT NULL,
  KEY `transcript_idx` (`transcript_id`),
  KEY `gene_idx` (`gene_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
