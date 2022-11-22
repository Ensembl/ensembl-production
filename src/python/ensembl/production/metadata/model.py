# coding: utf-8
from sqlalchemy import Column, Date, Enum, ForeignKey, Index, LargeBinary, String, TIMESTAMP, Text, text
from sqlalchemy.dialects.mysql import BIGINT, INTEGER, TINYINT, VARCHAR
from sqlalchemy.orm import relationship
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()
metadata = Base.metadata


class Assembly(Base):
    __tablename__ = 'assembly'
    __table_args__ = (
        Index('assembly_idx', 'assembly_accession', 'assembly_default', 'base_count', unique=True),
    )

    assembly_id = Column(INTEGER(10), primary_key=True)
    assembly_accession = Column(String(16))
    assembly_name = Column(String(200), nullable=False)
    assembly_default = Column(String(200), nullable=False)
    assembly_ucsc = Column(String(16))
    assembly_level = Column(String(50), nullable=False)
    base_count = Column(BIGINT(20), nullable=False)
    assembly_sequences = relationship("AssemblySequence", back_populates="assembly")
    genome = relationship("Genome", back_populates="assembly")


class DataRelease(Base):
    __tablename__ = 'data_release'
    __table_args__ = (
        Index('ensembl_version', 'ensembl_version', 'ensembl_genomes_version', unique=True),
    )

    data_release_id = Column(INTEGER(10), primary_key=True)
    ensembl_version = Column(INTEGER(10), nullable=False)
    ensembl_genomes_version = Column(INTEGER(10))
    release_date = Column(Date, nullable=False)
    is_current = Column(TINYINT(3), nullable=False, server_default=text("'0'"))
    data_release_db = relationship("DataReleaseDatabase", back_populates="data_release")
    genome = relationship('Genome',  back_populates="data_release")
    

class Division(Base):
    __tablename__ = 'division'

    division_id = Column(INTEGER(10), primary_key=True)
    name = Column(String(32), nullable=False, unique=True)
    short_name = Column(String(8), nullable=False, unique=True)
    data_release_db = relationship('DataReleaseDatabase', back_populates="division")
    genome = relationship('Genome', back_populates="division") 
    compara_analysis = relationship('ComparaAnalysis', back_populates="division")

class Organism(Base):
    __tablename__ = 'organism'

    organism_id = Column(INTEGER(10), primary_key=True)
    taxonomy_id = Column(INTEGER(10), nullable=False)
    reference = Column(String(128))
    species_taxonomy_id = Column(INTEGER(10), nullable=False)
    name = Column(String(128), nullable=False, unique=True)
    url_name = Column(String(128), nullable=False)
    display_name = Column(String(128), nullable=False)
    scientific_name = Column(String(128), nullable=False)
    strain = Column(String(128))
    serotype = Column(String(128))
    description = Column(Text)
    image = Column(LargeBinary)
    
    genome = relationship('Genome', back_populates="organism")
    organism_alias = relationship('OrganismAlias', back_populates="organism")
    organism_publication = relationship('OrganismPublication', back_populates="organism")


class AssemblySequence(Base):
    __tablename__ = 'assembly_sequence'
    __table_args__ = (
        Index('name_acc', 'assembly_id', 'name', 'acc', unique=True),
    )

    assembly_sequence_id = Column(INTEGER(10), primary_key=True)
    assembly_id = Column(ForeignKey('assembly.assembly_id', ondelete='CASCADE'), nullable=False)
    name = Column(String(40), nullable=False, index=True)
    acc = Column(String(24), index=True)
    assembly = relationship('Assembly', back_populates="assembly_sequences")


class ComparaAnalysis(Base):
    __tablename__ = 'compara_analysis'
    __table_args__ = (
        Index('division_method_set_name_dbname', 'division_id', 'method', 'set_name', 'dbname', unique=True),
    )

    compara_analysis_id = Column(INTEGER(10), primary_key=True)
    data_release_id = Column(INTEGER(10), nullable=False)
    division_id = Column(ForeignKey('division.division_id'), nullable=False)
    method = Column(String(50), nullable=False)
    set_name = Column(String(128))
    dbname = Column(String(64), nullable=False)

    division = relationship('Division', back_populates="compara_analysis")


