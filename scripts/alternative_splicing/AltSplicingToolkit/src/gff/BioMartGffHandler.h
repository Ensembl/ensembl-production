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


#ifndef BIOMARTGFFHANDLER_H_
#define BIOMARTGFFHANDLER_H_

#include <string>
#include <fstream>
#include <iostream>
#include <map>

#include <boost/regex.hpp>
#include <boost/algorithm/string/regex.hpp>
#include <boost/shared_ptr.hpp>

#include <log4cpp/Category.hh>

#include "GffParser.h"
#include "GffEventModel.h"
#include "as/Feature.h"
#include "as/TranscriptFeature.h"
#include "as/Transcript.h"
#include "as/Gene.h"
#include "util/StringUtil.h"

using namespace std;
using namespace boost;
using namespace as;

namespace gff {

  const boost::regex eTab("\\t");
  const boost::regex eComma(";\\s*");
  const boost::regex eFeatureId("[a-z_]+\\s+\"(.+)\"");

  class BioMartGffHandler: public GffHandler, public GffNewGeneEventHandler {

  public:
    BioMartGffHandler();
    BioMartGffHandler(int limit);
    virtual ~BioMartGffHandler();

  public:
    void start();
    bool newline(string & str);
    void end();

    const map<string, shared_ptr<Exon> >&getExons();
    const map<string, shared_ptr<Transcript> >&getTranscripts();

  private:
    void fireNewgeneEvent();

  protected:
    int countExons;
    int countTranscripts;
    int column;

    int limit;
    int countGenes;

    string chr;
    unsigned int exonStart;
    unsigned int exonEnd;
    short int strand;

    string geneIdentifier;
    Gene *gene;
    bool newGene;

    string transcriptIdentifier;
    string exonIdentifier;

    string currentTranscript;
    string previousExon;

    map<string, shared_ptr<Exon> > exons;
    map<string, shared_ptr<Transcript> > transcripts;

    boost::sregex_token_iterator noMoreTokens;


  };

}

#endif /* BIOMARTGFFHANDLER_H_ */
