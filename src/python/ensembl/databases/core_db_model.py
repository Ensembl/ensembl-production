from sqlalchemy import (Column, Index, Enum, ForeignKey, DateTime, Float, DECIMAL, text)
from sqlalchemy.dialects.mysql import (INTEGER, VARCHAR, TINYINT, SET, SMALLINT, TEXT, LONGTEXT, BIGINT, DOUBLE, MEDIUMTEXT, TINYTEXT)
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()

class Assembly(Base):
  __tablename__ = "assembly"
  __table_args__ = (
    Index("asm_seq_region_idx", "asm_seq_region_id", "asm_start"),
  )

  asm_seq_region_id = Column(INTEGER(10), ForeignKey("seq_region.seq_region_id"), primary_key=True)
  cmp_seq_region_id = Column(INTEGER(10), ForeignKey("seq_region.seq_region_id"), primary_key=True)
  asm_start         = Column(INTEGER(10), primary_key=True)
  asm_end           = Column(INTEGER(10), primary_key=True)
  cmp_start         = Column(INTEGER(10), primary_key=True)
  cmp_end           = Column(INTEGER(10), primary_key=True)
  ori               = Column(TINYINT(4), primary_key=True)

class AssemblyException(Base):
  __tablename__ = "assembly_exception"
  __table_args__ = (
    Index("sr_idx", "seq_region_id", "seq_region_start"),
    Index("ex_idx", "exc_seq_region_id", "exc_seq_region_start")
  )

  assembly_exception_id = Column(INTEGER(10), primary_key=True, autoincrement=True)
  seq_region_id         = Column(INTEGER(10), ForeignKey("seq_region.seq_region_id"), nullable=False)
  seq_region_start      = Column(INTEGER(10), nullable=False)
  seq_region_end        = Column(INTEGER(10), nullable=False)
  exc_type              = Column(Enum('HAP', 'PAR', 'PATCH_FIX', 'PATCH_NOVEL'), nullable=False)
  exc_seq_region_id     = Column(INTEGER(10), ForeignKey("seq_region.seq_region_id"), nullable=False)
  exc_seq_region_start  = Column(INTEGER(10), nullable=False)
  exc_seq_region_end    = Column(INTEGER(10), nullable=False)
  ori                   = Column(INTEGER(11), nullable=False)

class CoordSystem(Base):
  __tablename__ = "coord_system"
  __table_args__ = (
    Index("rank_idx", "rank", "species_id", unique=True),
    Index("name_idx", "name", "version", "species_id", unique=True)
  )

  coord_system_id = Column(INTEGER(10), primary_key=True, autoincrement=True)
  species_id      = Column(INTEGER(10), nullable=False, server_default=text("1"), index=True)
  name            = Column(VARCHAR(40), nullable=False)
  version         = Column(VARCHAR(255))
  rank            = Column(INTEGER(11), nullable=False)
  attrib          = Column(SET('default_version', 'sequence_level'))

class DataFile(Base):
  __tablename__ = "data_file"
  __table_args__ = (
    Index("df_unq_idx", "coord_system_id", "analysis_id", "name", "file_type", unique=True),
  )

  data_file_id    = Column(INTEGER(10), primary_key=True, autoincrement=True)
  coord_system_id = Column(INTEGER(10), ForeignKey("coord_system.coord_system_id"), nullable=False)
  analysis_id     = Column(SMALLINT(5), nullable=False, index=True)
  name            = Column(VARCHAR(100), nullable=False, index=True)
  version_lock    = Column(TINYINT(1), nullable=False, server_default=text("0"))
  absolute        = Column(TINYINT(1), nullable=False, server_default=text("0"))
  url             = Column(TEXT)
  file_type       = Column(Enum('BAM', 'BAMCOV', 'BIGBED', 'BIGWIG', 'VCF'))

class Dna(Base):
  __tablename__ = "dna"

  seq_region_id = Column(INTEGER(10), ForeignKey("seq_region.seq_region_id"), primary_key=True)
  sequence      = Column(LONGTEXT, nullable=False)

class GenomeStatistics(Base):
  __tablename__ = "genome_statistics"
  __table_args__ = (
    Index("stats_uniq", "statistic", "attrib_type_id", "species_id", unique=True),
  )

  genome_statistics_id = Column(INTEGER(10), primary_key=True, autoincrement=True)
  statistic            = Column(VARCHAR(128), nullable=False)
  value                = Column(BIGINT(11), nullable=False, server_default=text("0"))
  species_id           = Column(INTEGER(10), server_default=text("1"))
  attrib_type_id       = Column(INTEGER(10), nullable=False)
  timestamp            = Column(DateTime)

class Karyotype(Base):
  __tablename__ = "karyotype"
  __table_args__ = (
    Index("region_band_idx", "seq_region_id", "band"),
  )

  karyotype_id     = Column(INTEGER(10), primary_key=True, autoincrement=True)
  seq_region_id    = Column(INTEGER(10), ForeignKey("seq_region.seq_region_id"), nullable=False)
  seq_region_start = Column(INTEGER(10), nullable=False)
  seq_region_end   = Column(INTEGER(10), nullable=False)
  band             = Column(VARCHAR(40))
  stain            = Column(VARCHAR(40))

class Meta(Base):
  __tablename__ = "meta"
  __table_args__ = (
    Index("species_value_idx", "species_id", "meta_value"),
    Index("species_key_value_idx", "species_id", "meta_key", "meta_value", unique=True)
  )

  meta_id    = Column(INTEGER(11), primary_key=True, autoincrement=True)
  species_id = Column(INTEGER(10), server_default=text("1"))
  meta_key   = Column(VARCHAR(40), nullable=False)
  meta_value = Column(VARCHAR(255), nullable=False)

class MetaCoord(Base):
  __tablename__ = "meta_coord"

  table_name      = Column(VARCHAR(40), primary_key=True)
  coord_system_id = Column(INTEGER(10), ForeignKey("coord_system.coord_system_id"), primary_key=True)
  max_length      = Column(INTEGER(11))

class SeqRegion(Base):
  __tablename__ = "seq_region"
  __table_args__ = (
    Index("name_cs_idx", "name", "coord_system_id", unique=True),
  )

  seq_region_id   = Column(INTEGER(10), primary_key=True, autoincrement=True)
  name            = Column(VARCHAR(255), nullable=False)
  coord_system_id = Column(INTEGER(10), ForeignKey("coord_system.coord_system_id"), nullable=False, index=True)
  length          = Column(INTEGER(10), nullable=False)

class SeqRegionSynonym(Base):
  __tablename__ = "seq_region_synonym"
  __table_args__ = (
    Index("syn_idx", "synonym", "seq_region_id", unique=True),
  )

  seq_region_synonym_id = Column(INTEGER(10), primary_key=True, autoincrement=True)
  seq_region_id         = Column(INTEGER(10), ForeignKey("seq_region.seq_region_id"), nullable=False, index=True)
  synonym               = Column(VARCHAR(250), nullable=False)
  external_db_id        = Column(INTEGER(10), ForeignKey("external_db.external_db_id"))

