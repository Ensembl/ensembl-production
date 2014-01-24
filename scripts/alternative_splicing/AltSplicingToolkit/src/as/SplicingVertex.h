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


#ifndef _AS_VERTEX_H
#define _AS_VERTEX_H

#include <utility>                   // for std::pair
#include <vector>
#include <string>
#include <iostream>
#include <fstream>
#include <sstream>
#include <iterator>
#include <vector>
#include <map>
#include <utility>                   // for std::pair
#include <algorithm>
//#include <boost/graph/graph_traits.hpp>
//#include <boost/graph/adjacency_list.hpp>
//#include <boost/graph/adjacency_matrix.hpp>
//#include <boost/graph/dijkstra_shortest_paths.hpp>

#include "Exon.h"
#include "Transcript.h"

namespace as {

  const int DONOR_SITE=1;
  const int ACCEPTOR_SITE=2;

  class SplicingVertex {

  public:
    SplicingVertex();
    SplicingVertex(int gLocation, int site, int graphIndex);
    ~SplicingVertex();

  public:

    void addExon(const Exon& exon);
    int getIndex() const;
    int getSiteType();
    int getGenomicLocation();
    ExonVector getExons();

  protected:
    int genomicLocation;
    int siteType;
    int index;
    ExonVector exons;

  };

}

#endif /* not defined _AS_VERTEX_H */
