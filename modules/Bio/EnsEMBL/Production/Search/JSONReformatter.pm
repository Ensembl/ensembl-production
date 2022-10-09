
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

=head1 NAME

  Bio::EnsEMBL::Production::Search::JSONReformatter

=head1 SYNOPSIS


=head1 DESCRIPTION


=cut

package Bio::EnsEMBL::Production::Search::JSONReformatter;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT = qw(process_json_file reformat_json);

use Log::Log4perl qw/get_logger/;
use Carp qw/croak/;
#BEGIN { $ENV{PERL_JSON_BACKEND} = 'JSON::XS' }

use JSON;

my $logger = get_logger();

sub process_json_file {
  my ( $file, $callback ) = @_;
  $logger->info("Processing $file");
  print("..............................................");
  print("$file.......production error.......\n");
  # open filehandle
  print("json1111111111111111111111111111111111111111\n");
  open my $fh, "<", $file || croak "Could not open $file for reading: " . @_;
  # seek through whitespace
  my $c;
  while ( ( $c = getc($fh) ) =~ m/\s/ ) { }
  if ( $c ne '[' ) {
    croak "JSON file must contain an array only";
  }
  print("json222222222222222222222222222222222222222222222222\n");
  my $n    = 0;
  my $json = new JSON;
  $json->allow_nonref->escape_slash->encode("/");

  {
    local $/ = '}';
    while (<$fh>) {
     print("...///$_\n");	    
      my $obj = $json->incr_parse($_);
      if ( defined $obj ) {
        $n++;
        $callback->($obj);
        $json->incr_reset();
        my $c = getc($fh);
        last if $c eq ']';
      }
    }
  }
  print("json 3333333333333333333333333333333333\n");
  close $fh;
  $logger->info("Completed processing $n elements from $file");
  return;
} ## end sub process_json_file

sub reformat_json {
  my ( $infile, $outfile, $callback ) = @_;
  open my $fh, ">", $outfile || croak "Could not open $outfile for writing";
  print $fh '[';
  my $n = 0;

  process_json_file(
      $infile,
      sub {
        my ($obj) = @_;
        my $new_obj = $callback->($obj);
        return if !defined $new_obj;
        if ( ref($new_obj) eq 'ARRAY' ) {
          for my $o (@$new_obj) {
            if ( $n++ > 0 ) {
              print $fh ",";
            }
            print $fh encode_json($o);
          }
        }
        else {
          if ( $n++ > 0 ) {
            print $fh ",";
          }
          print $fh encode_json($new_obj);
        }
        return;
      } );

  print $fh ']';
  close $fh;
  return;
} ## end sub reformat_json

1;