class SeqRegionAttrib(Base):
  __tablename__ = "seq_region_attrib"
  __table_args__ = (
    Index("type_val_idx", "attrib_type_id", "value", mysql_length={"value" : 40}),
    Index("val_only_idx", "value", mysql_length=40),
    Index("region_attribx", "seq_region_id", "attrib_type_id", "value", unique=True, mysql_length={"value" : 500})
  )

  seq_region_id  = Column(INTEGER(10), ForeignKey("seq_region.seq_region_id"), primary_key=True, server_default=text("0"), index=True)
  attrib_type_id = Column(SMALLINT(5), ForeignKey("attrib_type.attrib_type_id"),
      primary_key=True, server_default=text("0"))
  value          = Column(TEXT, primary_key=True)

class AltAllele(Base):
  __tablename__ = "alt_allele"
  __table_args__ = (
    Index("gene_alt_group_idx", "gene_id", "alt_allele_group_id"),
  )

  alt_allele_id       = Column(INTEGER(10), primary_key=True, autoincrement=True)
  alt_allele_group_id = Column(INTEGER(10), ForeignKey("alt_allele_group.alt_allele_group_id"), nullable=False)
  gene_id             = Column(INTEGER(10), ForeignKey("gene.gene_id"), nullable=False, index=True)

class AltAlleleAttrib(Base):
  __tablename__ = "alt_allele_attrib"

  alt_allele_id = Column(INTEGER(10), primary_key=True)
  attrib        = Column(Enum('IS_REPRESENTATIVE', 'IS_MOST_COMMON_ALLELE', 'IN_CORRECTED_ASSEMBLY', 'HAS_CODING_POTENTIAL', 'IN_ARTIFICIALLY_DUPLICATED_ASSEMBLY', 'IN_SYNTENIC_REGION', 'HAS_SAME_UNDERLYING_DNA_SEQUENCE', 'IN_BROKEN_ASSEMBLY_REGION', 'IS_VALID_ALTERNATE', 'SAME_AS_REPRESENTATIVE', 'SAME_AS_ANOTHER_ALLELE', 'MANUALLY_ASSIGNED', 'AUTOMATICALLY_ASSIGNED', 'IS_PAR'), primary_key=True)

class AltAlleleGroup(Base):
  __tablename__ = "alt_allele_group"

  alt_allele_group_id = Column(INTEGER(10), primary_key=True, autoincrement=True)

class Analysis(Base):
  __tablename__ = "analysis"

  analysis_id     = Column(SMALLINT(5), primary_key=True, autoincrement=True)
  created         = Column(DateTime)
  logic_name      = Column(VARCHAR(128), nullable=False, index=True, unique=True)
  db              = Column(VARCHAR(120))
  db_version      = Column(VARCHAR(40))
  db_file         = Column(VARCHAR(120))
  program         = Column(VARCHAR(80))
  program_version = Column(VARCHAR(40))
  program_file    = Column(VARCHAR(80))
  parameters      = Column(TEXT)
  module          = Column(VARCHAR(80))
  module_version  = Column(VARCHAR(40))
  gff_source      = Column(VARCHAR(40))
  gff_feature     = Column(VARCHAR(40))

class AnalysisDescription(Base):
  __tablename__ = "analysis_description"

  analysis_id   = Column(SMALLINT(5), ForeignKey("analysis.analysis_id"), primary_key=True)
  description   = Column(TEXT)
  display_label = Column(VARCHAR(255), nullable=False)
  displayable   = Column(TINYINT(1), nullable=False, server_default=text("1"))
  web_data      = Column(TEXT)

class AttribType(Base):
  __tablename__ = "attrib_type"

  attrib_type_id = Column(SMALLINT(5), primary_key=True, autoincrement=True)
  code           = Column(VARCHAR(20), nullable=False, index=True, unique=True, server_default=text("''"))
  name           = Column(VARCHAR(255), nullable=False, server_default=text("''"))
  description    = Column(TEXT)

class DnaAlignFeature(Base):
  __tablename__ = "dna_align_feature"
  __table_args__ = (
    Index("seq_region_idx", "seq_region_id", "analysis_id", "seq_region_start", "score"),
    Index("seq_region_idx_2", "seq_region_id", "seq_region_start")
  )

  dna_align_feature_id = Column(INTEGER(10), primary_key=True, autoincrement=True)
  seq_region_id        = Column(INTEGER(10), ForeignKey("seq_region.seq_region_id"), nullable=False)
  seq_region_start     = Column(INTEGER(10), nullable=False)
  seq_region_end       = Column(INTEGER(10), nullable=False)
  seq_region_strand    = Column(TINYINT(1), nullable=False)
  hit_start            = Column(INTEGER(11), nullable=False)
  hit_end              = Column(INTEGER(11), nullable=False)
  hit_strand           = Column(TINYINT(1), nullable=False)
  hit_name             = Column(VARCHAR(40), nullable=False, index=True)
  analysis_id          = Column(SMALLINT(5), ForeignKey("analysis.analysis_id"), nullable=False, index=True)
  score                = Column(DOUBLE)
  evalue               = Column(DOUBLE)
  perc_ident           = Column(Float)
  cigar_line           = Column(TEXT)
  external_db_id       = Column(INTEGER(10), ForeignKey("external_db.external_db_id"), index=True)
  hcoverage            = Column(DOUBLE)
  align_type           = Column(Enum('ensembl', 'cigar', 'vulgar', 'mdtag'), server_default=text("'ensembl'"))

class DnaAlignFeatureAttrib(Base):
  __tablename__ = "dna_align_feature_attrib"
  __table_args__ = (
    Index("type_val_idx", "attrib_type_id", "value", mysql_length={"value" : 40}),
    Index("val_only_idx", "value", mysql_length=40),
    Index("dna_align_feature_attribx", "dna_align_feature_id", "attrib_type_id", "value", unique=True, mysql_length={"value" : 500})
  )

  dna_align_feature_id = Column(INTEGER(10), ForeignKey("dna_align_feature.dna_align_feature_id"), primary_key=True, index=True)
  attrib_type_id       = Column(SMALLINT(5), ForeignKey("attrib_type.attrib_type_id"), primary_key=True)
  value                = Column(TEXT, primary_key=True)

class Exon(Base):
  __tablename__ = "exon"
  __table_args__ = (
    Index("seq_region_idx", "seq_region_id", "seq_region_start"),
    Index("stable_id_idx", "stable_id", "version")
  )

  exon_id           = Column(INTEGER(10), primary_key=True, autoincrement=True)
  seq_region_id     = Column(INTEGER(10), ForeignKey("seq_region.seq_region_id"), nullable=False)
  seq_region_start  = Column(INTEGER(10), nullable=False)
  seq_region_end    = Column(INTEGER(10), nullable=False)
  seq_region_strand = Column(TINYINT(2), nullable=False)
  phase             = Column(TINYINT(2), nullable=False)
  end_phase         = Column(TINYINT(2), nullable=False)
  is_current        = Column(TINYINT(1), nullable=False, server_default=text("1"))
  is_constitutive   = Column(TINYINT(1), nullable=False, server_default=text("0"))
  stable_id         = Column(VARCHAR(128))
  version           = Column(SMALLINT(5))
  created_date      = Column(DateTime)
  modified_date     = Column(DateTime)

