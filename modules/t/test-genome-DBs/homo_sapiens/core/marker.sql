SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `marker` (
  `marker_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `display_marker_synonym_id` int(10) unsigned DEFAULT NULL,
  `left_primer` varchar(100) NOT NULL,
  `right_primer` varchar(100) NOT NULL,
  `min_primer_dist` int(10) unsigned NOT NULL,
  `max_primer_dist` int(10) unsigned NOT NULL,
  `priority` int(11) DEFAULT NULL,
  `type` enum('est','microsatellite') DEFAULT NULL,
  PRIMARY KEY (`marker_id`),
  KEY `marker_idx` (`marker_id`,`priority`),
  KEY `display_idx` (`display_marker_synonym_id`)
) ENGINE=MyISAM AUTO_INCREMENT=327516 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
