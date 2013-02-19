SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `misc_feature_misc_set` (
  `misc_feature_id` int(10) unsigned NOT NULL DEFAULT '0',
  `misc_set_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`misc_feature_id`,`misc_set_id`),
  KEY `reverse_idx` (`misc_set_id`,`misc_feature_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