class ExonTranscript(Base):
  __tablename__ = "exon_transcript"

  exon_id       = Column(INTEGER(10), ForeignKey("exon.exon_id"), primary_key=True, index=True)
  transcript_id = Column(INTEGER(10), ForeignKey("transcript.transcript_id"), primary_key=True, index=True)
  rank          = Column(INTEGER(10), primary_key=True)

class Gene(Base):
  __tablename__ = "gene"
  __table_args__ = (
    Index("seq_region_idx", "seq_region_id", "seq_region_start"),
    Index("stable_id_idx", "stable_id", "version")
  )

  gene_id                 = Column(INTEGER(10), primary_key=True, autoincrement=True)
  biotype                 = Column(VARCHAR(40), nullable=False)
  analysis_id             = Column(SMALLINT(5), ForeignKey("analysis.analysis_id"), nullable=False, index=True)
  seq_region_id           = Column(INTEGER(10), ForeignKey("seq_region.seq_region_id"), nullable=False)
  seq_region_start        = Column(INTEGER(10), nullable=False)
  seq_region_end          = Column(INTEGER(10), nullable=False)
  seq_region_strand       = Column(TINYINT(2), nullable=False)
  display_xref_id         = Column(INTEGER(10), ForeignKey("xref.xref_id"), index=True)
  source                  = Column(VARCHAR(40), nullable=False)
  description             = Column(TEXT)
  is_current              = Column(TINYINT(1), nullable=False, server_default=text("1"))
  canonical_transcript_id = Column(INTEGER(10), ForeignKey("transcript.transcript_id"), nullable=False, index=True)
  stable_id               = Column(VARCHAR(128))
  version                 = Column(SMALLINT(5))
  created_date            = Column(DateTime)
  modified_date           = Column(DateTime)

class GeneAttrib(Base):
  __tablename__ = "gene_attrib"
  __table_args__ = (
    Index("type_val_idx", "attrib_type_id", "value", mysql_length={"value" : 40}),
    Index("val_only_idx", "value", mysql_length=40),
    Index("gene_attribx", "gene_id", "attrib_type_id", "value", unique=True, mysql_length={"value" : 500})
  )

  gene_id        = Column(INTEGER(10), ForeignKey("gene.gene_id"), primary_key=True, server_default=text("0"), index=True)
  attrib_type_id = Column(SMALLINT(5), ForeignKey("attrib_type.attrib_type_id"),
      primary_key=True, server_default=text("0"))
  value          = Column(TEXT, primary_key=True)

class ProteinAlignFeature(Base):
  __tablename__ = "protein_align_feature"
  __table_args__ = (
    Index("seq_region_idx", "seq_region_id", "analysis_id", "seq_region_start", "score"),
    Index("seq_region_idx_2", "seq_region_id", "seq_region_start")
  )

  protein_align_feature_id = Column(INTEGER(10), primary_key=True, autoincrement=True)
  seq_region_id            = Column(INTEGER(10), ForeignKey("seq_region.seq_region_id"), nullable=False)
  seq_region_start         = Column(INTEGER(10), nullable=False)
  seq_region_end           = Column(INTEGER(10), nullable=False)
  seq_region_strand        = Column(TINYINT(1), nullable=False, server_default=text("1"))
  hit_start                = Column(INTEGER(10), nullable=False)
  hit_end                  = Column(INTEGER(10), nullable=False)
  hit_name                 = Column(VARCHAR(40), nullable=False, index=True)
  analysis_id              = Column(SMALLINT(5), ForeignKey("analysis.analysis_id"), nullable=False, index=True)
  score                    = Column(DOUBLE)
  evalue                   = Column(DOUBLE)
  perc_ident               = Column(Float)
  cigar_line               = Column(TEXT)
  external_db_id           = Column(INTEGER(10), ForeignKey("external_db.external_db_id"), index=True)
  hcoverage                = Column(DOUBLE)
  align_type               = Column(Enum('ensembl', 'cigar', 'vulgar', 'mdtag'), server_default=text("'ensembl'"))

class ProteinFeature(Base):
  __tablename__ = "protein_feature"
  __table_args__ = (
    Index("aln_idx", "translation_id", "hit_name", "seq_start", "seq_end", "hit_start", "hit_end", "analysis_id", unique=True),
  )

  protein_feature_id = Column(INTEGER(10), primary_key=True, autoincrement=True)
  translation_id     = Column(INTEGER(10), ForeignKey("translation.translation_id"), nullable=False, index=True)
  seq_start          = Column(INTEGER(10), nullable=False)
  seq_end            = Column(INTEGER(10), nullable=False)
  hit_start          = Column(INTEGER(10), nullable=False)
  hit_end            = Column(INTEGER(10), nullable=False)
  hit_name           = Column(VARCHAR(40), nullable=False, index=True)
  analysis_id        = Column(SMALLINT(5), ForeignKey("analysis.analysis_id"), nullable=False, index=True)
  score              = Column(DOUBLE)
  evalue             = Column(DOUBLE)
  perc_ident         = Column(Float)
  external_data      = Column(TEXT)
  hit_description    = Column(TEXT)
  cigar_line         = Column(TEXT)
  align_type         = Column(Enum('ensembl', 'cigar', 'cigarplus', 'vulgar', 'mdtag'))

class SupportingFeature(Base):
  __tablename__ = "supporting_feature"
  __table_args__ = (
    Index("all_idx", "exon_id", "feature_type", "feature_id", unique=True),
    Index("feature_idx", "feature_type", "feature_id")
  )

  exon_id      = Column(INTEGER(10), ForeignKey("exon.exon_id"), primary_key=True, server_default=text("0"))
  feature_type = Column(Enum('dna_align_feature', 'protein_align_feature'), primary_key=True)
  feature_id   = Column(INTEGER(10), primary_key=True, server_default=text("0"))

