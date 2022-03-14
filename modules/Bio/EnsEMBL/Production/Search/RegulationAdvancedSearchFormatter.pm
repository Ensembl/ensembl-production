=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Search::RegulationAdvancedSearchFormatter;

use warnings;
use strict;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Data::Dumper;
use Log::Log4perl qw/get_logger/;
use List::MoreUtils qw/natatime/;

use Bio::EnsEMBL::Production::Search::JSONReformatter;
use JSON;
use Carp;
use File::Slurp;

sub new {
  my ( $class, @args ) = @_;
  my $self = bless( {}, ref($class) || $class );
  $self->{log} = get_logger();
  my ( $tax_dba, $onto_dba ) =
    rearrange( [qw/taxonomy_dba ontology_dba/], @args );
  $self->{tax_dba} = $tax_dba;
  if ( !defined $self->{tax_dba} ) {
    $self->log()->warn("No taxonomy DBA defined");
  }
  $self->{onto_dba} = $onto_dba;
  if ( !defined $self->{onto_dba} ) {
    $self->log()->warn("No ontology DBA defined");
  }
  return $self;
}

sub log {
  my ($self) = @_;
  return $self->{log};
}

sub disconnect {
  my ($self) = @_;
  $self->{tax_dba}->dbc()->disconnect_if_idle();
  $self->{onto_dba}->dbc()->disconnect_if_idle();
  return;
}

sub remodel_regulation {
  my ( $self, $regulation_file, $genomes_file, $regulation_out ) = @_;
  my $genome  = decode_json( read_file($genomes_file) );

  open my $out, ">", $regulation_out || croak "Could not open $regulation_out for writing: $@";
  print $out "[";

  my $n = 0;
  process_json_file(
    $regulation_file,
    sub {
      my $feature = shift;
      $feature->{genome}         = $genome->{organism}{name};
      if ( $n++ > 0 ) {
        print $out ",";
      }
      print $out encode_json($feature);
    } );

  print $out "]";
  close $out;
  return;
} ## end sub remodel_regulation

sub remodel_probes {
  my ( $self, $probes_file, $genomes_file, $probes_file_out ) = @_;
  my $genome  = decode_json( read_file($genomes_file) );
  my $name = $genome->{name};

  open my $out, ">", $probes_file_out || croak "Could not open $probes_file_out for writing: $@";
  print $out "[";

  my $n = 0;
  process_json_file(
    $probes_file,
    sub {
      my $probe = shift;
      $probe->{genome} = $genome->{organism}{name};
      if ( $n++ > 0 ) {
        print $out ",";
      }
      print $out encode_json($probe);
    } );

  print $out "]";
  close $out;
  return;
} ## end sub remodel_probes

sub remodel_probesets {
  my ( $self, $probesets_file, $genomes_file, $probesets_file_out ) = @_;
  my $genome  = decode_json( read_file($genomes_file) );
  my $name = $genome->{name};

  open my $out, ">", $probesets_file_out || croak "Could not open $probesets_file_out for writing: $@";
  print $out "[";

  my $n = 0;
  process_json_file(
    $probesets_file,
    sub {
      my $probeset = shift;
      $probeset->{genome} = $genome->{organism}{name};
      if ( $n++ > 0 ) {
        print $out ",";
      }
      print $out encode_json($probeset);
    } );

  print $out "]";
  close $out;
  return;
} ## end sub remodel_probesets
1;
