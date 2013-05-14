SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `stable_id_event` (
  `old_stable_id` varchar(128) DEFAULT NULL,
  `old_version` smallint(6) DEFAULT NULL,
  `new_stable_id` varchar(128) DEFAULT NULL,
  `new_version` smallint(6) DEFAULT NULL,
  `mapping_session_id` int(10) unsigned NOT NULL DEFAULT '0',
  `type` enum('gene','transcript','translation') NOT NULL,
  `score` float NOT NULL DEFAULT '0',
  UNIQUE KEY `uni_idx` (`mapping_session_id`,`old_stable_id`,`new_stable_id`,`type`),
  KEY `new_idx` (`new_stable_id`),
  KEY `old_idx` (`old_stable_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
