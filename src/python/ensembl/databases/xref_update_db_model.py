from sqlalchemy import (Column, Index, Enum, DateTime, text)
from sqlalchemy.dialects.mysql import (INTEGER, VARCHAR, BOOLEAN, TEXT, MEDIUMTEXT, TINYINT, CHAR, SMALLINT, DOUBLE)
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()

class Xref(Base):
  __tablename__ = "xref"
  __table_args__ = (
    Index("acession_idx", "accession", "source_id", "species_id", "label", unique=True, mysql_length={'accession': 100, 'label': 100}),
    Index("species_source_idx", "species_id", "source_id")
  )

  xref_id     = Column(INTEGER(10, unsigned=True), primary_key=True, autoincrement=True)
  accession   = Column(VARCHAR(255), nullable=False)
  version     = Column(INTEGER(10, unsigned=True))
  label       = Column(VARCHAR(255))
  description = Column(TEXT)
  source_id   = Column(INTEGER(10, unsigned=True), nullable=False)
  species_id  = Column(INTEGER(10, unsigned=True), nullable=False, primary_key=True)
  info_type   = Column(Enum('NONE', 'PROJECTION', 'MISC', 'DEPENDENT', 'DIRECT', 'SEQUENCE_MATCH', 'INFERRED_PAIR', 'PROBE', 'UNMAPPED', 'COORDINATE_OVERLAP', 'CHECKSUM'), nullable=False, server_default=text("'NONE'"))
  info_text   = Column(VARCHAR(255), nullable=False, server_default=text("''"))
  dumped      = Column(Enum('MAPPED', 'NO_DUMP_ANOTHER_PRIORITY', 'UNMAPPED_NO_MAPPING', 'UNMAPPED_NO_MASTER', 'UNMAPPED_MASTER_FAILED', 'UNMAPPED_NO_STABLE_ID', 'UNMAPPED_INTERPRO'))

class PrimaryXref(Base):
  __tablename__ = "primary_xref"

  xref_id       = Column(INTEGER(10, unsigned=True), primary_key=True)
  sequence      = Column(MEDIUMTEXT)
  sequence_type = Column(Enum('dna', 'peptide'))
  status        = Column(Enum('experimental', 'predicted'))

class DependentXref(Base):
  __tablename__ = "dependent_xref"

  object_xref_id     = Column(INTEGER(10, unsigned=True), nullable=False, index=True)
  master_xref_id     = Column(INTEGER(10, unsigned=True), index=True, primary_key=True)
  dependent_xref_id  = Column(INTEGER(10, unsigned=True), index=True, primary_key=True)
  linkage_annotation = Column(VARCHAR(255))
  linkage_source_id  = Column(INTEGER(10, unsigned=True), nullable=False, primary_key=True)

class Synonym(Base):
  __tablename__ = "synonym"

  xref_id = Column(INTEGER(10, unsigned=True), index=True, primary_key=True)
  synonym = Column(VARCHAR(255), index=True, primary_key=True)

class Source(Base):
  __tablename__ = "source"

  source_id            = Column(INTEGER(10, unsigned=True), primary_key=True, autoincrement=True)
  name                 = Column(VARCHAR(255), nullable=False, index=True)
  status               = Column(Enum('KNOWN', 'XREF', 'PRED', 'ORTH', 'PSEUDO', 'LOWEVIDENCE', 'NOIDEA'), nullable=False, server_default=text("'NOIDEA'"))
  source_release       = Column(VARCHAR(255))
  ordered              = Column(INTEGER(10, unsigned=True), nullable=False)
  priority             = Column(INTEGER(5, unsigned=True), server_default=text("1"))
  priority_description = Column(VARCHAR(40), server_default=text("''"))

class SourceURL(Base):
  __tablename__ = "source_url"

  source_url_id = Column(INTEGER(10, unsigned=True), primary_key=True, autoincrement=True)
  source_id     = Column(INTEGER(10, unsigned=True), nullable=False, index=True)
  species_id    = Column(INTEGER(10, unsigned=True), nullable=False)
  parser        = Column(VARCHAR(255))

class SourceMappingMethod(Base):
  __tablename__ = "source_mapping_method"

  source_id = Column(INTEGER(10, unsigned=True), primary_key=True)
  method    = Column(VARCHAR(255), primary_key=True)

class GeneDirectXref(Base):
  __tablename__ = "gene_direct_xref"

  general_xref_id   = Column(INTEGER(10, unsigned=True), index=True, primary_key=True)
  ensembl_stable_id = Column(VARCHAR(255), index=True, primary_key=True)
  linkage_xref      = Column(VARCHAR(255))

class TranscriptDirectXref(Base):
  __tablename__ = "transcript_direct_xref"

  general_xref_id   = Column(INTEGER(10, unsigned=True), index=True, primary_key=True)
  ensembl_stable_id = Column(VARCHAR(255), index=True, primary_key=True)
  linkage_xref      = Column(VARCHAR(255))

