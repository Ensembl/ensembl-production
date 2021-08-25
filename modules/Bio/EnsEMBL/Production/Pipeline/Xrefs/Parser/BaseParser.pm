=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package Bio::EnsEMBL::Production::Pipeline::Xrefs::Parser::BaseParser;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception;
use XrefParser::Database;
use Carp;
use DBI;
use Getopt::Long;

my $base_dir = File::Spec->curdir();

my %xref_dependent_mapped;


###################################################
# Create new object.
###################################################
sub new
{
  my ($proto, $database) = @_;
  my $dbh;
  if(!defined $database){
    croak 'No database specified';
  } elsif ( $database->isa('XrefParser::Database') ) {
    $dbh = $database->dbi;
  } else {
    croak sprintf 'I do not recognise your %s class. It must be XrefParser::Database or a DBI $dbh instance'."\n",ref $database;
  }

  my $class = ref $proto || $proto;
  my $self =  bless {}, $class;
  return $self;
}


#######################################################################
# Given a file name, returns a IO::Handle object.  If the file is
# gzipped, the handle will be to an unseekable stream coming out of a
# zcat pipe.  If the given file name doesn't correspond to an existing
# file, the routine will try to add '.gz' to the file name or to remove
# any .'Z' or '.gz' and try again, printing a warning to stderr if the
# alternative name does match an existing file.
# Possible error states:
#  - throws if no file name has been given, or if neither the provided
#    name nor the alternative one points to an existing file
#  - returns undef if an uncompressed file could not be opened for
#    reading, or if the command 'zcat' is not in the search path
#  - at least on Perl installations with multi-threading enabled,
#    returns a VALID FILE HANDLE if zcat can be called but it cannot
#    open the target file for reading - zcat will only report an error
#    upon the first attempt to read from the handle
#######################################################################
sub get_filehandle
{
    my ($self, $file_name) = @_;

    my $io =undef;

    if(!(defined $file_name) or $file_name eq ''){
      confess "No file name";
    }
    my $alt_file_name = $file_name;
    $alt_file_name =~ s/\.(gz|Z)$//x;

    if ( $alt_file_name eq $file_name ) {
        $alt_file_name .= '.gz';
    }

    if ( !-e $file_name ) {
        if ( ! -e $alt_file_name ) {
            confess "Could not find either '$file_name' or '$alt_file_name'";
        }
        carp(   "File '$file_name' does not exist, "
              . "will try '$alt_file_name'" );
        $file_name = $alt_file_name;
    }

    if ( $file_name =~ /\.(gz|Z)$/x ) {
        # Read from zcat pipe
        $io = IO::File->new("zcat $file_name |")
          or carp("Can not call 'zcat' to open file '$file_name'");
    } else {
        # Read file normally
        $io = IO::File->new($file_name)
          or carp("Can not open file '$file_name'");
    }

    if ( !defined $io ) { return }

    return $io;
}


#############################################
# Get source ID for a particular source name
#
# Arg[1] source name
# Arg[2] priority description
#
# Returns source_id, or throws if not found
#############################################
sub get_source_id_for_source_name {
  my ($self, $source_name,$priority_desc, $dbi) = @_;

  my $low_name = lc $source_name;
  my $sql = "SELECT source_id FROM source WHERE LOWER(name)='$low_name'";
  if(defined $priority_desc){
    $low_name = lc $priority_desc;
    $sql .= " AND LOWER(priority_description)='$low_name'";
    $source_name .= " ($priority_desc)";
  }
  my $sth = $dbi->prepare($sql);
  $sth->execute();
  my @row = $sth->fetchrow_array();
  my $source_id;
  if (@row) {
    $source_id = $row[0];
  } else {
    my $msg = "No source_id for source_name='${source_name}'";
    if ( defined $priority_desc ) {
      $msg .= "priority_desc='${priority_desc}'";
    }
    confess $msg;
  }
  $sth->finish();
  return $source_id;
}

