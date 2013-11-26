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


#include <log4cpp/Category.hh>

#include "SplicingEventGffGenerator.h"
#include "as/RegionChunk.h"


namespace gff
{

  SplicingEventGffGenerator::SplicingEventGffGenerator(ostream &oStream, string datasource, bool bCNE, bool bRELAX) : oStream(oStream), datasource(datasource)
  {
    countAI = 0;
    countAT = 0;
    countAFE = 0;
    countALE = 0;
    countIR = 0;
    countII = 0;
    countEI = 0;
    countCE = 0;
    countMXE = 0;

    genes = 0;
    genesWithEvents = 0;
    genesWithSeveralTranscripts = 0;

    this->bCNE = bCNE;
		this->bRELAX = bRELAX;

  }

  SplicingEventGffGenerator::~SplicingEventGffGenerator()
  {
    //cout << "destroy SplicingEventGffGenerator" << endl;
  }

  void SplicingEventGffGenerator::command(const shared_ptr<GffNewGeneEvent> &triggeredEvent)
  {

    log4cpp::Category& root = log4cpp::Category::getRoot();

    map<string, shared_ptr<Transcript> > transcripts = triggeredEvent->getTranscripts();
    map<string, shared_ptr<Exon> > exons = triggeredEvent->getExons();

    /***********************************************************************************/
    /* FIND CONSTITUTIVE EXONS                                                         */
    /***********************************************************************************/

    /**
     * The following data structure will contain a compact representation of
     * the region convenient to determine the list of constitutive exon
     * This could also work with a splicing graph structure
     */
    RegionChunk chunk;

    /**
     * Loop over all the transcripts and compare them to find the constitutive pieces of the gene
     * Find also the constitutive exons / region
     */
    for( map<string, shared_ptr<Transcript> >::const_iterator ii=transcripts.begin(); ii!=transcripts.end(); ++ii) {

      shared_ptr<Transcript> transcript = ii->second;
      chunk.mergeTranscript(transcript);

    }

    chunk.checkConstitutiveExon(transcripts.size());
    chunk.getEventsGffOutput(oStream, datasource);
    countCNE += chunk.getConstitutiveExonEvents().size();

    //return;



    /***********************************************************************************/
    /* FIND ALTERNATIVE SPLICING EVENTS                                                */
    /***********************************************************************************/

    /**
     * The following data structure will contain all the
     * splicing events classified by type (Exon Isoform, Cassette Exon, etc.)
     * allocated on the stack
     */
    SplicingEventContainer container;

    if (!bCNE) {

    /**
     * Loop over all the transcripts and compare them to find alternative events

     */
    int max2 = 0;

    for( map<string, shared_ptr<Transcript> >::const_iterator ii=transcripts.begin(); ii!=transcripts.end(); ++ii)
      {
        // reinit index2
        int index2 = 0;


        for( map<string, shared_ptr<Transcript> >::const_iterator ij=transcripts.begin(); ij!=transcripts.end(); ++ij)
          {

            // skip the comparisons already done (half the space)
            while (index2 <= max2) {
              index2++;
              ++ij;
            }

            if (ij == transcripts.end())
              break;

            shared_ptr<Transcript> t1 = ii->second;
            shared_ptr<Transcript> t2 = ij->second;

            if (t1->getIdentifier().compare(t2->getIdentifier()) != 0)
               // && t1->getIdentifier().compare("ENST00000353540") == 0
               // && t2->getIdentifier().compare("ENST00000357654") == 0)
              {
                root.infoStream() << t1->getIdentifier() + " <=> " + t2->getIdentifier() << log4cpp::eol;

                // build a splicing matrix
                //cout << "build the splicing matrix" << endl;
                SplicingEventMatrix matrix(t1, t2);

                // compute splicing events
                //cout << "compute splicing events" << endl;
                matrix.computeSplicingEvents(bRELAX);

                // store the new events in the container.
                //cout << "store the new events in the container" << endl;
                container.mergeSplicingEvents(matrix);

		//container.getSummaryOutput(cerr);

              }

          }

          max2++;

      }

    container.getGffOutput(oStream, datasource);

    }

    // cumulative stats

    genes++; // number of genes parsed from the input stream

    // number of genes with several transcripts

    if (transcripts.size() > 1) {

      genesWithSeveralTranscripts++;

    }

    // genes with events

    if (container.getEventCount() > 0) {

      genesWithEvents++;

      countAI += container.getAlternativeInitiationEvents().size();
      countAT += container.getAlternativeTerminationEvents().size();
      countAFE += container.getAlternativeFirstExonEvents().size();
      countALE += container.getAlternativeLastExonEvents().size();
      countIR += container.getIntronRetentionEvents().size();
      countII += container.getIntronIsoformEvents().size();
      countEI += container.getExonIsoformEvents().size();
      countCE += container.getCassetteExonEvents().size();
      countMXE += container.getMutuallyExclusiveEvents().size();

    }
  }

  int SplicingEventGffGenerator::getCountAI() const { return countAI; }
  int SplicingEventGffGenerator::getCountAT() const { return countAT; }
  int SplicingEventGffGenerator::getCountAFE() const { return countAFE; }
  int SplicingEventGffGenerator::getCountALE() const { return countALE; }
  int SplicingEventGffGenerator::getCountIR() const { return countIR; }
  int SplicingEventGffGenerator::getCountII() const { return countII; }
  int SplicingEventGffGenerator::getCountEI() const { return countEI; }
  int SplicingEventGffGenerator::getCountCE() const { return countCE; }
  int SplicingEventGffGenerator::getCountMXE() const { return countMXE; }
  int SplicingEventGffGenerator::getCountCNE() const { return countCNE; }
  int SplicingEventGffGenerator::getGeneCount() const { return genes; }
  int SplicingEventGffGenerator::getGenesWithEventsCount() const { return genesWithEvents; }
  int SplicingEventGffGenerator::getGenesWithSeveralTranscriptsCount() const { return genesWithSeveralTranscripts; }
  int SplicingEventGffGenerator::getEventCount() const
  {
    // don't sum the constitutive exon events
    return (countAI+countAT+countAFE+countALE+countIR+countII+countEI+countCE+countMXE);
  }

}
