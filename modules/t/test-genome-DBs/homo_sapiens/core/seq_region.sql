SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `seq_region` (
  `seq_region_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(40) NOT NULL,
  `coord_system_id` int(10) unsigned NOT NULL,
  `length` int(10) unsigned NOT NULL,
  PRIMARY KEY (`seq_region_id`),
  UNIQUE KEY `name_cs_idx` (`name`,`coord_system_id`),
  KEY `cs_idx` (`coord_system_id`)
) ENGINE=MyISAM AUTO_INCREMENT=1000960143 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
