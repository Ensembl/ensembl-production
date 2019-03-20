
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

package Bio::EnsEMBL::Production::Search::EBeyeGenomeWrapper;

use warnings;
use strict;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Data::Dumper;
use Log::Log4perl qw/get_logger/;
use List::MoreUtils qw/natatime/;

use Carp;
use File::Slurp;
use File::Spec;
use POSIX 'strftime';
use XML::Writer;
use XML::LibXML;
use Data::Dumper;
use Exporter 'import';
our @EXPORT = qw(_array_nonempty _id_ver _base);

my $date = strftime '%Y-%m-%d', localtime;

sub new {
	my ( $class, @args ) = @_;
	my $self = bless( {}, ref($class) || $class );
	$self->{log} = get_logger();

	return $self;
}

sub log {
	my ($self) = @_;
	return $self->{log};
}

sub wrap_genomes {

	my ( $self, $ebeye_xml_dir, $division, $release_version ) = @_;
	my $out_path = File::Spec->catfile($ebeye_xml_dir,'ebeye');

        my $genome_file_out = File::Spec->catfile($out_path,'Genome_Ensembl' . $division . '.xml');

        my @genome_xml_files = File::Find::Rule->file->name("*_genome.xml")->in($out_path);

        open my $fh, '>', $genome_file_out or croak "Could not open $genome_file_out for writing";

        my $writer = XML::Writer->new( OUTPUT => $fh, DATA_MODE => 1, DATA_INDENT => 2, UNSAFE => 1 );
        $writer->xmlDecl("ISO-8859-1");
        $writer->doctype("database");
        $writer->startTag("database");
        $writer->dataElement(name => $division);
        $writer->dataElement(release => $release_version);
        $writer->startTag("entries");

       
        foreach my $genome_xml (@genome_xml_files)
                {
                 
                my $genome_dom = XML::LibXML->load_xml(location => $genome_xml);
                my @genome_entry_nodes = $genome_dom->findnodes('entry');
                $writer->raw($genome_entry_nodes[0]);
                }

        $writer->endTag("entries");
        $writer->endTag("database");
        $writer->end();
        close $fh;
	return $genome_file_out;

} 

sub wrap_genome_files {

        my ( $self, $ebeye_xml_dir, %genome_xml_files, $division, $release_version ) = @_;
        my $out_path = File::Spec->catfile($ebeye_xml_dir,'ebeye');

        my $genome_file_out = File::Spec->catfile($out_path,'Genome_Ensembl' . $division . '.xml');

        #my @genome_xml_files = File::Find::Rule->file->name("*_genome.xml")->in($out_path);

        open my $fh, '>', $genome_file_out or croak "Could not open $genome_file_out for writing";

        my $writer = XML::Writer->new( OUTPUT => $fh, DATA_MODE => 1, DATA_INDENT => 2, UNSAFE => 1 );
        $writer->xmlDecl("ISO-8859-1");
        $writer->doctype("database");
        $writer->startTag("database");
        $writer->dataElement(name => $division);
        $writer->dataElement(release => $release_version);
        $writer->startTag("entries");
	warn Dumper("IN FUNC", %genome_xml_files);

        foreach my $genome_xml (values %genome_xml_files)
                {

                my $genome_dom = XML::LibXML->load_xml(location => $genome_xml);
                my @genome_entry_nodes = $genome_dom->findnodes('entry');
                $writer->raw($genome_entry_nodes[0]);
                }

        $writer->endTag("entries");
        $writer->endTag("database");
        $writer->end();
        close $fh;
        return $genome_file_out;

}
