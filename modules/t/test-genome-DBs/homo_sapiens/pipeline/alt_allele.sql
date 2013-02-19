SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `alt_allele` (
  `alt_allele_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `gene_id` int(10) unsigned NOT NULL,
  `is_ref` tinyint(1) NOT NULL DEFAULT '0',
  UNIQUE KEY `gene_idx` (`gene_id`),
  UNIQUE KEY `allele_idx` (`alt_allele_id`,`gene_id`)
) ENGINE=MyISAM AUTO_INCREMENT=2177 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
