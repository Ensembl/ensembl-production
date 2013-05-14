SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `ditag_feature` (
  `ditag_feature_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `ditag_id` int(10) unsigned NOT NULL DEFAULT '0',
  `ditag_pair_id` int(10) unsigned NOT NULL DEFAULT '0',
  `seq_region_id` int(10) unsigned NOT NULL DEFAULT '0',
  `seq_region_start` int(10) unsigned NOT NULL DEFAULT '0',
  `seq_region_end` int(10) unsigned NOT NULL DEFAULT '0',
  `seq_region_strand` tinyint(1) NOT NULL DEFAULT '0',
  `analysis_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  `hit_start` int(10) unsigned NOT NULL DEFAULT '0',
  `hit_end` int(10) unsigned NOT NULL DEFAULT '0',
  `hit_strand` tinyint(1) NOT NULL DEFAULT '0',
  `cigar_line` tinytext NOT NULL,
  `ditag_side` enum('F','L','R') NOT NULL,
  PRIMARY KEY (`ditag_feature_id`),
  KEY `seq_region_idx` (`seq_region_id`,`seq_region_start`,`seq_region_end`),
  KEY `ditag_idx` (`ditag_id`),
  KEY `ditag_pair_idx` (`ditag_pair_id`)
) ENGINE=MyISAM AUTO_INCREMENT=1221441 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