class Transcript(Base):
  __tablename__ = "transcript"
  __table_args__ = (
    Index("seq_region_idx", "seq_region_id", "seq_region_start"),
    Index("stable_id_idx", "stable_id", "version")
  )

  transcript_id            = Column(INTEGER(10), primary_key=True, autoincrement=True)
  gene_id                  = Column(INTEGER(10), ForeignKey("gene.gene_id"), index=True)
  analysis_id              = Column(SMALLINT(5), ForeignKey("analysis.analysis_id"), nullable=False, index=True)
  seq_region_id            = Column(INTEGER(10), ForeignKey("seq_region.seq_region_id"), nullable=False)
  seq_region_start         = Column(INTEGER(10), nullable=False)
  seq_region_end           = Column(INTEGER(10), nullable=False)
  seq_region_strand        = Column(TINYINT(2), nullable=False)
  display_xref_id          = Column(INTEGER(10), ForeignKey("xref.xref_id"), index=True)
  source                   = Column(VARCHAR(40), nullable=False, server_default=text("'ensembl'"))
  biotype                  = Column(VARCHAR(40), nullable=False)
  description              = Column(TEXT)
  is_current               = Column(TINYINT(1), nullable=False, server_default=text("1"))
  canonical_translation_id = Column(INTEGER(10), ForeignKey("translation.translation_id"), index=True, unique=True)
  stable_id                = Column(VARCHAR(128))
  version                  = Column(SMALLINT(5))
  created_date             = Column(DateTime)
  modified_date            = Column(DateTime)

class TranscriptAttrib(Base):
  __tablename__ = "transcript_attrib"
  __table_args__ = (
    Index("type_val_idx", "attrib_type_id", "value", mysql_length={"value" : 40}),
    Index("val_only_idx", "value", mysql_length=40),
    Index("transcript_attribx", "transcript_id", "attrib_type_id", "value", unique=True, mysql_length={"value" : 500})
  )

  transcript_id  = Column(INTEGER(10), ForeignKey("transcript.transcript_id"), primary_key=True, server_default=text("0"), index=True)
  attrib_type_id = Column(SMALLINT(5), ForeignKey("attrib_type.attrib_type_id"),
      primary_key=True, server_default=text("0"))
  value          = Column(TEXT, primary_key=True)

class TranscriptSupportingFeature(Base):
  __tablename__ = "transcript_supporting_feature"
  __table_args__ = (
    Index("feature_idx", "feature_type", "feature_id"),
    Index("all_idx", "transcript_id", "feature_type", "feature_id", unique=True)
  )

  transcript_id = Column(INTEGER(10), ForeignKey("transcript.transcript_id"), primary_key=True, server_default=text("0"))
  feature_type  = Column(Enum('dna_align_feature', 'protein_align_feature'), primary_key=True)
  feature_id    = Column(INTEGER(10), primary_key=True, server_default=text("0"))

class Translation(Base):
  __tablename__ = "translation"
  __table_args__ = (
    Index("stable_id_idx", "stable_id", "version"),
  )

  translation_id = Column(INTEGER(10), primary_key=True, autoincrement=True)
  transcript_id  = Column(INTEGER(10), ForeignKey("transcript.transcript_id"), nullable=False, index=True)
  seq_start      = Column(INTEGER(10), nullable=False)
  start_exon_id  = Column(INTEGER(10), ForeignKey("exon.exon_id"), nullable=False)
  seq_end        = Column(INTEGER(10), nullable=False)
  end_exon_id    = Column(INTEGER(10), ForeignKey("exon.exon_id"), nullable=False)
  stable_id      = Column(VARCHAR(128))
  version        = Column(SMALLINT(5))
  created_date   = Column(DateTime)
  modified_date  = Column(DateTime)

class TranslationAttrib(Base):
  __tablename__ = "translation_attrib"
  __table_args__ = (
    Index("type_val_idx", "attrib_type_id", "value", mysql_length={"value" : 40}),
    Index("val_only_idx", "value", mysql_length=40),
    Index("translation_attribx", "translation_id", "attrib_type_id", "value", unique=True, mysql_length={"value" : 500})
  )

  translation_id = Column(INTEGER(10), ForeignKey("translation.translation_id"), primary_key=True, server_default=text("0"), index=True)
  attrib_type_id = Column(SMALLINT(5), ForeignKey("attrib_type.attrib_type_id"),
      primary_key=True, server_default=text("0"))
  value          = Column(TEXT, primary_key=True)

class DensityFeature(Base):
  __tablename__ = "density_feature"
  __table_args__ = (
    Index("seq_region_idx", "density_type_id", "seq_region_id", "seq_region_start"),
  )

  density_feature_id = Column(INTEGER(10), primary_key=True, autoincrement=True)
  density_type_id    = Column(INTEGER(10), ForeignKey("density_type.density_type_id"), nullable=False)
  seq_region_id      = Column(INTEGER(10), ForeignKey("seq_region.seq_region_id"), nullable=False, index=True)
  seq_region_start   = Column(INTEGER(10), nullable=False)
  seq_region_end     = Column(INTEGER(10), nullable=False)
  density_value      = Column(Float, nullable=False)

class DensityType(Base):
  __tablename__ = "density_type"
  __table_args__ = (
    Index("analysis_idx", "analysis_id", "block_size", "region_features", unique=True),
  )

  density_type_id = Column(INTEGER(10), primary_key=True, autoincrement=True)
  analysis_id     = Column(SMALLINT(5), ForeignKey("analysis.analysis_id"), nullable=False)
  block_size      = Column(INTEGER(11), nullable=False)
  region_features = Column(INTEGER(11), nullable=False)
  value_type      = Column(Enum('sum', 'ratio'), nullable=False)

class Ditag(Base):
  __tablename__ = "ditag"

  ditag_id  = Column(INTEGER(10), primary_key=True, autoincrement=True)
  name      = Column(VARCHAR(30), nullable=False)
  tag_type  = Column("type", VARCHAR(30), nullable=False)
  tag_count = Column(SMALLINT(6), nullable=False, server_default=text("1"))
  sequence  = Column(TINYTEXT, nullable=False)

class DitagFeature(Base):
  __tablename__ = "ditag_feature"
  __table_args__ = (
    Index("seq_region_idx", "seq_region_id", "seq_region_start", "seq_region_end"),
  )

  ditag_feature_id  = Column(INTEGER(10), primary_key=True, autoincrement=True)
  ditag_id          = Column(INTEGER(10), ForeignKey("ditag.ditag_id"), nullable=False, index=True, server_default=text("0"))
  ditag_pair_id     = Column(INTEGER(10), nullable=False, index=True, server_default=text("0"))
  seq_region_id     = Column(INTEGER(10), ForeignKey("seq_region.seq_region_id"), nullable=False, server_default=text("0"))
  seq_region_start  = Column(INTEGER(10), nullable=False, server_default=text("0"))
  seq_region_end    = Column(INTEGER(10), nullable=False, server_default=text("0"))
  seq_region_strand = Column(TINYINT(1), nullable=False, server_default=text("0"))
  analysis_id       = Column(SMALLINT(5), ForeignKey("analysis.analysis_id"), nullable=False, server_default=text("0"))
  hit_start         = Column(INTEGER(10), nullable=False, server_default=text("0"))
  hit_end           = Column(INTEGER(10), nullable=False, server_default=text("0"))
  hit_strand        = Column(TINYINT(1), nullable=False, server_default=text("0"))
  cigar_line        = Column(TINYTEXT, nullable=False)
  ditag_side        = Column(Enum('F', 'L', 'R'), nullable=False)

