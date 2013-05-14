SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `density_feature` (
  `density_feature_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `density_type_id` int(10) unsigned NOT NULL,
  `seq_region_id` int(10) unsigned NOT NULL,
  `seq_region_start` int(10) unsigned NOT NULL,
  `seq_region_end` int(10) unsigned NOT NULL,
  `density_value` float NOT NULL,
  PRIMARY KEY (`density_feature_id`),
  KEY `seq_region_idx` (`density_type_id`,`seq_region_id`,`seq_region_start`),
  KEY `seq_region_id_idx` (`seq_region_id`)
) ENGINE=MyISAM AUTO_INCREMENT=23 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
