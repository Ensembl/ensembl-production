CREATE TABLE `ens_release` (
  `release_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `number` varchar(5) NOT NULL DEFAULT '',
  `date` varchar(14) DEFAULT NULL,
  `archive` varchar(7) NOT NULL DEFAULT '',
  `online` enum('N','Y') DEFAULT 'Y',
  `mart` enum('N','Y') DEFAULT 'N',
  PRIMARY KEY (`release_id`),
  UNIQUE KEY `release_number` (`number`)
) ENGINE=MyISAM AUTO_INCREMENT=72 DEFAULT CHARSET=latin1;

CREATE TABLE `frontpage_stats` (
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `useragent` text NOT NULL,
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `updated` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `pageviews` int(10) unsigned NOT NULL DEFAULT '0',
  `jscr0` int(10) unsigned NOT NULL DEFAULT '0',
  `jscr1` int(10) unsigned NOT NULL DEFAULT '0',
  `cook0` int(10) unsigned NOT NULL DEFAULT '0',
  `cook1` int(10) unsigned NOT NULL DEFAULT '0',
  `ajax0` int(10) unsigned NOT NULL DEFAULT '0',
  `ajax1` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  KEY `created` (`created`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

CREATE TABLE `gene_autocomplete` (
  `species` varchar(255) DEFAULT NULL,
  `stable_id` varchar(128) NOT NULL DEFAULT '',
  `display_label` varchar(128) DEFAULT NULL,
  `db` varchar(32) NOT NULL DEFAULT 'core',
  KEY `i` (`species`,`display_label`),
  KEY `i2` (`species`,`stable_id`),
  KEY `i3` (`species`,`display_label`,`stable_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

CREATE TABLE `help_link` (
  `help_link_id` int(11) NOT NULL AUTO_INCREMENT,
  `page_url` tinytext,
  `help_record_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`help_link_id`)
) ENGINE=MyISAM AUTO_INCREMENT=87 DEFAULT CHARSET=latin1;

CREATE TABLE `help_record` (
  `help_record_id` int(11) NOT NULL AUTO_INCREMENT,
  `type` varchar(255) NOT NULL DEFAULT '',
  `keyword` tinytext,
  `data` text NOT NULL,
  `created_by` int(11) DEFAULT '0',
  `created_at` datetime DEFAULT NULL,
  `modified_by` int(11) DEFAULT '0',
  `modified_at` datetime DEFAULT NULL,
  `status` enum('draft','live','dead') DEFAULT NULL,
  `helpful` int(11) DEFAULT '0',
  `not_helpful` int(11) DEFAULT '0',
  PRIMARY KEY (`help_record_id`)
) ENGINE=MyISAM AUTO_INCREMENT=451 DEFAULT CHARSET=latin1;

CREATE TABLE `help_record_link` (
  `help_record_link_id` int(11) NOT NULL AUTO_INCREMENT,
  `link_from_id` int(11) NOT NULL DEFAULT '0',
  `link_to_id` int(11) NOT NULL DEFAULT '0',
  `relationship` enum('parent_of','see_also') DEFAULT NULL,
  `order_by` tinyint(4) DEFAULT NULL,
  PRIMARY KEY (`help_record_link_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

CREATE TABLE `item_species` (
  `item_species_id` int(11) NOT NULL DEFAULT '0',
  `news_item_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  `species_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`news_item_id`,`species_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

CREATE TABLE `news_category` (
  `news_category_id` int(11) NOT NULL AUTO_INCREMENT,
  `code` varchar(10) NOT NULL DEFAULT '',
  `name` varchar(64) NOT NULL DEFAULT '',
  `priority` tinyint(3) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`news_category_id`),
  UNIQUE KEY `code` (`code`),
  KEY `priority` (`priority`)
) ENGINE=MyISAM AUTO_INCREMENT=5 DEFAULT CHARSET=latin1;

CREATE TABLE `news_item` (
  `news_item_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `release_id` smallint(5) DEFAULT NULL,
  `created_by` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `modified_by` int(11) DEFAULT NULL,
  `modified_at` datetime DEFAULT NULL,
  `news_category_id` smallint(5) unsigned DEFAULT NULL,
  `declaration` text,
  `data` text,
  `notes` text,
  `title` tinytext,
  `content` text,
  `priority` tinyint(3) unsigned DEFAULT '0',
  `dec_status` enum('declared','handed_over','postponed','cancelled') DEFAULT NULL,
  `news_done` enum('N','Y','X') DEFAULT NULL,
  `status` enum('draft','published','dead') DEFAULT NULL,
  PRIMARY KEY (`news_item_id`),
  KEY `news_cat_id` (`news_category_id`)
) ENGINE=MyISAM AUTO_INCREMENT=1417 DEFAULT CHARSET=latin1;

CREATE TABLE `release_species` (
  `release_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  `species_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  `assembly_code` varchar(16) NOT NULL DEFAULT '',
  `assembly_name` varchar(16) NOT NULL DEFAULT '',
  `pre_code` varchar(16) NOT NULL DEFAULT '',
  `pre_name` varchar(16) NOT NULL DEFAULT '',
  `initial_release` varchar(8) DEFAULT NULL,
  `last_geneset` varchar(8) DEFAULT NULL,
  PRIMARY KEY (`release_id`,`species_id`)
) ENGINE=MyISAM AUTO_INCREMENT=1367 DEFAULT CHARSET=latin1;

CREATE TABLE `species` (
  `species_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `code` varchar(5) DEFAULT NULL,
  `name` varchar(255) NOT NULL DEFAULT '',
  `common_name` varchar(32) NOT NULL DEFAULT '',
  `vega` enum('N','Y') DEFAULT NULL,
  `dump_notes` text NOT NULL,
  `online` enum('N','Y') NOT NULL DEFAULT 'Y',
  PRIMARY KEY (`species_id`),
  UNIQUE KEY `species_code` (`code`)
) ENGINE=MyISAM AUTO_INCREMENT=84 DEFAULT CHARSET=latin1;