##############################
# Upload xrefs to the database
##############################
sub upload_xref_object_graphs {
  my ($self, $rxrefs, $dbi) = @_;

  my $count = scalar @{$rxrefs};
  if ($count) {

    #################
    # upload new ones
    ##################

    #################################################################################
    # Start of sql needed to add xrefs, primary_xrefs, synonym, dependent_xrefs etc..
    #################################################################################
    my $xref_sth = $dbi->prepare('INSERT INTO xref (accession,version,label,description,source_id,species_id, info_type) VALUES(?,?,?,?,?,?,?)');
    my $pri_insert_sth = $dbi->prepare('INSERT INTO primary_xref VALUES(?,?,?,?)');
    my $pri_update_sth = $dbi->prepare('UPDATE primary_xref SET sequence=? WHERE xref_id=?');
    my $syn_sth = $dbi->prepare('INSERT IGNORE INTO synonym ( xref_id, synonym ) VALUES(?,?)');
    my $xref_update_label_sth = $dbi->prepare('UPDATE xref SET label=? WHERE xref_id=?');
    my $xref_update_descr_sth = $dbi->prepare('UPDATE xref SET description=? WHERE xref_id=?');
    my $pair_sth = $dbi->prepare('INSERT INTO pairs VALUES(?,?,?)');
    my $xref_id_sth = $dbi->prepare("SELECT xref_id FROM xref WHERE accession = ? AND source_id = ? AND species_id = ?");
    my $primary_xref_id_sth = $dbi->prepare('SELECT xref_id FROM primary_xref WHERE xref_id=?');



    # disable error handling here as we'll do it ourselves
    # reenabled it, as errorcodes are really unhelpful
    $xref_sth->{RaiseError} = 0;
    $xref_sth->{PrintError} = 0;

    #################################################################################
    # End of sql needed to add xrefs, primary_xrefs, synonym, dependent_xrefs etc..
    #################################################################################


    foreach my $xref (@{$rxrefs}) {
       my ($xref_id, $direct_xref_id);
       if(!(defined $xref->{ACCESSION} )){
	 print "Your xref does not have an accession-number,so it can't be stored in the database\n"
	   || croak 'Could not write message';
	 return;
       }

       ########################################
       # Create entry in xref table and note ID
       ########################################
       if(! $xref_sth->execute($xref->{ACCESSION},
			 $xref->{VERSION} || 0,
			 $xref->{LABEL}|| $xref->{ACCESSION},
			 $xref->{DESCRIPTION},
			 $xref->{SOURCE_ID},
			 $xref->{SPECIES_ID},
			 $xref->{INFO_TYPE} || 'MISC')){
	 #
	 #  if we failed to add the xref it must already exist so go find the xref_id for this
	 #
	 if(!(defined $xref->{SOURCE_ID})){
	   print "your xref: $xref->{ACCESSION} does not have a source-id\n";
	   return;
	 }
         $xref_id_sth->execute(
                   $xref->{ACCESSION},
                   $xref->{SOURCE_ID},
                   $xref->{SPECIES_ID} );
         $xref_id = ($xref_id_sth->fetchrow_array())[0];
	 if(defined $xref->{LABEL} ) {
	   $xref_update_label_sth->execute($xref->{LABEL},$xref_id) ;
	 }
	 if(defined $xref->{DESCRIPTION} ){
	   $xref_update_descr_sth->execute($xref->{DESCRIPTION},$xref_id);
	 }
       }
       else{
         $xref_id_sth->execute(
                   $xref->{ACCESSION},
                   $xref->{SOURCE_ID},
                   $xref->{SPECIES_ID} );
         $xref_id = ($xref_id_sth->fetchrow_array())[0];
       }

       foreach my $direct_xref (@{$xref->{DIRECT_XREFS}}) {
         $xref_sth->execute( $xref->{ACCESSION},
                             $xref->{VERSION} || 0,
                             $xref->{LABEL} || $xref->{ACCESSION},
                             $xref->{DESCRIPTION},
                             $direct_xref->{SOURCE_ID},
                             $xref->{SPECIES_ID},
                             $direct_xref->{LINKAGE_TYPE});
         $xref_id_sth->execute(
                   $xref->{ACCESSION},
                   $direct_xref->{SOURCE_ID},
                   $xref->{SPECIES_ID} );
         $direct_xref_id = ($xref_id_sth->fetchrow_array())[0];
         $self->add_direct_xref($direct_xref_id, $direct_xref->{STABLE_ID}, $direct_xref->{ENSEMBL_TYPE},$direct_xref->{LINKAGE_TYPE}, $dbi);
       }

       ################
       # Error checking
       ################
       if(!((defined $xref_id) and $xref_id)){
	 print STDERR "xref_id is not set for :\n".
	   "$xref->{ACCESSION}\n$xref->{LABEL}\n".
	     "$xref->{DESCRIPTION}\n$xref->{SOURCE_ID}\n".
	       "$xref->{SPECIES_ID}\n";
       }


       #############################################################################
       # create entry in primary_xref table with sequence; if this is a "cumulative"
       # entry it may already exist, and require an UPDATE rather than an INSERT
       #############################################################################
       if(defined $xref->{SEQUENCE} ){
         $primary_xref_id_sth->execute($xref_id) or croak( $dbi->errstr() );
         my @row = $primary_xref_id_sth->fetchrow_array();
         my $exists = $row[0];
	 if ( $exists ) {
	   $pri_update_sth->execute( $xref->{SEQUENCE}, $xref_id )
	     or croak( $dbi->errstr() );
	 } else {
	   $pri_insert_sth->execute( $xref_id, $xref->{SEQUENCE},
				     $xref->{SEQUENCE_TYPE},
				     $xref->{STATUS} )
	     or croak( $dbi->errstr() );
	 }
       }

       ##########################################################
       # if there are synonyms, add entries in the synonym table
       ##########################################################
       foreach my $syn ( @{ $xref->{SYNONYMS} } ) {
	 $syn_sth->execute( $xref_id, $syn )
	   or croak( $dbi->errstr() . "\n $xref_id\n $syn\n" );
       }

       #######################################################################
       # if there are dependent xrefs, add xrefs and dependent xrefs for them
       #######################################################################
     DEPENDENT_XREF:
       foreach my $depref (@{$xref->{DEPENDENT_XREFS}}) {
         my %dep = %{$depref};

         #####################################
         # Insert the xref and get its xref_id
         #####################################
         # print "inserting $dep{ACCESSION},$dep{VERSION},$dep{LABEL},$dep{DESCRIPTION},$dep{SOURCE_ID},${\$xref->{SPECIES_ID}}\n";
         my $dep_xref_id = $self->add_xref({
                                            'acc'        => $dep{ACCESSION},
                                            'source_id'  => $dep{SOURCE_ID},
                                            'species_id' => $xref->{SPECIES_ID},
                                            'label'      => $dep{LABEL},
                                            'desc'       => $dep{DESCRIPTION},
                                            'version'    => $dep{VERSION},
                                            'info_type'  => 'DEPENDENT',
                                            'dbi'        => $dbi,
                                          });
         if( ! $dep_xref_id ) {
           next DEPENDENT_XREF;
         }

         #
         # Add the linkage_annotation and source id it came from
         #
         $self->add_dependent_xref_maponly( $dep_xref_id,
                                            $dep{LINKAGE_SOURCE_ID},
                                            $xref_id,
                                            $dep{LINKAGE_ANNOTATION},
				            $dbi);

         #########################################################
         # if there are synonyms, add entries in the synonym table
         #########################################################
         foreach my $syn ( @{ $dep{SYNONYMS} } ) {
           $syn_sth->execute( $dep_xref_id, $syn )
             or croak( $dbi->errstr() . "\n $xref_id\n $syn\n" );
         } # foreach syn

       } # foreach dep

       #################################################
       # Add the pair data. refseq dna/pep pairs usually
       #################################################
       if(defined $xref_id and defined $xref->{PAIR} ){
	 $pair_sth->execute($xref->{SOURCE_ID},$xref->{ACCESSION},$xref->{PAIR});
       }


       ###########################
       # tidy up statement handles
       ###########################
       if(defined $xref_sth) {$xref_sth->finish()};
       if(defined $pri_insert_sth) {$pri_insert_sth->finish()} ;
       if(defined $pri_update_sth) {$pri_update_sth->finish()};
       if(defined $syn_sth) { $syn_sth->finish()};
       if(defined $xref_update_label_sth) { $xref_update_label_sth->finish()};
       if(defined $xref_update_descr_sth) { $xref_update_descr_sth->finish()};
       if(defined $pair_sth) { $pair_sth->finish()};
       if(defined $xref_id_sth) { $xref_id_sth->finish()};
       if(defined $primary_xref_id_sth) { $primary_xref_id_sth->finish()};

     }  # foreach xref

  }
  return 1;
}

