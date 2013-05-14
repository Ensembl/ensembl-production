SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `exon_transcript` (
  `exon_id` int(10) unsigned NOT NULL,
  `transcript_id` int(10) unsigned NOT NULL,
  `rank` int(10) NOT NULL,
  PRIMARY KEY (`exon_id`,`transcript_id`,`rank`),
  KEY `transcript` (`transcript_id`),
  KEY `exon` (`exon_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
