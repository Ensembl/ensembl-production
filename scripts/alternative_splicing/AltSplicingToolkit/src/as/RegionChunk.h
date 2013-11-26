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


#ifndef REGIONCHUNK_H_
#define REGIONCHUNK_H_

#include <vector>
#include <list>
#include <string>

#include <boost/shared_ptr.hpp>

#include "Coordinates.h"
#include "Transcript.h"
#include "ExonChunk.h"
#include "SplicingEvent.h"
#include "Gene.h"

namespace as
{

  class RegionChunk : public as::Coordinates
  {
  public:
    RegionChunk();
    virtual
    ~RegionChunk();

    //void addExonChunk(const shared_ptr<ExonChunk> &exonChunk);
    void mergeTranscript(const shared_ptr<Transcript> &transcript);
    vector< shared_ptr< SplicingEvent > >&  getConstitutiveExonEvents();
    void checkConstitutiveExon(unsigned int upperBound);
    void getEventsGffOutput(ostream &oStream, string datasource) const;
    void getSummaryOutput(ostream &oStream) const;

    int computeFeatureStart(int start, int end) const;
    int computeFeatureEnd(int start, int end) const;

    void setGene(const shared_ptr<Gene> &gene);
    const shared_ptr<Gene> &getGene() const;

  protected:
    shared_ptr<Gene> gene;
    vector< shared_ptr<ExonChunk> > exonChunks;
    int strand;
    int referentialPosition;

    vector< shared_ptr< SplicingEvent > > constitutiveExonEvents;

  };

}

#endif /* REGIONCHUNK_H_ */
