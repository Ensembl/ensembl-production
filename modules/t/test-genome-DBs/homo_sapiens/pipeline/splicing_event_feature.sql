SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `splicing_event_feature` (
  `splicing_event_feature_id` int(10) unsigned NOT NULL,
  `splicing_event_id` int(10) unsigned NOT NULL,
  `exon_id` int(10) unsigned NOT NULL,
  `transcript_id` int(10) unsigned NOT NULL,
  `feature_order` int(10) unsigned NOT NULL,
  `transcript_association` int(10) unsigned NOT NULL,
  `type` enum('constitutive_exon','exon','flanking_exon') DEFAULT NULL,
  `start` int(10) unsigned NOT NULL,
  `end` int(10) unsigned NOT NULL,
  PRIMARY KEY (`splicing_event_feature_id`,`exon_id`,`transcript_id`),
  KEY `se_idx` (`splicing_event_id`),
  KEY `transcript_idx` (`transcript_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
