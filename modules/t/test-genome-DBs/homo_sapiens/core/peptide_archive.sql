SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `peptide_archive` (
  `peptide_archive_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `md5_checksum` varchar(32) DEFAULT NULL,
  `peptide_seq` mediumtext NOT NULL,
  PRIMARY KEY (`peptide_archive_id`),
  KEY `checksum` (`md5_checksum`)
) ENGINE=MyISAM AUTO_INCREMENT=151888 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
