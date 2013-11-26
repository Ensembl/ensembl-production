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


#include "BioMartGffHandler.h"
#include "util/Logger.h"
#include <log4cpp/Category.hh>
#include <log4cpp/Appender.hh>

namespace gff {

  BioMartGffHandler::BioMartGffHandler()
  {
    limit = 0;

    //log4cpp::Appender* appender = util::Logger::getAppender();
    //parserLog = log4cpp::Category::getInstance(std::string("parser"));
    //parserLog.addAppender(appender);
  }

  BioMartGffHandler::BioMartGffHandler(int limit)
  {
    this->limit = limit;
  }

  BioMartGffHandler::~BioMartGffHandler()
  {
    //cout << "destroy BioMartGffHandler " << endl;
  }

  void BioMartGffHandler::start()
  {

    log4cpp::Category& root = log4cpp::Category::getRoot();
    //cerr << "get root priority" << root.getRootPriority() << endl;
    root.info("start BioMart parsing.");

    countExons = 0;
    countTranscripts = 0;
    countGenes = 0;
    exonStart = 0;
    exonEnd = 0;
    strand = 0;
    chr = "";
    newGene = false;

  }

  bool BioMartGffHandler::newline(string & str)
  {

    // parse the current line

    log4cpp::Category& root = log4cpp::Category::getRoot();

    if (limit > 0 && countGenes == limit) {
      return false;
    } else {

    bool bExon = false;
    column = 0;

    boost::sregex_token_iterator it(str.begin(), str.end(), eTab, -1);

    while(it != noMoreTokens)
      {

        if ( column <= GFF_TYPE || bExon )
          {
            switch (column) {

            case GFF_CHR:
              chr = *it;
              break;

            case GFF_STRAND:
              strand = (it->compare("+") == 0) ? 1 : -1;
              break;

            case GFF_TYPE:
              bExon = (it->compare("exon") == 0);
              break;

            case GFF_START:
              exonStart = util::StringUtil::ToInt(*it);
              break;

            case GFF_END:
              exonEnd = util::StringUtil::ToInt(*it);
              break;

            case GFF_COMMENTS:
              // split the string in pieces
              int countComments = 0;
              string comments = *it;
              boost::sregex_token_iterator itComments(comments.begin(), comments.end(), eComma, -1);
              while(itComments != noMoreTokens)
                {
                  string token = *itComments;
                  string identifier;
                  boost::sregex_token_iterator itID(token.begin(), token.end(), eFeatureId, 1);
                  if(itID != noMoreTokens)
                    {
                      identifier = *itID;
                    }

                  switch (countComments) {

                  case GFF_GENE_ID:

                    /**
                     * If the gene identifier has changed,
                     * we have to report it to find the splicing events
                     * on the current gene.
                     */
                    if (geneIdentifier.compare(identifier) != 0) {

                      // check if we had a previous gene
                      newGene = (geneIdentifier.length() > 0);
                      geneIdentifier = identifier;

                    }
                    break;

                  case GFF_TRANSCRIPT_ID:
                    transcriptIdentifier = identifier;
                    break;

                  case GFF_EXON_ID:
                    exonIdentifier = identifier;
                    break;
                  } // end countComments

                  itComments++;
                  countComments++;
                } // while comments

              break;
            }
          }

        // move to next column
        it++;
        column++;
      }

    /**
     * fire an GffNewGene event.
     */
    if (newGene)
      fireNewgeneEvent();


    // now that all the information is parsed.
    // look if it's a new transcript

    if(transcriptIdentifier.compare(currentTranscript) != 0) {

      currentTranscript = transcriptIdentifier;

      root.infoStream()<< currentTranscript << "(chr: " << chr << " strand: " << strand << ")" << log4cpp::eol;

      // create a new transcript on the heap
      Transcript *transcript = new Transcript(transcriptIdentifier);
      transcript->setGene(shared_ptr<Gene>(new Gene(geneIdentifier)));
      transcript->setStrand(strand);
      transcript->setChromosome(chr);
      // use insert instead of direct assignment.
      transcripts[currentTranscript].reset(transcript);
      //transcripts[currentTranscript] = new shared_ptr< Transcript >(transcript);
      //transcripts.insert(currentTranscript, new shared_ptr< Transcript >(transcript) );


    }

    if (bExon) {

      // we don't want to duplicate exons

      shared_ptr< Exon > pExon;

      // is the exon already stored?
      // check whether it's in the hash map
      // if not, add it to the map

      map<string, shared_ptr<Exon> >::const_iterator ii = exons.find( exonIdentifier );

      root.infoStream() << "\tExon: " << exonIdentifier << log4cpp::eol;

      if ( ii == exons.end() ) {

        // create a new exon on the heap
        //cout << exonIdentifier + "\t" << exonStart << "\t" << exonEnd  << endl;
        // create a new feature
        Exon *exon = new Exon(exonIdentifier);
        exon->setStart(exonStart);
        exon->setEnd(exonEnd);
        exon->setStrand(strand);
        exon->setChromosome(chr);

        // count the number of elements in the map
        // and assigned the current size to the feature

        exon->setIndex(exons.size()+1);

        // exons[exonIdentifier] = exon;
        //shared_ptr< Exon > pExon(exon);
        //exons[exonIdentifier] = exon;
        exons[exonIdentifier].reset(exon);
        //exons.insert(exonIdentifier, pExon);

      }

      //
      // add the shared pointer to the new exon to the transcript
      //

      transcripts[currentTranscript]->addExon(exons[exonIdentifier]);

      //
      // conversely add the transcript reference.
      //

      exons[exonIdentifier]->addTranscript(transcripts[currentTranscript]);


      //path.push_back(exonIdentifier);

      previousExon = exonIdentifier;

    }

    return true;
    }
  }

  void BioMartGffHandler::end()
  {
    if (transcripts.size() > 0)
      fireNewgeneEvent();
  }

  const map<string, shared_ptr< Exon > >&BioMartGffHandler::getExons()
  {
    return exons;
  }

  const map<string, shared_ptr< Transcript > >&BioMartGffHandler::getTranscripts()
  {
    return transcripts;
  }

  void BioMartGffHandler::fireNewgeneEvent() {


    //cout << exons.size()  << " exons parsed." << std::endl;
    //cout << transcripts.size() << " transcripts parsed." << std::endl;

    // fire new gene event

    log4cpp::Category& root = log4cpp::Category::getRoot();
    root.info("\n*** " + geneIdentifier + " ***\n");

    triggerEvent(shared_ptr<GffNewGeneEvent>(new GffNewGeneEvent(transcripts, exons)));

    // then reset the exons list and transcript list.

    //cout << "clear the current transcript list " << transcripts.size() << endl;
    transcripts.clear();
    //cout << "current transcript list done " << transcripts.size() << endl;

    //cout << "clear the current exon list " << exons.size() << endl;
    exons.clear();
    //cout << "current exon list done " << exons.size() << endl;

    //cout << "fireNewgeneEvent end" << endl;

    // purge the current status
    newGene = false;
    countGenes++;
  }

}