class IntronSupportingEvidence(Base):
  __tablename__ = "intron_supporting_evidence"
  __table_args__ = (
    Index("intron_all_idx", "analysis_id", "analysis_id", "seq_region_id", "seq_region_start", "seq_region_end", "seq_region_strand", "hit_name", unique=True),
    Index("seq_region_idx", "seq_region_id", "seq_region_start")
  )

  intron_supporting_evidence_id = Column(INTEGER(10), primary_key=True, autoincrement=True)
  analysis_id                   = Column(SMALLINT(5), ForeignKey("analysis.analysis_id"), nullable=False)
  seq_region_id                 = Column(INTEGER(10), ForeignKey("seq_region.seq_region_id"), nullable=False)
  seq_region_start              = Column(INTEGER(10), nullable=False)
  seq_region_end                = Column(INTEGER(10), nullable=False)
  seq_region_strand             = Column(TINYINT(2), nullable=False)
  hit_name                      = Column(VARCHAR(100), nullable=False)
  score                         = Column(DECIMAL(10, 3))
  score_type                    = Column(Enum('NONE', 'DEPTH'), server_default=text("'NONE'"))
  is_splice_canonical           = Column(TINYINT(1), nullable=False, server_default=text("0"))

class Map(Base):
  __tablename__ = "map"

  map_id = Column(INTEGER(10), primary_key=True, autoincrement=True)
  map_name = Column(VARCHAR(30), nullable=False)

class Marker(Base):
  __tablename__ = "marker"
  __table_args__ = (
    Index("marker_idx", "marker_id", "priority"),
  )

  marker_id                 = Column(INTEGER(10), primary_key=True, autoincrement=True)
  display_marker_synonym_id = Column(INTEGER(10), ForeignKey("marker_synonym.marker_synonym_id"), index=True)
  left_primer               = Column(VARCHAR(100), nullable=False)
  right_primer              = Column(VARCHAR(100), nullable=False)
  min_primer_dist           = Column(INTEGER(10), nullable=False)
  max_primer_dist           = Column(INTEGER(10), nullable=False)
  priority                  = Column(INTEGER(11))
  marker_type               = Column("type", Enum('est', 'microsatellite'))

class MarkerFeature(Base):
  __tablename__ = "marker_feature"
  __table_args__ = (
    Index("seq_region_idx", "seq_region_id", "seq_region_start"),
  )

  marker_feature_id = Column(INTEGER(10), primary_key=True, autoincrement=True)
  marker_id         = Column(INTEGER(10), ForeignKey("marker.marker_id"), nullable=False)
  seq_region_id     = Column(INTEGER(10), ForeignKey("seq_region.seq_region_id"), nullable=False)
  seq_region_start  = Column(INTEGER(10), nullable=False)
  seq_region_end    = Column(INTEGER(10), nullable=False)
  analysis_id       = Column(SMALLINT(5), ForeignKey("analysis.analysis_id"), nullable=False, index=True)
  map_weight        = Column(INTEGER(10))

class MarkerMapLocation(Base):
  __tablename__ = "marker_map_location"
  __table_args__ = (
    Index("map_idx", "map_id", "chromosome_name", "position"),
  )

  marker_id         = Column(INTEGER(10), ForeignKey("marker.marker_id"), primary_key=True)
  map_id            = Column(INTEGER(10), ForeignKey("map.map_id"), primary_key=True)
  chromosome_name   = Column(VARCHAR(15), nullable=False)
  marker_synonym_id = Column(INTEGER(10), ForeignKey("marker_synonym.marker_synonym_id"), nullable=False)
  position          = Column(VARCHAR(15), nullable=False)
  lod_score         = Column(DOUBLE)

class MarkerSynonym(Base):
  __tablename__ = "marker_synonym"
  __table_args__ = (
    Index("marker_synonym_idx", "marker_synonym_id", "name"),
  )

  marker_synonym_id = Column(INTEGER(10), primary_key=True, autoincrement=True)
  marker_id         = Column(INTEGER(10), ForeignKey("marker.marker_id"), nullable=False, index=True)
  source            = Column(VARCHAR(20))
  name              = Column(VARCHAR(50))

class MiscAttrib(Base):
  __tablename__ = "misc_attrib"
  __table_args__ = (
    Index("type_val_idx", "attrib_type_id", "value", mysql_length={"value" : 40}),
    Index("val_only_idx", "value", mysql_length=40),
    Index("misc_attribx", "misc_feature_id", "attrib_type_id", "value", unique=True, mysql_length={"value" : 500})
  )

  misc_feature_id = Column(INTEGER(10), ForeignKey("misc_feature.misc_feature_id"), primary_key=True, index=True, server_default=text("0"))
  attrib_type_id  = Column(SMALLINT(5), ForeignKey("attrib_type.attrib_type_id"), primary_key=True, server_default=text("0"))
  value           = Column(TEXT, primary_key=True, index=True)

class MiscFeature(Base):
  __tablename__ = "misc_feature"
  __table_args__ = (
    Index("seq_region_idx", "seq_region_id", "seq_region_start"),
  )

  misc_feature_id   = Column(INTEGER(10), primary_key=True, autoincrement=True)
  seq_region_id     = Column(INTEGER(10), ForeignKey("seq_region.seq_region_id"), nullable=False, server_default=text("0"))
  seq_region_start  = Column(INTEGER(10), nullable=False, server_default=text("0"))
  seq_region_end    = Column(INTEGER(10), nullable=False, server_default=text("0"))
  seq_region_strand = Column(TINYINT(4), nullable=False, server_default=text("0"))

class MiscFeatureMiscSet(Base):
  __tablename__ = "misc_feature_misc_set"
  __table_args__ = (
    Index("reverse_idx", "misc_set_id", "misc_feature_id"),
  )

  misc_feature_id = Column(INTEGER(10), ForeignKey("misc_feature.misc_feature_id"), primary_key=True, server_default=text("0"))
  misc_set_id     = Column(SMALLINT(5), ForeignKey("misc_set.misc_set_id"), primary_key=True, server_default=text("0"))

class MiscSet(Base):
  __tablename__ = "misc_set"

  misc_set_id = Column(SMALLINT(5), primary_key=True, autoincrement=True)
  code        = Column(VARCHAR(25), nullable=False, index=True, unique=True, server_default=text("''"))
  name        = Column(VARCHAR(255), nullable=False, server_default=text("''"))
  description = Column(TEXT, nullable=False)
  max_length  = Column(INTEGER(10), nullable=False)