#################################################
# Create a hash of all the source names for xrefs
#################################################
sub get_xref_sources {

  my $self = shift;
  my $dbi = shift;
  my %sourcename_to_sourceid;

  my $sth = $dbi->prepare('SELECT name,source_id FROM source');
  $sth->execute() or croak( $dbi->errstr() );
  while(my @row = $sth->fetchrow_array()) {
    my $source_name = $row[0];
    my $source_id = $row[1];
    $sourcename_to_sourceid{$source_name} = $source_id;
  }
  $sth->finish;

  return %sourcename_to_sourceid;
}


#################################################
# xref_ids for a given stable id and linkage_xref
#################################################
sub get_direct_xref{
  my ($self,$stable_id,$type,$link, $dbi) = @_;
 
  $type = lc $type;
 
  my $sql = "select general_xref_id from ${type}_direct_xref d where ensembl_stable_id = ? and linkage_xref ";
  my @sql_params = ( $stable_id );
  if ( defined $link ) {
    $sql .= '= ?';
    push @sql_params, $link;
  }
  else {
    $sql .= 'is null';
  }
  my  $direct_sth = $dbi->prepare($sql);
 
  $direct_sth->execute( @sql_params ) || croak( $dbi->errstr() );
  # Generic behaviour
 
  my @results;
 
  my $all_rows = $direct_sth->fetchall_arrayref();
  foreach my $row_ref ( @{ $all_rows } ) {
    push @results, $row_ref->[0];
  }
 
  return @results;
  $direct_sth->finish();
  return;
}


