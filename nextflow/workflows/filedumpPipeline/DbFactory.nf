// See the NOTICE file distributed with this work for additional information
// regarding copyright ownership.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

process DbFactory {

  debug 'true'
  label 'mem20GB'
  errorStrategy 'finish'
  tag "${db_name}-top_level_sequence_build"
  maxForks 1

  input: 
  val(db_name)

  output:
  db_name
  species_id
  output_dir

  """
  mysql -e show schemas &&
   --username ${params.user} --password ${params.password}  --db ${params.server}/${db_name}
  """
}
