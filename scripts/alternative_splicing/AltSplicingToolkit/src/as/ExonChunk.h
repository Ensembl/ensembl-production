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


#ifndef EXONCHUNK_H_
#define EXONCHUNK_H_


#include <vector>
#include <list>
#include <string>

#include <boost/shared_ptr.hpp>

#include "Coordinates.h"
#include "TranscriptFeature.h"

using namespace boost;
using namespace std;

namespace as
{

  class TranscriptFeature; // forward reference

  class ExonChunk : public as::Coordinates
  {
  public:

    ExonChunk(unsigned int start, unsigned int end);
    virtual ~ExonChunk();

    vector< shared_ptr<TranscriptFeature> >& getExons();
    void addExon(const shared_ptr<TranscriptFeature> &exon);
    void mergeExons(const vector< shared_ptr<TranscriptFeature> > &features);

  protected:

    vector< shared_ptr<TranscriptFeature> > features;

  };

}

#endif /* EXONCHUNK_H_ */
