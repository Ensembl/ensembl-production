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


#ifndef _SPLICING_GRAPH_H
#define _SPLICING_GRAPH_H

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

#include "Exon.h"
#include "Transcript.h"
#include "SplicingVertex.h"
#include "SplicingEvent.h"

#include <boost/multi_array.hpp>

using namespace boost;
using namespace as;

namespace as {

  //class SplicingVertex;

  // graph definition
  //typedef adjacency_matrix<directedS> Graph;
	/*
	 * An edge is simple a pair of integer position in the
	 * adjacency matrix.
	 */
  typedef std::pair<int,int> Edge;

  /*
   * A set of edges to return to the caller
   * is a vector of Edge instances.
   */
  typedef std::vector<Edge> Edges;
  typedef std::map<int, SplicingVertex> SplicingVertexMap;
  typedef std::vector<SplicingVertex> SplicingVertexVector;
  typedef boost::multi_array<bool, 2> BooleanMatrix;
  typedef BooleanMatrix::index BooleanIndex;
  //BooleanMatrix::extent_gen booleanExtents;

  class SplicingGraph {

    static int objectCount;

  public:
    SplicingGraph();
    ~SplicingGraph();

  protected:

    SplicingGraph(std::vector<int> gLocations, SplicingVertexMap vMap, Edges edges);
    void computeInputsOutputs();
    const SplicingVertexVector intersect(SplicingVertexVector setA, SplicingVertexVector setB);

  public:

    static SplicingGraph buildGraph(const Transcript& t1, const Transcript& t2);
    static void printMsg(const std::string& msg = "");

    SplicingVertexVector getInputs();
    SplicingVertexVector getOutputs();

    int getInDegree(unsigned int vertex);
    int getOutDegree(unsigned int vertex);

    SplicingVertexVector getInVertices(const SplicingVertex& vertex);
    SplicingVertexVector getOutVertices(const SplicingVertex& vertex);


    static void create_matrix(bool ***m, int size);
    static void delete_matrix(bool ***m, int size);
    static void display_matrix(bool ***m, int size);

    SplicingEventVector computeSplicingEvents();

  protected:

    std::vector<int> genomicLocations; // genomic locations of the vertices
    SplicingVertexMap vertexMap;       // map of all the vertices
    Edges edges;

    bool **adjacencyMatrix;            // 2-dimension array (matrix)
    unsigned int size;                 // number of vertices

    SplicingVertexVector inputs;       // inputs of the graph
    SplicingVertexVector outputs;      // outputs of the graph

  };

}

#endif /* not defined _SPLICING_GRAPH_H */
