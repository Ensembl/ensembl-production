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


#ifndef SPLICINGEVENTMATRIX_H_
#define SPLICINGEVENTMATRIX_H_

#include <iostream>
#include <algorithm>

#include <boost/shared_ptr.hpp>
#include <boost/ptr_container/ptr_vector.hpp>
#include <boost/ptr_container/ptr_list.hpp>

#include "TranscriptFeature.h"
#include "Transcript.h"
#include "SplicingEvent.h"
#include "SplicingEventContainer.h"

using namespace std;
using namespace boost;

namespace as {

  // code for overlaps type
  const short int NO_OVERLAP = 0x0; // 0        0000
  const short int ID5P_ID3P = 0xf; //15         1111
  const short int DIFF5P_ID3P = 0xe; //14       1110
  const short int ID5P_DIFF3P = 0xd; //13       1101
  const short int PART_OF = 0xc; // 12          1100
  const short int OVERLAP = 0x4; // 4           0100

  // bitwise constants
  const short int ID5P = 0x1; //1               0001
  const short int ID3P = 0x2; //2               0010

  class SplicingEventMatrix: public SplicingEventContainer
  {
  public:
    SplicingEventMatrix(const shared_ptr<Transcript> & t1, const shared_ptr<Transcript> & t2);
    virtual
    ~SplicingEventMatrix();

    static short int overlapCode(int start1, int end1, int start2, int end2);

    void computeSplicingEvents(bool bRELAX);

  protected:
    void buildOverlapMatrix();


  private:
    static void create_matrix(short int ***m, int xSize, int ySize);
    static void delete_matrix(short int ***m, int xSize, int ySize);
    static void display_matrix(short int ***m, int xSize, int ySize);

    void checkAlternativeFirstLastExon(const shared_ptr<TranscriptFeature> & f1, const shared_ptr<TranscriptFeature> & f2, int t1Index, int t2Index);
    void checkIntronRetention(const shared_ptr<TranscriptFeature> & f1, const shared_ptr<TranscriptFeature> & f2, int t1Index, int t2Index);
    void checkIntronIsoform(const shared_ptr<TranscriptFeature> & f1, const shared_ptr<TranscriptFeature> & f2, int t1Index, int t2Index);
    void checkExonIsoform(const shared_ptr<TranscriptFeature> & f1, const shared_ptr<TranscriptFeature> & f2, int t1Index, int t2Index, bool bRELAX);
    void checkCassetteExon(const shared_ptr<TranscriptFeature> & f1, const shared_ptr<TranscriptFeature> & f2, int t1Index, int t2Index, bool bRELAX);
    void checkMutualExclusion(const shared_ptr<TranscriptFeature> & f1, const shared_ptr<TranscriptFeature> & f2, int t1Index, int t2Index, bool bRELAX);

    inline int computeFeatureStart(int start, int end) const;
    inline int computeFeatureEnd(int start, int end) const;

  protected:
    short int **overlapMatrix; // is allocated here and released here
    shared_ptr<Transcript> t1; // pointer to a transcript defined elsewhere, no worry about the allocation
    shared_ptr<Transcript> t2; // pointer to a transcript defined elsewhere, no worry about the allocation
    vector< shared_ptr<TranscriptFeature> > &t1Features;
    vector< shared_ptr<TranscriptFeature> > &t2Features;
    int xSize;
    int ySize;
    int strand;
    int referentialPosition;

  };

}

#endif /* SPLICINGEVENTMATRIX_H_ */
