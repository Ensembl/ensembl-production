#!/bin/sh
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

while getopts 'd:e' opt; do
  case ${opt} in
    d)  dir=${OPTARG}    ;;
  esac
done

# If requested to run interactively, do not run any jobs concurrently.
if [[ -z ${dir} ]]; then
  dir='.'
fi

# Pombe ontology sources, MOD and PBO are not in this list at the moment.
wget "http://curation.pombase.org/dumps/releases/pombase-chado-latest/pombe-embl/mini-ontologies/fypo_extension.obo" -O $dir/FYPO_EXTENSION.obo
wget "http://curation.pombase.org/dumps/releases/pombase-chado-latest/pombe-embl/mini-ontologies/quiescence.obo" -O $dir/PBQ.obo
wget "http://curation.pombase.org/dumps/releases/pombase-chado-latest/ontologies/go.obo" -O $dir/FYPO_GO.obo
wget "http://curation.pombase.org/dumps/releases/pombase-chado-latest/ontologies/fypo-simple.obo" -O $dir/FYPO.obo
wget "http://curation.pombase.org/dumps/releases/pombase-chado-latest/pombe-embl/mini-ontologies/pombe_mini_PR.obo" -O $dir/PRO.obo
wget "http://curation.pombase.org/dumps/releases/pombase-chado-latest/pombe-embl/mini-ontologies/chebi.obo" -O $dir/CHEBI.obo
wget "http://www.geneontology.org/ontology/obo_format_1_2/gene_ontology.1_2.obo" -O $dir/GO.obo
wget "https://raw.githubusercontent.com/The-Sequence-Ontology/SO-Ontologies/master/so-simple.obo" -O $dir/SO.obo
wget "http://palea.cgrb.oregonstate.edu/viewsvn/Poc/trunk/ontology/OBO_format/plant_ontology.obo?view=co" -O $dir/PO.obo
wget "http://palea.cgrb.oregonstate.edu/viewsvn/Poc/trunk/ontology/collaborators_ontology/gramene/temporal_gramene.obo?view=co" -O $dir/GRO.obo
wget "http://palea.cgrb.oregonstate.edu/viewsvn/Poc/trunk/ontology/collaborators_ontology/gramene/taxonomy/GR_tax-ontology.obo?view=co" -O $dir/GR_TAX.obo
wget "http://obo.cvs.sourceforge.net/viewvc/obo/obo/ontology/phenotype/environment/environment_ontology.obo?view=co" -O $dir/EO.obo
wget "http://palea.cgrb.oregonstate.edu/viewsvn/Poc/trunk/ontology/collaborators_ontology/gramene/traits/trait.obo?view=co" -O $dir/TO.obo
wget "http://svn.code.sf.net/p/efo/code/trunk/src/efoinobo/efo.obo" -O $dir/EFO.obo
wget "http://sourceforge.net/p/pombase/code/HEAD/tree/phenotype_ontology/peco.obo?format=raw" -O $dir/PECO.obo
wget "http://purl.obolibrary.org/obo/cl-basic.obo" -O $dir/CL.obo
wget "https://raw.githubusercontent.com/pato-ontology/pato/master/pato.obo" -O $dir/PATO.obo
wget "https://raw.githubusercontent.com/OGMS/ogms/master/src/ontology/ogms.obo" -O $dir/OGMS.obo
wget "http://www.brenda-enzymes.info/ontology/tissue/tree/update/update_files/BrendaTissueOBO" -O $dir/BTO.obo
wget "https://raw.githubusercontent.com/BFO-ontology/BFO/master/releases/2.0/bfo.obo" -O $dir/BFO.obo
wget "https://raw.githubusercontent.com/bio-ontology-research-group/unit-ontology/master/unit.obo" -O $dir/UO.obo
wget "https://raw.githubusercontent.com/evidenceontology/evidenceontology/master/eco.obo" -O $dir/ECO.obo
wget --no-check-certificate "https://build.berkeleybop.org/job/build-mp-edit/lastSuccessfulBuild/artifact/src/ontology/mp.obo/*view*/" -O $dir/MP.obo
wget "ftp://ftp.rgd.mcw.edu/pub/ontology/clinical_measurement/clinical_measurement.obo" -O $dir/CMO.obo
wget "http://purl.obolibrary.org/obo/hp.obo" -O $dir/HPO.obo
wget "https://raw.githubusercontent.com/AnimalGenome/vertebrate-trait-ontology/master/VT_v8.2" -O $dir/VT.obo
