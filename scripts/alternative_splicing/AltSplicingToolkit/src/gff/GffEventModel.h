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


#ifndef GFFLISTENER_H_
#define GFFLISTENER_H_

#include <list>
#include <map>
#include <iostream>

#include <boost/shared_ptr.hpp>

#include "as/TranscriptFeature.h"
#include "as/Transcript.h"


using namespace std;
using namespace boost;
using namespace as;

namespace gff
{

  class GffEventListener
  {
    public: virtual ~GffEventListener();
  };


  class GffEventHandler
  {
    public: virtual ~GffEventHandler();
  };

  class GffNewGeneEvent
  {
  public:
    GffNewGeneEvent(map<string, shared_ptr<Transcript> > &transcripts, map<string, shared_ptr<Exon> > &exons);
    virtual ~GffNewGeneEvent();

    map<string, shared_ptr<Transcript> > &getTranscripts();
    map<string, shared_ptr<Exon> > &getExons();

  protected:

    map<string, shared_ptr<Transcript> > &transcripts;
    map<string, shared_ptr<Exon> > &exons;

  };

  /**
   * ABC (Abstract Base Class)
   */
  class GffNewGeneEventListener
  {
  public:
    GffNewGeneEventListener();
    virtual ~GffNewGeneEventListener();
    virtual void command(const shared_ptr<GffNewGeneEvent> &event ) = 0; // {cout << "GffNewGeneEventListener::command" << endl; } // Pure virtual function, no body.
  };

  class GffNewGeneEventHandler
  {
  public:
    GffNewGeneEventHandler();
    virtual
    ~GffNewGeneEventHandler();

    //void registerNewGeneEventListener(const shared_ptr<GffNewGeneEventListener> & listener);
    void registerNewGeneEventListener(GffNewGeneEventListener* listener);
    void triggerEvent(const shared_ptr<GffNewGeneEvent> &event);

  private:
    //list< shared_ptr<GffNewGeneEventListener> > listeners;
    list< GffNewGeneEventListener* > listeners;

  };


}

#endif /* GFFLISTENER_H_ */
