SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `seq_region_synonym` (
  `seq_region_synonym_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `seq_region_id` int(10) unsigned NOT NULL,
  `synonym` varchar(40) NOT NULL,
  `external_db_id` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`seq_region_synonym_id`),
  UNIQUE KEY `syn_idx` (`synonym`),
  KEY `seq_region_idx` (`seq_region_id`)
) ENGINE=MyISAM AUTO_INCREMENT=230 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
