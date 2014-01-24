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


#ifndef _SPLICING_EVENT_H
#define _SPLICING_EVENT_H

#include <utility> // for pair
#include <algorithm> // to merge 2 vectors
#include <list>
#include <vector>
#include <string>
#include <fstream>
#include <iostream>
#include <sstream>

#include <boost/shared_ptr.hpp>
#include <boost/ptr_container/ptr_vector.hpp>
#include <boost/ptr_container/ptr_list.hpp>
#include <boost/utility.hpp>

#include "GeneFeature.h"
#include "Transcript.h"
#include "TranscriptFeature.h"

using namespace std;
using namespace boost;

namespace as {

  const int NO_EVENT = 2;
  const int MXE_EVENT = 4;   // mutually exclusive
  const int CE_EVENT = 5;    // cassette exon / skipped exon
  const int IR_EVENT = 6;    // intron retention
  const int II_EVENT = 7;    // intron isoform
  const int EI_EVENT = 8;    // exon isoform
  const int A3SS_EVENT = 9;  // Alternative 3' splice site
  const int A5SS_EVENT = 10;  // Alternative 5' splice site

  const int ALT_FIRST_LAST_EXON_EVENT = 16;  // first last exon events
  const int AI_EVENT = 17;  // alternative initiation
  const int AT_EVENT = 18;  // alternative termination
  const int AFE_EVENT = 19; // alternative first exon
  const int ALE_EVENT = 20; // alternative last exon

  const int CONSTITUTIVE_EVENT = 32; // constitutive region/exon event
  const int CNE_EVENT = 33; // constitutive exon
  const int CNR_EVENT = 34; // constitutive region

  class SplicingEvent : public GeneFeature
 {

  public:

    SplicingEvent();
    SplicingEvent(int type, unsigned int start, unsigned int end, string chr, short int strand);
    virtual ~SplicingEvent();

    void setSetA(const list< shared_ptr< TranscriptFeature > > &a);
    void setSetB(const list< shared_ptr< TranscriptFeature > > &b);
    void setConstitutiveExons(const list< shared_ptr< TranscriptFeature > > &constitutives);

    void setSitesA(const list< int > &a);
    void setSitesB(const list< int > &b);
    void setConstitutiveSites(const list< int > &c);

    bool equals(const SplicingEvent &event) const;
    bool compareFeatures(const list< shared_ptr< TranscriptFeature > > &set1, const list< shared_ptr< TranscriptFeature > > &set2 ) const;
    bool compareFeatureSites(const list< int > &sites1, const list< int > &sites2 ) const;

    const list< shared_ptr< TranscriptFeature > >& getSetA() const;
    const list< shared_ptr< TranscriptFeature > >& getSetB() const;
    const list< shared_ptr< TranscriptFeature > >& getConstitutiveExons() const;

    const list< int >& getSitesA() const;
    const list< int >& getSitesB() const;
    const list< int >& getConstitutiveSites() const;

    void outputAsGFF(ostream &oStream, string datasource, int number) const;
    string getTypeAsString() const;

    bool contains(vector< shared_ptr< SplicingEvent > > &events) const;
    vector< shared_ptr< SplicingEvent > >::iterator find(vector< shared_ptr< SplicingEvent > > &events) const;
    void addTranscriptPair(const shared_ptr< Transcript > & t1, const shared_ptr< Transcript > & t2);
    void mergeTranscriptPairs(const vector< pair< shared_ptr< Transcript >, shared_ptr< Transcript > > > &pairs);
    const vector< pair< shared_ptr< Transcript >, shared_ptr< Transcript > > > &getTranscriptPairs() const;
    void mergeCoordinates(unsigned int start, unsigned int end);
    void mergeSetA(const list< shared_ptr< TranscriptFeature > > &a);
    void mergeSetB(const list< shared_ptr< TranscriptFeature > > &a);
    void mergeConstitutiveExons(const list< shared_ptr< TranscriptFeature > > &constitutives);

  private:

    void mergeSets(list< shared_ptr< TranscriptFeature > > &x, const list< shared_ptr< TranscriptFeature > > &y);

    string findInvolvedTranscriptIdentifier(ostream &oStream, list<string> &transcriptList, TranscriptFeature &feature) const;

  protected:

    //TranscriptSets sets;
    list< shared_ptr< TranscriptFeature > > setA;
    list< shared_ptr< TranscriptFeature > > setB;
    list< shared_ptr< TranscriptFeature > > constitutiveExons;

    list< int > sitesA;
    list< int > sitesB;
    list< int > constitutiveSites;

    vector< pair< shared_ptr< Transcript >, shared_ptr< Transcript > > > transcriptPairs;

  };


  class SplicingEventNotFoundException : public std::exception
  {
    public:
      SplicingEventNotFoundException(string m="Splicing event not found") : msg(m) {}
      ~SplicingEventNotFoundException() throw() {}
      const char* what() const throw() { return msg.c_str(); }

    private:
      string msg;

  };

  class AlternativeInitiation : public SplicingEvent
    {

    public:
      AlternativeInitiation();
      ~AlternativeInitiation();

    };

  class AlternativeTermination : public SplicingEvent
    {

    public:
      AlternativeTermination();
      ~AlternativeTermination();

    };

  typedef vector<SplicingEvent> SplicingEventVector;

}



#endif /* not defined _SPLICING_EVENT_H */
