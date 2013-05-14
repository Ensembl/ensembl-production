SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `transcript_supporting_feature` (
  `transcript_id` int(10) unsigned NOT NULL DEFAULT '0',
  `feature_type` enum('dna_align_feature','protein_align_feature') DEFAULT NULL,
  `feature_id` int(10) unsigned NOT NULL DEFAULT '0',
  UNIQUE KEY `all_idx` (`transcript_id`,`feature_type`,`feature_id`),
  KEY `feature_idx` (`feature_type`,`feature_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 MAX_ROWS=100000000 AVG_ROW_LENGTH=80;
SET character_set_client = @saved_cs_client;
