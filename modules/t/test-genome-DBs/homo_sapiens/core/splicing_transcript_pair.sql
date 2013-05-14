SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `splicing_transcript_pair` (
  `splicing_transcript_pair_id` int(10) unsigned NOT NULL,
  `splicing_event_id` int(10) unsigned NOT NULL,
  `transcript_id_1` int(10) unsigned NOT NULL,
  `transcript_id_2` int(10) unsigned NOT NULL,
  PRIMARY KEY (`splicing_transcript_pair_id`),
  KEY `se_idx` (`splicing_event_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
