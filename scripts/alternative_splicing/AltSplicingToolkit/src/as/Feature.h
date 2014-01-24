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


#ifndef _FEATURE_H
#define _FEATURE_H

#include <string>
#include <iostream>

#include "Coordinates.h"

using namespace std;

namespace as {

  const int EXON_TYPE = 1;
  const int INTRON_TYPE = 2;
  const int TRANSCRIPT_TYPE = 100;

  class Feature : public Coordinates {

  public:
    Feature();
    Feature( string s );
    Feature(int type, unsigned int start, unsigned int end, string chr, short int strand);

  public:
    string getIdentifier() const;

    short int getStrand() const;
    string getStrandAsString() const;
    string getChromosome() const;
    int getIndex() const;
    int getType() const;

    void setStrand(short int s);
    void setChromosome(string v);
    void setType(int type);

    void setIndex(int v);


  protected:
    // the current identifier
    int type;
    string chr;
    short int strand;
    string identifier;
    int index;

  public:
    virtual ~Feature(void);
  };

}

#endif /* not defined _FEATURE_H */
