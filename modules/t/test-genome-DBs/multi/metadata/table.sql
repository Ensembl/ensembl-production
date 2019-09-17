-- MySQL dump 10.14  Distrib 5.5.47-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: ensembl_metadata
-- ------------------------------------------------------
-- Server version	5.5.47-MariaDB-1ubuntu0.14.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `assembly`
--

DROP TABLE IF EXISTS `assembly`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `assembly` (
  `assembly_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `assembly_accession` varchar(16) DEFAULT NULL,
  `assembly_name` varchar(200) NOT NULL,
  `assembly_default` varchar(200) NOT NULL,
  `assembly_ucsc` varchar(16) DEFAULT NULL,
  `assembly_level` varchar(50) NOT NULL,
  `base_count` bigint(20) unsigned NOT NULL,
  PRIMARY KEY (`assembly_id`),
  UNIQUE KEY `assembly_idx` (`assembly_accession`,`assembly_default`,`base_count`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `assembly_sequence`
--

DROP TABLE IF EXISTS `assembly_sequence`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `assembly_sequence` (
  `assembly_sequence_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `assembly_id` int(10) unsigned NOT NULL,
  `name` varchar(40) NOT NULL,
  `acc` varchar(24) DEFAULT NULL,
  PRIMARY KEY (`assembly_sequence_id`),
  UNIQUE KEY `name_acc` (`assembly_id`,`name`,`acc`),
  KEY `acc` (`acc`),
  KEY `name` (`name`),
  CONSTRAINT `assembly_sequence_ibfk_1` FOREIGN KEY (`assembly_id`) REFERENCES `assembly` (`assembly_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compara_analysis`
--

DROP TABLE IF EXISTS `compara_analysis`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `compara_analysis` (
  `compara_analysis_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `data_release_id` int(10) unsigned NOT NULL,
  `division_id` int(10) unsigned NOT NULL,
  `method` varchar(50) NOT NULL,
  `set_name` varchar(128) DEFAULT NULL,
  `dbname` varchar(64) NOT NULL,
  PRIMARY KEY (`compara_analysis_id`),
  UNIQUE KEY `division_method_set_name_dbname` (`division_id`,`method`,`set_name`,`dbname`),
  CONSTRAINT `compara_analysis_ibfk_1` FOREIGN KEY (`division_id`) REFERENCES `division` (`division_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `compara_analysis_event`
--

DROP TABLE IF EXISTS `compara_analysis_event`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `compara_analysis_event` (
  `compara_analysis_event_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `compara_analysis_id` int(10) unsigned NOT NULL,
  `type` varchar(32) NOT NULL,
  `source` varchar(128) DEFAULT NULL,
  `creation_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `details` text,
  PRIMARY KEY (`compara_analysis_event_id`),
  KEY `compara_analysis_event_ibfk_1` (`compara_analysis_id`),
  CONSTRAINT `compara_analysis_event_ibfk_1` FOREIGN KEY (`compara_analysis_id`) REFERENCES `compara_analysis` (`compara_analysis_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `data_release`
--

DROP TABLE IF EXISTS `data_release`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `data_release` (
  `data_release_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `ensembl_version` int(10) unsigned NOT NULL,
  `ensembl_genomes_version` int(10) unsigned DEFAULT NULL,
  `release_date` date NOT NULL,
  `is_current` tinyint(3) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`data_release_id`),
  UNIQUE KEY `ensembl_version` (`ensembl_version`,`ensembl_genomes_version`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `data_release_database`
--

DROP TABLE IF EXISTS `data_release_database`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `data_release_database` (
  `data_release_database_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `data_release_id` int(10) unsigned NOT NULL,
  `dbname` varchar(64) NOT NULL,
  `type` enum('mart','ontology','ids','other') DEFAULT 'other',
  `division_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`data_release_database_id`),
  UNIQUE KEY `id_dbname` (`data_release_id`,`dbname`),
  KEY `data_release_database_ibfk_2` (`division_id`),
  CONSTRAINT `data_release_database_ibfk_1` FOREIGN KEY (`data_release_id`) REFERENCES `data_release` (`data_release_id`),
  CONSTRAINT `data_release_database_ibfk_2` FOREIGN KEY (`division_id`) REFERENCES `division` (`division_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `data_release_database_event`
--

DROP TABLE IF EXISTS `data_release_database_event`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `data_release_database_event` (
  `data_release_database_event_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `data_release_database_id` int(10) unsigned NOT NULL,
  `type` varchar(32) NOT NULL,
  `source` varchar(128) DEFAULT NULL,
  `creation_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `details` text,
  PRIMARY KEY (`data_release_database_event_id`),
  KEY `data_release_database_event_ibfk_1` (`data_release_database_id`),
  CONSTRAINT `data_release_database_event_ibfk_1` FOREIGN KEY (`data_release_database_id`) REFERENCES `data_release_database` (`data_release_database_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `division`
--

DROP TABLE IF EXISTS `division`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `division` (
  `division_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(32) NOT NULL,
  `short_name` varchar(8) NOT NULL,
  PRIMARY KEY (`division_id`),
  UNIQUE KEY `name` (`name`),
  UNIQUE KEY `short_name` (`short_name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `genome`
--

DROP TABLE IF EXISTS `genome`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
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
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `genome_alignment`
--

DROP TABLE IF EXISTS `genome_alignment`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `genome_alignment` (
  `genome_alignment_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genome_id` int(10) unsigned NOT NULL,
  `type` varchar(32) NOT NULL,
  `name` varchar(128) NOT NULL,
  `count` int(10) unsigned NOT NULL,
  `genome_database_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`genome_alignment_id`),
  UNIQUE KEY `id_type_key` (`genome_id`,`type`,`name`,`genome_database_id`),
  CONSTRAINT `genome_alignment_ibfk_1` FOREIGN KEY (`genome_id`) REFERENCES `genome` (`genome_id`) ON DELETE CASCADE,
  CONSTRAINT `genome_alignment_ibfk_2` FOREIGN KEY (`genome_database_id`) REFERENCES `genome_database` (`genome_database_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `genome_annotation`
--

DROP TABLE IF EXISTS `genome_annotation`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `genome_annotation` (
  `genome_annotation_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genome_id` int(10) unsigned NOT NULL,
  `type` varchar(32) NOT NULL,
  `value` varchar(128) NOT NULL,
  `genome_database_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`genome_annotation_id`),
  UNIQUE KEY `id_type` (`genome_id`,`type`,`genome_database_id`),
  CONSTRAINT `genome_annotation_ibfk_1` FOREIGN KEY (`genome_id`) REFERENCES `genome` (`genome_id`) ON DELETE CASCADE,
  CONSTRAINT `genome_annotation_ibfk_2` FOREIGN KEY (`genome_database_id`) REFERENCES `genome_database` (`genome_database_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `genome_compara_analysis`
--

DROP TABLE IF EXISTS `genome_compara_analysis`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `genome_compara_analysis` (
  `genome_compara_analysis_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genome_id` int(10) unsigned NOT NULL,
  `compara_analysis_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`genome_compara_analysis_id`),
  UNIQUE KEY `genome_compara_analysis_key` (`genome_id`,`compara_analysis_id`),
  KEY `compara_analysis_idx` (`compara_analysis_id`),
  CONSTRAINT `genome_compara_analysis_ibfk_1` FOREIGN KEY (`genome_id`) REFERENCES `genome` (`genome_id`) ON DELETE CASCADE,
  CONSTRAINT `genome_compara_analysis_ibfk_2` FOREIGN KEY (`compara_analysis_id`) REFERENCES `compara_analysis` (`compara_analysis_id`)  ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `genome_database`
--

DROP TABLE IF EXISTS `genome_database`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `genome_database` (
  `genome_database_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genome_id` int(10) unsigned NOT NULL,
  `dbname` varchar(64) NOT NULL,
  `species_id` int(10) unsigned NOT NULL,
  `type` enum('core','funcgen','variation','otherfeatures','rnaseq','cdna','vega') DEFAULT NULL,
  PRIMARY KEY (`genome_database_id`),
  UNIQUE KEY `id_dbname` (`genome_id`,`dbname`),
  UNIQUE KEY `dbname_species_id` (`dbname`,`species_id`),
  CONSTRAINT `genome_database_ibfk_1` FOREIGN KEY (`genome_id`) REFERENCES `genome` (`genome_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `genome_event`
--

DROP TABLE IF EXISTS `genome_event`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `genome_event` (
  `genome_event_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genome_id` int(10) unsigned NOT NULL,
  `type` varchar(32) NOT NULL,
  `source` varchar(128) DEFAULT NULL,
  `creation_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `details` text,
  PRIMARY KEY (`genome_event_id`),
  KEY `genome_event_ibfk_1` (`genome_id`),
  CONSTRAINT `genome_event_ibfk_1` FOREIGN KEY (`genome_id`) REFERENCES `genome` (`genome_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `genome_feature`
--

DROP TABLE IF EXISTS `genome_feature`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `genome_feature` (
  `genome_feature_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genome_id` int(10) unsigned NOT NULL,
  `type` varchar(32) NOT NULL,
  `analysis` varchar(128) NOT NULL,
  `count` int(10) unsigned NOT NULL,
  `genome_database_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`genome_feature_id`),
  UNIQUE KEY `id_type_analysis` (`genome_id`,`type`,`analysis`,`genome_database_id`),
  CONSTRAINT `genome_feature_ibfk_1` FOREIGN KEY (`genome_id`) REFERENCES `genome` (`genome_id`) ON DELETE CASCADE,
  CONSTRAINT `genome_feature_ibfk_2` FOREIGN KEY (`genome_database_id`) REFERENCES `genome_database` (`genome_database_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `genome_variation`
--

DROP TABLE IF EXISTS `genome_variation`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `genome_variation` (
  `genome_variation_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `genome_id` int(10) unsigned NOT NULL,
  `type` varchar(32) NOT NULL,
  `name` varchar(128) NOT NULL,
  `count` int(10) unsigned NOT NULL,
  `genome_database_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`genome_variation_id`),
  UNIQUE KEY `id_type_key` (`genome_id`,`type`,`name`,`genome_database_id`),
  CONSTRAINT `genome_variation_ibfk_1` FOREIGN KEY (`genome_id`) REFERENCES `genome` (`genome_id`) ON DELETE CASCADE,
  CONSTRAINT genome_variation_ibfk_2 FOREIGN KEY (genome_database_id) REFERENCES genome_database (genome_database_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `organism`
--

DROP TABLE IF EXISTS `organism`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
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
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `organism_alias`
--

DROP TABLE IF EXISTS `organism_alias`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `organism_alias` (
  `organism_alias_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `organism_id` int(10) unsigned NOT NULL,
  `alias` varchar(255) CHARACTER SET latin1 COLLATE latin1_bin DEFAULT NULL,
  PRIMARY KEY (`organism_alias_id`),
  UNIQUE KEY `id_alias` (`organism_id`,`alias`),
  CONSTRAINT `organism_alias_ibfk_1` FOREIGN KEY (`organism_id`) REFERENCES `organism` (`organism_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `organism_publication`
--

DROP TABLE IF EXISTS `organism_publication`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `organism_publication` (
  `organism_publication_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `organism_id` int(10) unsigned NOT NULL,
  `publication` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`organism_publication_id`),
  UNIQUE KEY `id_publication` (`organism_id`,`publication`),
  CONSTRAINT `organism_publication_ibfk_1` FOREIGN KEY (`organism_id`) REFERENCES `organism` (`organism_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2016-03-31 16:01:31
