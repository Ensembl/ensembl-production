SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `xref` (
  `xref_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `external_db_id` int(10) unsigned NOT NULL,
  `dbprimary_acc` varchar(40) NOT NULL,
  `display_label` varchar(128) NOT NULL,
  `version` varchar(10) NOT NULL DEFAULT '0',
  `description` text,
  `info_type` enum('NONE','PROJECTION','MISC','DEPENDENT','DIRECT','SEQUENCE_MATCH','INFERRED_PAIR','PROBE','UNMAPPED','COORDINATE_OVERLAP','CHECKSUM') NOT NULL DEFAULT 'NONE',
  `info_text` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`xref_id`),
  UNIQUE KEY `id_index` (`dbprimary_acc`,`external_db_id`,`info_type`,`info_text`,`version`),
  KEY `display_index` (`display_label`),
  KEY `info_type_idx` (`info_type`)
) ENGINE=MyISAM AUTO_INCREMENT=3727757 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
