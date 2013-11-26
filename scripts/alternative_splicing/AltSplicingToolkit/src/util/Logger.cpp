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


#include "Logger.h"

namespace util {

  log4cpp::Appender* Logger::appender = 0;

  log4cpp::Appender* Logger::getAppender() {

    if (appender == 0) {

      appender = new log4cpp::OstreamAppender("default", &std::cerr);
      log4cpp::PatternLayout* patternLayout = new log4cpp::PatternLayout();
      patternLayout->setConversionPattern("%d{%H:%M:%S:%l} %c: %m\n"); //"%R %p %c %x: %m\n");
      appender->setLayout(patternLayout);
      //appender->setLayout(new log4cpp::BasicLayout());
      //log4cpp::Category& root = log4cpp::Category::getRoot();
      //root.addAppender(appender);
      
    }

    return appender;

  }

}
