=head1 LICENSE

Copyright [2009-2015] EMBL-European Bioinformatics Institute

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

=head1 NAME

Bio::EnsEMBL::Production::Pipeline::Chainfile::DumpFile

=head1 DESCRIPTION

Generate the assembly chain files, which is made available via the ftp site
eg: ftp://ftp.ensemblgenomes.org/pub/metazoa/release-30/assembly_chain/

Logic adapted from script:
ensembl/misc-scripts/assembly/ensembl_assembly_to_chain.pl

=head1 MAINTAINER

ckong

=cut
package Bio::EnsEMBL::Production::Pipeline::Chainfile::DumpFile; 

use strict;
use warnings;
use base qw/Bio::EnsEMBL::Production::Pipeline::Base/;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::SqlHelper;
use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Utils::IO qw/work_with_file gz_work_with_file/;
use File::Spec::Functions qw/catdir/;
use File::Path qw/mkpath rmtree/;
use File::Spec;
use JSON;

my %ucsc_name_cache;

sub fetch_input {
    my ($self) = @_;

    my $eg       = $self->param_required('eg');
    my $compress = $self->param_required('compress');
    my $ucsc     = $self->param_required('ucsc');

    $self->param('eg', $eg);
    $self->param('compress', $compress);
    $self->param('ucsc', $ucsc);

    if($eg){
       my $base_path = $self->build_base_directory();
       my $release   = $self->param('eg_version');
       $self->param('base_path', $base_path);
       $self->param('release', $release);
    }

return;
}

sub run {
    my ($self) = @_;

    my $species   = $self->param_required('species');
    my $release   = $self->param_required('release');
    my $base_path = $self->param_required('base_path');
    my $core_dba  = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'core');
    confess('Type error!') unless($core_dba->isa('Bio::EnsEMBL::DBSQL::DBAdaptor'));

    my $chain_path = $self->get_data_path('assembly_chain');
    my $prod_name  = $core_dba->get_MetaContainer->get_production_name();
    $prod_name   //= $core_dba->species();
    my $liftovers  = get_liftover_mappings($core_dba);
 
    if(scalar(@{$liftovers})==0){
      $self->info('NO assembly to chain file available for %s', $prod_name);
      $self->info('Removing empty species directory for %s', $prod_name);
      rmtree($chain_path) if(-d $chain_path);
    return; 
    }
   
    $self->info('Producing assembly to chain file for %s', $prod_name);

    foreach my $mappings (@{$liftovers}) {
      my ($asm_cs, $cmp_cs) = @{$mappings};

      $self->info('Working with %s to %s', $asm_cs, $cmp_cs);
      $self->info('Fetching mappings');
      my $asm_to_cmp_mappings = get_assembly_mappings($self, $core_dba, $asm_cs, $cmp_cs);

      # If there is no assembly_mappings between coord versions 
      next unless scalar(@$asm_to_cmp_mappings > 0);
      write_mappings($self, $chain_path, $asm_cs, $cmp_cs, $prod_name, $asm_to_cmp_mappings, $core_dba);

      $self->info('Fetching reverse mappings');
      my $cmp_to_asm_mappings = get_reverse_assembly_mappings($self, $core_dba, $asm_cs, $cmp_cs);
      write_mappings($self, $chain_path, $cmp_cs, $asm_cs, $prod_name, $cmp_to_asm_mappings, $core_dba);
      $self->info('Completed processing %s', $prod_name);
    }

    $core_dba->dbc->disconnect_if_idle;

return;
}

sub write_output {
    my ($self) = @_;

}

1;

############
#SUBROUTINES
############

