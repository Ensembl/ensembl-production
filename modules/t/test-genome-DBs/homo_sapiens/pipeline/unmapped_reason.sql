SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `unmapped_reason` (
  `unmapped_reason_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `summary_description` varchar(255) DEFAULT NULL,
  `full_description` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`unmapped_reason_id`)
) ENGINE=MyISAM AUTO_INCREMENT=139 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
