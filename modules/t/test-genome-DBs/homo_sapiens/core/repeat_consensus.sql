SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `repeat_consensus` (
  `repeat_consensus_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `repeat_name` varchar(255) NOT NULL,
  `repeat_class` varchar(100) NOT NULL,
  `repeat_type` varchar(40) NOT NULL,
  `repeat_consensus` text,
  PRIMARY KEY (`repeat_consensus_id`),
  KEY `name` (`repeat_name`),
  KEY `class` (`repeat_class`),
  KEY `consensus` (`repeat_consensus`(10)),
  KEY `type` (`repeat_type`)
) ENGINE=MyISAM AUTO_INCREMENT=596276 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
