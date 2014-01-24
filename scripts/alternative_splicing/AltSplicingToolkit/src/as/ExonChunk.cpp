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


#include "ExonChunk.h"

namespace as
{

  ExonChunk::ExonChunk(unsigned int start, unsigned int end) : Coordinates(start, end)
  {
    // TODO Auto-generated constructor stub

  }

  ExonChunk::~ExonChunk()
  {
    // TODO Auto-generated destructor stub
  }

  vector< shared_ptr<TranscriptFeature> >& ExonChunk::getExons() {
    return features;
  }

  void ExonChunk::addExon(const shared_ptr<TranscriptFeature> &exon)
  {
    //if (features.empty()) {

      features.push_back(exon);

   // } else {
      /**
       * Loop on the exon
       * TODO: order by exon start
       */

     // vector< shared_ptr< TranscriptFeature > >::const_iterator exonIt;
     // int index = 0;
     // for (exonIt=features.begin(); exonIt!=features.end();exonIt++) {
      //  if ((**exonIt).getStart() > )
      //}
   // }
    //} else {
   //   exons.push_front(exon);
   // }

    if (exon->getStart() < start) {
      start = exon->getStart();
    }
    if (exon->getEnd() > end) {
      end = exon->getEnd();
    }

  }

  void ExonChunk::mergeExons(const vector< shared_ptr<TranscriptFeature> > &exons)
  {
    features.insert (features.end(),exons.begin(),exons.end());
  }
}
