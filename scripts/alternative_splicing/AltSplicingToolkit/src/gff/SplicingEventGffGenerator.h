/*
 * Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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


#ifndef SPLICINGEVENTGFFGENERATOR_H_
#define SPLICINGEVENTGFFGENERATOR_H_

#include <map>
#include <boost/shared_ptr.hpp>

#include "GffEventModel.h"
#include "as/Feature.h"
#include "as/TranscriptFeature.h"
#include "as/Transcript.h"
#include "as/SplicingEventContainer.h"
#include "as/SplicingEventMatrix.h"

using namespace std;
using namespace boost;

namespace gff
{

  class SplicingEventGffGenerator: public GffNewGeneEventListener
  {

  public:
    SplicingEventGffGenerator(ostream &oStream, string datasource, bool bCNE, bool bRELAX);
    virtual
    ~SplicingEventGffGenerator();

    void command(const shared_ptr<GffNewGeneEvent> &event);

    int getCountAI() const;
    int getCountAT() const;
    int getCountAFE() const;
    int getCountALE() const;
    int getCountIR() const;
    int getCountII() const;
    int getCountEI() const;
    int getCountCE() const;
    int getCountMXE() const;

    int getCountCNE() const;

    int getGeneCount() const;
    int getGenesWithEventsCount() const;
    int getGenesWithSeveralTranscriptsCount() const;
    int getEventCount() const;

  private:

    ostream &oStream;
    string datasource;

    int countAI;
    int countAT;
    int countALE;
    int countAFE;
    int countIR;
    int countII;
    int countEI;
    int countCE;
    int countMXE;

    int countCNE;

    bool bCNE;
		bool bRELAX;

    int genes;
    int genesWithEvents;
    int genesWithSeveralTranscripts;

  };

}

#endif /* SPLICINGEVENTGFFGENERATOR_H_ */
