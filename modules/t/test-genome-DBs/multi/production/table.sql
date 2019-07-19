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
  `web_data_id` int(1) unsigned DEFAULT NULL,
  `displayable` tinyint(1) NOT NULL,
  PRIMARY KEY (`analysis_description_id`),
  UNIQUE KEY `logic_name_idx` (`logic_name`)
) ENGINE=MyISAM AUTO_INCREMENT=1074 DEFAULT CHARSET=latin1;


CREATE TABLE `master_attrib` (
  `attrib_id` int(11) unsigned NOT NULL DEFAULT '0',
  `attrib_type_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  `value` text NOT NULL,
  `is_current` tinyint(1) NOT NULL DEFAULT '1',
  `created_by` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `modified_by` int(11) DEFAULT NULL,
  `modified_at` datetime DEFAULT NULL,
  PRIMARY KEY (`attrib_id`),
  UNIQUE KEY `type_val_idx` (`attrib_type_id`,`value`(80))
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

CREATE TABLE `master_attrib_set` (
  `attrib_set_id` int(11) unsigned NOT NULL DEFAULT '0',
  `attrib_id` int(11) unsigned NOT NULL DEFAULT '0',
  `is_current` tinyint(1) NOT NULL DEFAULT '1',
  `created_by` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `modified_by` int(11) DEFAULT NULL,
  `modified_at` datetime DEFAULT NULL,
  UNIQUE KEY `set_idx` (`attrib_set_id`,`attrib_id`),
  KEY `attrib_idx` (`attrib_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

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
) ENGINE=MyISAM AUTO_INCREMENT=460 DEFAULT CHARSET=latin1;

CREATE TABLE `master_biotype` (
  `biotype_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(64) NOT NULL,
  `is_current` tinyint(1) NOT NULL DEFAULT '1',
  `is_dumped` tinyint(1) NOT NULL DEFAULT '1',
  `object_type` enum('gene','transcript') NOT NULL DEFAULT 'gene',
  `db_type` set('cdna','core','coreexpressionatlas','coreexpressionest','coreexpressiongnf','funcgen','otherfeatures','rnaseq','variation','vega','presite','sangervega') NOT NULL DEFAULT 'core',
  `attrib_type_id` int(11) DEFAULT NULL,
  `description` text,
  `biotype_group` enum('coding','pseudogene','snoncoding','lnoncoding','mnoncoding','LRG','undefined','no_group') DEFAULT NULL,
  `so_acc` varchar(64) DEFAULT NULL,
  `so_term` VARCHAR(1023) DEFAULT NULL,
  `created_by` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `modified_by` int(11) DEFAULT NULL,
  `modified_at` datetime DEFAULT NULL,
  PRIMARY KEY (`biotype_id`),
  UNIQUE KEY `name_type_idx` (`name`,`object_type`)
) ENGINE=MyISAM AUTO_INCREMENT=204 DEFAULT CHARSET=latin1;

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
) ENGINE=MyISAM AUTO_INCREMENT=64 DEFAULT CHARSET=latin1;

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

CREATE TABLE `web_data` (
  `web_data_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `data` text,
  `comment` text,
  `created_by` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `modified_by` int(11) DEFAULT NULL,
  `modified_at` datetime DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`web_data_id`)
) ENGINE=MyISAM AUTO_INCREMENT=111 DEFAULT CHARSET=latin1;

CREATE ALGORITHM=UNDEFINED DEFINER=CURRENT_USER SQL SECURITY INVOKER VIEW `attrib` AS select `master_attrib`.`attrib_id` AS `attrib_id`,`master_attrib`.`attrib_type_id` AS `attrib_type_id`,`master_attrib`.`value` AS `value` from `master_attrib` where (`master_attrib`.`is_current` = 1) order by `master_attrib`.`attrib_id`;

CREATE ALGORITHM=UNDEFINED DEFINER=CURRENT_USER SQL SECURITY INVOKER VIEW `attrib_set` AS select `master_attrib_set`.`attrib_set_id` AS `attrib_set_id`,`master_attrib_set`.`attrib_id` AS `attrib_id` from `master_attrib_set` where (`master_attrib_set`.`is_current` = 1) order by `master_attrib_set`.`attrib_set_id`,`master_attrib_set`.`attrib_id`;

CREATE ALGORITHM=UNDEFINED DEFINER=CURRENT_USER SQL SECURITY INVOKER VIEW `attrib_type` AS select `master_attrib_type`.`attrib_type_id` AS `attrib_type_id`,`master_attrib_type`.`code` AS `code`,`master_attrib_type`.`name` AS `name`,`master_attrib_type`.`description` AS `description` from `master_attrib_type` where (`master_attrib_type`.`is_current` = 1) order by `master_attrib_type`.`attrib_type_id`;

CREATE ALGORITHM=UNDEFINED DEFINER=CURRENT_USER SQL SECURITY INVOKER VIEW `biotype` AS select `master_biotype`.`biotype_id` AS `biotype_id`,`master_biotype`.`name` AS `name`,`master_biotype`.`object_type` AS `object_type`,`master_biotype`.`db_type` AS `db_type`,`master_biotype`.`attrib_type_id` AS `attrib_type_id`,`master_biotype`.`description` AS `description`,`master_biotype`.`biotype_group` AS `biotype_group`,`master_biotype`.`so_acc` AS `so_acc`, `master_biotype`.`so_term` AS `so_term` from `master_biotype` where (`master_biotype`.`is_current` = 1) order by `master_biotype`.`biotype_id`;

CREATE ALGORITHM=UNDEFINED DEFINER=CURRENT_USER SQL SECURITY INVOKER VIEW `external_db` AS select `master_external_db`.`external_db_id` AS `external_db_id`,`master_external_db`.`db_name` AS `db_name`,`master_external_db`.`db_release` AS `db_release`,`master_external_db`.`status` AS `status`,`master_external_db`.`priority` AS `priority`,`master_external_db`.`db_display_name` AS `db_display_name`,`master_external_db`.`type` AS `type`,`master_external_db`.`secondary_db_name` AS `secondary_db_name`,`master_external_db`.`secondary_db_table` AS `secondary_db_table`,`master_external_db`.`description` AS `description` from `master_external_db` where (`master_external_db`.`is_current` = 1) order by `master_external_db`.`external_db_id`;

CREATE ALGORITHM=UNDEFINED DEFINER=CURRENT_USER SQL SECURITY INVOKER VIEW `misc_set` AS select `master_misc_set`.`misc_set_id` AS `misc_set_id`,`master_misc_set`.`code` AS `code`,`master_misc_set`.`name` AS `name`,`master_misc_set`.`description` AS `description`,`master_misc_set`.`max_length` AS `max_length` from `master_misc_set` where (`master_misc_set`.`is_current` = 1) order by `master_misc_set`.`misc_set_id`;

CREATE ALGORITHM=UNDEFINED DEFINER=CURRENT_USER SQL SECURITY INVOKER VIEW `unmapped_reason` AS select `master_unmapped_reason`.`unmapped_reason_id` AS `unmapped_reason_id`,`master_unmapped_reason`.`summary_description` AS `summary_description`,`master_unmapped_reason`.`full_description` AS `full_description` from `master_unmapped_reason` where (`master_unmapped_reason`.`is_current` = 1) order by `master_unmapped_reason`.`unmapped_reason_id`;