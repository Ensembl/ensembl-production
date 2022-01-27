package Bio::EnsEMBL::Production::Pipeline::Common::MetadataCSVersion;

use strict;
use warnings;

use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::Registry;

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

sub run {
    my ($self) = @_;
    # Parse filename to get $target_species
    my $species = $self->param('species');
    my $core_adaptor = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'core');
    my $mca = $core_adapter->get_MetaContainer()
    my $cs_version = $mca->single_value_by_key('assembly.name');
    my $core_dbc = $core_adaptor->dbc;


    $self->dataflow_output_id({
          'host'    => $core_dbc->host,
          'dbname'  => $core_dbc->dbname,
          'port'    => $core_dbc->port,
          'user'    => $core_dbc->user,
          'pass'    => $core_dbc->pass,
          'cs_version'=> $cs_version,
          'species' => $species,
         },
       2
    );
}

1;