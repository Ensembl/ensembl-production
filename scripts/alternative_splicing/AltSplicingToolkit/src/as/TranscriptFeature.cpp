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


#include <string>
#include "TranscriptFeature.h"
#include "Transcript.h"

namespace as
{

  //: Feature::Feature()
  TranscriptFeature::TranscriptFeature()
  {
  }

  TranscriptFeature::TranscriptFeature(std::string featureIdentifier) : Feature(featureIdentifier)
  {
  }

  TranscriptFeature::~TranscriptFeature(void)
  {
  }

  void TranscriptFeature::addTranscript(const shared_ptr<Transcript> &transcript)
  {
    transcripts.push_back(transcript);
  }

  vector< shared_ptr<Transcript> >& TranscriptFeature::getTranscripts()
  {

    return transcripts;
  }


//: Feature::Feature()
Exon::Exon()
{
  type = EXON_TYPE;
}

Exon::Exon(std::string featureIdentifier) : TranscriptFeature(featureIdentifier)
{
  type = EXON_TYPE;
}

Exon::~Exon()
{
}

Intron::Intron()
{
  type = INTRON_TYPE;
}

Intron::Intron(std::string featureIdentifier) : TranscriptFeature(featureIdentifier)
{
  type = INTRON_TYPE;
}

Intron::~Intron()
{
}

}
