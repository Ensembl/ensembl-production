SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `interpro` (
  `interpro_ac` varchar(40) NOT NULL,
  `id` varchar(40) NOT NULL,
  UNIQUE KEY `accession_idx` (`interpro_ac`,`id`),
  KEY `id_idx` (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
