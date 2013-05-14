SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `dna_align_feature` (
  `dna_align_feature_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `seq_region_id` int(10) unsigned NOT NULL,
  `seq_region_start` int(10) unsigned NOT NULL,
  `seq_region_end` int(10) unsigned NOT NULL,
  `seq_region_strand` tinyint(1) NOT NULL,
  `hit_start` int(11) NOT NULL,
  `hit_end` int(11) NOT NULL,
  `hit_strand` tinyint(1) NOT NULL,
  `hit_name` varchar(40) NOT NULL,
  `analysis_id` smallint(5) unsigned NOT NULL,
  `score` double DEFAULT NULL,
  `evalue` double DEFAULT NULL,
  `perc_ident` float DEFAULT NULL,
  `cigar_line` text,
  `external_db_id` int(10) unsigned DEFAULT NULL,
  `hcoverage` double DEFAULT NULL,
  `external_data` text,
  `pair_dna_align_feature_id` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`dna_align_feature_id`),
  KEY `seq_region_idx` (`seq_region_id`,`analysis_id`,`seq_region_start`,`score`),
  KEY `seq_region_idx_2` (`seq_region_id`,`seq_region_start`),
  KEY `hit_idx` (`hit_name`),
  KEY `analysis_idx` (`analysis_id`),
  KEY `external_db_idx` (`external_db_id`),
  KEY `pair_idx` (`pair_dna_align_feature_id`)
) ENGINE=MyISAM AUTO_INCREMENT=29285518 DEFAULT CHARSET=latin1 MAX_ROWS=100000000 AVG_ROW_LENGTH=80;
SET character_set_client = @saved_cs_client;
