CREATE TABLE `analysis_description` (
  `analysis_description_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `logic_name` varchar(128) NOT NULL,
  `description` text,
  `display_label` varchar(256) NOT NULL,
  `db_version` tinyint(1) NOT NULL DEFAULT '1',
  `is_current` tinyint(1) NOT NULL DEFAULT '1',
  `created_by` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `modified_by` int(11) DEFAULT NULL,
  `modified_at` datetime DEFAULT NULL,
  `default_web_data_id` int(10) unsigned DEFAULT NULL,
  `default_displayable` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`analysis_description_id`),
  UNIQUE KEY `logic_name_idx` (`logic_name`)
) ENGINE=MyISAM AUTO_INCREMENT=1074 DEFAULT CHARSET=latin1;

CREATE TABLE `analysis_web_data` (
  `analysis_web_data_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `analysis_description_id` int(10) unsigned NOT NULL,
  `web_data_id` int(10) unsigned DEFAULT NULL,
  `species_id` int(10) unsigned NOT NULL,
  `db_type` enum('cdna','core','funcgen','otherfeatures','rnaseq','vega','presite','sangervega','grch37_archive') NOT NULL DEFAULT 'core',
  `displayable` tinyint(1) NOT NULL DEFAULT '1',
  `created_by` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `modified_by` int(11) DEFAULT NULL,
  `modified_at` datetime DEFAULT NULL,
  PRIMARY KEY (`analysis_web_data_id`),
  UNIQUE KEY `uniq_idx` (`species_id`,`db_type`,`analysis_description_id`),
  KEY `ad_idx` (`analysis_description_id`),
  KEY `wd_idx` (`web_data_id`)
) ENGINE=MyISAM AUTO_INCREMENT=4509 DEFAULT CHARSET=latin1;

CREATE TABLE `biotype` (
  `biotype_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(64) NOT NULL,
  `is_current` tinyint(1) NOT NULL DEFAULT '1',
  `is_dumped` tinyint(1) NOT NULL DEFAULT '1',
  `object_type` enum('gene','transcript') NOT NULL DEFAULT 'gene',
  `db_type` set('cdna','core','coreexpressionatlas','coreexpressionest','coreexpressiongnf','funcgen','otherfeatures','rnaseq','variation','vega','presite','sangervega') NOT NULL DEFAULT 'core',
  `attrib_type_id` int(11) DEFAULT NULL,
  `description` text,
  `biotype_group` enum('coding','pseudogene','snoncoding','lnoncoding','mnoncoding','LRG','undefined','no_group') DEFAULT NULL,
  `created_by` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `modified_by` int(11) DEFAULT NULL,
  `modified_at` datetime DEFAULT NULL,
  PRIMARY KEY (`biotype_id`),
  UNIQUE KEY `name_type_idx` (`name`,`object_type`,`db_type`)
) ENGINE=MyISAM AUTO_INCREMENT=173 DEFAULT CHARSET=latin1;

CREATE TABLE `changelog` (
  `changelog_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `release_id` int(11) DEFAULT NULL,
  `title` varchar(128) DEFAULT NULL,
  `content` text,
  `notes` text,
  `status` enum('declared','handed_over','postponed','cancelled') NOT NULL DEFAULT 'declared',
  `team` enum('Compara','Core','Funcgen','Genebuild','Outreach','Variation','Web','EnsemblGenomes','Wormbase','Production') DEFAULT NULL,
  `assembly` enum('N','Y') NOT NULL DEFAULT 'N',
  `gene_set` enum('N','Y') NOT NULL DEFAULT 'N',
  `repeat_masking` enum('N','Y') NOT NULL DEFAULT 'N',
  `stable_id_mapping` enum('N','Y') NOT NULL DEFAULT 'N',
  `affy_mapping` enum('N','Y') NOT NULL DEFAULT 'N',
  `biomart_affected` enum('N','Y') NOT NULL DEFAULT 'N',
  `variation_pos_changed` enum('N','Y') NOT NULL DEFAULT 'N',
  `db_status` enum('N/A','unchanged','patched','new') NOT NULL DEFAULT 'N/A',
  `db_type_affected` set('cdna','core','funcgen','otherfeatures','rnaseq','variation','vega') DEFAULT NULL,
  `mitochondrion` enum('Y','N','changed') NOT NULL DEFAULT 'N',
  `priority` tinyint(1) NOT NULL DEFAULT '2',
  `created_by` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `modified_by` int(11) DEFAULT NULL,
  `modified_at` datetime DEFAULT NULL,
  `is_current` int(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`changelog_id`)
) ENGINE=MyISAM AUTO_INCREMENT=1173 DEFAULT CHARSET=latin1;

