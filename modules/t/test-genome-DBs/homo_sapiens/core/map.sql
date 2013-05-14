SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `map` (
  `map_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `map_name` varchar(30) NOT NULL,
  PRIMARY KEY (`map_id`)
) ENGINE=MyISAM AUTO_INCREMENT=13 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