class TranslationDirectXref(Base):
  __tablename__ = "translation_direct_xref"

  general_xref_id   = Column(INTEGER(10, unsigned=True), index=True, primary_key=True)
  ensembl_stable_id = Column(VARCHAR(255), index=True, primary_key=True)
  linkage_xref      = Column(VARCHAR(255))

class Species(Base):
  __tablename__ = "species"

  species_id  = Column(INTEGER(10, unsigned=True), nullable=False, index=True, primary_key=True)
  taxonomy_id = Column(INTEGER(10, unsigned=True), nullable=False, index=True, primary_key=True)
  name        = Column(VARCHAR(255), nullable=False, index=True)
  aliases     = Column(VARCHAR(255))

class Pairs(Base):
  __tablename__ = "pairs"

  pair_id    = Column(INTEGER(10, unsigned=True), primary_key=True, autoincrement=True)
  source_id  = Column(INTEGER(10, unsigned=True), nullable=False)
  accession1 = Column(VARCHAR(255), nullable=False, index=True)
  accession2 = Column(VARCHAR(255), nullable=False, index=True)

class CoordinateXref(Base):
  __tablename__ = "coordinate_xref"
  __table_args__ = (
    Index("start_pos_idx", "species_id", "chromosome", "strand", "txStart"),
    Index("end_pos_idx", "species_id", "chromosome", "strand", "txEnd")
  )

  coord_xref_id = Column(INTEGER(10, unsigned=True), primary_key=True, autoincrement=True)
  source_id     = Column(INTEGER(10, unsigned=True), nullable=False)
  species_id    = Column(INTEGER(10, unsigned=True), nullable=False)
  accession     = Column(VARCHAR(255), nullable=False)
  chromosome    = Column(VARCHAR(255), nullable=False)
  strand        = Column(TINYINT(2), nullable=False)
  txStart       = Column(INTEGER(10), nullable=False)
  txEnd         = Column(INTEGER(10), nullable=False)
  cdsStart      = Column(INTEGER(10))
  cdsEnd        = Column(INTEGER(10))
  exonStarts    = Column(TEXT, nullable=False)
  exonEnds      = Column(TEXT, nullable=False)

class ChecksumXref(Base):
  __tablename__ = "checksum_xref"
  __table_args__ = (
    Index("checksum_idx", "checksum", mysql_length=10),
  )

  checksum_xref_id = Column(INTEGER(10, unsigned=True), primary_key=True, autoincrement=True)
  source_id        = Column(INTEGER(10, unsigned=True), nullable=False)
  accession        = Column(CHAR(14), nullable=False)
  checksum         = Column(CHAR(32), nullable=False)

class Mapping(Base):
  __tablename__ = "mapping"

  job_id                = Column(INTEGER(10, unsigned=True), primary_key=True)
  type                  = Column(Enum('dna', 'peptide', 'UCSC'))
  command_line          = Column(TEXT)
  percent_query_cutoff  = Column(INTEGER(10, unsigned=True))
  percent_target_cutoff = Column(INTEGER(10, unsigned=True))
  method                = Column(VARCHAR(255))
  array_size            = Column(INTEGER(10, unsigned=True))

class MappingJobs(Base):
  __tablename__ = "mapping_jobs"

  mapping_job_id    = Column(INTEGER(10), primary_key=True, autoincrement=True)
  root_dir          = Column(TEXT)
  map_file          = Column(VARCHAR(255))
  status            = Column(Enum('SUBMITTED', 'FAILED', 'SUCCESS'))
  out_file          = Column(VARCHAR(255))
  err_file          = Column(VARCHAR(255))
  array_number      = Column(INTEGER(10, unsigned=True))
  job_id            = Column(INTEGER(10, unsigned=True))
  failed_reason     = Column(VARCHAR(255))
  object_xref_start = Column(INTEGER(10, unsigned=True))
  object_xref_end   = Column(INTEGER(10, unsigned=True))

class GeneTranscriptTranslation(Base):
  __tablename__ = "gene_transcript_translation"

  gene_id        = Column(INTEGER(10, unsigned=True), nullable=False, index=True)
  transcript_id  = Column(INTEGER(10, unsigned=True), primary_key=True)
  translation_id = Column(INTEGER(10, unsigned=True), index=True)

class ProcessStatus(Base):
  __tablename__ = "process_status"

  id     = Column(INTEGER(10, unsigned=True), primary_key=True, autoincrement=True)
  status = Column(Enum('xref_created', 'parsing_started', 'parsing_finished', 'alt_alleles_added', 'xref_fasta_dumped', 'core_fasta_dumped', 'core_data_loaded', 'mapping_submitted', 'mapping_finished', 'mapping_processed', 'direct_xrefs_parsed', 'prioritys_flagged', 'processed_pairs', 'biomart_test_finished', 'source_level_move_finished', 'alt_alleles_processed', 'official_naming_done', 'checksum_xrefs_started', 'checksum_xrefs_finished', 'coordinate_xrefs_started', 'coordinate_xref_finished', 'tests_started', 'tests_failed', 'tests_finished', 'core_loaded', 'display_xref_done', 'gene_description_done'))
  date   = Column(DateTime, nullable=False)

