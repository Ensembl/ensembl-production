SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `gene_archive` (
  `gene_stable_id` varchar(128) NOT NULL,
  `gene_version` smallint(6) NOT NULL DEFAULT '1',
  `transcript_stable_id` varchar(128) NOT NULL,
  `transcript_version` smallint(6) NOT NULL DEFAULT '1',
  `translation_stable_id` varchar(128) DEFAULT NULL,
  `translation_version` smallint(6) NOT NULL DEFAULT '1',
  `peptide_archive_id` int(10) unsigned DEFAULT NULL,
  `mapping_session_id` int(10) unsigned NOT NULL,
  KEY `peptide_archive_id_idx` (`peptide_archive_id`),
  KEY `gene_idx` (`gene_stable_id`,`gene_version`),
  KEY `transcript_idx` (`transcript_stable_id`,`transcript_version`),
  KEY `translation_idx` (`translation_stable_id`,`translation_version`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
