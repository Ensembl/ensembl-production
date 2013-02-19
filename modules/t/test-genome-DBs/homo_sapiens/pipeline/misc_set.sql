SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `misc_set` (
  `misc_set_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `code` varchar(25) NOT NULL DEFAULT '',
  `name` varchar(255) NOT NULL DEFAULT '',
  `description` text NOT NULL,
  `max_length` int(10) unsigned NOT NULL,
  PRIMARY KEY (`misc_set_id`),
  UNIQUE KEY `code_idx` (`code`)
) ENGINE=MyISAM AUTO_INCREMENT=24 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
