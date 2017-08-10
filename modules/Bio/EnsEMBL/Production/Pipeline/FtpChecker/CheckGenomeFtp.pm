
=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::FtpChecker::CheckGenomeFtp;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Data::Dumper;

my $expected_files = {
		      "{division}/embl/{species_dir}/"=>[
							'{species_uc}.*.dat.gz',
							 'README',
							 'CHECKSUMS'
						       ],
		      "{division}/genbank/{species_dir}/"=>[
							'{species_uc}.*.dat.gz',
							 'README',
							 'CHECKSUMS'
						       ],
		      "{division}/gtf/{species_dir}/"=>[
							'{species_uc}.*.gtf.gz',
							 'README',
							 'CHECKSUMS'
						       ],
		      "{division}/gff3/{species_dir}/"=>[
							'{species_uc}.*.gff3.gz',
							 'README',
							 'CHECKSUMS'
						       ],
		      "{division}/vep/{collection_dir}"=>[
							'{species}_vep*.tar.gz',
							 'CHECKSUMS'
						       ],
		      "{division}/json/{species_dir}/"=>[
							'{species}.json.gz',
							 'CHECKSUMS'
						       ],
		      "{division}/rdf/{species_dir}/"=>[
							'{species}.ttl.gz',
							'{species}.ttl.gz.graph',
							'{species}_xrefs.ttl.gz',
							'{species}_xrefs.ttl.gz.graph',
							 'CHECKSUMS'
						       ],
		      "{division}/tsv/{species_dir}/"=>[
							'{species}.ena.ttl.gz',
							'{species}.entrez.ttl.gz',
							'{species}.karyotype.ttl.gz',
							'{species}.refseq.ttl.gz',
							'{species}.uniprot.ttl.gz',
							 'README_ENA.tsv',
							 'README_entrez.tsv',
							 'README_refseq.tsv',
							 'README_uniprot.tsv',
							 'CHECKSUMS'
						       ],
		      "{division}/fasta/{species_dir}/pep/"=>[
							'{species_uc}.*.fa.gz',
							 'README',
							 'CHECKSUMS'
						       ],
		      "{division}/fasta/{species_dir}/cdna/"=>[
							'{species_uc}.*.fa.gz',
							 'README',
							 'CHECKSUMS'
						       ],
		      "{division}/fasta/{species_dir}/cds/"=>[
							'{species_uc}.*.fa.gz',
							 'README',
							 'CHECKSUMS'
						       ],
#		      "{division}/fasta/{species_dir}/ncrna/"=>[
#							'{species_uc}.*.fa.gz',
#							 'README',
#							 'CHECKSUMS'
#						       ],
		      "{division}/fasta/{species_dir}/dna/"=>[
							'{species_uc}.*.fa.gz',
							 'README',
							 'CHECKSUMS'
						       ],
		      "{division}/fasta/{species_dir}/dna_index/"=>[
							'{species_uc}.*.fa.gz',
							'{species_uc}.*.fa.gz.fai',
							'{species_uc}.*.fa.gz.gzi',
							 'README',
							 'CHECKSUMS'
						       ],
};

sub run {
  my ($self) = @_;
  my $species = $self->param('species');
  if ( $species ne "Ancestral sequences" ) {
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
      $vals->{division} = $division if $division ne '';
    }
    my $base_path = $self->param('base_path');
    while( my($dir,$files) = each %$expected_files) { 
      for my $file (@$files) {
	my $path = _expand_str($base_path.'/'.$dir.'/'.$file, $vals);
	my @files = glob($path);
	if(scalar(@files) == 0) {
	  print "Could not find $path\n";
	  push @problems, $path;
	}
      }
    }    
  }
  return;
}

sub _expand_str {
  my ($template, $vals) = @_;
  my $str = $template;
  while(my ($k,$v) = each %$vals) {
    $str =~ s/\{$k\}/$v/g;
  }
  return $str;
}

1;
