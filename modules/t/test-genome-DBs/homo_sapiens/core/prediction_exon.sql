SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `prediction_exon` (
  `prediction_exon_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `prediction_transcript_id` int(10) unsigned NOT NULL,
  `exon_rank` smallint(5) unsigned NOT NULL,
  `seq_region_id` int(10) unsigned NOT NULL,
  `seq_region_start` int(10) unsigned NOT NULL,
  `seq_region_end` int(10) unsigned NOT NULL,
  `seq_region_strand` tinyint(4) NOT NULL,
  `start_phase` tinyint(4) NOT NULL,
  `score` double DEFAULT NULL,
  `p_value` double DEFAULT NULL,
  PRIMARY KEY (`prediction_exon_id`),
  KEY `transcript_idx` (`prediction_transcript_id`),
  KEY `seq_region_idx` (`seq_region_id`,`seq_region_start`)
) ENGINE=MyISAM AUTO_INCREMENT=378250 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
