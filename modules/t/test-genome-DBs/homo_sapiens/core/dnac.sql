SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `dnac` (
  `seq_region_id` int(10) unsigned NOT NULL,
  `sequence` mediumblob NOT NULL,
  `n_line` text,
  PRIMARY KEY (`seq_region_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 MAX_ROWS=750000 AVG_ROW_LENGTH=19000;
SET character_set_client = @saved_cs_client;