# Parse mapping keys like 
# # chromosome:WBcel235#chromosome:WBcel215
# # chromosome:GRCh37#chromosome:NCBI36 to ['GRCh37','NCBI36']
sub get_liftover_mappings {
  my ($dba) = @_;
  my $mappings = $dba->get_MetaContainer()->list_value_by_key('liftover.mapping');

return [ map { $_ =~ /.+:(.+)#.+:(.+)/; [$1, $2] } @{$mappings} ];
}

sub get_assembly_mappings {
    my ($self, $dba, $asm_version, $cmp_version) = @_;

    my $sql = get_sql(
     ['sr1.name as asm_name',
     'sr1.length as asm_length',
     'sr2.name as cmp_name',
     'sr2.length as cmp_length',
     'asm.asm_start', 'asm.asm_end', 'asm.cmp_start', 'asm.cmp_end'],
     'order by cs2.version, sr2.name, asm.cmp_start');

return $dba->dbc->sql_helper->execute( -SQL => $sql, -PARAMS => [$asm_version, $cmp_version], -USE_HASHREFS => 1);
}

sub write_mappings {
    my ($self, $dir, $source_cs, $target_cs, $prod_name, $mappings, $core_dba) = @_;

    my $file  = "${source_cs}_to_${target_cs}.chain";
    $file    .= '.gz' if $self->param('compress');
    my $path  = File::Spec->catfile($dir, $file);

    $self->info("\tBuilding chain mappings");
    my $chains      = build_chain_mappings($self, $mappings);
    my $ucsc_chains = [];

   if($self->param('ucsc')) {
     $self->info("\tBuilding UCSC mappings");
     $ucsc_chains = create_ucsc_chains($self, $core_dba, $prod_name, $chains);
   }

   $self->info("\tWriting mappings to $path");
   open my $fh,">","$path" or die $!;
 
   my $writer = sub {
      my ($fh) = @_;
      print_chains($self, $fh, $chains);
      print_chains($self, $fh, $ucsc_chains) if @{$ucsc_chains};
   };
  
   if($self->param('compress')) {
      gz_work_with_file($path, 'w', $writer);
   }
   else {
     work_with_file($path, 'w', $writer);
   }

return;
}

sub build_chain_mappings {
    my ($self, $assembly_mappings) = @_;

    my @chain_mappings;
    my ($t_name, $t_size, $t_strand, $t_start, $t_end);
    my ($q_name, $q_size, $q_strand, $q_start, $q_end);
    my $chain_id = 1;
    my @chain_gaps;
  
    my $length = scalar(@{$assembly_mappings});

    for (my $i = 0; $i < $length; $i++) {
       my $current = $assembly_mappings->[$i];
       my $next    = ($i+1 != $length) ? $assembly_mappings->[$i+1] : undef;
       my $ori     = $current->{ori};
       my ($asm_diff, $cmp_diff);

       if($next) {
         $asm_diff = ($next->{asm_start} - $current->{asm_end})-1;
         # Rev strands means the next cmp region has a lower start than the 
         # current end (because it's running in reverse). Rember length in 1-based
         # coords always is (high-low)-1
         $cmp_diff = ($ori == 1) ? ($next->{cmp_start} - $current->{cmp_end})-1 : ($current->{cmp_start} - $next->{cmp_end})-1;
       }
      
      if(! $t_name) {
        # Reset variables to current
        @chain_gaps = ();
        $chain_id++;
        ($t_name, $t_size, $t_strand, $t_start) = ($current->{asm_name}, $current->{asm_length}, 1, $current->{asm_start});
        ($q_name, $q_size, $q_strand) = ($current->{cmp_name}, $current->{cmp_length}, $current->{ori});
        $q_start = ($ori == 1) ? $current->{cmp_start} : $current->{cmp_end};
      }

      # Block that decides we need to start a new chain definition
      # Can mean we have run out of mappings, we are into a new chromsome (both source and target) 
      # or strand has swapped.
      # Final reason is we've had an out-of-order meaning a negative gap was produced 
      # (we're going backwards). In any situation this means the chain is finished
      if( ! defined $next || 
        $t_name ne $next->{asm_name} ||
        $q_name ne $next->{cmp_name} || # we can switch target chromosomes. e.g. cross chromsome mappings in mouse NCBI37->GRCm38
        $ori != $next->{ori} ||
        $asm_diff < 0 ||
        $cmp_diff < 0) {
        # Add the last gap on which is just the length of this alignment
        push(@chain_gaps, [$current->{length}]);
        # Set the ends of the chain since this is the last block
        $t_end = $current->{asm_end};
        $q_end = ($ori == 1) ? $current->{cmp_end} : $current->{cmp_start};
      
        if ($i != 0) {
          #If strand was negative we need to represent all data as reverse complemented regions
          if($q_strand == -1) {
              $q_start = ($q_size - $q_start)+1;
              $q_end   = ($q_size - $q_end)+1;
          }
        
          # Convert to UCSC formats (0-based half-open intervals and +/- strands)
          $t_start--;
          $q_start--;
          $t_strand = ($t_strand == 1) ? '+' : '-';
          $q_strand = ($q_strand == 1) ? '+' : '-';
        
          # Store the chain
          my $chain_score = 1;
          push(@chain_mappings, {
              header => ['chain', $chain_score, $t_name, $t_size, $t_strand, $t_start, $t_end, $q_name, $q_size, $q_strand, $q_start, $q_end, $chain_id],
              gaps => [@chain_gaps]
          });
      }

      if(! defined $next) {
        last;
      }

      # Clear variables
      ($t_name, $t_size, $t_strand, $t_start) = ();
      ($q_name, $q_size, $q_strand, $q_start) = ();
    }
    push(@chain_gaps, [$current->{length}, $asm_diff, $cmp_diff]);
  }

return \@chain_mappings;
}

sub create_ucsc_chains {
    my ($self, $dba, $prod_name, $chains) = @_;
    my @new_chains;

    foreach my $chain_def (@{$chains}) {
      my $ensembl_name = $chain_def->{header}->[2];
      my $target_name  = ensembl_to_ucsc_name($self, $dba, $prod_name, $ensembl_name);
      next if $ensembl_name eq $target_name;
      my $new_chain_def = decode_json(encode_json($chain_def)); # quick clone
      # Substitute tName which in a GRCh37 -> GRCh38 mapping tName is GRCh37's code
      $new_chain_def->{header}[2] = $target_name;
      push(@new_chains, $new_chain_def);
    }

return \@new_chains;
}

sub ensembl_to_ucsc_name {
    my ($self, $dba, $prod_name, $ensembl_name) = @_;

    return $ucsc_name_cache{$prod_name}{$ensembl_name} if exists $ucsc_name_cache{$prod_name}{$ensembl_name};
    # Default is Ensembl name
    my $ucsc_name = $ensembl_name;
    my $slice     = $dba->get_SliceAdaptor()->fetch_by_region(undef, $ensembl_name);
    my $synonyms  = $slice->get_all_synonyms('UCSC');

    if(@{$synonyms}) {
      $ucsc_name = $synonyms->[0]->name();
    } else {
      #MT is a special case; it's chrM
      if($slice->is_chromosome()) { $ucsc_name = 'chrM' if($ensembl_name eq 'MT' );}
      # If it was a ref region add chr onto it (only check if we have an adaptor)
      elsif($slice->is_reference()) { $ucsc_name = 'chr'.$ensembl_name; }
    }

return $ucsc_name_cache{$prod_name}{$ensembl_name} = $ucsc_name;  
}

sub print_chains {
    my ($self, $fh, $chains) = @_;

    while(my $chain_def = shift @{$chains}) {
      my $header = $chain_def->{header};
      my $gaps   = $chain_def->{gaps};

      print $fh join(q{ }, @{$header});
      print $fh "\n";
    
      foreach my $gap (@{$gaps}) {
        print $fh join(q{ }, @{$gap});
        print $fh "\n";
      }

    print $fh "\n";
   }

return;
}

sub get_reverse_assembly_mappings {
    my ($self, $dba, $asm_version, $cmp_version) = @_;
    # Reverse the columns to get the reverse mapping

    my $sql = get_sql(
     ['sr1.name as cmp_name', 
     'sr1.length as cmp_length', 
     'sr2.name as asm_name', 
     'sr2.length as asm_length', 
     'asm.cmp_start as asm_start', 'asm.cmp_end as asm_end', 'asm.asm_start as cmp_start', 'asm.asm_end as cmp_end'],
     'order by cs2.version, sr2.name, asm.cmp_start');

return $dba->dbc->sql_helper->execute( -SQL => $sql, -PARAMS => [$asm_version, $cmp_version], -USE_HASHREFS => 1);
}

sub get_sql {
    my ($columns, $order_by) = @_;
    my $select = join(q{, }, @{$columns}, 'asm.ori', '(asm.asm_end - asm.asm_start)+1 as length');
  return <<SQL;
select ${select}
from coord_system cs1
join seq_region sr1 on (cs1.coord_system_id = sr1.coord_system_id)
join assembly asm on (sr1.seq_region_id = asm.asm_seq_region_id)
join seq_region sr2 on (sr2.seq_region_id = asm.cmp_seq_region_id)
join coord_system cs2 on (sr2.coord_system_id = cs2.coord_system_id)
where cs1.version =?
and cs2.version =?
$order_by
SQL
}
