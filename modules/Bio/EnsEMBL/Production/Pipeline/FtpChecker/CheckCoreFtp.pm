=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::FtpChecker::CheckCoreFtp;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::FtpChecker::CheckFtp/;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Data::Dumper;

use Log::Log4perl qw/:easy/;

my $expected_files = {
		      "embl" => {"dir" => "{division}/embl/{species_dir}/", "expected" =>[
							'{species_uc}.*.dat.gz',
							 'README*',
							 'CHECKSUMS*'
						       ]},
		      "genbank" => {"dir" => "{division}/genbank/{species_dir}/", "expected" =>[
							'{species_uc}.*.dat.gz',
							 'README*',
							 'CHECKSUMS*'
						       ]},
		      "gtf" => {"dir" => "{division}/gtf/{species_dir}/", "expected" =>[
							'{species_uc}.*.gtf.gz',
							 'README*',
							 'CHECKSUMS*'
						       ]},
		      "gff3" => {"dir" => "{division}/gff3/{species_dir}/", "expected" =>[
							'{species_uc}.*.gff3.gz',
							 'README*',
							 'CHECKSUMS*'
						       ]},
		      "vep" => {"dir" => "{division}/variation/vep/{collection_dir}", "expected" =>[
							'{species}_vep*.tar.gz',
							 'CHECKSUMS*'
						       ]},
		      "json" => {"dir" => "{division}/json/{species_dir}/", "expected" =>[
							'{species}*.json',
							 'CHECKSUMS*'
						       ]},
		      "rdf" => {"dir" => "{division}/rdf/{species_dir}/", "expected" =>[
							'{species}*.ttl.gz',
							'{species}*.ttl.gz.graph',
							'{species}_xrefs*.ttl.gz',
							'{species}_xrefs*.ttl.gz.graph',
							 'CHECKSUMS*'
						       ]},
		      "tsv" => {"dir" => "{division}/tsv/{species_dir}/", "expected" =>[
							'{species_uc}*.ena.tsv.gz',
							'{species_uc}*.entrez.tsv.gz',
							'{species_uc}*.karyotype.tsv.gz',
							'{species_uc}*.refseq.tsv.gz',
							'{species_uc}*.uniprot.tsv.gz',
							 'README_ENA*.tsv',
							 'README_entrez*.tsv',
							 'README_refseq*.tsv',
							 'README_uniprot*.tsv',
							 'CHECKSUMS*'
						       ]},
		      "fasta_pep" => {"dir" => "{division}/fasta/{species_dir}/pep/", "expected" =>[
							'{species_uc}.*.fa.gz',
							 'README*',
							 'CHECKSUMS*'
						       ]},
		      "fasta_cdna" => {"dir" => "{division}/fasta/{species_dir}/cdna/", "expected" =>[
							'{species_uc}.*.fa.gz',
							 'README*',
							 'CHECKSUMS*'
						       ]},
		      "fasta_cds" => {"dir" => "{division}/fasta/{species_dir}/cds/", "expected" =>[
							'{species_uc}.*.fa.gz',
							 'README*',
							 'CHECKSUMS*'
						       ]},
		      "fasta_dna" => {"dir" => "{division}/fasta/{species_dir}/dna/", "expected" =>[
							'{species_uc}.*.fa.gz',
							 'README*',
							 'CHECKSUMS*'
						       ]},
		      "fasta_dna_index" => {"dir" => "{division}/fasta/{species_dir}/dna_index/", "expected" =>[
							'{species_uc}.*.fa.gz',
							'{species_uc}.*.fa.gz.fai',
							'{species_uc}.*.fa.gz.gzi',
							 'CHECKSUMS*'
						       ]},
};

sub run {
  my ($self) = @_;
  my $species = $self->param('species');
  if ( $species ne "Ancestral sequences" ) {
    Log::Log4perl->easy_init($DEBUG);
    $self->{logger} = get_logger();
    my $base_path = $self->param('base_path');
    $self->{logger}->info("Checking $species on $base_path");
    my $dba = $self->core_dba();
    my $vals = {};
    $vals->{species} = $species;    
    $vals->{species_uc} = ucfirst $species;
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
    $self->check_files($species, 'core', $base_path, $expected_files, $vals);
  }
  return;
}

1;
