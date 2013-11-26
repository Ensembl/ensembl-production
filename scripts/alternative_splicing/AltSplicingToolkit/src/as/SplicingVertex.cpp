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


#include "SplicingVertex.h"

namespace as {

  SplicingVertex::SplicingVertex()
  {
  }

  SplicingVertex::SplicingVertex(int gLocation, int site, int graphIndex)
  {
    genomicLocation = gLocation;
    siteType = site;
    index = graphIndex;
  }

  SplicingVertex::~SplicingVertex()
  {
  }

  void SplicingVertex::addExon(const Exon& exon)
  {

    exons.push_back(exon);

  }

  int SplicingVertex::getIndex() const
  {
    return index;
  }

  int SplicingVertex::getSiteType()
  {
    return siteType;
  }

  int SplicingVertex::getGenomicLocation()
  {
    return genomicLocation;
  }

  ExonVector SplicingVertex::getExons()
  {
    return exons;
  }


}
