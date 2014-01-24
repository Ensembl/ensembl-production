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


#ifndef _TRANSCRIPT_H
#define _TRANSCRIPT_H

#include <vector>
#include <list>
#include <string>

#include <boost/shared_ptr.hpp>
#include <boost/ptr_container/ptr_vector.hpp>

#include "GeneFeature.h"
#include "TranscriptFeature.h"
#include "Gene.h"

using namespace boost;
using namespace std;

namespace as {

  class Exon; // forward declaration
  class TranscriptFeature; // forward declaration

  //typedef std::map<string, Exon> ExonMap;

  class Transcript: public GeneFeature
    {

    protected:

      /*
       * it makes no sense to use a ptr_vector because:
       *  i) exon can be shared between transcript structure
       * ii) we have to build a structure with the intron again and again...
       */

      list< shared_ptr<Exon> > exons;
      vector< shared_ptr<Exon> > vExons;
      vector< shared_ptr<TranscriptFeature> > features; // it's a trick to avoid memory leaks

    public:

      // default constructor
      Transcript();
      Transcript(string s);

      virtual ~Transcript();

      void addExon(const shared_ptr<Exon> &exon);
      vector< shared_ptr<Exon> >& getExons();
      vector< shared_ptr<TranscriptFeature> >& getTranscriptFeatures();

    };

}

#endif /* not defined _TRANSCRIPT_H */
