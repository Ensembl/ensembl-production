SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `transcript_intron_supporting_evidence` (
  `transcript_id` int(10) unsigned NOT NULL,
  `intron_supporting_evidence_id` int(10) unsigned NOT NULL,
  `previous_exon_id` int(10) unsigned NOT NULL,
  `next_exon_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`intron_supporting_evidence_id`,`transcript_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
