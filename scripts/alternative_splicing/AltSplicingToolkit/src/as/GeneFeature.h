/*
 * Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *      http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


#ifndef GENEFEATURE_H_
#define GENEFEATURE_H_

#include "Feature.h"
#include "Gene.h"

#include <boost/shared_ptr.hpp>
#include <boost/ptr_container/ptr_vector.hpp>

using namespace boost;
using namespace std;

namespace as
{

  class GeneFeature : public as::Feature
  {
  public:
    GeneFeature(string s);
    GeneFeature(int type, unsigned int start, unsigned int end, string chr, short int strand);
    GeneFeature();
    virtual
    ~GeneFeature();

    void setGene(const shared_ptr<Gene> &gene);
    const shared_ptr<Gene> &getGene() const;

  protected:
    shared_ptr<Gene> gene;
  };

}

#endif /* GENEFEATURE_H_ */
