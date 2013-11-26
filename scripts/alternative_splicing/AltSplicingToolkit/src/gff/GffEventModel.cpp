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


#include "GffEventModel.h"

namespace gff
{

  /**
   * GffEventListener methods
   */

  GffEventListener::~GffEventListener() {}


  /**
   * GffEventHandler methods
   */

  GffEventHandler::~GffEventHandler() {}


  GffNewGeneEvent::GffNewGeneEvent(map<string, shared_ptr<Transcript> > &transcripts, map<string, shared_ptr<Exon> > &exons) : transcripts(transcripts), exons(exons)
  {

  }

  GffNewGeneEvent::~GffNewGeneEvent()
  {
    //cout << "destroy GffNewGeneEvent" << endl;
  }

  map<string, shared_ptr<Transcript> > &GffNewGeneEvent::getTranscripts()
  {
    return transcripts;
  }

  map<string, shared_ptr<Exon> > &GffNewGeneEvent::getExons()
  {
    return exons;
  }

  /**
   * GffNewGeneEventListener methods
   */

  GffNewGeneEventListener::GffNewGeneEventListener() {}
  GffNewGeneEventListener::~GffNewGeneEventListener()
  {
    //cout << "destroy GffNewGeneEventListener" << endl;
 }

  /**
   * GffNewGeneEventHandler methods
   */
  GffNewGeneEventHandler::GffNewGeneEventHandler()
  {
  }

  GffNewGeneEventHandler::~GffNewGeneEventHandler()
  {
    // clear the listener list
    //cout << "destroy GffNewGeneEventHandler start: " << listeners.size() << endl;
    listeners.clear();
    //cout << "destroy GffNewGeneEventHandler end: " << listeners.size() << endl;
  }

  //void GffNewGeneEventHandler::registerNewGeneEventListener(const shared_ptr<GffNewGeneEventListener> & listener)
  void GffNewGeneEventHandler::registerNewGeneEventListener(GffNewGeneEventListener* listener)
  {
    listeners.push_back(listener);
  }

  void GffNewGeneEventHandler::triggerEvent(const shared_ptr<GffNewGeneEvent> &event)
  {
    //list< shared_ptr < GffNewGeneEventListener> >::iterator ii;
    list<  GffNewGeneEventListener* >::iterator ii;

    for(ii=listeners.begin(); ii!=listeners.end(); ii++) {

      (*ii)->command(event);
    }

  }
}
