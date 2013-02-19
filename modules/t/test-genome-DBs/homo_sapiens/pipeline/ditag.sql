SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `ditag` (
  `ditag_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(30) NOT NULL,
  `type` varchar(30) NOT NULL,
  `tag_count` smallint(6) unsigned NOT NULL DEFAULT '1',
  `sequence` tinytext NOT NULL,
  PRIMARY KEY (`ditag_id`)
) ENGINE=MyISAM AUTO_INCREMENT=3598657 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
