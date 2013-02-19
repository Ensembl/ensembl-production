SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `marker_map_location` (
  `marker_id` int(10) unsigned NOT NULL,
  `map_id` int(10) unsigned NOT NULL,
  `chromosome_name` varchar(15) NOT NULL,
  `marker_synonym_id` int(10) unsigned NOT NULL,
  `position` varchar(15) NOT NULL,
  `lod_score` double DEFAULT NULL,
  PRIMARY KEY (`marker_id`,`map_id`),
  KEY `map_idx` (`map_id`,`chromosome_name`,`position`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
