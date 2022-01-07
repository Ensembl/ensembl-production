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

package Bio::EnsEMBL::Production::Pipeline::FtpChecker::CheckVariationFtp;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::FtpChecker::CheckFtp/;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Data::Dumper;

use Log::Log4perl qw/:easy/;

my $expected_files = {
		      "vcf" => {"dir" => "{division}/vcf/{species_dir}/", "excepted" =>[
							'{species}*.vcf.gz',
							'{species}_incl_consequences*.vcf.gz',
							'{species}*.vcf.gz.tbi',
							'{species}_incl_consequences*.vcf.gz.tbi',
							 'README*',
							 'CHECKSUMS*'
						       ]},
		      "gvf" => {"dir" => "{division}/gvf/{species_dir}/", "excepted" =>[
							'{species}*.gvf.gz',
							'{species}_failed*.gvf.gz',
							'{species}_incl_consequences*.gvf.gz',
							 'README*',
							 'CHECKSUMS*'
						       ]}
};

sub run {
  my ($self) = @_;
  my $species = $self->param('species');
  if ( $species !~ /Ancestral sequences/ ) {
    Log::Log4perl->easy_init($DEBUG);
    $self->{logger} = get_logger();
    my $base_path = $self->param('base_path');
    $self->{logger}->info("Checking $species on $base_path");
    my $vals = {};
    $vals->{species} = $species;    
    $vals->{species_uc} = ucfirst $species;
    my $dba = $self->core_dba();
    if($dba->dbc()->dbname() =~ m/^(.*_collection)_core_.*/) {
      $vals->{species_dir} = $1.'/'.$species;
      $vals->{collection_dir} = $1.'/';
    } else {
      $vals->{species_dir} = $species;
      $vals->{collection_dir} = '';
    }
    my $division = $dba->get_MetaContainer()->get_division();   
    $dba->dbc()->disconnect_if_idle();
    if(defined $division) {
      $division = lc ($division);
      $division =~ s/ensembl//i;
    }
    if ($division eq "vertebrates"){
      $division = "";
    }
    $vals->{division} = $division;
    $self->check_files($species, 'variation', $base_path, $expected_files, $vals);
  }
  return;
}

1;
