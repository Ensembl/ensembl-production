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


#ifndef GFFPARSER_H_
#define GFFPARSER_H_

#include <string>
#include <fstream>
#include <iostream>


using namespace std;

namespace gff {

  const int GFF_CHR=0;
  const int GFF_DATASOURCE=1;
  const int GFF_TYPE=2;
  const int GFF_START=3;
  const int GFF_END=4;
  const int GFF_SCORE=5;
  const int GFF_STRAND=6;
  const int GFF_PHASE=7;
  const int GFF_COMMENTS=8;

  const int GFF_GENE_ID=0;
  const int GFF_TRANSCRIPT_ID=1;
  const int GFF_EXON_ID=2;

  class GffHandler {

  public:
    virtual void start() = 0;
    virtual bool newline(string & str) = 0;
    virtual void end() = 0;

    // copy constructor
    const GffHandler &operator=( const GffHandler& inRhs ) { return inRhs; };
    // assignment operator
    //void GffHandler( const GffHandler &inParam );

  };

  class GffParser {

  public:
    GffParser(istream &iStream, GffHandler *handler);
    virtual ~GffParser();

  public:
    void parse();

  protected:
    istream &iStream;
    GffHandler *pHandler; //OK, pfile should point to a derived object

  };



}

#endif /* GFFPARSER_H_ */
