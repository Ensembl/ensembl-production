SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `prediction_transcript` (
  `prediction_transcript_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `seq_region_id` int(10) unsigned NOT NULL,
  `seq_region_start` int(10) unsigned NOT NULL,
  `seq_region_end` int(10) unsigned NOT NULL,
  `seq_region_strand` tinyint(4) NOT NULL,
  `analysis_id` smallint(5) unsigned NOT NULL,
  `display_label` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`prediction_transcript_id`),
  KEY `analysis_idx` (`analysis_id`),
  KEY `seq_region_idx` (`seq_region_id`,`seq_region_start`)
) ENGINE=MyISAM AUTO_INCREMENT=52628 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