###################################################################
# return the xref_id for a particular accession, source and species
# if not found return undef;
###################################################################
sub get_xref{
  my ($self,$acc,$source, $species_id, $dbi) = @_;

  #
  # If the statement handle does nt exist create it.
  #
  my $sql = 'select xref_id from xref where accession = ? and source_id = ? and species_id = ?';
  my $get_xref_sth = $dbi->prepare($sql);

  #
  # Find the xref_id using the sql above
  #
  $get_xref_sth->execute( $acc, $source, $species_id ) or croak( $dbi->errstr() );
  if(my @row = $get_xref_sth->fetchrow_array()) {
    return $row[0];
  }
  $get_xref_sth->finish();
  return;
}


###########################################################
# Create an xref..
# If it already exists it return that xrefs xref_id
# else creates it and return the new xre_id
###########################################################
sub add_xref {
  my ( $self, $arg_ref) = @_;

  my $acc         = $arg_ref->{acc}        || croak 'add_xref needs aa acc';
  my $source_id   = $arg_ref->{source_id}  || croak 'add_xref needs a source_id';
  my $species_id  = $arg_ref->{species_id} || croak 'add_xref needs a species_id';
  my $label       = $arg_ref->{label}      // $acc;
  my $description = $arg_ref->{desc};
  my $version     = $arg_ref->{version}    // 0;
  my $info_type   = $arg_ref->{info_type}  // 'MISC';
  my $info_text   = $arg_ref->{info_text}  // q{};
  my $dbi         = $arg_ref->{dbi};

  ##################################################################
  # See if it already exists. It so return the xref_id for this one.
  ##################################################################
  my $xref_id = $self->get_xref($acc,$source_id, $species_id, $dbi);
  if(defined $xref_id){
    return $xref_id;
  }

  my $add_xref_sth =
      $dbi->prepare( 'INSERT INTO xref '
         . '(accession,version,label,description,source_id,species_id, info_type, info_text) '
         . 'VALUES(?,?,?,?,?,?,?,?)' );

  ######################################################################
  # If the description is more than 255 characters, chop it off and add
  # an indication that it has been truncated to the end of it.
  ######################################################################
  if (defined $description && ((length $description) > 255 ) ) {
    my $truncmsg = ' /.../';
    substr $description, 255 - (length $truncmsg),
            length $truncmsg, $truncmsg;
  }


  ####################################
  # Add the xref and croak if it fails
  ####################################
  $add_xref_sth->execute( $acc, $version || 0, $label,
                          $description, $source_id, $species_id, $info_type, $info_text
  ) or croak("$acc\t$label\t\t$source_id\t$species_id\n");

  $add_xref_sth->finish();
  return $add_xref_sth->{'mysql_insertid'};
} ## end sub add_xref


