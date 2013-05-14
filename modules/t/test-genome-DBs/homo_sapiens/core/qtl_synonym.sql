SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `qtl_synonym` (
  `qtl_synonym_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `qtl_id` int(10) unsigned NOT NULL,
  `source_database` enum('rat genome database','ratmap') NOT NULL,
  `source_primary_id` varchar(255) NOT NULL,
  PRIMARY KEY (`qtl_synonym_id`),
  KEY `qtl_idx` (`qtl_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
