-- Create syntax for TABLE 'assembly'
CREATE TABLE `assembly` (
  `assembly_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `assembly_accession` varchar(16) DEFAULT NULL,
  `assembly_name` varchar(200) NOT NULL,
  `assembly_default` varchar(200) NOT NULL,
  `assembly_ucsc` varchar(16) DEFAULT NULL,
  `assembly_level` varchar(50) NOT NULL,
  `base_count` bigint(20) unsigned NOT NULL,
  PRIMARY KEY (`assembly_id`),
  UNIQUE KEY `assembly_idx` (`assembly_accession`,`assembly_default`)
) ENGINE=InnoDB AUTO_INCREMENT=47700 DEFAULT CHARSET=latin1;

-- Create syntax for TABLE 'data_release'
CREATE TABLE `data_release` (
  `data_release_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `ensembl_version` int(10) unsigned NOT NULL,
  `ensembl_genomes_version` int(10) unsigned DEFAULT NULL,
  `release_date` date NOT NULL,
  `is_current` tinyint(3) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`data_release_id`),
  UNIQUE KEY `ensembl_version` (`ensembl_version`,`ensembl_genomes_version`)
) ENGINE=InnoDB AUTO_INCREMENT=52 DEFAULT CHARSET=latin1;

-- Create syntax for TABLE 'division'
CREATE TABLE `division` (
  `division_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(32) NOT NULL,
  `short_name` varchar(8) NOT NULL,
  PRIMARY KEY (`division_id`),
  UNIQUE KEY `name` (`name`),
  UNIQUE KEY `short_name` (`short_name`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=latin1;

-- Create syntax for TABLE 'genome'
CREATE TABLE `genome` (
  `genome_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `data_release_id` int(10) unsigned NOT NULL,
  `assembly_id` int(10) unsigned NOT NULL,
  `organism_id` int(10) unsigned NOT NULL,
  `genebuild` varchar(64) NOT NULL,
  `division_id` int(10) unsigned NOT NULL,
  `has_pan_compara` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `has_variations` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `has_peptide_compara` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `has_genome_alignments` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `has_synteny` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `has_other_alignments` tinyint(3) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`genome_id`),
  UNIQUE KEY `release_genome_division` (`data_release_id`,`genome_id`,`division_id`),
  KEY `genome_ibfk_1` (`assembly_id`),
  KEY `genome_ibfk_3` (`organism_id`),
  KEY `genome_ibfk_4` (`division_id`),
  CONSTRAINT `genome_ibfk_1` FOREIGN KEY (`assembly_id`) REFERENCES `assembly` (`assembly_id`),
  CONSTRAINT `genome_ibfk_2` FOREIGN KEY (`data_release_id`) REFERENCES `data_release` (`data_release_id`),
  CONSTRAINT `genome_ibfk_3` FOREIGN KEY (`organism_id`) REFERENCES `organism` (`organism_id`) ON DELETE CASCADE,
  CONSTRAINT `genome_ibfk_4` FOREIGN KEY (`division_id`) REFERENCES `division` (`division_id`)
) ENGINE=InnoDB AUTO_INCREMENT=744630 DEFAULT CHARSET=latin1;

-- Create syntax for TABLE 'organism'
CREATE TABLE `organism` (
  `organism_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `taxonomy_id` int(10) unsigned NOT NULL,
  `is_reference` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `species_taxonomy_id` int(10) unsigned NOT NULL,
  `name` varchar(128) NOT NULL,
  `url_name` varchar(128) NOT NULL,
  `display_name` varchar(128) NOT NULL,
  `scientific_name` varchar(128) NOT NULL,
  `strain` varchar(128) DEFAULT NULL,
  `serotype` varchar(128) DEFAULT NULL,
  `description` text,
  `image` blob,
  PRIMARY KEY (`organism_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=51406 DEFAULT CHARSET=latin1;