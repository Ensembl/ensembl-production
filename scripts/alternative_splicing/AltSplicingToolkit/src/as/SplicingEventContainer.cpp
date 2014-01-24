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


#include "SplicingEventContainer.h"

namespace as
{

  SplicingEventContainer::SplicingEventContainer()
  {
  }

  SplicingEventContainer::~SplicingEventContainer()
  {
  }


  /**
   * Returns the computed alternative initiation events.
   */
  vector< shared_ptr< SplicingEvent > >& SplicingEventContainer::getAlternativeInitiationEvents()
  {
    return alternativeInitiationEvents;
  }

  /**
   * Returns the computed alternative termination events.
   */
  vector< shared_ptr< SplicingEvent > >& SplicingEventContainer::getAlternativeTerminationEvents()
  {
    return alternativeTerminationEvents;
  }

  /**
   * Returns the computed alternative first exon events.
   */
  vector< shared_ptr< SplicingEvent > >& SplicingEventContainer::getAlternativeFirstExonEvents()
  {
    return alternativeFirstExonEvents;
  }

  /**
   * Returns the computed alternative last exon events.
   */
  vector< shared_ptr< SplicingEvent > >& SplicingEventContainer::getAlternativeLastExonEvents()
  {
    return alternativeLastExonEvents;
  }

  /**
   * Returns the computed intron retention events.
   */
  vector< shared_ptr< SplicingEvent > >& SplicingEventContainer::getIntronRetentionEvents()
  {
    return intronRetentionEvents;
  }

  /**
   * Returns the computed intron isoforms events.
   */
  vector< shared_ptr< SplicingEvent > >& SplicingEventContainer::getIntronIsoformEvents()
  {
    return intronIsoformEvents;
  }

  /**
   * Returns the computed exon isoform events.
   */
  vector< shared_ptr< SplicingEvent > >& SplicingEventContainer::getExonIsoformEvents()
  {
    return exonIsoformEvents;
  }

  /**
   * Returns the computed mutually exclusive events.
   */
  vector< shared_ptr< SplicingEvent > >& SplicingEventContainer::getMutuallyExclusiveEvents()
  {
    return mutuallyExclusiveEvents;
  }

  /**
   * Returns the cassette exon events.
   */
  vector< shared_ptr< SplicingEvent > >& SplicingEventContainer::getCassetteExonEvents()
  {
    return cassetteExonEvents;
  }

  void SplicingEventContainer::addNewEvent(const shared_ptr<SplicingEvent> &event)
  {

    switch (event->getType()) {

      case IR_EVENT:

        if (!event->contains(intronRetentionEvents))
        {
          intronRetentionEvents.push_back(event);
        }
        break;

      case CE_EVENT:

        if (!event->contains(cassetteExonEvents))
        {
          cassetteExonEvents.push_back(event);
        }
        break;

      case MXE_EVENT:
        if (!event->contains(mutuallyExclusiveEvents))
        {
          mutuallyExclusiveEvents.push_back(event);
        }
        break;
    }

  }


  void SplicingEventContainer::mergeSplicingEvents(SplicingEventContainer &eventContainer)
  {
    mergeSplicingEventVectors(alternativeInitiationEvents, eventContainer.getAlternativeInitiationEvents());
    mergeSplicingEventVectors(alternativeTerminationEvents, eventContainer.getAlternativeTerminationEvents());

    mergeSplicingEventVectors(alternativeFirstExonEvents, eventContainer.getAlternativeFirstExonEvents());
    mergeSplicingEventVectors(alternativeLastExonEvents, eventContainer.getAlternativeLastExonEvents());

    mergeSplicingEventVectors(cassetteExonEvents, eventContainer.getCassetteExonEvents());
    mergeSplicingEventVectors(exonIsoformEvents, eventContainer.getExonIsoformEvents());
    mergeSplicingEventVectors(intronIsoformEvents, eventContainer.getIntronIsoformEvents());
    mergeSplicingEventVectors(intronRetentionEvents, eventContainer.getIntronRetentionEvents());
    mergeSplicingEventVectors(mutuallyExclusiveEvents, eventContainer.getMutuallyExclusiveEvents());
  }

