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

package Bio::EnsEMBL::Production::Pipeline::FileDump::Assembly_Chain; 

use strict;
use warnings;
use feature 'say';
use base qw(Bio::EnsEMBL::Production::Pipeline::FileDump::Base_Filetype);

use File::Spec::Functions qw/catdir/;
use JSON;
use Path::Tiny;

sub param_defaults {
  my ($self) = @_;

  return {
    %{$self->SUPER::param_defaults},
    data_type => 'assembly_mapping',
    file_type => 'chain',
    ucsc      => 1,
  };
}

sub fetch_input {
  my ($self) = @_;

  my $overwrite  = $self->param_required('overwrite');
  my $output_dir = $self->param_required('output_dir');
  my $data_type  = $self->param_required('data_type');

  my $chain_dir = catdir($output_dir, $data_type);

  if (-e $chain_dir) {
    if (! $overwrite) {
      $self->complete_early('Files exist and will not be overwritten');
    }
  }

  $self->param('chain_dir', $chain_dir);
}

sub run {
  my ($self) = @_;

  my $file_type    = $self->param_required('file_type');
  my $web_dir      = $self->param_required('web_dir');
  my $species_name = $self->param_required('species_name');
  my $chain_dir    = $self->param_required('chain_dir');

  my $dba = $self->dba;

  my $liftovers = $self->liftover_config($dba);
 
  if (scalar(@{$liftovers})) {
    path($chain_dir)->mkpath();

    $self->param('ucsc_name_cache', {});

    foreach my $liftover (@{$liftovers}) {
      my ($from, $to) = @$liftover;

      my $filename = $self->generate_custom_filename(
        $chain_dir, "${from}_to_${to}", $file_type);
      if (defined $filename) {
        my $mappings = $self->liftover_mappings($dba, $from, $to);
        if (scalar(@$mappings)) {
          $self->write_mappings($dba, $from, $to, $mappings, $filename);
        }
      }

      my $reverse_filename = $self->generate_custom_filename(
        $chain_dir, "${to}_to_${from}", $file_type);
      if (defined $reverse_filename) {
        my $reverse_mappings = $self->reverse_liftover_mappings($dba, $from, $to);
        if (scalar(@$reverse_mappings)) {
          $self->write_mappings($dba, $to, $from, $reverse_mappings, $reverse_filename);
        }
      }
    }
  } else {
    $self->complete_early('Species does not have liftover mappings');
  }

  $dba->dbc->disconnect_if_idle();
}

sub liftover_config {
  my ($self, $dba) = @_;
  my $mca = $dba->get_adaptor('MetaContainer');
  my $mappings = $mca->list_value_by_key('liftover.mapping');

  return [ map { $_ =~ /.+:(.+)#.+:(.+)/; [$1, $2] } @{$mappings} ];
}

sub liftover_mappings {
  my ($self, $dba, $from, $to) = @_;

  my $sql = get_sql(
    ['sr1.name as asm_name',
     'sr1.length as asm_length',
     'sr2.name as cmp_name',
     'sr2.length as cmp_length',
     'asm.asm_start',
     'asm.asm_end',
     'asm.cmp_start',
     'asm.cmp_end'
    ],
    'order by cs2.version, sr2.name, asm.cmp_start'
  );

  return $dba->dbc->sql_helper->execute(
    -SQL => $sql,
    -PARAMS => [$from, $to],
    -USE_HASHREFS => 1
  );
}

sub reverse_liftover_mappings {
  my ($self, $dba, $from , $to) = @_;

  my $sql = get_sql(
    ['sr1.name as cmp_name', 
     'sr1.length as cmp_length', 
     'sr2.name as asm_name', 
     'sr2.length as asm_length', 
     'asm.cmp_start as asm_start',
     'asm.cmp_end as asm_end',
     'asm.asm_start as cmp_start',
     'asm.asm_end as cmp_end'
    ],
    'order by cs2.version, sr2.name, asm.cmp_start'
  );

  return $dba->dbc->sql_helper->execute(
    -SQL => $sql,
    -PARAMS => [$from, $to],
    -USE_HASHREFS => 1
  );
}

sub get_sql {
  my ($columns, $order_by) = @_;

  my $select = join(q{, },
    @{$columns},
    'asm.ori',
    '(asm.asm_end - asm.asm_start)+1 as length'
  );
  my $sql = qq/
    SELECT ${select} FROM
      coord_system cs1 INNER JOIN
      seq_region sr1 ON (cs1.coord_system_id = sr1.coord_system_id) INNER JOIN
      assembly asm ON (sr1.seq_region_id = asm.asm_seq_region_id) INNER JOIN
      seq_region sr2 ON (sr2.seq_region_id = asm.cmp_seq_region_id) INNER JOIN
      coord_system cs2 ON (sr2.coord_system_id = cs2.coord_system_id)
    WHERE cs1.version = ? AND cs2.version = ?
    $order_by
  /;

  return $sql;
}

sub write_mappings {
  my ($self, $dba, $from, $to, $mappings, $filename) = @_;

  my $chains = $self->build_chain_mappings($mappings);
  my $ucsc_chains = [];
  if ($self->param('ucsc')) {
    $ucsc_chains = $self->create_ucsc_chains($dba, $chains);
  }

  my $fh = path($filename)->filehandle('>');
  print_chains($self, $fh, $chains);
  print_chains($self, $fh, $ucsc_chains) if @{$ucsc_chains};
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
  my ($self, $dba, $chains) = @_;
  my @new_chains;

  foreach my $chain_def (@{$chains}) {
    my $ensembl_name = $chain_def->{header}->[2];
    my $target_name  = $self->ensembl_to_ucsc_name($dba, $ensembl_name);
    next if $ensembl_name eq $target_name;
    my $new_chain_def = decode_json(encode_json($chain_def)); # quick clone
    $new_chain_def->{header}[2] = $target_name;
    push(@new_chains, $new_chain_def);
  }

  return \@new_chains;
}

sub ensembl_to_ucsc_name {
  my ($self, $dba, $ensembl_name) = @_;
  my $ucsc_name_cache = $self->param('ucsc_name_cache');

  return $$ucsc_name_cache{$ensembl_name} if exists $$ucsc_name_cache{$ensembl_name};

  my $ucsc_name = $ensembl_name;
  my $slice     = $dba->get_adaptor('Slice')->fetch_by_region(undef, $ensembl_name);
  my $synonyms  = $slice->get_all_synonyms('UCSC');

  if (@{$synonyms}) {
    $ucsc_name = $synonyms->[0]->name();
  } else {
    if ($slice->is_chromosome) {
      if ($ensembl_name eq 'MT') {
        $ucsc_name = 'chrM';
      } elsif ($slice->is_reference) {
        $ucsc_name = 'chr'.$ensembl_name;
      }
    }
  }

  $$ucsc_name_cache{$ensembl_name} = $ucsc_name;
  $self->param('ucsc_name_cache', $ucsc_name_cache);

  return $ucsc_name;  
}

sub print_chains {
  my ($self, $fh, $chains) = @_;

  while(my $chain_def = shift @{$chains}) {
    my $header = $chain_def->{header};
    my $gaps   = $chain_def->{gaps};

    say $fh join(q{ }, @{$header});

    foreach my $gap (@{$gaps}) {
      say $fh join(q{ }, @{$gap});
    }

    print $fh "\n";
  }
}

1;
