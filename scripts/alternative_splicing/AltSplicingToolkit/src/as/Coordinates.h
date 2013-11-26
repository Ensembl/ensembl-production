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


#ifndef COORDINATES_H_
#define COORDINATES_H_

namespace as
{

  class Coordinates
  {
  public:
    Coordinates();
    Coordinates(unsigned int start, unsigned int end);

    virtual
    ~Coordinates();

  public:

    unsigned int getStart() const;
    unsigned int getEnd() const;
    unsigned int getLength() const;

    void setStart(unsigned int v);
    void setEnd(unsigned int v);

  protected:
    unsigned int start;
    unsigned int end;

  };

}

#endif /* COORDINATES_H_ */