  /**
   * merge two vectors of splicing events into one.
   */
  void SplicingEventContainer::mergeSplicingEventVectors(vector< shared_ptr< SplicingEvent > > &eventSetA, vector< shared_ptr< SplicingEvent > > &eventSetB)
  {

    // optimiZation to speed up the merge
    // when there are no events in SetA

    if (eventSetA.size() == 0) {

      if (eventSetB.size() > 0) {

        // transfer ownership (no cloning happens) in the case of ptr_vector
        //eventSetA.transfer( eventSetA.end(), eventSetB.begin(), eventSetB.end(), eventSetB );

        eventSetA.assign(eventSetB.begin(), eventSetB.end());
      }

    } else {

      //
      // iterate on events from set B
      //
      vector< shared_ptr< SplicingEvent > >::iterator eventSetBIterator;

      for( eventSetBIterator=eventSetB.begin(); eventSetBIterator!=eventSetB.end(); eventSetBIterator++ ) {

        //
        // find an identical event from Set A
        //

        vector< shared_ptr< SplicingEvent > >::iterator foundEventFromSetA = (*eventSetBIterator)->find(eventSetA);

        if (foundEventFromSetA != eventSetA.end()) {
          //cout << "event found... " << endl;

          /*
           * Then merge the 2 events by adding a new pair of transcripts to this event.
           * Retrieve pairs of transcripts from setA event
           */

          vector< pair<boost::shared_ptr< Transcript >, boost::shared_ptr< Transcript > > > pairs = (*eventSetBIterator)->getTranscriptPairs();


          /**
           * If this event concerns the first exon or the last exon
           * with similar properties, then merge the coordinates because even
           * if the 5'/3' coordinates are different, it's likely the 'same' first or last exons.
           */

          if (((*foundEventFromSetA)->getType() & ALT_FIRST_LAST_EXON_EVENT) == ALT_FIRST_LAST_EXON_EVENT) {

            /**
             * merge coordinates
             */

            (*foundEventFromSetA)->mergeCoordinates( (*eventSetBIterator)->getStart(), (*eventSetBIterator)->getEnd() );

            //
            // merge also the set of exons
            //

            if ((*foundEventFromSetA)->getType() == AFE_EVENT || (*foundEventFromSetA)->getType() == ALE_EVENT) {

              // merge setA with setA based on identifier (in ensembl: could be same coordinates but different IDs)
              (*foundEventFromSetA)->mergeSetA((*eventSetBIterator)->getSetA());
              (*foundEventFromSetA)->mergeSetB((*eventSetBIterator)->getSetB());
              (*foundEventFromSetA)->mergeConstitutiveExons((*eventSetBIterator)->getConstitutiveExons());

            } else if ((*foundEventFromSetA)->getType() == AI_EVENT || (*foundEventFromSetA)->getType() == AT_EVENT) {

              // merge setA with setA based on identifier (in ensembl: could be same coordinates but different IDs)
              (*foundEventFromSetA)->mergeSetA((*eventSetBIterator)->getSetA());

            }

          }

          /**
           * Then merge the transcript pairs to the current event
           */

          (*foundEventFromSetA)->mergeTranscriptPairs(pairs);

        } else {

          //cout << "No equivalent splicing event found. Add this event to the list." << endl;
          // if the event was not found, we have to push it to the end of the vector.
          // release the entry to copy it.
          /* code for ptr_vector
           * vector< shared_ptr< SplicingEvent > >::auto_type ptr2 = eventSetB.release( eventSetBIterator );
           * SplicingEvent *clone = &(*ptr2);
           */

          eventSetA.push_back( *eventSetBIterator );

        }
      }

    }

  }

  void SplicingEventContainer::getSummaryOutput(ostream &oStream) const
  {
    oStream << "alternativeInitiationEvents:\t\t" << alternativeInitiationEvents.size() << endl;
    oStream << "alternativeTerminationEvents:\t\t" << alternativeTerminationEvents.size() << endl;

    oStream << "alternativeFirstExonEvents:\t\t" << alternativeFirstExonEvents.size() << endl;
    oStream << "alternativeLastExonEvents:\t\t" << alternativeLastExonEvents.size() << endl;

    oStream << "intronRetentionEvents:\t\t" << intronRetentionEvents.size() << endl;
    oStream << "intronIsoformEvents:\t\t" << intronIsoformEvents.size() << endl;
    oStream << "exonIsoformEvents:\t\t" << exonIsoformEvents.size() << endl;
    oStream << "mutuallyExclusiveEvents:\t" << mutuallyExclusiveEvents.size() << endl;
    oStream << "cassetteExonEvents:\t\t" << cassetteExonEvents.size() << endl;
  }

  void SplicingEventContainer::getGffOutput(ostream &oStream, string datasource) const
  {

    getEventsGffOutput(oStream, datasource, alternativeInitiationEvents);
    getEventsGffOutput(oStream, datasource, alternativeTerminationEvents);

    getEventsGffOutput(oStream, datasource, alternativeFirstExonEvents);
    getEventsGffOutput(oStream, datasource, alternativeLastExonEvents);

    getEventsGffOutput(oStream, datasource, intronRetentionEvents);
    getEventsGffOutput(oStream, datasource, intronIsoformEvents);
    getEventsGffOutput(oStream, datasource, exonIsoformEvents);
    getEventsGffOutput(oStream, datasource, mutuallyExclusiveEvents);
    getEventsGffOutput(oStream, datasource, cassetteExonEvents);

  }

  int SplicingEventContainer::getEventCount() const
  {
    return
      alternativeInitiationEvents.size() +
      alternativeTerminationEvents.size() +
      alternativeFirstExonEvents.size() +
      alternativeLastExonEvents.size() +
      intronRetentionEvents.size() +
      intronIsoformEvents.size() +
      exonIsoformEvents.size() +
      mutuallyExclusiveEvents.size() +
      cassetteExonEvents.size();
  }

  void SplicingEventContainer::getEventsGffOutput(ostream &oStream, string datasource, const vector< shared_ptr< SplicingEvent > >& events) const
  {
    int number = 1;
    vector< shared_ptr< SplicingEvent > >::const_iterator mii;
    for(mii=events.begin(); mii!=events.end(); mii++) {
        (*mii)->outputAsGFF(oStream, datasource, number);
        number++;
    }

  }

}
// ;P
