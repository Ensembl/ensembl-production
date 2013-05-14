SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `protein_feature` (
  `protein_feature_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `translation_id` int(10) unsigned NOT NULL,
  `seq_start` int(10) NOT NULL,
  `seq_end` int(10) NOT NULL,
  `hit_start` int(10) NOT NULL,
  `hit_end` int(10) NOT NULL,
  `hit_name` varchar(40) NOT NULL,
  `analysis_id` smallint(5) unsigned NOT NULL,
  `score` double DEFAULT NULL,
  `evalue` double DEFAULT NULL,
  `perc_ident` float DEFAULT NULL,
  `external_data` text,
  `hit_description` text,
  PRIMARY KEY (`protein_feature_id`),
  KEY `hitname_idx` (`hit_name`),
  KEY `analysis_idx` (`analysis_id`),
  KEY `translation_idx` (`translation_id`)
) ENGINE=MyISAM AUTO_INCREMENT=4908003 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
