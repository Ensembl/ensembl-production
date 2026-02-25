=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2025] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Production::Pipeline::GPAD::LoadFile;

use strict;
use warnings;

use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::Registry;

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

sub run {
    my ($self) = @_;
    my $species    = $self->param_required('species');
    my $file       = $self->param_required('gpad_file');
    my $logic_name = $self->param_required('logic_name');

    my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'core');
    my $hive_dbc = $self->dbc;
    $hive_dbc->disconnect_if_idle() if defined $self->dbc;

    $self->log()->info("Loading $species from $file");

    my $odba = Bio::EnsEMBL::Registry->get_adaptor('multi', 'ontology', 'OntologyTerm');
    my $gos  = $self->fetch_ontology($odba);
    $odba->dbc->disconnect_if_idle();

    my $analysis_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, "core", "analysis");
    my $analysis         = $analysis_adaptor->fetch_by_logic_name($logic_name);
    die "Could not find analysis with logic_name '$logic_name' for species '$species'"
        unless defined $analysis;

    my $tl_adaptor  = $dba->get_TranslationAdaptor();
    my $dbe_adaptor = $dba->get_DBEntryAdaptor();
    my $t_adaptor   = $dba->get_TranscriptAdaptor();

    # ------------------------------------------------------------------
    # Pre-load all translations and their transcripts into memory.
    # For human/mouse these hashes will be large but give us O(1) lookup
    # for every tgt_protein stable_id hit in the file, with zero repeat
    # DB queries.
    # ------------------------------------------------------------------
    $self->log()->info("Pre-loading all translations for $species");
    my %translation_hash;   # stable_id  -> translation object
    my %transcript_hash;    # stable_id  -> transcript object (keyed by translation stable_id)

    my $all_translations = $tl_adaptor->fetch_all();
    foreach my $tl (@$all_translations) {
        my $tl_stable_id = $tl->stable_id;
        my $tr           = $tl->transcript;
        die "Transcript not found for translation '$tl_stable_id' during pre-load"
            unless defined $tr;
        $translation_hash{$tl_stable_id} = $tl;
        $transcript_hash{$tl_stable_id}  = $tr;
    }
    $self->log()->info("Pre-loaded " . scalar(keys %translation_hash) . " translations");

    # ------------------------------------------------------------------
    # Pre-load all transcripts into memory, keyed by stable_id.
    # Used for any path that needs to resolve a transcript stable_id
    # directly (e.g. tgt_transcript if re-introduced, or future use).
    # ------------------------------------------------------------------
    $self->log()->info("Pre-loading all transcripts for $species");
    my %transcript_by_stable_id;    # stable_id -> transcript object

    my $all_transcripts = $t_adaptor->fetch_all();
    foreach my $tr (@$all_transcripts) {
        $transcript_by_stable_id{$tr->stable_id} = $tr;
    }
    $self->log()->info("Pre-loaded " . scalar(keys %transcript_by_stable_id) . " transcripts");

    # ------------------------------------------------------------------
    # Xref caches — we cannot bulk-load these without knowing the IDs
    # in advance, so we use per-ID caching keyed on accession (and
    # "$accession|$dbname" where the same accession could appear under
    # multiple source databases).
    # ------------------------------------------------------------------
    my %cache_uniprot;            # fetch_all_by_name($id)
    my %cache_rnacentral_xref;    # fetch_all_by_name($id, 'RNAcentral')
    my %cache_rnacentral_trans;   # fetch_all_by_external_name($id)
    my %cache_protein_id;         # fetch_all_by_name($id, 'protein_id')
    my %cache_wormbase_xref;      # fetch_all_by_name($id, 'wormbase_transcript')
    my %cache_wormbase_trans;     # fetch_all_by_external_name($id)
    my %cache_flybase;            # fetch_all_by_name($id, 'flybase_translation_id')
    my %cache_ext_name;           # fetch_all_by_external_name($id, $dbname) keyed "$id|$dbname"

    my (%species_added_via_xref, %species_added_via_tgt);

    open my $fh, "<", $file or die "Could not open '$file' for reading: $!";
    my $lineN = 0;

    while (<$fh>) {
        chomp $_;
        $lineN++;
        next if $_ =~ /^!/;

        my ($translation, $translations, $transcript, $transcripts, $is_protein, $is_transcript, $already_stored);

        $self->log()->debug($lineN . ": " . $_);

        my ($db, $db_object_id, $qualifier, $go_id, $go_ref, $eco, $with, $taxon_id,
            $date, $assigned_by, $annotation_extension, $annotation_properties) = split /\t/, $_;

        $self->log()->debug("Parsed: " . sprintf(
            "db %s, db_object_id %s, qualifier %s, go_id %s, go_ref %s, eco %s, ".
            "with %s, date %s, assigned_by %s, annotation_properties %s ",
            $db, $db_object_id, $qualifier, $go_id, $go_ref, $eco,
            $with, $date, $assigned_by, $annotation_properties));

        my ($go_evidence, $tgt_species, $tgt_gene, $tgt_protein,
            $src_species, $src_gene, $src_protein, $precursor_rna);

        foreach my $annotation_propertie (split /\|/, $annotation_properties) {
            if ($annotation_propertie =~ m/tgt_gene/) {
                $annotation_propertie =~ s/tgt_gene=\w+://;
                $tgt_gene = $annotation_propertie;
            }
            elsif ($annotation_propertie =~ m/tgt_species/) {
                $annotation_propertie =~ s/tgt_species=//;
                $tgt_species = $annotation_propertie;
            }
            elsif ($annotation_propertie =~ m/go_evidence/) {
                $annotation_propertie =~ s/go_evidence=//;
                $go_evidence = $annotation_propertie;
            }
            elsif ($annotation_propertie =~ m/tgt_protein/) {
                $annotation_propertie =~ s/tgt_protein=[\w\-\d\.]+://;
                $tgt_protein = $annotation_propertie;
            }
            elsif ($annotation_propertie =~ m/src_protein/) {
                $annotation_propertie =~ s/src_protein=[\w\-]+://;
                $src_protein = $annotation_propertie;
            }
            elsif ($annotation_propertie =~ m/src_species/) {
                $annotation_propertie =~ s/src_species=//;
                $src_species = $annotation_propertie;
            }
            elsif ($annotation_propertie =~ m/src_gene/) {
                $annotation_propertie =~ s/src_gene=//;
                $src_gene = $annotation_propertie;
            }
            elsif ($annotation_propertie =~ m/precursor_rna/) {
                $annotation_propertie =~ s/precursor_rna=//;
                $precursor_rna = $annotation_propertie;
            }
            else {
                die "Line $lineN: could not parse annotation property '$annotation_propertie'";
            }
        }

        # This is intentional filtering — the GOA file covers many species
        # and we only process records for the species we were given.
        if ($tgt_species !~ /$species/){
                    die "Line $lineN: tgt_species does not match" ;
        };
        die "Line $lineN: go_id is undefined or empty" unless defined $go_id && $go_id ne '';
        die "Line $lineN: go_evidence is undefined or empty" unless defined $go_evidence && $go_evidence ne '';

        $self->log()->debug("Creating GO xref for $go_id");
        my $info_type = 'DIRECT';
        my $info_text = $assigned_by;
        if ($assigned_by =~ /Ensembl/ and defined $src_protein) {
            $info_text = "from $src_species translation $src_protein";
            $info_type = 'PROJECTION';
        }

        my $go_xref = Bio::EnsEMBL::OntologyXref->new(
            -primary_id         => $go_id,
            -display_id         => $go_id,
            -info_text          => $info_text,
            -info_type          => $info_type,
            -description        => $$gos{$go_id},
            -linkage_annotation => $go_evidence,
            -dbname             => 'GO'
        );

        $go_xref->analysis($analysis);
        my $master_xref;

        $self->log()->debug("DB $db Go Evidence $go_evidence");

        if ($db =~ /UniProt/) {
            $self->log()->debug("Adding linkage to UniProt");
            $is_protein = 1;

            unless (exists $cache_uniprot{$db_object_id}) {
                $cache_uniprot{$db_object_id} = $dbe_adaptor->fetch_all_by_name($db_object_id);
            }
            my @master_xref = grep { $_->dbname =~ m/uniprot/i } @{ $cache_uniprot{$db_object_id} };

            die "Line $lineN: no UniProt xref found in core DB for '$db_object_id'"
                unless scalar(@master_xref) != 0;

            $master_xref = $master_xref[0];
            $go_xref->add_linkage_type($go_evidence, $master_xref);
        }
        elsif ($db =~ /RNAcentral/) {
            $self->log()->debug("Adding linkage to RNAcentral");
            $is_transcript = 1;

            my @db_object_ids = $precursor_rna ? split(",", $precursor_rna) : ($db_object_id);

            foreach my $db_object_id (@db_object_ids) {
                $db_object_id =~ s/_[0-9]+$//;

                unless (exists $cache_rnacentral_xref{$db_object_id}) {
                    $cache_rnacentral_xref{$db_object_id} =
                        $dbe_adaptor->fetch_all_by_name($db_object_id, 'RNAcentral');
                }
                die "Line $lineN: no RNAcentral xref found in core DB for '$db_object_id'"
                    unless scalar(@{ $cache_rnacentral_xref{$db_object_id} }) != 0;

                $master_xref = $cache_rnacentral_xref{$db_object_id}->[0];
                $go_xref->add_linkage_type($go_evidence, $master_xref);

                unless (exists $cache_rnacentral_trans{$db_object_id}) {
                    $cache_rnacentral_trans{$db_object_id} =
                        $t_adaptor->fetch_all_by_external_name($db_object_id);
                }
                die "Line $lineN: no transcripts found via RNAcentral xref '$db_object_id'"
                    unless scalar(@{ $cache_rnacentral_trans{$db_object_id} }) != 0;

                foreach my $transcript (@{ $cache_rnacentral_trans{$db_object_id} }) {
                    $dbe_adaptor->store($go_xref, $transcript->dbID, 'Transcript', 1, $master_xref);
                    $species_added_via_xref{$tgt_species}++;
                }
            }
            $already_stored = 1;  # storage was handled above — skip the fallback stage entirely
        }
        elsif (lc($db) =~ /ena/) {
            $self->log()->debug("Adding linkage to Protein ID");
            $is_protein = 1;

            unless (exists $cache_protein_id{$db_object_id}) {
                $cache_protein_id{$db_object_id} =
                    $dbe_adaptor->fetch_all_by_name($db_object_id, 'protein_id');
            }
            die "Line $lineN: no protein_id xref found in core DB for '$db_object_id'"
                unless scalar(@{ $cache_protein_id{$db_object_id} }) != 0;

            $master_xref = $cache_protein_id{$db_object_id}->[0];
            $go_xref->add_linkage_type($go_evidence, $master_xref);
        }
        elsif (lc($db) =~ /wormbase/) {
            $self->log()->debug("Adding linkage to Wormbase Transcript");
            $is_transcript = 1;

            unless (exists $cache_wormbase_xref{$db_object_id}) {
                $cache_wormbase_xref{$db_object_id} =
                    $dbe_adaptor->fetch_all_by_name($db_object_id, 'wormbase_transcript');
            }
            die "Line $lineN: no wormbase_transcript xref found in core DB for '$db_object_id'"
                unless scalar(@{ $cache_wormbase_xref{$db_object_id} }) != 0;

            $master_xref = $cache_wormbase_xref{$db_object_id}->[0];
            $go_xref->add_linkage_type($go_evidence, $master_xref);

            unless (exists $cache_wormbase_trans{$db_object_id}) {
                $cache_wormbase_trans{$db_object_id} =
                    $t_adaptor->fetch_all_by_external_name($db_object_id);
            }
            die "Line $lineN: no transcripts found via wormbase_transcript xref '$db_object_id'"
                unless scalar(@{ $cache_wormbase_trans{$db_object_id} }) != 0;

            foreach my $transcript (@{ $cache_wormbase_trans{$db_object_id} }) {
                $dbe_adaptor->store($go_xref, $transcript->dbID, 'Transcript', 1, $master_xref);
                $species_added_via_xref{$tgt_species}++;
            }
            $already_stored = 1;  # storage was handled above — skip the fallback stage entirely
        }
        elsif (lc($db) =~ /flybase/) {
            $self->log()->debug("Adding linkage to Flybase translation");
            $is_protein = 1;

            unless (exists $cache_flybase{$db_object_id}) {
                $cache_flybase{$db_object_id} =
                    $dbe_adaptor->fetch_all_by_name($db_object_id, 'flybase_translation_id');
            }
            die "Line $lineN: no flybase_translation_id xref found in core DB for '$db_object_id'"
                unless scalar(@{ $cache_flybase{$db_object_id} }) != 0;

            $master_xref = $cache_flybase{$db_object_id}->[0];
            $go_xref->add_linkage_type($go_evidence, $master_xref);
        }
        else {
            $self->log()->debug("Adding default linkage");
            $go_xref->add_linkage_type($go_evidence);
        }

        if (defined $tgt_protein) {
            $self->log()->debug("Looking for protein $tgt_protein");

            # Use the pre-loaded translation/transcript hashes — no DB call needed
            die "Line $lineN: translation '$tgt_protein' not found in pre-loaded translation set"
                unless exists $translation_hash{$tgt_protein};
            die "Line $lineN: transcript not found for translation '$tgt_protein' in pre-loaded set"
                unless defined $transcript_hash{$tgt_protein};

            $translation = $translation_hash{$tgt_protein};
            $transcript  = $transcript_hash{$tgt_protein};

            $self->log()->debug("Storing on transcript " . $transcript->dbID());
            $dbe_adaptor->store($go_xref, $transcript->dbID, 'Transcript', 1, $master_xref);
            $species_added_via_tgt{$tgt_species}++;
        }
        elsif (!$already_stored) {
            $self->log()->debug("Finding tgt_feature via xref");
            die "Line $lineN: no master_xref resolved for '$db_object_id' (db: $db) — cannot attach GO term"
                unless defined $master_xref;

            if ($is_protein) {
                $self->log()->debug("Finding protein $db_object_id");

                my $ext_key = $db_object_id . '|' . $master_xref->dbname;
                unless (exists $cache_ext_name{$ext_key}) {
                    $cache_ext_name{$ext_key} =
                        $tl_adaptor->fetch_all_by_external_name($db_object_id, $master_xref->dbname);
                }
                $translations = $cache_ext_name{$ext_key};

                die "Line $lineN: no translations found via external name '$db_object_id' (dbname: " .
                    $master_xref->dbname . ")"
                    unless scalar(@$translations) != 0;

                foreach my $translation (@$translations) {
                    $self->log()->debug("Attaching via translation to transcript " .
                        $translation->transcript()->dbID());
                    $dbe_adaptor->store($go_xref, $translation->transcript->dbID,
                        'Transcript', 1, $master_xref);
                    $species_added_via_xref{$tgt_species}++;
                }
            }
            elsif ($is_transcript) {
                $self->log()->debug("Finding transcript $db_object_id");

                my $ext_key = $db_object_id . '|' . $master_xref->dbname;
                unless (exists $cache_ext_name{$ext_key}) {
                    $cache_ext_name{$ext_key} =
                        $t_adaptor->fetch_all_by_external_name($db_object_id, $master_xref->dbname);
                }
                $transcripts = $cache_ext_name{$ext_key};

                die "Line $lineN: no transcripts found via external name '$db_object_id' (dbname: " .
                    $master_xref->dbname . ")"
                    unless scalar(@$transcripts) != 0;

                foreach my $transcript (@$transcripts) {
                    $self->log()->debug("Attaching to transcript " . $transcript->dbID());
                    $dbe_adaptor->store($go_xref, $transcript->dbID(), 'Transcript', 1, $master_xref);
                    $species_added_via_xref{$tgt_species}++;
                }
            }
            else {
                die "Line $lineN: db source '$db' did not set is_protein or is_transcript — " .
                    "cannot determine target feature type";
            }
        }
    }

    close $fh;
    $dba->dbc->disconnect_if_idle();

    return;
}

#############
##SUBROUTINES
#############
sub fetch_ontology {
    my ($self, $odba) = @_;

    my %ontology_definition;
    my $gos = $odba->fetch_all();

    foreach my $go (@$gos) {
        $ontology_definition{$go->accession} = $go->name();
    }

    return \%ontology_definition;
}

1;