SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `marker_synonym` (
  `marker_synonym_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `marker_id` int(10) unsigned NOT NULL,
  `source` varchar(20) DEFAULT NULL,
  `name` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`marker_synonym_id`),
  KEY `marker_synonym_idx` (`marker_synonym_id`,`name`),
  KEY `marker_idx` (`marker_id`)
) ENGINE=MyISAM AUTO_INCREMENT=786734 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
