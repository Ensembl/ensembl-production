SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `operon_transcript` (
  `operon_transcript_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `seq_region_id` int(10) unsigned NOT NULL,
  `seq_region_start` int(10) unsigned NOT NULL,
  `seq_region_end` int(10) unsigned NOT NULL,
  `seq_region_strand` tinyint(2) NOT NULL,
  `operon_id` int(10) unsigned NOT NULL,
  `display_label` varchar(255) DEFAULT NULL,
  `analysis_id` smallint(5) unsigned NOT NULL,
  `stable_id` varchar(128) DEFAULT NULL,
  `version` smallint(5) unsigned NOT NULL DEFAULT '1',
  `created_date` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `modified_date` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`operon_transcript_id`),
  KEY `operon_idx` (`operon_id`),
  KEY `seq_region_idx` (`seq_region_id`,`seq_region_start`),
  KEY `stable_id_idx` (`stable_id`,`version`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
