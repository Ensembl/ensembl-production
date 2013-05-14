SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `attrib_type` (
  `attrib_type_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `code` varchar(15) NOT NULL DEFAULT '',
  `name` varchar(255) NOT NULL DEFAULT '',
  `description` text,
  PRIMARY KEY (`attrib_type_id`),
  UNIQUE KEY `code_idx` (`code`)
) ENGINE=MyISAM AUTO_INCREMENT=371 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