CREATE TABLE `changelog_species` (
  `changelog_id` int(11) NOT NULL DEFAULT '0',
  `species_id` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`changelog_id`,`species_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

CREATE TABLE `db` (
  `db_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `species_id` int(10) unsigned NOT NULL,
  `is_current` tinyint(1) NOT NULL DEFAULT '0',
  `db_type` enum('cdna','core','coreexpressionatlas','coreexpressionest','coreexpressiongnf','funcgen','otherfeatures','rnaseq','variation','vega') NOT NULL DEFAULT 'core',
  `db_release` varchar(8) NOT NULL,
  `db_assembly` int(11) NOT NULL,
  `db_suffix` char(1) DEFAULT '',
  `db_host` varchar(32) DEFAULT NULL,
  PRIMARY KEY (`db_id`),
  UNIQUE KEY `species_release_idx` (`species_id`,`db_type`,`db_release`)
) ENGINE=MyISAM AUTO_INCREMENT=2038 DEFAULT CHARSET=latin1;

CREATE TABLE `master_attrib_type` (
  `attrib_type_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `code` varchar(20) NOT NULL DEFAULT '',
  `name` varchar(255) NOT NULL DEFAULT '',
  `description` text,
  `is_current` tinyint(1) NOT NULL DEFAULT '1',
  `created_by` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `modified_by` int(11) DEFAULT NULL,
  `modified_at` datetime DEFAULT NULL,
  PRIMARY KEY (`attrib_type_id`),
  UNIQUE KEY `code_idx` (`code`)
) ENGINE=MyISAM AUTO_INCREMENT=392 DEFAULT CHARSET=latin1;

CREATE TABLE `master_external_db` (
  `external_db_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `db_name` varchar(100) NOT NULL,
  `db_release` varchar(255) DEFAULT NULL,
  `status` enum('KNOWNXREF','KNOWN','XREF','PRED','ORTH','PSEUDO') NOT NULL,
  `priority` int(11) NOT NULL,
  `db_display_name` varchar(255) NOT NULL,
  `type` enum('ARRAY','ALT_TRANS','ALT_GENE','MISC','LIT','PRIMARY_DB_SYNONYM','ENSEMBL') DEFAULT NULL,
  `secondary_db_name` varchar(255) DEFAULT NULL,
  `secondary_db_table` varchar(255) DEFAULT NULL,
  `description` text,
  `is_current` tinyint(1) NOT NULL DEFAULT '1',
  `created_by` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `modified_by` int(11) DEFAULT NULL,
  `modified_at` datetime DEFAULT NULL,
  PRIMARY KEY (`external_db_id`),
  UNIQUE KEY `db_name_idx` (`db_name`,`db_release`,`is_current`)
) ENGINE=MyISAM AUTO_INCREMENT=50748 DEFAULT CHARSET=latin1;

CREATE TABLE `master_misc_set` (
  `misc_set_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `code` varchar(25) NOT NULL DEFAULT '',
  `name` varchar(255) NOT NULL DEFAULT '',
  `description` text NOT NULL,
  `max_length` int(10) unsigned NOT NULL,
  `is_current` tinyint(1) NOT NULL DEFAULT '1',
  `created_by` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `modified_by` int(11) DEFAULT NULL,
  `modified_at` datetime DEFAULT NULL,
  PRIMARY KEY (`misc_set_id`),
  UNIQUE KEY `code_idx` (`code`)
) ENGINE=MyISAM AUTO_INCREMENT=19 DEFAULT CHARSET=latin1;

CREATE TABLE `master_unmapped_reason` (
  `unmapped_reason_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `summary_description` varchar(255) DEFAULT NULL,
  `full_description` varchar(255) DEFAULT NULL,
  `is_current` tinyint(1) NOT NULL DEFAULT '1',
  `created_by` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `modified_by` int(11) DEFAULT NULL,
  `modified_at` datetime DEFAULT NULL,
  PRIMARY KEY (`unmapped_reason_id`)
) ENGINE=MyISAM AUTO_INCREMENT=139 DEFAULT CHARSET=latin1;

CREATE TABLE `meta` (
  `meta_id` int(11) NOT NULL AUTO_INCREMENT,
  `species_id` int(10) unsigned DEFAULT '1',
  `meta_key` varchar(40) NOT NULL,
  `meta_value` text NOT NULL,
  PRIMARY KEY (`meta_id`),
  UNIQUE KEY `species_key_value_idx` (`species_id`,`meta_key`,`meta_value`(255)),
  KEY `species_value_idx` (`species_id`,`meta_value`(255))
) ENGINE=MyISAM AUTO_INCREMENT=31 DEFAULT CHARSET=latin1;

