from sqlalchemy import (Column, Index, ForeignKey, text)
from sqlalchemy.dialects.mysql import (INTEGER, VARCHAR, BOOLEAN)
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()

class ChecksumXref(Base):
  __tablename__ = "checksum_xref"
  __table_args__ = (
    Index("checksum_idx", "checksum", mysql_length=10),
  )

  checksum_xref_id = Column(INTEGER, primary_key=True, autoincrement=True)
  source_id        = Column(INTEGER, nullable=False)
  accession        = Column(VARCHAR(14), nullable=False)
  checksum         = Column(VARCHAR(32), nullable=False)

class Source(Base):
  __tablename__ = "source"

  source_id = Column(INTEGER(10), primary_key=True, autoincrement=True)
  name      = Column(VARCHAR(128), index=True, unique=True)
  active    = Column(BOOLEAN, nullable=False, server_default=text("1"))
  parser    = Column(VARCHAR(128))

class Version(Base):
  __tablename__ = "version"
  __table_args__ = (
    Index("version_idx", "source_id", "revision")
  )

  version_id = Column(INTEGER(10), primary_key=True, autoincrement=True)
  source_id  = Column(INTEGER(10), ForeignKey("source.source_id"))
  revision   = Column(VARCHAR(255))
  count_seen = Column(INTEGER(10), nullable=False)
  uri        = Column(VARCHAR(255))
  index_uri  = Column(VARCHAR(255))
  clean_uri  = Column(VARCHAR(255))
  preparse   = Column(BOOLEAN, nullable=False, server_default=text("0"))
