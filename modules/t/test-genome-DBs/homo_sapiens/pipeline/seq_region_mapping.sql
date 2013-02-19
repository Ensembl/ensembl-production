SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `seq_region_mapping` (
  `external_seq_region_id` int(10) unsigned NOT NULL,
  `internal_seq_region_id` int(10) unsigned NOT NULL,
  `mapping_set_id` int(10) unsigned NOT NULL,
  KEY `mapping_set_idx` (`mapping_set_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
