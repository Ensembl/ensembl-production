SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `density_type` (
  `density_type_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `analysis_id` smallint(5) unsigned NOT NULL,
  `block_size` int(11) NOT NULL,
  `region_features` int(11) NOT NULL,
  `value_type` enum('sum','ratio') NOT NULL,
  PRIMARY KEY (`density_type_id`),
  UNIQUE KEY `analysis_idx` (`analysis_id`,`block_size`,`region_features`)
) ENGINE=MyISAM AUTO_INCREMENT=8 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
