SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `external_synonym` (
  `xref_id` int(10) unsigned NOT NULL,
  `synonym` varchar(100) NOT NULL,
  PRIMARY KEY (`xref_id`,`synonym`),
  KEY `name_index` (`synonym`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
