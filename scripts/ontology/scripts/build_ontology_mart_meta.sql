-- MySQL dump 10.13  Distrib 5.6.26, for Linux (x86_64)
--
-- Host: mysql-eg-staging-1.ebi.ac.uk    Database: egontology_mart_31
-- ------------------------------------------------------
-- Server version	5.6.24

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
-- Table structure for table `meta_conf__dataset__main`
--

DROP TABLE IF EXISTS `meta_conf__dataset__main`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `meta_conf__dataset__main` (
  `dataset_id_key` int(11) NOT NULL,
  `dataset` varchar(100) DEFAULT NULL,
  `display_name` varchar(200) DEFAULT NULL,
  `description` varchar(200) DEFAULT NULL,
  `type` varchar(20) DEFAULT NULL,
  `visible` int(1) unsigned DEFAULT NULL,
  `version` varchar(25) DEFAULT NULL,
  `modified` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY `dataset_id_key` (`dataset_id_key`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 CHECKSUM=1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `meta_conf__interface__dm`
--

DROP TABLE IF EXISTS `meta_conf__interface__dm`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `meta_conf__interface__dm` (
  `dataset_id_key` int(11) DEFAULT NULL,
  `interface` varchar(100) DEFAULT NULL,
  UNIQUE KEY `dataset_id_key` (`dataset_id_key`,`interface`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 CHECKSUM=1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `meta_conf__user__dm`
--

DROP TABLE IF EXISTS `meta_conf__user__dm`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `meta_conf__user__dm` (
  `dataset_id_key` int(11) DEFAULT NULL,
  `mart_user` varchar(100) DEFAULT NULL,
  UNIQUE KEY `dataset_id_key` (`dataset_id_key`,`mart_user`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 CHECKSUM=1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `meta_conf__xml__dm`
--

DROP TABLE IF EXISTS `meta_conf__xml__dm`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `meta_conf__xml__dm` (
  `dataset_id_key` int(11) NOT NULL,
  `xml` longblob,
  `compressed_xml` longblob,
  `message_digest` blob,
  UNIQUE KEY `dataset_id_key` (`dataset_id_key`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 CHECKSUM=1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `meta_template__template__main`
--

DROP TABLE IF EXISTS `meta_template__template__main`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `meta_template__template__main` (
  `dataset_id_key` int(11) NOT NULL,
  `template` varchar(100) NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1 CHECKSUM=1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `meta_template__xml__dm`
--

DROP TABLE IF EXISTS `meta_template__xml__dm`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `meta_template__xml__dm` (
  `template` varchar(100) DEFAULT NULL,
  `compressed_xml` longblob,
  UNIQUE KEY `template` (`template`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 CHECKSUM=1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2016-07-06 16:11:42
