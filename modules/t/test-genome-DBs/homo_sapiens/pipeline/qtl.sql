SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `qtl` (
  `qtl_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `trait` varchar(255) NOT NULL,
  `lod_score` float DEFAULT NULL,
  `flank_marker_id_1` int(10) unsigned DEFAULT NULL,
  `flank_marker_id_2` int(10) unsigned DEFAULT NULL,
  `peak_marker_id` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`qtl_id`),
  KEY `trait_idx` (`trait`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