class DataReleaseDatabase(Base):
    __tablename__ = 'data_release_database'
    __table_args__ = (
        Index('id_dbname', 'data_release_id', 'dbname', unique=True),
    )

    data_release_database_id = Column(INTEGER(10), primary_key=True)
    data_release_id = Column(ForeignKey('data_release.data_release_id'), nullable=False)
    dbname = Column(String(64), nullable=False)
    type = Column(Enum('mart', 'ontology', 'ids', 'other'), server_default=text("'other'"))
    division_id = Column(ForeignKey('division.division_id'), nullable=False, index=True)

    data_release = relationship('DataRelease', back_populates="data_release_db")
    division = relationship('Division', back_populates="data_release_db")


class Genome(Base):
    __tablename__ = 'genome'
    __table_args__ = (
        Index('release_genome_division', 'data_release_id', 'genome_id', 'division_id', unique=True),
    )

    genome_id = Column(INTEGER(10), primary_key=True)
    data_release_id = Column(ForeignKey('data_release.data_release_id'), nullable=False)
    assembly_id = Column(ForeignKey('assembly.assembly_id'), nullable=False, index=True)
    organism_id = Column(ForeignKey('organism.organism_id', ondelete='CASCADE'), nullable=False, index=True)
    genebuild = Column(String(255), nullable=False)
    division_id = Column(ForeignKey('division.division_id'), nullable=False, index=True)
    has_pan_compara = Column(TINYINT(3), nullable=False, server_default=text("'0'"))
    has_variations = Column(TINYINT(3), nullable=False, server_default=text("'0'"))
    has_peptide_compara = Column(TINYINT(3), nullable=False, server_default=text("'0'"))
    has_genome_alignments = Column(TINYINT(3), nullable=False, server_default=text("'0'"))
    has_synteny = Column(TINYINT(3), nullable=False, server_default=text("'0'"))
    has_other_alignments = Column(TINYINT(3), nullable=False, server_default=text("'0'"))
    has_microarray = Column(TINYINT(3), nullable=False, server_default=text("'0'"))
    website_packed = Column(TINYINT(3), nullable=False, server_default=text("'0'"))

    assembly = relationship('Assembly', back_populates="genome")
    data_release = relationship('DataRelease',  back_populates="genome")
    division = relationship('Division', back_populates="genome")
    organism = relationship('Organism', back_populates="genome")
    genome_databases= relationship('GenomeDatabase', back_populates="genome")


class OrganismAlias(Base):
    __tablename__ = 'organism_alias'
    __table_args__ = (
        Index('id_alias', 'organism_id', 'alias', unique=True),
    )

    organism_alias_id = Column(INTEGER(10), primary_key=True)
    organism_id = Column(ForeignKey('organism.organism_id', ondelete='CASCADE'), nullable=False)
    alias = Column(VARCHAR(255))

    organism = relationship('Organism', back_populates="organism_alias")


class OrganismPublication(Base):
    __tablename__ = 'organism_publication'
    __table_args__ = (
        Index('id_publication', 'organism_id', 'publication', unique=True),
    )

    organism_publication_id = Column(INTEGER(10), primary_key=True)
    organism_id = Column(ForeignKey('organism.organism_id', ondelete='CASCADE'), nullable=False)
    publication = Column(String(64))

    organism = relationship('Organism', back_populates="organism_publication")


class ComparaAnalysisEvent(Base):
    __tablename__ = 'compara_analysis_event'

    compara_analysis_event_id = Column(INTEGER(10), primary_key=True)
    compara_analysis_id = Column(ForeignKey('compara_analysis.compara_analysis_id', ondelete='CASCADE'), nullable=False, index=True)
    type = Column(String(32), nullable=False)
    source = Column(String(128))
    creation_time = Column(TIMESTAMP, nullable=False, server_default=text("CURRENT_TIMESTAMP"))
    details = Column(Text)

    compara_analysis = relationship('ComparaAnalysis')


class DataReleaseDatabaseEvent(Base):
    __tablename__ = 'data_release_database_event'

    data_release_database_event_id = Column(INTEGER(10), primary_key=True)
    data_release_database_id = Column(ForeignKey('data_release_database.data_release_database_id', ondelete='CASCADE'), nullable=False, index=True)
    type = Column(String(32), nullable=False)
    source = Column(String(128))
    creation_time = Column(TIMESTAMP, nullable=False, server_default=text("CURRENT_TIMESTAMP"))
    details = Column(Text)

    data_release_database = relationship('DataReleaseDatabase')


