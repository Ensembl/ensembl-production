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

package Bio::EnsEMBL::Production::Pipeline::FtpChecker::CheckComparaFtp;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::FtpChecker::CheckFtp/;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Data::Dumper;

use Log::Log4perl qw/:easy/;

my $expected_files = {
		      "tsv" =>{"dir" => "{division}tsv/ensembl-compara/homologies/", "expected" =>[
							   'Compara.*.homologies.tsv.gz',
							   'README.*',
							   'MD5SUM*'
							  ]},
          "emf" =>{"dir" => "{division}emf/ensembl-compara/homologies/", "expected" =>[
							   'Compara.*.fasta.gz',
                 'Compara.*.emf.gz',
							   'README.*',
							   'MD5SUM'
							  ]},
		      "xml" => {"dir" => "{division}xml/ensembl-compara/homologies/", "expected" =>[
						       'Compara.*.xml.gz',
						       'Compara.*phyloxml.xml.tar',
                   'Compara.*.orthoxml.xml.tar',
						       'README.*',
						       'MD5SUM*'
						      ]},
		     };
sub run {
  my ($self) = @_;
  my $species = $self->param('species');
  Log::Log4perl->easy_init($DEBUG);
  $self->{logger} = get_logger();
  my $base_path = $self->param('base_path');
  $self->{logger}->info("Checking $species on $base_path");
  my $division;
  if($species eq 'multi') {
    $division = "";
  }elsif($species eq 'pan_homology') {
    $division = "pan_ensembl/";
  }elsif($species eq 'bacteria'){
    #Bacteria compara is only a subset of data, we don't generate dumps for this database
    return;
  }else {
    $division = "$species/";
  }
  my $vals = {
	      division => $division
	     };
  $self->check_files($species, 'compara', $base_path, $expected_files, $vals);  
  return;
}

1;
