=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::Production::PepStatsBatch;

use strict;
use warnings;
use Log::Log4perl qw(get_logger :levels);
use base qw/Bio::EnsEMBL::Production::Pipeline::Production::PepStats/;

use Bio::EnsEMBL::Attribute;

sub run {
  my ($self)  = @_;
  my $species = $self->param('species');
  my $dbtype  = $self->param('dbtype');
  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species, $dbtype);
  if ($dbtype =~ 'vega' || $dbtype =~ 'otherf') {
	my $core_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'core');
	$dba->dnadb($core_dba);
  }
  my $log    = get_logger();
  my $helper = $dba->dbc()->sql_helper();

  my @attrib_codes = $self->get_attrib_codes();
  $log->info("Deleting old codes");
  $self->delete_old_attrib($dba, @attrib_codes);

  my $tmpfile = $self->param('tmpdir') . "/$$.pep";
  $log->info("Dumping translations");
  $self->dump_translation($dba, $tmpfile);
  $log->info("Running pepstats");
  my $results = $self->run_pepstats($tmpfile);

  $log->info("Storing attribs");
  $self->store_attribs($dba, $results);
  $log->info("Completed");
} ## end sub run

sub store_attribs {

  my ($self, $dba, $results) = @_;

  my $attrib_types = $self->get_attrib_types();

  # transform results into a hash
  # $attributes is a hashref where the key is the object ID
  # and the value is an array ref of Attribute objects
  my $attributes = {};
  foreach my $translation (keys %$results) {
	foreach my $key (keys %{$results->{$translation}}) {

	  my $value       = $results->{$translation}{$key};
	  my $attrib_type = $attrib_types->{$key};

	  push @{$attributes->{$translation}},
		Bio::EnsEMBL::Attribute->new(-NAME        => $attrib_type->{name},
									 -CODE        => $key,
									 -VALUE       => $value,
									 -DESCRIPTION => $attrib_type->{description});
	}
  }
  my $aa = $dba->get_AttributeAdaptor();
  $aa->store_batch_on_Translation($attributes,1000);
  return;
} ## end sub store_attribs
1;
