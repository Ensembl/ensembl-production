# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2022] EMBL-European Bioinformatics Institute
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
# limitations under the License.

use strict;
use warnings;

use Test::More;
use Test::Exception;
use File::Spec;
use File::Basename qw/dirname/;


diag("Testing DB renaming patterns ");

subtest "Version upgrade", sub {
    my $file_dir = dirname(dirname(__FILE__));
    my @in = ("ensembl_compara_109", "bacteria_109_collection_core_56_109_1", "homo_sapiens_core_109_38", "agrilus_planipennis_gca000109045v2_core_56_109_1");
    my @out = ();
    my @expected = ("ensembl_compara_110", "bacteria_109_collection_core_57_110_1", "homo_sapiens_core_110_38", "agrilus_planipennis_gca000109045v2_core_57_110_1");
    chdir($file_dir);
    my $script = File::Spec->catfile($file_dir, "get_new_db_name.pl");
    foreach (@in) {
        my $output = `$script $_`;
        chomp($output);
        push (@out, $output);
    }
    is_deeply(\@out, \@expected, "Same output as expected");
};

done_testing();