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


#ifndef _TRANSCRIPT_FEATURE_H
#define _TRANSCRIPT_FEATURE_H

#include <vector>
#include <string>
#include <fstream>
#include <iostream>

#include <boost/shared_ptr.hpp>
#include <boost/ptr_container/ptr_vector.hpp>

#include "Transcript.h"
#include "Feature.h"

using namespace std;

namespace as {

  class Transcript; // forward declaration of Transcript

  class TranscriptFeature: public Feature {
  public:
    TranscriptFeature();
    TranscriptFeature(std::string s);
    ~TranscriptFeature(void);

    void addTranscript(const shared_ptr<Transcript> &transcript);

    vector< shared_ptr< Transcript > >& getTranscripts();

  protected:
    // a transcriptFeature can be shared by different transcripts
    vector< shared_ptr<Transcript> > transcripts;


  };

  class Exon: public TranscriptFeature {

  public:
    Exon();
    Exon(std::string s);
    ~Exon();

  };

  class Intron: public TranscriptFeature {

  public:
    Intron();
    Intron(std::string s);
    ~Intron();

  };

}


#endif /* not defined _TRANSCRIPT_FEATURE_H */
