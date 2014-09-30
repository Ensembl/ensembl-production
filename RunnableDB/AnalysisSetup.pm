=head1 LICENSE

Copyright [1999-2014] EMBL-European Bioinformatics Institute
and Wellcome Trust Sanger Institute

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


=pod

=head1 NAME

Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisSetup

=head1 DESCRIPTION

Add a new analysis to a database. By default, the script expects to be
given the location of a db backup file, since it may delete data without
doing a backup itself. This behaviour can be switched off, if you walk to
walk the tightrope without a net (db_backup_required=0).

If the analysis exists already, the default behaviour is to rename the
existing analysis, and insert a fresh analysis. This is useful if you want
to easily compare new and old results associated with that analysis, but means
that you are responsible for subsequently tidying up the database yourself,
since you probably don't want both new and old analyses in a production db.

Alternatively, if the analysis exists you can delete it, and any rows
connected to it (delete_existing=1). You are responsible for providing
an arrayref of the tables which have the relevant analysis_id foreign
keys (linked_tables).

The script will look up descriptions from the production database, by default;
this relies on the production server (usually pan-1) being in the registry.
Lookup parameters will be over-ridden if description parameters are explicitly
given, or can be set as undefined (production_lookup=0).

=head1 Author

James Allen

=cut

package Bio::EnsEMBL::EGPipeline::Common::RunnableDB::AnalysisSetup;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base);
use Bio::EnsEMBL::Analysis;

sub param_defaults {
  return {
    'db_type'            => 'core',
    'linked_tables'      => [],
    'delete_existing'    => 0,
    'logic_rename'       => undef,
    'db_backup_required' => 1,
    'production_lookup'  => 1,
    'db'                 => undef,
    'db_version'         => undef,
    'db_file'            => undef,
    'program'            => undef,
    'program_version'    => undef,
    'program_file'       => undef,
    'parameters'         => undef,
    'module'             => undef,
    'module_version'     => undef,
    'gff_source'         => undef,
    'gff_feature'        => undef,
    'description'        => undef,
    'display_label'      => undef,
    'displayable'        => undef,
    'web_data'           => undef,
  };
}

sub fetch_input {
  my $self = shift @_;
  
  my $logic_name = $self->param_required('logic_name');
  $self->param('program', $logic_name) unless $self->param_is_defined('program');
  
  if (!$self->param('delete_existing')) {
    $self->param('logic_rename', "$logic_name\_bkp") unless $self->param_is_defined('logic_rename');
  }
  
  if ($self->param('db_backup_required')) {
    my $db_backup_file = $self->param_required('db_backup_file');
    
    if (!-e $db_backup_file) {
      $self->throw("Database backup file '$db_backup_file' does not exist");
    }
  }
  
}

sub run {
  my $self = shift @_;
  my $species = $self->param_required('species');
  my $logic_name = $self->param_required('logic_name');
  
  my $dba = $self->get_DBAdaptor($self->param('db_type'));
  my $dbh = $dba->dbc->db_handle;
  my $aa = $dba->get_adaptor('Analysis');
  my $analysis = $aa->fetch_by_logic_name($logic_name);
  
  if (defined $analysis) {
    if ($self->param('delete_existing')) {
      my $analysis_id = $analysis->dbID;
      foreach my $table (@{$self->param('linked_tables')}) {
        my $sql = "DELETE FROM $table WHERE analysis_id = $analysis_id";
        my $sth = $dbh->prepare($sql) or throw("Failed to delete rows using '$sql': ".$dbh->errstr);
        $sth->execute or throw("Failed to delete rows using '$sql': ".$sth->errstr);
      }
      $aa->remove($analysis);
    } else {
      my $logic_rename = $self->param_required('logic_rename');
      my $renamed_analysis = $aa->fetch_by_logic_name($logic_rename);
      if (defined $renamed_analysis) {
        $self->throw(
          "Cannot rename '$logic_name' to '$logic_rename' because '$logic_rename' already exists.\n".
          "Either provide a different 'logic_rename' parameter, or delete the '$logic_rename' analysis.\n"
        );
      } else {
        $analysis->logic_name($logic_rename);
        $aa->update($analysis);
      }
    }
  }
  
  if ($self->param('production_lookup')) {
    $self->production_updates;
  }
  
  my $new_analysis = $self->create_analysis;
  $aa->store($new_analysis);
  
}

