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

#include "Feature.h"

namespace as {

  Feature::Feature() : Coordinates()
  {
  }

  Feature::Feature(std::string featureIdentifier) : Coordinates()
  {
    identifier = featureIdentifier;
  }

  Feature::Feature(int type, unsigned int start, unsigned int end, std::string chr, short int strand) : Coordinates(start,end), type(type), chr(chr), strand(strand)
  {
  }

  Feature::~Feature(void)
  {
    //cout << "Calling Feature destructor for type " << type << " " << identifier << endl;
  }

  std::string Feature::getIdentifier() const
  {
    return identifier;
  }

  short int Feature::getStrand() const
  {
    return strand;
  }

  std::string Feature::getStrandAsString() const
  {
    return (strand == 1) ? "+" : "-";
  }

  std::string Feature::getChromosome() const
  {
    return chr;
  }

  void Feature::setStrand(short int v)
  {
    strand = v;
  }

  void Feature::setChromosome(std::string v)
   {
     chr = v;
   }

  void Feature::setType(int featureType)
  {
    type = featureType;
  }

  void Feature::setIndex(int v) {
    index = v;
  }

  int Feature::getIndex() const {
    return index;
  }

  int Feature::getType() const {
    return type;
  }

}
// ;P
