SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `karyotype` (
  `karyotype_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `seq_region_id` int(10) unsigned NOT NULL,
  `seq_region_start` int(10) unsigned NOT NULL,
  `seq_region_end` int(10) unsigned NOT NULL,
  `band` varchar(40) NOT NULL,
  `stain` varchar(40) NOT NULL,
  PRIMARY KEY (`karyotype_id`),
  KEY `region_band_idx` (`seq_region_id`,`band`)
) ENGINE=MyISAM AUTO_INCREMENT=1610 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