class PredictionExon(Base):
  __tablename__ = "prediction_exon"
  __table_args__ = (
    Index("seq_region_idx", "seq_region_id", "seq_region_start"),
  )

  prediction_exon_id       = Column(INTEGER(10), primary_key=True, autoincrement=True)
  prediction_transcript_id = Column(INTEGER(10), ForeignKey("prediction_transcript.prediction_transcript_id"), nullable=False, index=True)
  exon_rank                = Column(SMALLINT(5), nullable=False)
  seq_region_id            = Column(INTEGER(10), ForeignKey("seq_region.seq_region_id"), nullable=False)
  seq_region_start         = Column(INTEGER(10), nullable=False)
  seq_region_end           = Column(INTEGER(10), nullable=False)
  seq_region_strand        = Column(TINYINT(4), nullable=False)
  start_phase              = Column(TINYINT(4), nullable=False)
  score                    = Column(DOUBLE)
  p_value                  = Column(DOUBLE)

class PredictionTranscript(Base):
  __tablename__ = "prediction_transcript"
  __table_args__ = (
    Index("seq_region_idx", "seq_region_id", "seq_region_start"),
  )

  prediction_transcript_id = Column(INTEGER(10), primary_key=True, autoincrement=True)
  seq_region_id            = Column(INTEGER(10), ForeignKey("seq_region.seq_region_id"), nullable=False)
  seq_region_start         = Column(INTEGER(10), nullable=False)
  seq_region_end           = Column(INTEGER(10), nullable=False)
  seq_region_strand        = Column(TINYINT(4), nullable=False)
  analysis_id              = Column(SMALLINT(5), ForeignKey("analysis.analysis_id"), nullable=False, index=True)
  display_label            = Column(VARCHAR(255))

class RepeatConsensus(Base):
  __tablename__ = "repeat_consensus"
  __table_args__ = (
    Index("consensus", "repeat_consensus", mysql_length=10),
  )

  repeat_consensus_id = Column(INTEGER(10), primary_key=True, autoincrement=True)
  repeat_name         = Column(VARCHAR(255), nullable=False, index=True)
  repeat_class        = Column(VARCHAR(100), nullable=False, index=True)
  repeat_type         = Column(VARCHAR(40), nullable=False, index=True)
  repeat_consensus    = Column(TEXT)

class RepeatFeature(Base):
  __tablename__ = "repeat_feature"
  __table_args__ = (
    Index("seq_region_idx", "seq_region_id", "seq_region_start"),
  )

  repeat_feature_id   = Column(INTEGER(10), primary_key=True, autoincrement=True)
  seq_region_id       = Column(INTEGER(10), ForeignKey("seq_region.seq_region_id"), nullable=False)
  seq_region_start    = Column(INTEGER(10), nullable=False)
  seq_region_end      = Column(INTEGER(10), nullable=False)
  seq_region_strand   = Column(TINYINT(1), nullable=False, server_default=text("1"))
  repeat_start        = Column(INTEGER(10), nullable=False)
  repeat_end          = Column(INTEGER(10), nullable=False)
  repeat_consensus_id = Column(INTEGER(10), ForeignKey("repeat_consensus.repeat_consensus_id"), nullable=False, index=True)
  analysis_id         = Column(SMALLINT(5), ForeignKey("analysis.analysis_id"), nullable=False, index=True)
  score               = Column(DOUBLE)

class SimpleFeature(Base):
  __tablename__ = "simple_feature"
  __table_args__ = (
    Index("seq_region_idx", "seq_region_id", "seq_region_start"),
  )

  simple_feature_id = Column(INTEGER(10), primary_key=True, autoincrement=True)
  seq_region_id     = Column(INTEGER(10), ForeignKey("seq_region.seq_region_id"), nullable=False)
  seq_region_start  = Column(INTEGER(10), nullable=False)
  seq_region_end    = Column(INTEGER(10), nullable=False)
  seq_region_strand = Column(TINYINT(1), nullable=False)
  display_label     = Column(VARCHAR(255), nullable=False, index=True)
  analysis_id       = Column(SMALLINT(5), ForeignKey("analysis.analysis_id"), nullable=False, index=True)
  score             = Column(DOUBLE)

class TranscriptIntronSupportingEvidence(Base):
  __tablename__ = "transcript_intron_supporting_evidence"

  transcript_id                 = Column(INTEGER(10), ForeignKey("transcript.transcript_id"), primary_key=True, index=True)
  intron_supporting_evidence_id = Column(INTEGER(10), primary_key=True)
  previous_exon_id              = Column(INTEGER(10), nullable=False)
  next_exon_id                  = Column(INTEGER(10), nullable=False)

# class GeneArchive(Base):
#   __tablename__ = "gene_archive"

#   gene_stable_id        = Column(VARCHAR(128), nullable=False)
#   gene_version          = Column(SMALLINT(6), nullable=False, server_default=text("1"))
#   transcript_stable_id  = Column(VARCHAR(128), nullable=False)
#   transcript_version    = Column(SMALLINT(6), nullable=False, server_default=text("1"))
#   translation_stable_id = Column(VARCHAR(128))
#   translation_version   = Column(SMALLINT(6), nullable=False, server_default=text("1"))
#   peptide_archive_id    = Column(INTEGER(10), index=True)
#   mapping_session_id    = Column(INTEGER(10), ForeignKey("mapping_session.mapping_session_id"), nullable=False)

#   Index("gene_idx", "gene_stable_id", "gene_version")
#   Index("transcript_idx", "transcript_stable_id", "transcript_version")
#   Index("translation_idx", "translation_stable_id", "translation_version")

class MappingSession(Base):
  __tablename__ = "mapping_session"

  mapping_session_id = Column(INTEGER(10), primary_key=True, autoincrement=True)
  old_db_name        = Column(VARCHAR(80), nullable=False, server_default=text("''"))
  new_db_name        = Column(VARCHAR(80), nullable=False, server_default=text("''"))
  old_release        = Column(VARCHAR(5), nullable=False, server_default=text("''"))
  new_release        = Column(VARCHAR(5), nullable=False, server_default=text("''"))
  old_assembly       = Column(VARCHAR(80), nullable=False, server_default=text("''"))
  new_assembly       = Column(VARCHAR(80), nullable=False, server_default=text("''"))
  created            = Column(DateTime, nullable=False)

class PeptideArchive(Base):
  __tablename__ = "peptide_archive"

  peptide_archive_id = Column(INTEGER(10), primary_key=True, autoincrement=True)
  md5_checksum       = Column(VARCHAR(32), index=True)
  peptide_seq        = Column(MEDIUMTEXT, nullable=False)

class MappingSet(Base):
  __tablename__ = "mapping_set"
  __table_args__ = (
    Index("mapping_idx", "internal_schema_build", "external_schema_build", unique=True),
  )

  mapping_set_id        = Column(INTEGER(10), primary_key=True)
  internal_schema_build = Column(VARCHAR(20), nullable=False)
  external_schema_build = Column(VARCHAR(20), nullable=False)

class StableIdEvent(Base):
  __tablename__ = "stable_id_event"

  old_stable_id      = Column(VARCHAR(128), primary_key=True, index=True)
  old_version        = Column(SMALLINT(6))
  new_stable_id      = Column(VARCHAR(128), primary_key=True, index=True)
  new_version        = Column(SMALLINT(6))
  mapping_session_id = Column(INTEGER(10), ForeignKey("mapping_session.mapping_session_id"), primary_key=True, server_default=text("0"))
  id_type            = Column("type", Enum('gene', 'transcript', 'translation', 'rnaproduct'), primary_key=True)
  score              = Column(Float, nullable=False, server_default=text("0"))

