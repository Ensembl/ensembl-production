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


#include "Feature.h"
#include "Transcript.h"
//#include "Exon.h"

#include <fstream>
#include <iostream>
#include <sstream>

using namespace std;

namespace as {

  //: Feature::Feature()

  Transcript::Transcript()
  {
    type = TRANSCRIPT_TYPE;
  }

  Transcript::Transcript(std::string featureIdentifier) : GeneFeature(featureIdentifier)
  {
    type = TRANSCRIPT_TYPE;
  }

  void Transcript::addExon(const shared_ptr<Exon> &exon)
  {
    //if (strand == 1) {
      exons.push_back(exon);
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

  vector< shared_ptr< Exon > >& Transcript::getExons()
  {
    vExons.clear();
    vector< shared_ptr< Exon > >::iterator it;
    vExons.insert(it, exons.begin(), exons.end());
    return vExons;
  }

  /**
   * Create a full structure including the introns.
   */
  vector< shared_ptr< TranscriptFeature> >& Transcript::getTranscriptFeatures() {

    int lastExonStart = 0;
    int lastExonEnd = 0;
    //int exonIndex = (strand == 1) ? 0 : exons.size()+1;
    int exonIndex = 0;

    // create a vector of exon - intron on the heap
    features.clear();

    list< shared_ptr< Exon > >::const_iterator exonIterator;

    for(exonIterator=exons.begin(); exonIterator!=exons.end(); exonIterator++)
      {

        // current exon


        int exonStart = (**exonIterator).getStart();
        int exonEnd = (**exonIterator).getEnd();

        // if there is an exon before the current exon
        if (lastExonStart > 0) {

          ostringstream osstream;
          osstream << "intron" << exonIndex << "-" << (exonIndex+1);
          std::string my_id = osstream.str();

          // create the intron on the heap
          Intron *intron =  new Intron(my_id);
          // get the donor site of the previous exon
          intron->setStart((strand == 1) ? lastExonEnd + 1 : exonEnd + 1 );
          // get the acceptor site of th current exon
          intron->setEnd((strand == 1) ? exonStart - 1 : lastExonStart - 1 );
          // get the strand and chromosome of the previous feature
          intron->setStrand(getStrand());
          intron->setChromosome(getChromosome());

          shared_ptr< TranscriptFeature > pIntron(intron);
          features.push_back(pIntron);
        }

        // push the current exon shared pointer
        features.push_back(*exonIterator);

        lastExonStart = exonStart;
        lastExonEnd = exonEnd;

        exonIndex++; // = exonIndex + ((strand == 1) ? 1 : -1);

      }
    return features;
  }

  Transcript::~Transcript()
  {
    //cout << "Calling transcript destructor: " << identifier << endl;
  }

}
