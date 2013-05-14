SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `mapping_set` (
  `mapping_set_id` int(10) unsigned NOT NULL,
  `internal_schema_build` varchar(20) NOT NULL,
  `external_schema_build` varchar(20) NOT NULL,
  UNIQUE KEY `mapping_idx` (`internal_schema_build`,`external_schema_build`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