class GenomeComparaAnalysis(Base):
    __tablename__ = 'genome_compara_analysis'
    __table_args__ = (
        Index('genome_compara_analysis_key', 'genome_id', 'compara_analysis_id', unique=True),
    )

    genome_compara_analysis_id = Column(INTEGER(10), primary_key=True)
    genome_id = Column(ForeignKey('genome.genome_id', ondelete='CASCADE'), nullable=False)
    compara_analysis_id = Column(ForeignKey('compara_analysis.compara_analysis_id', ondelete='CASCADE'), nullable=False, index=True)

    compara_analysis = relationship('ComparaAnalysis')
    genome = relationship('Genome')


class GenomeDatabase(Base):
    __tablename__ = 'genome_database'
    __table_args__ = (
        Index('genome_db_species', 'genome_id', 'dbname', 'species_id', unique=True),
    )

    genome_database_id = Column(INTEGER(10), primary_key=True)
    genome_id = Column(ForeignKey('genome.genome_id', ondelete='CASCADE'), nullable=False)
    dbname = Column(String(64), nullable=False)
    species_id = Column(INTEGER(10), nullable=False)
    type = Column(String(128))

    genome = relationship('Genome', back_populates='genome_databases')


class GenomeEvent(Base):
    __tablename__ = 'genome_event'

    genome_event_id = Column(INTEGER(10), primary_key=True)
    genome_id = Column(ForeignKey('genome.genome_id', ondelete='CASCADE'), nullable=False, index=True)
    type = Column(String(32), nullable=False)
    source = Column(String(128))
    creation_time = Column(TIMESTAMP, nullable=False, server_default=text("CURRENT_TIMESTAMP"))
    details = Column(Text)

    genome = relationship('Genome')


class GenomeAlignment(Base):
    __tablename__ = 'genome_alignment'
    __table_args__ = (
        Index('id_type_key', 'genome_id', 'type', 'name', 'genome_database_id', unique=True),
    )

    genome_alignment_id = Column(INTEGER(10), primary_key=True)
    genome_id = Column(ForeignKey('genome.genome_id', ondelete='CASCADE'), nullable=False)
    type = Column(String(32), nullable=False)
    name = Column(String(128), nullable=False)
    count = Column(INTEGER(10), nullable=False)
    genome_database_id = Column(ForeignKey('genome_database.genome_database_id', ondelete='CASCADE'), nullable=False, index=True)

    genome_database = relationship('GenomeDatabase')
    genome = relationship('Genome')


class GenomeAnnotation(Base):
    __tablename__ = 'genome_annotation'
    __table_args__ = (
        Index('id_type', 'genome_id', 'type', 'genome_database_id', unique=True),
    )

    genome_annotation_id = Column(INTEGER(10), primary_key=True)
    genome_id = Column(ForeignKey('genome.genome_id', ondelete='CASCADE'), nullable=False)
    type = Column(String(32), nullable=False)
    value = Column(String(128), nullable=False)
    genome_database_id = Column(ForeignKey('genome_database.genome_database_id', ondelete='CASCADE'), nullable=False, index=True)

    genome_database = relationship('GenomeDatabase')
    genome = relationship('Genome')


class GenomeFeature(Base):
    __tablename__ = 'genome_feature'
    __table_args__ = (
        Index('id_type_analysis', 'genome_id', 'type', 'analysis', 'genome_database_id', unique=True),
    )

    genome_feature_id = Column(INTEGER(10), primary_key=True)
    genome_id = Column(ForeignKey('genome.genome_id', ondelete='CASCADE'), nullable=False)
    type = Column(String(32), nullable=False)
    analysis = Column(String(128), nullable=False)
    count = Column(INTEGER(10), nullable=False)
    genome_database_id = Column(ForeignKey('genome_database.genome_database_id', ondelete='CASCADE'), nullable=False, index=True)

    genome_database = relationship('GenomeDatabase')
    genome = relationship('Genome')


class GenomeVariation(Base):
    __tablename__ = 'genome_variation'
    __table_args__ = (
        Index('id_type_key', 'genome_id', 'type', 'name', 'genome_database_id', unique=True),
    )

    genome_variation_id = Column(INTEGER(10), primary_key=True)
    genome_id = Column(ForeignKey('genome.genome_id', ondelete='CASCADE'), nullable=False)
    type = Column(String(32), nullable=False)
    name = Column(String(128), nullable=False)
    count = Column(INTEGER(10), nullable=False)
    genome_database_id = Column(ForeignKey('genome_database.genome_database_id', ondelete='CASCADE'), nullable=False, index=True)

    genome_database = relationship('GenomeDatabase')
    genome = relationship('Genome')
