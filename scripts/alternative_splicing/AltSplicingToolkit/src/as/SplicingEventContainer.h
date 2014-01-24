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


#ifndef SPLICINGEVENTCONTAINER_H_
#define SPLICINGEVENTCONTAINER_H_

#include <iostream>
#include <string>
#include <algorithm>

#include <boost/shared_ptr.hpp>
#include <boost/ptr_container/ptr_vector.hpp>

#include "SplicingEvent.h"

using namespace boost;

namespace as
{

  class SplicingEventContainer
  {
  public:
    SplicingEventContainer();
    virtual
    ~SplicingEventContainer();

    vector< shared_ptr< SplicingEvent > >&  getIntronRetentionEvents();
    vector< shared_ptr< SplicingEvent > >&  getIntronIsoformEvents();
    vector< shared_ptr< SplicingEvent > >&  getExonIsoformEvents();
    vector< shared_ptr< SplicingEvent > >&  getMutuallyExclusiveEvents();
    vector< shared_ptr< SplicingEvent > >&  getCassetteExonEvents();

    vector< shared_ptr< SplicingEvent > >&  getAlternativeInitiationEvents();
    vector< shared_ptr< SplicingEvent > >&  getAlternativeTerminationEvents();

    vector< shared_ptr< SplicingEvent > >&  getAlternativeFirstExonEvents();
    vector< shared_ptr< SplicingEvent > >&  getAlternativeLastExonEvents();

    void addNewEvent(const shared_ptr<SplicingEvent> &event);
    void mergeSplicingEvents(SplicingEventContainer &eventContainer);

    void getSummaryOutput(ostream &oStream) const;
    void getGffOutput(ostream &oStream, string datasource) const;

    int getEventCount() const;

  protected:

    inline void getEventsGffOutput(ostream &oStream, string datasource, const vector< shared_ptr< SplicingEvent > >& events) const;
    void mergeSplicingEventVectors(vector< shared_ptr<SplicingEvent> > &eventSetA, vector< shared_ptr<SplicingEvent> > &eventSetB);

    vector< shared_ptr< SplicingEvent > > intronRetentionEvents;
    vector< shared_ptr< SplicingEvent > > intronIsoformEvents;
    vector< shared_ptr< SplicingEvent > > exonIsoformEvents;
    vector< shared_ptr< SplicingEvent > > mutuallyExclusiveEvents;
    vector< shared_ptr< SplicingEvent > > cassetteExonEvents;

    vector< shared_ptr< SplicingEvent > > alternativeInitiationEvents;
    vector< shared_ptr< SplicingEvent > > alternativeTerminationEvents;

    vector< shared_ptr< SplicingEvent > > alternativeFirstExonEvents;
    vector< shared_ptr< SplicingEvent > > alternativeLastExonEvents;

  };

}

#endif /* SPLICINGEVENTCONTAINER_H_ */
