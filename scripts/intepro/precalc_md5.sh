#!/bin/bash
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License
SET NEWPAGE   NONE;
SET PAGESIZE     0;
SET LINESIZE  200;
SET HEADING    OFF;
SET FEEDBACK   OFF;
SET TRIMSPOOL   ON;
SET TRIMOUT     ON;
SET WRAP       OFF;
SET TAB        OFF;
SET TERMOUT    OFF;
SET ECHO       OFF;
SET VERIFY     OFF;
SET TIMING     OFF;
SPOOL ipr_precalc_md5s
select /*+ parallel */ md5 from uniparc.protein where upi < (select  /*+ parallel */ max(upi) from iprscan.mv_iprscan);
SPOOL OFF