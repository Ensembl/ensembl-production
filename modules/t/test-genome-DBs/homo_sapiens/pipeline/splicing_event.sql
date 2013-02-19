SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `splicing_event` (
  `splicing_event_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(134) DEFAULT NULL,
  `gene_id` int(10) unsigned NOT NULL,
  `seq_region_id` int(10) unsigned NOT NULL,
  `seq_region_start` int(10) unsigned NOT NULL,
  `seq_region_end` int(10) unsigned NOT NULL,
  `seq_region_strand` tinyint(2) NOT NULL,
  `attrib_type_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`splicing_event_id`),
  KEY `gene_idx` (`gene_id`),
  KEY `seq_region_idx` (`seq_region_id`,`seq_region_start`)
) ENGINE=MyISAM AUTO_INCREMENT=409449 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