sub create_analysis {
  my ($self) = @_;
  
  my $analysis = Bio::EnsEMBL::Analysis->new(
    -logic_name      => $self->param('logic_name'),
    -db              => $self->param('db'),
    -db_version      => $self->param('db_version'),
    -db_file         => $self->param('db_file'),
    -program         => $self->param('program'),
    -program_version => $self->param('program_version'),
    -program_file    => $self->param('program_file'),
    -parameters      => $self->param('parameters'),
    -module          => $self->param('module'),
    -module_version  => $self->param('module_version'),
    -gff_source      => $self->param('gff_source'),
    -gff_feature     => $self->param('gff_feature'),
    -description     => $self->param('description'),
    -display_label   => $self->param('display_label'),
    -displayable     => $self->param('displayable'),
    -web_data        => $self->param('web_data'),
  );
  
  return $analysis;
}

sub production_updates {
  my ($self) = @_;
  
  my $logic_name = $self->param('logic_name');
  my $species = $self->param('species'),
  my $db_type = $self->param('db_type'),
  
  my $dbc = $self->production_dbc();
  my $dbh = $dbc->db_handle();
  my %properties;
  
  # Load generic, non-species-specific, analyses
  my $sth = $dbh->prepare(
    'SELECT ad.description, ad.display_label, 1, wd.data '.
    'FROM analysis_description ad '.
    'LEFT OUTER JOIN web_data wd ON ad.default_web_data_id = wd.web_data_id '.
    'WHERE ad.is_current = 1 '.
    'AND ad.logic_name = ? '
  );
  $sth->execute($logic_name);
  
  $sth->bind_columns(\(
    $properties{'description'},
    $properties{'display_label'},
    $properties{'displayable'},
    $properties{'web_data'},
  ));
  
  $sth->fetch();
  
  # Load species-specific analyses, overwriting the generic info
  $sth = $dbh->prepare(
    'SELECT ad.description, ad.display_label, aw.displayable, wd.data '.
    'FROM analysis_description ad, species s, analysis_web_data aw '.
    'LEFT OUTER JOIN web_data wd ON aw.web_data_id = wd.web_data_id '.
    'WHERE ad.analysis_description_id = aw.analysis_description_id '.
    'AND aw.species_id = s.species_id '.
    'AND ad.logic_name = ? '.
    'AND s.db_name = ? '.
    'AND aw.db_type = ? '
  );
  $sth->execute($logic_name, $species, $db_type);
  
  $sth->bind_columns(\(
    $properties{'description'},
    $properties{'display_label'},
    $properties{'displayable'},
    $properties{'web_data'},
  ));
  
  $sth->fetch();
  $properties{'web_data'} = eval ($properties{'web_data'}) if defined $properties{'web_data'};
  
  # Explicitly passed parameters do not get overwritten.
  foreach my $property (keys %properties) {
    if (! $self->param_is_defined($property)) {
      $self->param($property, $properties{$property});
    }      
  }
  
  if ($dbc->user eq 'ensrw') {
    $sth = $dbh->prepare(
      'INSERT IGNORE INTO analysis_web_data '.
        '(analysis_description_id, web_data_id, species_id, db_type, '.
          'displayable, created_at, modified_at) '.
      'SELECT '.
        'ad.analysis_description_id, ad.default_web_data_id, s.species_id, ?, '.
          'ad.default_displayable, NOW(), NOW() '.
      'FROM analysis_description ad, species s '.
      'WHERE ad.logic_name = ? AND ad.is_current = 1 AND s.db_name = ?;'
    );
    
    $sth->execute($db_type, $logic_name, $species);
  } else {
    $self->warning("Insufficient permissions to link $species and $logic_name");
  }
  
}

1;