###################################################################
# Create new xref if needed and add as a direct xref to a stable_id
# Note that a corresponding method for dependent xrefs is called add_dependent_xref()
###################################################################
sub add_to_direct_xrefs{
  my ($self, $arg_ref) = @_;

  my $stable_id   = $arg_ref->{stable_id}   || croak ('Need a direct_xref on which this xref linked too' );
  my $type        = $arg_ref->{type}        || croak ('Need a table type on which to add');
  my $acc         = $arg_ref->{acc}         || croak ('Need an accession of this direct xref' );
  my $source_id   = $arg_ref->{source_id}   || croak ('Need a source_id for this direct xref' );
  my $species_id  = $arg_ref->{species_id}  || croak ('Need a species_id for this direct xref' );
  my $version     = $arg_ref->{version}     // 0;
  my $label       = $arg_ref->{label}       // $acc;
  my $description = $arg_ref->{desc};
  my $linkage     = $arg_ref->{linkage};
  my $info_text   = $arg_ref->{info_text}   // q{};
  my $dbi         = $arg_ref->{dbi};

  $dbi = $self->dbi unless defined $dbi;

  my $sql = (<<'AXX');
  INSERT INTO xref (accession,version,label,description,source_id,species_id, info_type, info_text)
          VALUES (?,?,?,?,?,?,?,?)
AXX
  my $add_xref_sth = $dbi->prepare($sql);

  ###############################################################
  # If the acc already has an xrefs find it else cretae a new one
  ###############################################################
  my $direct_id = $self->get_xref($acc, $source_id, $species_id, $dbi);
  if(!(defined $direct_id)){
    $add_xref_sth->execute(
        $acc, $version || 0, $label,
        $description, $source_id, $species_id, 'DIRECT', $info_text
    ) or croak("$acc\t$label\t\t$source_id\t$species_id\n");
  }
  $add_xref_sth->finish();

  $direct_id = $self->get_xref($acc, $source_id, $species_id, $dbi);

  #########################
  # Now add the direct info
  #########################
  $self->add_direct_xref($direct_id, $stable_id, $type, $linkage, $dbi);
  return;
}


##################################################################
# Add a single record to the direct_xref table.
# Note that an xref must already have been added to the xref table
# Note that a corresponding method for dependent xrefs is called add_dependent_xref_maponly()
##################################################################
sub add_direct_xref {
  my ($self, $general_xref_id, $ensembl_stable_id, $ensembl_type, $linkage_type, $dbi) = @_;

  # Check if such a mapping exists yet. Make sure get_direct_xref() is
  # invoked in list context, otherwise it will fall back to legacy
  # behaviour of returning a single xref_id even when multiple ones
  # match.
  my @existing_xref_ids = $self->get_direct_xref($ensembl_stable_id,
                                                 $ensembl_type,
                                                 $linkage_type,
                                                 $dbi);
  if ( scalar grep { $_ == $general_xref_id } @existing_xref_ids ) {
    return;
  }

  $ensembl_type = lc($ensembl_type);
  my $sql = "INSERT INTO " . $ensembl_type . "_direct_xref VALUES (?,?,?)";
  my $add_direct_xref_sth = $dbi->prepare($sql);

  $add_direct_xref_sth->execute($general_xref_id, $ensembl_stable_id, $linkage_type);
  $add_direct_xref_sth->finish();

  return;
}


##################################################################
# Add a single record to the dependent_xref table.
# Note that an xref must already have been added to the xref table
# Note that a corresponding method for direct xrefs is called add_direct_xref()
##################################################################

sub add_dependent_xref_maponly {
  my ( $self, $dependent_id, $dependent_source_id, $master_id, $master_source_id, $dbi) = @_;

  my $sql = (<<'ADX');
INSERT INTO dependent_xref 
  (master_xref_id,dependent_xref_id,linkage_annotation,linkage_source_id)
  VALUES (?,?,?,?)
ADX
  my $add_dependent_xref_sth = $dbi->prepare($sql);

  # If the dependency cannot be found in %xref_dependent_mapped,
  # i.e. has not been set yet, add it
  if ( ( ! defined $xref_dependent_mapped{"$master_id|$dependent_id"} )
       || $xref_dependent_mapped{"$master_id|$dependent_id"} ne $master_source_id ) {

    $add_dependent_xref_sth->execute( $master_id, $dependent_id,
                                      $master_source_id, $dependent_source_id )
      || croak("$master_id\t$dependent_id\t$master_source_id\t$dependent_source_id");

    $xref_dependent_mapped{"$master_id|$dependent_id"} = $master_source_id;
  }

  $add_dependent_xref_sth->finish();

  return;
}


########################################
# Set release for a particular source_id.
########################################
sub set_release{
    my ($self, $source_id, $s_release, $dbi ) = @_;

    my $sth =
      $dbi->prepare('UPDATE source SET source_release=? WHERE source_id=?');

    $sth->execute( $s_release, $source_id );
    $sth->finish();
    return;
}


1;

