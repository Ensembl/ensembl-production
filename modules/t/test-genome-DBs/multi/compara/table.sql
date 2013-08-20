    

CREATE TABLE IF NOT EXISTS meta (
  meta_id                     INT NOT NULL AUTO_INCREMENT,
  species_id                  INT UNSIGNED DEFAULT 1,
  meta_key                    VARCHAR(40) NOT NULL,
  meta_value                  TEXT NOT NULL,
  PRIMARY   KEY (meta_id),
  UNIQUE    KEY species_key_value_idx (species_id, meta_key, meta_value(255)),
            KEY species_value_idx (species_id, meta_value(255))
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;
    

CREATE TABLE ncbi_taxa_node (
  taxon_id                        int(10) unsigned NOT NULL,
  parent_id                       int(10) unsigned NOT NULL,
  rank                            char(32) default '' NOT NULL,
  genbank_hidden_flag             tinyint(1) default 0 NOT NULL,
  left_index                      int(10) DEFAULT 0 NOT NULL,
  right_index                     int(10) DEFAULT 0 NOT NULL,
  root_id                         int(10) default 1 NOT NULL,
  PRIMARY KEY (taxon_id),
  KEY (parent_id),
  KEY (rank),
  KEY (left_index),
  KEY (right_index)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;
    

CREATE TABLE ncbi_taxa_name (
  taxon_id                    int(10) unsigned NOT NULL,
  name                        varchar(255),
  name_class                  varchar(50),
  FOREIGN KEY (taxon_id) REFERENCES ncbi_taxa_node(taxon_id),
  KEY (taxon_id),
  KEY (name),
  KEY (name_class)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;
   

CREATE TABLE genome_db (
  genome_db_id                int(10) unsigned NOT NULL AUTO_INCREMENT, 
  taxon_id                    int(10) unsigned DEFAULT NULL, 
  name                        varchar(40) DEFAULT '' NOT NULL,
  assembly                    varchar(100) DEFAULT '' NOT NULL,
  assembly_default            tinyint(1) DEFAULT 1,
  genebuild                   varchar(100) DEFAULT '' NOT NULL,
  locator                     varchar(400),
  FOREIGN KEY (taxon_id) REFERENCES ncbi_taxa_node(taxon_id),
  PRIMARY KEY (genome_db_id),
  UNIQUE name (name,assembly,genebuild)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;
   
  

CREATE TABLE species_set (
  species_set_id              int(10) unsigned NOT NULL AUTO_INCREMENT,
  genome_db_id                int(10) unsigned DEFAULT NULL,
  FOREIGN KEY (genome_db_id) REFERENCES genome_db(genome_db_id),
  UNIQUE KEY  (species_set_id,genome_db_id)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;
     

CREATE TABLE species_set_tag (
  species_set_id              int(10) unsigned NOT NULL, 
  tag                         varchar(50) NOT NULL,
  value                       mediumtext,
  
  
  UNIQUE KEY tag_species_set_id (species_set_id,tag)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;
     

CREATE TABLE method_link (
  method_link_id              int(10) unsigned NOT NULL AUTO_INCREMENT, 
  type                        varchar(50) DEFAULT '' NOT NULL,
  class                       varchar(50) DEFAULT '' NOT NULL,
  PRIMARY KEY (method_link_id),
  UNIQUE KEY type (type)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;
   

CREATE TABLE method_link_species_set (
  method_link_species_set_id  int(10) unsigned NOT NULL AUTO_INCREMENT, 
  method_link_id              int(10) unsigned, 
  species_set_id              int(10) unsigned NOT NULL default 0,
  name                        varchar(255) NOT NULL default '',
  source                      varchar(255) NOT NULL default 'ensembl',
  url                         varchar(255) NOT NULL default '',
  FOREIGN KEY (method_link_id) REFERENCES method_link(method_link_id),
  
  
  PRIMARY KEY (method_link_species_set_id),
  UNIQUE KEY method_link_id (method_link_id,species_set_id)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

CREATE TABLE method_link_species_set_tag (
  method_link_species_set_id  int(10) unsigned NOT NULL, 
  tag                         varchar(50) NOT NULL,
  value                       mediumtext,
  FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),
  PRIMARY KEY tag_mlss_id (method_link_species_set_id,tag)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;
   
   

CREATE TABLE synteny_region (
  synteny_region_id           int(10) unsigned NOT NULL AUTO_INCREMENT, 
  method_link_species_set_id  int(10) unsigned NOT NULL, 
  FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),
  PRIMARY KEY (synteny_region_id),
  KEY (method_link_species_set_id)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;
    

CREATE TABLE dnafrag (
  dnafrag_id                  bigint unsigned NOT NULL AUTO_INCREMENT, 
  length                      int(11) DEFAULT 0 NOT NULL,
  name                        varchar(40) DEFAULT '' NOT NULL,
  genome_db_id                int(10) unsigned NOT NULL, 
  coord_system_name           varchar(40) DEFAULT NULL,
  is_reference                tinyint(1) DEFAULT 1,
  FOREIGN KEY (genome_db_id) REFERENCES genome_db(genome_db_id),
  PRIMARY KEY (dnafrag_id),
  UNIQUE name (genome_db_id, name)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;
    
    

CREATE TABLE dnafrag_region (
  synteny_region_id           int(10) unsigned DEFAULT 0 NOT NULL, 
  dnafrag_id                  bigint unsigned DEFAULT 0 NOT NULL, 
  dnafrag_start               int(10) unsigned DEFAULT 0 NOT NULL,
  dnafrag_end                 int(10) unsigned DEFAULT 0 NOT NULL,
  dnafrag_strand              tinyint(4) DEFAULT 0 NOT NULL,
  FOREIGN KEY (synteny_region_id) REFERENCES synteny_region(synteny_region_id),
  FOREIGN KEY (dnafrag_id) REFERENCES dnafrag(dnafrag_id),
  KEY synteny (synteny_region_id,dnafrag_id),
  KEY synteny_reversed (dnafrag_id,synteny_region_id)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;
    

CREATE TABLE genomic_align_block (
  genomic_align_block_id      bigint unsigned NOT NULL AUTO_INCREMENT, 
  method_link_species_set_id  int(10) unsigned DEFAULT 0 NOT NULL, 
  score                       double,
  perc_id                     tinyint(3) unsigned DEFAULT NULL,
  length                      int(10),
  group_id                    bigint unsigned DEFAULT NULL,
  level_id                    tinyint(2) unsigned DEFAULT 0 NOT NULL,
  FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),
  PRIMARY KEY genomic_align_block_id (genomic_align_block_id),
  KEY method_link_species_set_id (method_link_species_set_id)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;
      
      

CREATE TABLE genomic_align_tree (
  node_id                     bigint(20) unsigned NOT NULL AUTO_INCREMENT, 
  parent_id                   bigint(20) unsigned NOT NULL default 0,
  root_id                     bigint(20) unsigned NOT NULL default 0,
  left_index                  int(10) NOT NULL default 0,
  right_index                 int(10) NOT NULL default 0,
  left_node_id                bigint(10) NOT NULL default 0,
  right_node_id               bigint(10) NOT NULL default 0,
  distance_to_parent          double NOT NULL default 1,
  PRIMARY KEY node_id (node_id),
  KEY parent_id (parent_id),
  KEY root_id (root_id),
  KEY left_index (root_id, left_index)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;
      

CREATE TABLE genomic_align (
  genomic_align_id            bigint unsigned NOT NULL AUTO_INCREMENT, 
  genomic_align_block_id      bigint unsigned NOT NULL, 
  method_link_species_set_id  int(10) unsigned DEFAULT 0 NOT NULL, 
  dnafrag_id                  bigint unsigned DEFAULT 0 NOT NULL, 
  dnafrag_start               int(10) DEFAULT 0 NOT NULL,
  dnafrag_end                 int(10) DEFAULT 0 NOT NULL,
  dnafrag_strand              tinyint(4) DEFAULT 0 NOT NULL,
  cigar_line                  mediumtext,
  visible                     tinyint(2) unsigned DEFAULT 1 NOT NULL,
  node_id                     bigint(20) unsigned DEFAULT NULL,
  FOREIGN KEY (genomic_align_block_id) REFERENCES genomic_align_block(genomic_align_block_id),
  FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),
  FOREIGN KEY (dnafrag_id) REFERENCES dnafrag(dnafrag_id),
  FOREIGN KEY (node_id) REFERENCES genomic_align_tree(node_id),
  PRIMARY KEY genomic_align_id (genomic_align_id),
  KEY genomic_align_block_id (genomic_align_block_id),
  KEY method_link_species_set_id (method_link_species_set_id),
  KEY dnafrag (dnafrag_id, method_link_species_set_id, dnafrag_start, dnafrag_end),
  KEY node_id (node_id)
) MAX_ROWS = 1000000000 AVG_ROW_LENGTH = 60 COLLATE=latin1_swedish_ci ENGINE=MyISAM;

CREATE TABLE conservation_score (
  genomic_align_block_id bigint unsigned not null,
  window_size            smallint unsigned not null,
  position               int unsigned not null,
  expected_score         blob,
  diff_score             blob,
  FOREIGN KEY (genomic_align_block_id) REFERENCES genomic_align_block(genomic_align_block_id),
  KEY (genomic_align_block_id, window_size)
) MAX_ROWS = 15000000 AVG_ROW_LENGTH = 841 COLLATE=latin1_swedish_ci ENGINE=MyISAM;
     
     

CREATE TABLE constrained_element (
  constrained_element_id bigint(20) unsigned NOT NULL,
  dnafrag_id bigint unsigned NOT NULL,
  dnafrag_start int(12) unsigned NOT NULL,
  dnafrag_end int(12) unsigned NOT NULL,
  dnafrag_strand int(2),
  method_link_species_set_id int(10) unsigned NOT NULL,
  p_value double,
  score double NOT NULL default 0,
  FOREIGN KEY (dnafrag_id) REFERENCES dnafrag(dnafrag_id),
  FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),
  KEY constrained_element_id_idx (constrained_element_id),
  KEY mlssid_idx (method_link_species_set_id),
  KEY mlssid_dfId_dfStart_dfEnd_idx (method_link_species_set_id,dnafrag_id,dnafrag_start,dnafrag_end),
  KEY mlssid_dfId_idx (method_link_species_set_id,dnafrag_id)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

CREATE TABLE sequence (
  sequence_id                 int(10) unsigned NOT NULL AUTO_INCREMENT, 
  length                      int(10) NOT NULL,
  sequence                    longtext NOT NULL,
  PRIMARY KEY (sequence_id),
  KEY sequence (sequence(18))
) MAX_ROWS = 10000000 AVG_ROW_LENGTH = 19000 COLLATE=latin1_swedish_ci ENGINE=MyISAM;
      

CREATE TABLE member (
  member_id                   int(10) unsigned NOT NULL AUTO_INCREMENT, 
  stable_id                   varchar(128) NOT NULL, 
  version                     int(10) DEFAULT 0,
  source_name                 ENUM('ENSEMBLGENE','ENSEMBLPEP','Uniprot/SPTREMBL','Uniprot/SWISSPROT','ENSEMBLTRANS','EXTERNALCDS') NOT NULL,
  taxon_id                    int(10) unsigned NOT NULL, 
  genome_db_id                int(10) unsigned, 
  sequence_id                 int(10) unsigned, 
  gene_member_id              int(10) unsigned, 
  canonical_member_id         int(10) unsigned, 
  description                 text DEFAULT NULL,
  chr_name                    char(40),
  chr_start                   int(10),
  chr_end                     int(10),
  chr_strand                  tinyint(1) NOT NULL,
  display_label               varchar(128) default NULL,
  FOREIGN KEY (taxon_id) REFERENCES ncbi_taxa_node(taxon_id),
  FOREIGN KEY (genome_db_id) REFERENCES genome_db(genome_db_id),
  FOREIGN KEY (sequence_id) REFERENCES sequence(sequence_id),
  FOREIGN KEY (gene_member_id) REFERENCES member(member_id),
  PRIMARY KEY (member_id),
  UNIQUE source_stable_id (stable_id, source_name),
  KEY (stable_id),
  KEY (source_name),
  KEY (sequence_id),
  KEY (gene_member_id),
  KEY gdb_name_start_end (genome_db_id,chr_name,chr_start,chr_end)
) MAX_ROWS = 100000000 COLLATE=latin1_swedish_ci ENGINE=MyISAM;

CREATE TABLE `member_production_counts` (
  `stable_id`                varchar(128) NOT NULL,
  `families`                 tinyint(1) unsigned default 0,
  `gene_trees`               tinyint(1) unsigned default 0,
  `gene_gain_loss_trees`     tinyint(1) unsigned default 0,
  `orthologues`              int(10) unsigned default 0,
  `paralogues`               int(10) unsigned default 0,
  FOREIGN KEY (stable_id) REFERENCES member(stable_id)
)COLLATE=latin1_swedish_ci ENGINE=MyISAM;

CREATE TABLE `external_db` (
  `external_db_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `db_name` varchar(100) NOT NULL,
  `db_release` varchar(255) DEFAULT NULL,
  `status` enum('KNOWNXREF','KNOWN','XREF','PRED','ORTH','PSEUDO') NOT NULL,
  `priority` int(11) NOT NULL,
  `db_display_name` varchar(255) DEFAULT NULL,
  `type` enum('ARRAY','ALT_TRANS','ALT_GENE','MISC','LIT','PRIMARY_DB_SYNONYM','ENSEMBL') DEFAULT NULL,
  `secondary_db_name` varchar(255) DEFAULT NULL,
  `secondary_db_table` varchar(255) DEFAULT NULL,
  `description` text,
  PRIMARY KEY (`external_db_id`),
  UNIQUE KEY `db_name_db_release_idx` (`db_name`,`db_release`)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

CREATE TABLE `member_xref` (
  `member_id` int(10) unsigned NOT NULL,
  `dbprimary_acc` varchar(10) NOT NULL,
  `external_db_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`member_id`,`dbprimary_acc`,`external_db_id`),
  FOREIGN KEY (member_id) REFERENCES member(member_id),
  FOREIGN KEY (external_db_id) REFERENCES external_db(external_db_id)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

CREATE TABLE other_member_sequence (
  member_id                   int(10) unsigned NOT NULL, 
  seq_type                    VARCHAR(40) NOT NULL,
  length                      int(10) NOT NULL,
  sequence                    mediumtext NOT NULL,
  FOREIGN KEY (member_id) REFERENCES member(member_id),
  PRIMARY KEY (member_id, seq_type)
) MAX_ROWS = 10000000 AVG_ROW_LENGTH = 60000 COLLATE=latin1_swedish_ci ENGINE=MyISAM;
     
     

CREATE TABLE peptide_align_feature (
  peptide_align_feature_id    bigint  unsigned NOT NULL AUTO_INCREMENT, 
  qmember_id                  int(10) unsigned NOT NULL, 
  hmember_id                  int(10) unsigned NOT NULL, 
  qgenome_db_id               int(10) unsigned NOT NULL, 
  hgenome_db_id               int(10) unsigned NOT NULL, 
  qstart                      int(10) DEFAULT 0 NOT NULL,
  qend                        int(10) DEFAULT 0 NOT NULL,
  hstart                      int(11) DEFAULT 0 NOT NULL,
  hend                        int(11) DEFAULT 0 NOT NULL,
  score                       double(16,4) DEFAULT 0.0000 NOT NULL,
  evalue                      double,
  align_length                int(10),
  identical_matches           int(10),
  perc_ident                  int(10),
  positive_matches            int(10),
  perc_pos                    int(10),
  hit_rank                    int(10),
  cigar_line                  mediumtext,
  PRIMARY KEY (peptide_align_feature_id)
) MAX_ROWS = 100000000 AVG_ROW_LENGTH = 133 COLLATE=latin1_swedish_ci ENGINE=MyISAM;
    

CREATE TABLE family (
  family_id                   int(10) unsigned NOT NULL AUTO_INCREMENT, 
  stable_id                   varchar(40) NOT NULL, 
  version                     INT UNSIGNED NOT NULL,
  method_link_species_set_id  int(10) unsigned NOT NULL, 
  description                 varchar(255),
  description_score           double,
  FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),
  PRIMARY KEY (family_id),
  UNIQUE (stable_id),
  KEY (method_link_species_set_id),
  KEY (description)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;
    

CREATE TABLE family_member (
  family_id                   int(10) unsigned NOT NULL, 
  member_id                   int(10) unsigned NOT NULL, 
  cigar_line                  mediumtext,
  FOREIGN KEY (family_id) REFERENCES family(family_id),
  FOREIGN KEY (member_id) REFERENCES member(member_id),
  PRIMARY KEY family_member_id (family_id,member_id),
  KEY (family_id),
  KEY (member_id)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

CREATE TABLE domain (
  domain_id                   int(10) unsigned NOT NULL AUTO_INCREMENT, 
  stable_id                   varchar(40) NOT NULL,
  method_link_species_set_id  int(10) unsigned NOT NULL, 
  description                 varchar(255),
  FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),
  PRIMARY KEY (domain_id),
  UNIQUE (stable_id, method_link_species_set_id)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

CREATE TABLE domain_member (
  domain_id                   int(10) unsigned NOT NULL, 
  member_id                   int(10) unsigned NOT NULL, 
  member_start                int(10),
  member_end                  int(10),
  FOREIGN KEY (domain_id) REFERENCES domain(domain_id),
  FOREIGN KEY (member_id) REFERENCES member(member_id),
  UNIQUE (domain_id,member_id,member_start,member_end),
  UNIQUE (member_id,domain_id,member_start,member_end)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

CREATE TABLE gene_align (
         gene_align_id         int(10) unsigned NOT NULL AUTO_INCREMENT,
	 seq_type              varchar(40),
	 aln_method            varchar(40) NOT NULL DEFAULT '',
	 aln_length            int(10) NOT NULL DEFAULT 0,
  PRIMARY KEY (gene_align_id)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

CREATE TABLE gene_align_member (
       gene_align_id         int(10) unsigned NOT NULL,
       member_id             int(10) unsigned NOT NULL,
       cigar_line            mediumtext,
  FOREIGN KEY (gene_align_id) REFERENCES gene_align(gene_align_id),
  FOREIGN KEY (member_id) REFERENCES member(member_id),
  PRIMARY KEY (gene_align_id,member_id),
  KEY member_id (member_id)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;
     

CREATE TABLE gene_tree_node (
  node_id                         int(10) unsigned NOT NULL AUTO_INCREMENT, 
  parent_id                       int(10) unsigned,
  root_id                         int(10) unsigned,
  left_index                      int(10) NOT NULL DEFAULT 0,
  right_index                     int(10) NOT NULL DEFAULT 0,
  distance_to_parent              double default 1.0 NOT NULL,
  member_id                       int(10) unsigned,
  FOREIGN KEY (root_id) REFERENCES gene_tree_node(node_id),
  FOREIGN KEY (parent_id) REFERENCES gene_tree_node(node_id),
  FOREIGN KEY (member_id) REFERENCES member(member_id),
  PRIMARY KEY (node_id),
  KEY parent_id (parent_id),
  KEY member_id (member_id),
  KEY root_id (root_id),
  KEY root_id_left_index (root_id,left_index)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;
     
     
     

CREATE TABLE gene_tree_root (
    root_id                         INT(10) UNSIGNED NOT NULL,
    member_type                     ENUM('protein', 'ncrna') NOT NULL,
    tree_type                       ENUM('clusterset', 'supertree', 'tree') NOT NULL,
    clusterset_id                   VARCHAR(20) NOT NULL DEFAULT 'default',
    method_link_species_set_id      INT(10) UNSIGNED NOT NULL,
    gene_align_id                   INT(10) UNSIGNED,
    ref_root_id                     INT(10) UNSIGNED,
    stable_id                       VARCHAR(40),            
    version                         INT UNSIGNED,           
    FOREIGN KEY (root_id) REFERENCES gene_tree_node(node_id),
    FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),
    FOREIGN KEY (gene_align_id) REFERENCES gene_align(gene_align_id),
    FOREIGN KEY (ref_root_id) REFERENCES gene_tree_root(root_id),
    PRIMARY KEY (root_id ),
    UNIQUE KEY ( stable_id ),
    KEY ref_root_id (ref_root_id),
    KEY (tree_type)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

CREATE TABLE gene_tree_node_tag (
  node_id                int(10) unsigned NOT NULL,
  tag                    varchar(50) NOT NULL,
  value                  mediumtext NOT NULL,
  FOREIGN KEY (node_id) REFERENCES gene_tree_node(node_id),
  KEY node_id_tag (node_id, tag),
  KEY (node_id)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

CREATE TABLE gene_tree_root_tag (
  root_id                int(10) unsigned NOT NULL,
  tag                    varchar(50) NOT NULL,
  value                  mediumtext NOT NULL,
  FOREIGN KEY (root_id) REFERENCES gene_tree_root(root_id),
  KEY root_id_tag (root_id, tag),
  KEY (root_id)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

CREATE TABLE gene_tree_node_attr (
  node_id                         INT(10) UNSIGNED NOT NULL,
  node_type                       ENUM("duplication", "dubious", "speciation", "gene_split"),
  taxon_id                        INT(10) UNSIGNED,
  taxon_name                      VARCHAR(255),
  bootstrap                       TINYINT UNSIGNED,
  duplication_confidence_score    DOUBLE(5,4),
  FOREIGN KEY (node_id) REFERENCES gene_tree_node(node_id),
  PRIMARY KEY (node_id)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

CREATE TABLE hmm_profile (
  model_id                    varchar(40) NOT NULL,
  name                        varchar(40),
  type                        varchar(40) NOT NULL,
  hc_profile                  mediumtext,
  consensus                   mediumtext,
  PRIMARY KEY (model_id,type)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;
     

CREATE TABLE homology (
  homology_id                 int(10) unsigned NOT NULL AUTO_INCREMENT, 
  method_link_species_set_id  int(10) unsigned NOT NULL, 
  description                 ENUM('ortholog_one2one','apparent_ortholog_one2one','ortholog_one2many','ortholog_many2many','within_species_paralog','other_paralog','putative_gene_split','contiguous_gene_split','between_species_paralog','possible_ortholog','UBRH','BRH','MBRH','RHS', 'projection_unchanged','projection_altered'),
  subtype                     varchar(40) NOT NULL DEFAULT '',
  dn                          float(10,5),
  ds                          float(10,5),
  n                           float(10,1),
  s                           float(10,1),
  lnl                         float(10,3),
  threshold_on_ds             float(10,5),
  ancestor_node_id            int(10) unsigned,
  tree_node_id                int(10) unsigned,
  FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),
  FOREIGN KEY (ancestor_node_id) REFERENCES gene_tree_node(node_id),
  FOREIGN KEY (tree_node_id) REFERENCES gene_tree_root(root_id),
  PRIMARY KEY (homology_id),
  KEY (method_link_species_set_id),
  KEY (ancestor_node_id),
  KEY (tree_node_id)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

CREATE TABLE homology_member (
  homology_id                 int(10) unsigned NOT NULL, 
  member_id                   int(10) unsigned NOT NULL, 
  peptide_member_id           int(10) unsigned, 
  cigar_line                  mediumtext,
  perc_cov                    int(10),
  perc_id                     int(10),
  perc_pos                    int(10),
  FOREIGN KEY (homology_id) REFERENCES homology(homology_id),
  FOREIGN KEY (member_id) REFERENCES member(member_id),
  FOREIGN KEY (peptide_member_id) REFERENCES member(member_id),
  PRIMARY KEY homology_member_id (homology_id,member_id),
  KEY (homology_id),
  KEY (member_id),
  KEY (peptide_member_id)
) MAX_ROWS = 300000000 COLLATE=latin1_swedish_ci ENGINE=MyISAM;

CREATE TABLE mapping_session (
    mapping_session_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    type               ENUM('family', 'tree'),
    when_mapped        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    rel_from           INT UNSIGNED,
    rel_to             INT UNSIGNED,
    prefix             CHAR(4) NOT NULL,
    PRIMARY KEY ( mapping_session_id ),
    UNIQUE KEY  ( type, rel_from, rel_to, prefix )
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

CREATE TABLE stable_id_history (
    mapping_session_id INT UNSIGNED NOT NULL,
    stable_id_from     VARCHAR(40) NOT NULL DEFAULT '',
    version_from       INT UNSIGNED NULL DEFAULT NULL,
    stable_id_to       VARCHAR(40) NOT NULL DEFAULT '',
    version_to         INT UNSIGNED NULL DEFAULT NULL,
    contribution       FLOAT,
    FOREIGN KEY (mapping_session_id) REFERENCES mapping_session(mapping_session_id),
    PRIMARY KEY ( mapping_session_id, stable_id_from, stable_id_to )
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

CREATE TABLE sitewise_aln (
  sitewise_id                 int(10) unsigned NOT NULL AUTO_INCREMENT, 
  aln_position                int(10) unsigned NOT NULL,
  node_id                     int(10) unsigned NOT NULL,
  tree_node_id                int(10) unsigned NOT NULL,
  omega                       float(10,5),
  omega_lower                 float(10,5),
  omega_upper                 float(10,5),
  optimal                     float(10,5),
  ncod                        int(10),
  threshold_on_branch_ds      float(10,5),
  type                        ENUM('single_character','random','all_gaps','constant','default','negative1','negative2','negative3','negative4','positive1','positive2','positive3','positive4','synonymous') NOT NULL,
  FOREIGN KEY (node_id) REFERENCES gene_tree_node(node_id),
  UNIQUE aln_position_node_id_ds (aln_position,node_id,threshold_on_branch_ds),
  PRIMARY KEY (sitewise_id),
  KEY (tree_node_id),
  KEY (node_id)
) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

CREATE TABLE `species_tree_node` (
  `node_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `parent_id` int(10) unsigned,
  `root_id` int(10) unsigned,
  `left_index` int(10) NOT NULL DEFAULT 0,
  `right_index` int(10) NOT NULL DEFAULT 0,
  `distance_to_parent` double DEFAULT '1',
  PRIMARY KEY (`node_id`),
  KEY `parent_id` (`parent_id`),
  KEY `root_id` (`root_id`,`left_index`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

CREATE TABLE `species_tree_root` (
  `root_id` int(10) unsigned NOT NULL,
  `method_link_species_set_id` int(10) unsigned NOT NULL,
  `species_tree` mediumtext,
  `pvalue_lim` double(5,4) DEFAULT NULL,
  FOREIGN KEY (root_id) REFERENCES species_tree_node(node_id),
  FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),
  PRIMARY KEY (root_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

CREATE TABLE `species_tree_node_tag` (
  `node_id` int(10) unsigned NOT NULL,
  `tag` varchar(50) NOT NULL,
  `value` mediumtext NOT NULL,
  FOREIGN KEY (node_id) REFERENCES species_tree_node(node_id),
  KEY `node_id_tag` (`node_id`,`tag`),
  KEY `tag_node_id` (`tag`,`node_id`),
  KEY `node_id` (`node_id`),
  KEY `tag` (`tag`)
  
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

CREATE TABLE `CAFE_gene_family` (
  `cafe_gene_family_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `root_id` int(10) unsigned NOT NULL,
  `lca_id` int(10) unsigned NOT NULL,
  `gene_tree_root_id` int(10) unsigned NOT NULL,
  `pvalue_avg` double(5,4) DEFAULT NULL,
  `lambdas` varchar(100) DEFAULT NULL,
  FOREIGN KEY (root_id) REFERENCES species_tree_root(root_id),
  FOREIGN KEY (lca_id) REFERENCES species_tree_node(node_id),
  FOREIGN KEY (gene_tree_root_id) REFERENCES gene_tree_root(root_id),
  PRIMARY KEY (`cafe_gene_family_id`),
  KEY `root_id` (`root_id`),
  KEY `gene_tree_root_id` (`gene_tree_root_id`)
) ENGINE=MyISAM AUTO_INCREMENT=10 DEFAULT CHARSET=latin1;

CREATE TABLE `CAFE_species_gene` (
  `cafe_gene_family_id` int(10) unsigned NOT NULL,
  `node_id` int(10) unsigned NOT NULL,
  `taxon_id` int(10) unsigned DEFAULT NULL,
  `n_members` int(4) unsigned NOT NULL,
  `pvalue` double(5,4) DEFAULT NULL,
  FOREIGN KEY (cafe_gene_family_id) REFERENCES CAFE_gene_family(cafe_gene_family_id),
  FOREIGN KEY (node_id) REFERENCES species_tree_node(node_id),
  KEY `cafe_gene_family_id` (`cafe_gene_family_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
