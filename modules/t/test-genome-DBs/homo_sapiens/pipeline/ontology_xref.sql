SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `ontology_xref` (
  `object_xref_id` int(10) unsigned NOT NULL DEFAULT '0',
  `source_xref_id` int(10) unsigned DEFAULT NULL,
  `linkage_type` varchar(3) DEFAULT NULL,
  UNIQUE KEY `object_source_type_idx` (`object_xref_id`,`source_xref_id`,`linkage_type`(1)),
  KEY `source_idx` (`source_xref_id`),
  KEY `object_idx` (`object_xref_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