class DisplayXrefPriority(Base):
  __tablename__ = "display_xref_priority"

  ensembl_object_type = Column(VARCHAR(100), primary_key=True)
  source_id           = Column(INTEGER(10, unsigned=True), primary_key=True)
  priority            = Column(SMALLINT(unsigned=True), nullable=False)

class GeneDescPriority(Base):
  __tablename__ = "gene_desc_priority"

  source_id = Column(INTEGER(10, unsigned=True), primary_key=True)
  priority  = Column(SMALLINT(unsigned=True), nullable=False)

class AltAllele(Base):
  __tablename__ = "alt_allele"

  alt_allele_id = Column(INTEGER(10, unsigned=True), autoincrement=True, primary_key=True)
  gene_id       = Column(INTEGER(10, unsigned=True), index=True, primary_key=True)
  is_reference  = Column(INTEGER(2, unsigned=True), server_default=text("0"))

class GeneStableId(Base):
  __tablename__ = "gene_stable_id"

  internal_id     = Column(INTEGER(10, unsigned=True), nullable=False, index=True)
  stable_id       = Column(VARCHAR(128), primary_key=True)
  display_xref_id = Column(INTEGER(10, unsigned=True))
  desc_set        = Column(INTEGER(10, unsigned=True), server_default=text("0"))

class TranscriptStableId(Base):
  __tablename__ = "transcript_stable_id"

  internal_id     = Column(INTEGER(10, unsigned=True), nullable=False, index=True)
  stable_id       = Column(VARCHAR(128), primary_key=True)
  display_xref_id = Column(INTEGER(10, unsigned=True))
  biotype         = Column(VARCHAR(40), nullable=False)

class TranslationStableId(Base):
  __tablename__ = "translation_stable_id"

  internal_id = Column(INTEGER(10, unsigned=True), primary_key=True)
  stable_id   = Column(VARCHAR(128), nullable=False, index=True)

class ObjectXref(Base):
  __tablename__ = "object_xref"
  __table_args__ = (
    Index("unique_idx", "ensembl_object_type", "ensembl_id", "xref_id", "ox_status", "master_xref_id", unique=True),
    Index("oxref_idx", "object_xref_id", "xref_id", "ensembl_object_type", "ensembl_id"),
    Index("xref_idx", "xref_id", "ensembl_object_type")
  )

  object_xref_id      = Column(INTEGER(10, unsigned=True), primary_key=True, autoincrement=True)
  ensembl_id          = Column(INTEGER(10, unsigned=True), nullable=False)
  ensembl_object_type = Column(Enum('RawContig', 'Transcript', 'Gene', 'Translation'), nullable=False)
  xref_id             = Column(INTEGER(10, unsigned=True), nullable=False)
  linkage_annotation  = Column(VARCHAR(255))
  linkage_type        = Column(Enum('PROJECTION', 'MISC', 'DEPENDENT', 'DIRECT', 'SEQUENCE_MATCH', 'INFERRED_PAIR', 'PROBE', 'UNMAPPED', 'COORDINATE_OVERLAP', 'CHECKSUM'))
  ox_status           = Column(Enum('DUMP_OUT', 'FAILED_PRIORITY', 'FAILED_CUTOFF', 'NO_DISPLAY', 'MULTI_DELETE'), nullable=False, server_default=text("'DUMP_OUT'"))
  unused_priority     = Column(INTEGER(10, unsigned=True))
  master_xref_id      = Column(INTEGER(10, unsigned=True))

class IdentityXref(Base):
  __tablename__ = "identity_xref"

  object_xref_id    = Column(INTEGER(10, unsigned=True), primary_key=True)
  query_identity    = Column(INTEGER(5))
  target_identity   = Column(INTEGER(5))
  hit_start         = Column(INTEGER(10))
  hit_end           = Column(INTEGER(10))
  translation_start = Column(INTEGER(10))
  translation_end   = Column(INTEGER(10))
  cigar_line        = Column(TEXT)
  score             = Column(DOUBLE)
  evalue            = Column(DOUBLE)

class Meta(Base):
  __tablename__ = "meta"
  __table_args__ = (
    Index("species_key_value_idx", "meta_id", "species_id", "meta_key", "meta_value", unique=True),
    Index("species_value_idx", "species_id", "meta_value")
  )

  meta_id    = Column(INTEGER(10), primary_key=True, autoincrement=True)
  species_id = Column(INTEGER(10, unsigned=True), server_default=text("1"))
  meta_key   = Column(VARCHAR(40), nullable=False)
  meta_value = Column(VARCHAR(255, binary=True), nullable=False)
  date       = Column(DateTime, nullable=False)
