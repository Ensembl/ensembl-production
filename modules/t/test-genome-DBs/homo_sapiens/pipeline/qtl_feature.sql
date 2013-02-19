SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `qtl_feature` (
  `seq_region_id` int(10) unsigned NOT NULL,
  `seq_region_start` int(10) unsigned NOT NULL,
  `seq_region_end` int(10) unsigned NOT NULL,
  `qtl_id` int(10) unsigned NOT NULL,
  `analysis_id` smallint(5) unsigned NOT NULL,
  KEY `loc_idx` (`seq_region_id`,`seq_region_start`),
  KEY `analysis_idx` (`analysis_id`),
  KEY `qtl_idx` (`qtl_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
