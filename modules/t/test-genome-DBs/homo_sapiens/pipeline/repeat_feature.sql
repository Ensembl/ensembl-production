SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `repeat_feature` (
  `repeat_feature_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `seq_region_id` int(10) unsigned NOT NULL,
  `seq_region_start` int(10) unsigned NOT NULL,
  `seq_region_end` int(10) unsigned NOT NULL,
  `seq_region_strand` tinyint(1) NOT NULL DEFAULT '1',
  `repeat_start` int(10) NOT NULL,
  `repeat_end` int(10) NOT NULL,
  `repeat_consensus_id` int(10) unsigned NOT NULL,
  `analysis_id` smallint(5) unsigned NOT NULL,
  `score` double DEFAULT NULL,
  PRIMARY KEY (`repeat_feature_id`),
  KEY `seq_region_idx` (`seq_region_id`,`seq_region_start`),
  KEY `repeat_idx` (`repeat_consensus_id`),
  KEY `analysis_idx` (`analysis_id`)
) ENGINE=MyISAM AUTO_INCREMENT=31297400 DEFAULT CHARSET=latin1 MAX_ROWS=100000000 AVG_ROW_LENGTH=80;
SET character_set_client = @saved_cs_client;
