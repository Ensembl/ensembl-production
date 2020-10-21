package Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::variants::VariantsScaler;

use Moose;
use Path::Tiny qw(path);
use JSON qw/decode_json/;
use Array::Utils qw(intersect);


use Bio::EnsEMBL::Production::Pipeline::Webdatafile::lib::GenomeLookup;

my $initial_scale = 1;
my $scale_multiplier = 4;
my @scale_names = reverse ('a'..'z');

has 'input_bed_file' => ( isa => 'Path::Tiny', is => 'ro', required => 1 );
has 'genome_id' => ( isa => 'Str', is => 'ro' );

has 'current_scale' => ( isa => 'Int', is => 'rw', default => 1 );
has 'current_scale_name_index' => ( isa => 'Int', is => 'rw', default => 0 );
has 'current_output_file_handle' => ( isa => 'FileHandle', is => 'rw' );
has 'meaningful_file_name' => ( isa => 'Str', is => 'rw' );
has 'written_files_count' => ( isa => 'Int', is => 'rw', default => 0 );
has 'last_written_lines_count' => ( isa => 'Int', is => 'rw' );
has 'last_written_bed_file_name' => ( isa => 'Str', is => 'rw' );
has 'temp_lines_storage' => ( isa => 'ArrayRef', is => 'rw', default => sub { [] }, clearer => 'clear_temp_lines_storage' );

has 'genome' => (isa => 'Any', is => 'rw');

has 'variant_categories' => ( isa => 'ArrayRef', is => 'rw', default => sub {[]});

has 'variant_path'   => ( isa => 'Path::Tiny', is => 'ro', required => 1 );

my $current_scale_boundary;
my $current_scale_index;

sub scale_variants_bed {
  my ($self) = @_;

  if ($self->should_scale()) {
    $self->do_scaling();
    $self->update_scale();

    # yay, recursion!
    $self->scale_variants_bed();
  }

}

sub should_scale {
  my ($self) = @_;
  return !$self->written_files_count ||
        $self->current_scale_name_index < scalar @scale_names &&  $self->last_written_lines_count > 1;
}

sub update_scale {
  my ($self) = @_;
  $self->current_scale($self->current_scale * $scale_multiplier);
  $self->current_scale_name_index($self->current_scale_name_index + 1);
}

sub do_scaling {
  my ($self) = @_;
  my $input_file_path = $self->get_input_file_path();
  my $output_file_path = $self->get_output_bed_file_path();
  open(my $input_file_handle, '<', $input_file_path) or die "Could not open file '$input_file_path' $!";
  open(my $output_file_handle, '>', $output_file_path) or die "Could not open file '$output_file_path' $!";
  $self->report_status();
  $self->last_written_lines_count(0);

  while (my $row = <$input_file_handle>) {
    chomp $row;
    $self->process_row($row, $output_file_handle);
  }
  $self->process_last_row($output_file_handle);

  close($input_file_handle);
  close($output_file_handle);

  $self->last_written_bed_file_name($self->get_output_bed_file_name());
  $self->written_files_count($self->written_files_count + 1);
  $self->reset_temp_lines_storage();
}

sub process_row {
  $\ = "\n"; # use line break for output separator
  my ($self, $row, $output_file_handle) = @_;
  my @split_line = split(/\t/, $row);
  my ($chromosome, $start, $end, $variant) = @split_line;
  if (!$chromosome || !$start || !$end || !$variant) {
    return;
  }
  my ($first_line_ref) = @{ $self->temp_lines_storage };

  if (!$first_line_ref) {
    push (@{$self->temp_lines_storage}, \@split_line);
  } else {
    my ($stored_chromosome, $stored_start) = @{$first_line_ref};
    if ($chromosome eq $stored_chromosome && ($end - $stored_start <= $self->current_scale)) {
      push (@{$self->temp_lines_storage}, \@split_line);
    } else {
      my @average_variant = $self->build_average_variant();
      print $output_file_handle join("\t", @average_variant);
      $self->last_written_lines_count($self->last_written_lines_count + 1);

      $self->temp_lines_storage([]);
      push (@{$self->temp_lines_storage}, \@split_line);
    }
  }
}

sub process_last_row {
  $\ = "\n"; # use line break for output separator
  my ($self, $output_file_handle) = @_;
  if (scalar @{ $self->temp_lines_storage }) {
    my @average_variant = $self->build_average_variant();
    print $output_file_handle join("\t", @average_variant);
    $self->last_written_lines_count($self->last_written_lines_count + 1);
  }
}

sub build_average_variant {
  my ($self) = @_;
  my @variants = @{$self->temp_lines_storage};
  my ($first_variant) = @variants;
  my $chromosome = $first_variant->[0];
  my @start_positions = map { $_->[1] } @variants;
  my @end_positions = map { $_->[2] } @variants;
  my @variant_categories = map { $_->[3] } @variants;
  my $start_position = shift @{[sort {$a <=> $b} @start_positions]};
  my $end_position = shift @{[sort {$b <=> $a } @end_positions]};
  my @variants_intersection = intersect(@variant_categories, @{$self->get_all_variant_categoties()});
  my $winning_variant = shift @variants_intersection;

  return ($chromosome, $start_position, $end_position, $winning_variant);
}

sub reset_temp_lines_storage {
  my ($self) = @_;
  $self->clear_temp_lines_storage;
  $self->temp_lines_storage([]);
}

sub get_input_file_path {
  my ($self) = @_;
  my $file_name;
  my $dir_path = $self->get_variants_dir_path();

  if ($self->last_written_bed_file_name) {
    $file_name = $self->last_written_bed_file_name;
    return "$dir_path/$file_name";
  } else {
    return $self->input_bed_file->stringify;
  }

}

sub get_output_bed_file_path {
  my ($self) = @_;
  return $self->get_variants_dir_path() . '/' . $self->get_output_bed_file_name();
}

sub get_output_bed_file_name {
  my ($self) = @_;
  return $self->get_meaningful_file_name() . '.' . @scale_names[$self->current_scale_name_index] . '.bed';
}

sub prepare_for_scaling {
  my ($self) = @_;
  $self->bump_scaling_factor();
}

sub bump_scaling_factor {
  my ($self) = @_;
  if (!$self->current_scale) {
    $self->current_scale(1);
  } else {
    $self->current_scale($self->current_scale * 4);
  }
}

sub get_meaningful_file_name {
  my ($self) = @_;
  if (!$self->meaningful_file_name) {
    my ($meaningful_file_name) = $self->input_bed_file->basename =~ /(.+)\.bed$/;
    $self->meaningful_file_name($meaningful_file_name);
  }
  return $self->meaningful_file_name;
}

sub get_variants_dir_path {
  my ($self) = @_;
  return $self->variant_path; 
}

sub get_all_variant_categoties {
  my ($self) = @_;
  if (!scalar @{$self->variant_categories}) {
    my $path_to_json = path(__FILE__)->absolute->parent(1)->child('variant_categories.json');
    open my $fh, '<', $path_to_json or die "Can't open file $!";
    my $file_content = do { local $/; <$fh> };
    my $json = decode_json($file_content);
    my @sorted = sort { $json->{$b} <=> $json->{$a} } keys %{$json};
    $self->variant_categories(\@sorted);
  }
  return $self->variant_categories;
}

sub report_status {
  my ($self) = @_;
  print "Converting " . $self->input_bed_file->basename . ' to scale '
    . @scale_names[$self->current_scale_name_index]
    . ' (' . $self->current_scale . 'bp)...';
}

__PACKAGE__->meta->make_immutable;

1;