class SeqRegionMapping(Base):
  __tablename__ = "seq_region_mapping"

  external_seq_region_id = Column(INTEGER(10), primary_key=True)
  internal_seq_region_id = Column(INTEGER(10), primary_key=True)
  mapping_set_id         = Column(INTEGER(10), primary_key=True, index=True)

class AssociatedGroup(Base):
  __tablename__ = "associated_group"

  associated_group_id = Column(INTEGER(10), primary_key=True, autoincrement=True)
  description         = Column(VARCHAR(128))

class AssociatedXref(Base):
  __tablename__ = "associated_xref"
  __table_args__ = (
    Index("object_associated_source_type_idx", "object_xref_id", "xref_id", "source_xref_id", "condition_type", "associated_group_id", unique=True),
  )

  associated_xref_id  = Column(INTEGER(10), primary_key=True, autoincrement=True)
  object_xref_id      = Column(INTEGER(10), ForeignKey("object_xref.object_xref_id"), nullable=False, index=True, server_default=text("0"))
  xref_id             = Column(INTEGER(10), ForeignKey("xref.xref_id"), nullable=False, index=True, server_default=text("0"))
  source_xref_id      = Column(INTEGER(10), index=True)
  condition_type      = Column(VARCHAR(128))
  associated_group_id = Column(INTEGER(10), ForeignKey("associated_group.associated_group_id"), index=True)
  rank                = Column(INTEGER(10), server_default=text("0"))

class DependentXref(Base):
  __tablename__ = "dependent_xref"

  object_xref_id    = Column(INTEGER(10), ForeignKey("object_xref.object_xref_id"), primary_key=True)
  master_xref_id    = Column(INTEGER(10), ForeignKey("xref.xref_id"), nullable=False, index=True)
  dependent_xref_id = Column(INTEGER(10), ForeignKey("xref.xref_id"), nullable=False, index=True)

class ExternalDb(Base):
  __tablename__ = "external_db"
  __table_args__ = (
    Index("db_name_db_release_idx", "db_name", "db_release", unique=True),
  )

  external_db_id     = Column(INTEGER(10), primary_key=True, autoincrement=True)
  db_name            = Column(VARCHAR(100), nullable=False)
  db_release         = Column(VARCHAR(255))
  status             = Column(Enum('KNOWNXREF', 'KNOWN', 'XREF', 'PRED', 'ORTH', 'PSEUDO'), nullable=False)
  priority           = Column(INTEGER(11), nullable=False)
  db_display_name    = Column(VARCHAR(255))
  db_type            = Column("type", Enum('ARRAY', 'ALT_TRANS', 'ALT_GENE', 'MISC', 'LIT', 'PRIMARY_DB_SYNONYM', 'ENSEMBL'), nullable=False)
  secondary_db_name  = Column(VARCHAR(255))
  secondary_db_table = Column(VARCHAR(255))
  description        = Column(TEXT)

class Biotype(Base):
  __tablename__ = "biotype"
  __table_args__ = (
    Index("name_type_idx", "name", "object_type", unique=True),
  )

  biotype_id     = Column(INTEGER(10), primary_key=True, autoincrement=True)
  name           = Column(VARCHAR(64), nullable=False)
  object_type    = Column(Enum('gene', 'transcript'), nullable=False, server_default=text("'gene'"))
  db_type        = Column(SET('cdna', 'core', 'coreexpressionatlas', 'coreexpressionest', 'coreexpressiongnf', 'funcgen', 'otherfeatures', 'rnaseq', 'variation', 'vega', 'presite', 'sangervega'), nullable=False, server_default=text("'core'"))
  attrib_type_id = Column(INTEGER(11))
  description    = Column(TEXT)
  biotype_group  = Column(Enum('coding', 'pseudogene', 'snoncoding', 'lnoncoding', 'mnoncoding', 'LRG', 'undefined', 'no_group'))
  so_acc         = Column(VARCHAR(64))
  so_term        = Column(VARCHAR(1023))

class ExternalSynonym(Base):
  __tablename__ = "external_synonym"

  xref_id = Column(INTEGER(10), ForeignKey("xref.xref_id"), primary_key=True)
  synonym = Column(VARCHAR(100), primary_key=True, index=True)

class IdentityXref(Base):
  __tablename__ = "identity_xref"

  object_xref_id   = Column(INTEGER(10), ForeignKey("object_xref.object_xref_id"), primary_key=True)
  xref_identity    = Column(INTEGER(5))
  ensembl_identity = Column(INTEGER(5))
  xref_start       = Column(INTEGER(11))
  xref_end         = Column(INTEGER(11))
  ensembl_start    = Column(INTEGER(11))
  ensembl_end      = Column(INTEGER(11))
  cigar_line       = Column(TEXT)
  score            = Column(DOUBLE)
  evalue           = Column(DOUBLE)

class Interpro(Base):
  __tablename__ = "interpro"

  interpro_ac = Column(VARCHAR(40), primary_key=True)
  interpro_id = Column("id", VARCHAR(40), primary_key=True, index=True)

class ObjectXref(Base):
  __tablename__ = "object_xref"
  __table_args__ = (
    Index("ensembl_idx", "ensembl_object_type", "ensembl_id"),
    Index("xref_idx", "xref_id", "ensembl_object_type", "ensembl_id", "analysis_id", unique=True)
  )

  object_xref_id      = Column(INTEGER(10), primary_key=True, autoincrement=True)
  ensembl_id          = Column(INTEGER(10), nullable=False)
  ensembl_object_type = Column(Enum('RawContig', 'Transcript', 'Gene', 'Translation', 'Operon', 'OperonTranscript', 'Marker', 'RNAProduct'), nullable=False)
  xref_id             = Column(INTEGER(10), ForeignKey("xref.xref_id"), nullable=False)
  linkage_annotation  = Column(VARCHAR(255))
  analysis_id         = Column(SMALLINT(5), ForeignKey("analysis.analysis_id"), index=True)

class OntologyXref(Base):
  __tablename__ = "ontology_xref"

  object_xref_id = Column(INTEGER(10), ForeignKey("object_xref.object_xref_id"), primary_key=True, index=True, server_default=text("0"))
  source_xref_id = Column(INTEGER(10), ForeignKey("xref.xref_id"), primary_key=True, index=True)
  linkage_type   = Column(VARCHAR(3), primary_key=True)

