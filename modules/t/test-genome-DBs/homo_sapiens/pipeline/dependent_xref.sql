SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `dependent_xref` (
  `object_xref_id` int(10) unsigned NOT NULL,
  `master_xref_id` int(10) unsigned NOT NULL,
  `dependent_xref_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`object_xref_id`),
  KEY `dependent` (`dependent_xref_id`),
  KEY `master_idx` (`master_xref_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
