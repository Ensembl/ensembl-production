#!/bin/ksh
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016] EMBL-European Bioinformatics Institute
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

# GO    - Gene Ontology
wget -O $dir/GO.obo "http://www.geneontology.org/ontology/obo_format_1_2/gene_ontology.1_2.obo"

# SO    - Sequence Ontology
wget -O $dir/SO.obo "https://raw.githubusercontent.com/The-Sequence-Ontology/SO-Ontologies/master/so-xp-simple.obo"

# HPO   - HPO Ontology
wget -O $dir/HPO.obo "http://purl.obolibrary.org/obo/hp.obo"

# EFO   - Experimental Factor Ontology
wget -O $dir/EFO.obo "http://svn.code.sf.net/p/efo/code/trunk/src/efoinobo/efo.obo"

#MP
wget -O $dir/MP.obo "http://www.berkeleybop.org/ontologies/mp.obo"

#CMO
wget -O $dir/CMO.obo "ftp://ftp.rgd.mcw.edu/pub/ontology/clinical_measurement/clinical_measurement.obo"

exit

# ----------------------------------------------------------------------
# Ontologies used in the Gramene project

# PO    - Plant Ontology
wget -O PO.obo "http://palea.cgrb.oregonstate.edu/viewsvn/Poc/trunk/ontology/OBO_format/po_anatomy.obo?view=co"

# GRO   - Plant Growth Stage Ontology
wget -O GRO.obo "http://palea.cgrb.oregonstate.edu/viewsvn/Poc/trunk/ontology/collaborators_ontology/gramene/temporal_gramene.obo?view=co"

# TO    - Plant Traits Ontology
wget -O TO.obo "http://palea.cgrb.oregonstate.edu/viewsvn/Poc/trunk/ontology/collaborators_ontology/gramene/traits/trait.obo?view=co"

# GR_tax    - Gramene Taxonomy Ontology
wget -O GR_tax.obo "http://palea.cgrb.oregonstate.edu/viewsvn/Poc/trunk/ontology/collaborators_ontology/gramene/taxonomy/GR_tax-ontology.obo?view=co"

# EO    - Plant Envionment Ontology
wget -O EO.obo "http://obo.cvs.sourceforge.net/viewvc/obo/obo/ontology/phenotype/environment/environment_ontology.obo"

# $Id$