CREATE TABLE `meta_key` (
  `meta_key_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(64) NOT NULL,
  `is_optional` tinyint(1) NOT NULL DEFAULT '0',
  `is_current` tinyint(1) NOT NULL DEFAULT '1',
  `db_type` set('cdna','core','funcgen','otherfeatures','rnaseq','variation','vega','presite','sangervega') NOT NULL DEFAULT 'core',
  `description` text,
  `created_by` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `modified_by` int(11) DEFAULT NULL,
  `modified_at` datetime DEFAULT NULL,
  PRIMARY KEY (`meta_key_id`),
  KEY `name_type_idx` (`name`,`db_type`)
) ENGINE=MyISAM AUTO_INCREMENT=95 DEFAULT CHARSET=latin1;

CREATE TABLE `meta_key_species` (
  `meta_key_id` int(10) unsigned NOT NULL,
  `species_id` int(10) unsigned NOT NULL,
  UNIQUE KEY `uniq_idx` (`meta_key_id`,`species_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

CREATE TABLE `species` (
  `species_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `db_name` varchar(255) NOT NULL,
  `common_name` varchar(255) NOT NULL,
  `web_name` varchar(255) NOT NULL,
  `scientific_name` varchar(255) NOT NULL,
  `production_name` varchar(255) NOT NULL,
  `url_name` varchar(255) NOT NULL DEFAULT '',
  `taxon` varchar(8) NOT NULL,
  `species_prefix` varchar(7) NOT NULL,
  `is_current` tinyint(1) NOT NULL DEFAULT '1',
  `created_by` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `modified_by` int(11) DEFAULT NULL,
  `modified_at` datetime DEFAULT NULL,
  `attrib_type_id` smallint(5) unsigned DEFAULT NULL,
  PRIMARY KEY (`species_id`),
  UNIQUE KEY `db_name_idx` (`db_name`),
  UNIQUE KEY `production_name_idx` (`production_name`),
  UNIQUE KEY `species_prefix_idx` (`species_prefix`),
  UNIQUE KEY `taxon_idx` (`taxon`)
) ENGINE=MyISAM AUTO_INCREMENT=22 DEFAULT CHARSET=latin1;

CREATE TABLE `species_alias` (
  `species_alias_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `species_id` int(10) unsigned NOT NULL,
  `alias` varchar(255) NOT NULL,
  `is_current` tinyint(1) NOT NULL DEFAULT '1',
  `created_by` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `modified_by` int(11) DEFAULT NULL,
  `modified_at` datetime DEFAULT NULL,
  PRIMARY KEY (`species_alias_id`),
  UNIQUE KEY `alias` (`alias`,`is_current`),
  KEY `sa_speciesid_idx` (`species_id`)
) ENGINE=MyISAM AUTO_INCREMENT=219 DEFAULT CHARSET=latin1;

CREATE TABLE `web_data` (
  `web_data_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `data` text,
  `comment` text,
  `created_by` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `modified_by` int(11) DEFAULT NULL,
  `modified_at` datetime DEFAULT NULL,
  PRIMARY KEY (`web_data_id`)
) ENGINE=MyISAM AUTO_INCREMENT=111 DEFAULT CHARSET=latin1;

CREATE ALGORITHM=UNDEFINED DEFINER=`ensadmin`@`%` SQL SECURITY INVOKER VIEW `attrib_type` AS select `master_attrib_type`.`attrib_type_id` AS `attrib_type_id`,`master_attrib_type`.`code` AS `code`,`master_attrib_type`.`name` AS `name`,`master_attrib_type`.`description` AS `description` from `master_attrib_type` where (`master_attrib_type`.`is_current` = 1) order by `master_attrib_type`.`attrib_type_id`;

CREATE ALGORITHM=UNDEFINED DEFINER=`ensadmin`@`%` SQL SECURITY INVOKER VIEW `db_list` AS select `db`.`db_id` AS `db_id`,concat(concat_ws('_',`species`.`db_name`,`db`.`db_type`,`db`.`db_release`,`db`.`db_assembly`),`db`.`db_suffix`) AS `full_db_name` from (`species` join `db` on((`species`.`species_id` = `db`.`species_id`))) where (`species`.`is_current` = 1);

CREATE ALGORITHM=UNDEFINED DEFINER=`ensadmin`@`%` SQL SECURITY INVOKER VIEW `external_db` AS select `master_external_db`.`external_db_id` AS `external_db_id`,`master_external_db`.`db_name` AS `db_name`,`master_external_db`.`db_release` AS `db_release`,`master_external_db`.`status` AS `status`,`master_external_db`.`priority` AS `priority`,`master_external_db`.`db_display_name` AS `db_display_name`,`master_external_db`.`type` AS `type`,`master_external_db`.`secondary_db_name` AS `secondary_db_name`,`master_external_db`.`secondary_db_table` AS `secondary_db_table`,`master_external_db`.`description` AS `description` from `master_external_db` where (`master_external_db`.`is_current` = 1) order by `master_external_db`.`external_db_id`;

CREATE ALGORITHM=UNDEFINED DEFINER=`ensadmin`@`%` SQL SECURITY INVOKER VIEW `full_analysis_description` AS select `list`.`full_db_name` AS `full_db_name`,`ad`.`logic_name` AS `logic_name`,`ad`.`description` AS `description`,`ad`.`display_label` AS `display_label`,`awd`.`displayable` AS `displayable`,`wd`.`data` AS `web_data` from ((((`db_list` `list` join `db` on((`list`.`db_id` = `db`.`db_id`))) join `analysis_web_data` `awd` on(((`db`.`species_id` = `awd`.`species_id`) and (`db`.`db_type` = `awd`.`db_type`)))) join `analysis_description` `ad` on((`awd`.`analysis_description_id` = `ad`.`analysis_description_id`))) left join `web_data` `wd` on((`awd`.`web_data_id` = `wd`.`web_data_id`))) where ((`db`.`is_current` = 1) and (`ad`.`is_current` = 1));

CREATE ALGORITHM=UNDEFINED DEFINER=`ensadmin`@`%` SQL SECURITY INVOKER VIEW `logic_name_overview` AS select `awd`.`analysis_web_data_id` AS `analysis_web_data_id`,`ad`.`logic_name` AS `logic_name`,`ad`.`analysis_description_id` AS `analysis_description_id`,`s`.`db_name` AS `species`,`s`.`species_id` AS `species_id`,`awd`.`db_type` AS `db_type`,`wd`.`web_data_id` AS `web_data_id`,`awd`.`displayable` AS `displayable` from (((`analysis_description` `ad` join `analysis_web_data` `awd` on((`ad`.`analysis_description_id` = `awd`.`analysis_description_id`))) join `species` `s` on((`awd`.`species_id` = `s`.`species_id`))) left join `web_data` `wd` on((`awd`.`web_data_id` = `wd`.`web_data_id`))) where ((`s`.`is_current` = 1) and (`ad`.`is_current` = 1));

CREATE ALGORITHM=UNDEFINED DEFINER=`ensadmin`@`%` SQL SECURITY INVOKER VIEW `misc_set` AS select `master_misc_set`.`misc_set_id` AS `misc_set_id`,`master_misc_set`.`code` AS `code`,`master_misc_set`.`name` AS `name`,`master_misc_set`.`description` AS `description`,`master_misc_set`.`max_length` AS `max_length` from `master_misc_set` where (`master_misc_set`.`is_current` = 1) order by `master_misc_set`.`misc_set_id`;

CREATE ALGORITHM=UNDEFINED DEFINER=`ensadmin`@`%` SQL SECURITY INVOKER VIEW `unconnected_analyses` AS select `ad`.`analysis_description_id` AS `analysis_description_id`,`ad`.`logic_name` AS `logic_name` from (`analysis_description` `ad` left join `analysis_web_data` `awd` on((`ad`.`analysis_description_id` = `awd`.`analysis_description_id`))) where (isnull(`awd`.`species_id`) and (`ad`.`is_current` = 1));

CREATE ALGORITHM=UNDEFINED DEFINER=`ensadmin`@`%` SQL SECURITY INVOKER VIEW `unmapped_reason` AS select `master_unmapped_reason`.`unmapped_reason_id` AS `unmapped_reason_id`,`master_unmapped_reason`.`summary_description` AS `summary_description`,`master_unmapped_reason`.`full_description` AS `full_description` from `master_unmapped_reason` where (`master_unmapped_reason`.`is_current` = 1) order by `master_unmapped_reason`.`unmapped_reason_id`;

CREATE ALGORITHM=UNDEFINED DEFINER=`ensadmin`@`%` SQL SECURITY INVOKER VIEW `unused_web_data` AS select `wd`.`web_data_id` AS `web_data_id` from (`web_data` `wd` left join `analysis_web_data` `awd` on((`wd`.`web_data_id` = `awd`.`web_data_id`))) where isnull(`awd`.`analysis_web_data_id`);