class UnmappedObject(Base):
  __tablename__ = "unmapped_object"
  __table_args__ = (
    Index("unique_unmapped_obj_idx", "ensembl_id", "ensembl_object_type", "identifier", "unmapped_reason_id", "parent", "external_db_id", unique=True),
    Index("id_idx", "identifier", mysql_length=50),
    Index("anal_exdb_idx", "analysis_id", "external_db_id"),
    Index("ext_db_identifier_idx", "external_db_id", "identifier")
  )

  unmapped_object_id   = Column(INTEGER(10), primary_key=True, autoincrement=True)
  unmapped_object_type = Column("type", Enum('xref', 'cDNA', 'Marker'), nullable=False)
  analysis_id          = Column(SMALLINT(5), ForeignKey("analysis.analysis_id"), nullable=False)
  external_db_id       = Column(INTEGER(10), ForeignKey("external_db.external_db_id"))
  identifier           = Column(VARCHAR(255), nullable=False)
  unmapped_reason_id   = Column(INTEGER(10), ForeignKey("unmapped_reason.unmapped_reason_id"), nullable=False)
  query_score          = Column(DOUBLE)
  target_score         = Column(DOUBLE)
  ensembl_id           = Column(INTEGER(10), server_default=text("0"))
  ensembl_object_type  = Column(Enum('RawContig', 'Transcript', 'Gene', 'Translation'), server_default=text("'RawContig'"))
  parent               = Column(VARCHAR(255))

class UnmappedReason(Base):
  __tablename__ = "unmapped_reason"

  unmapped_reason_id  = Column(INTEGER(10), primary_key=True, autoincrement=True)
  summary_description = Column(VARCHAR(255))
  full_description    = Column(VARCHAR(255))

class Xref(Base):
  __tablename__ = "xref"
  __table_args__ = (
    Index("id_index", "dbprimary_acc", "external_db_id", "info_type", "info_text", "version", unique=True),
  )

  xref_id        = Column(INTEGER(10), primary_key=True, autoincrement=True)
  external_db_id = Column(INTEGER(10), ForeignKey("external_db.external_db_id"), nullable=False)
  dbprimary_acc  = Column(VARCHAR(512), nullable=False)
  display_label  = Column(VARCHAR(512), nullable=False, index=True)
  version        = Column(VARCHAR(10))
  description    = Column(TEXT)
  info_type      = Column(Enum('NONE', 'PROJECTION', 'MISC', 'DEPENDENT', 'DIRECT', 'SEQUENCE_MATCH', 'INFERRED_PAIR', 'PROBE', 'UNMAPPED', 'COORDINATE_OVERLAP', 'CHECKSUM'), nullable=False, index=True, server_default=text("'NONE'"))
  info_text      = Column(VARCHAR(255), nullable=False, server_default=text("''"))

class Operon(Base):
  __tablename__ = "operon"
  __table_args__ = (
    Index("seq_region_idx", "seq_region_id", "seq_region_start"),
    Index("stable_id_idx", "stable_id", "version")
  )

  operon_id         = Column(INTEGER(10), primary_key=True, autoincrement=True)
  seq_region_id     = Column(INTEGER(10), ForeignKey("seq_region.seq_region_id"), nullable=False)
  seq_region_start  = Column(INTEGER(10), nullable=False)
  seq_region_end    = Column(INTEGER(10), nullable=False)
  seq_region_strand = Column(TINYINT(2), nullable=False)
  display_label     = Column(VARCHAR(255), index=True)
  analysis_id       = Column(SMALLINT(5), ForeignKey("analysis.analysis_id"), nullable=False)
  stable_id         = Column(VARCHAR(128))
  version           = Column(SMALLINT(5))
  created_date      = Column(DateTime)
  modified_date     = Column(DateTime)

class OperonTranscript(Base):
  __tablename__ = "operon_transcript"
  __table_args__ = (
    Index("stable_id_idx", "stable_id", "version"),
    Index("seq_region_idx", "seq_region_id", "seq_region_start")
  )

  operon_transcript_id = Column(INTEGER(10), primary_key=True, autoincrement=True)
  seq_region_id        = Column(INTEGER(10), ForeignKey("seq_region.seq_region_id"), nullable=False)
  seq_region_start     = Column(INTEGER(10), nullable=False)
  seq_region_end       = Column(INTEGER(10), nullable=False)
  seq_region_strand    = Column(TINYINT(2), nullable=False)
  operon_id            = Column(INTEGER(10), ForeignKey("operon.operon_id"), nullable=False, index=True)
  display_label        = Column(VARCHAR(255))
  analysis_id          = Column(SMALLINT(5), ForeignKey("analysis.analysis_id"), nullable=False)
  stable_id            = Column(VARCHAR(128))
  version              = Column(SMALLINT(5))
  created_date         = Column(DateTime)
  modified_date        = Column(DateTime)

class OperonTranscriptGene(Base):
  __tablename__ = "operon_transcript_gene"

  operon_transcript_id = Column(INTEGER(10), ForeignKey("operon_transcript.operon_transcript_id"), primary_key=True)
  gene_id              = Column(INTEGER(10), ForeignKey("gene.gene_id"), primary_key=True)

class Rnaproduct(Base):
  __tablename__ = "rnaproduct"
  __table_args__ = (
    Index("stable_id_idx", "stable_id", "version"),
  )

  rnaproduct_id      = Column(INTEGER(10), primary_key=True, autoincrement=True)
  rnaproduct_type_id = Column(SMALLINT(5), ForeignKey("rnaproduct_type.rnaproduct_type_id"), nullable=False)
  transcript_id      = Column(INTEGER(10), ForeignKey("transcript.transcript_id"), nullable=False, index=True)
  seq_start          = Column(INTEGER(10), nullable=False)
  start_exon_id      = Column(INTEGER(10), ForeignKey("exon.exon_id"))
  seq_end            = Column(INTEGER(10), nullable=False)
  end_exon_id        = Column(INTEGER(10), ForeignKey("exon.exon_id"))
  stable_id          = Column(VARCHAR(128))
  version            = Column(SMALLINT(5))
  created_date       = Column(DateTime)
  modified_date      = Column(DateTime)

class RnaproductAttrib(Base):
  __tablename__ = "rnaproduct_attrib"
  __table_args__ = (
    Index("type_val_idx", "attrib_type_id", "value", mysql_length={"value" : 40}),
    Index("val_only_idx", "value", mysql_length=40),
    Index("rnaproduct_attribx", "rnaproduct_id", "attrib_type_id", "value", unique=True, mysql_length={"value" : 500})
  )

  rnaproduct_id  = Column(INTEGER(10), ForeignKey("rnaproduct.rnaproduct_id"), primary_key=True, index=True)
  attrib_type_id = Column(SMALLINT(5), ForeignKey("attrib_type.attrib_type_id"), primary_key=True)
  value          = Column(TEXT, primary_key=True)

class RnaproductType(Base):
  __tablename__ = "rnaproduct_type"

  rnaproduct_type_id = Column(SMALLINT(5), primary_key=True, autoincrement=True)
  code               = Column(VARCHAR(20), nullable=False, index=True, unique=True, server_default=text("''"))
  name               = Column(VARCHAR(255), nullable=False, server_default=text("''"))
  description        = Column(TEXT)
