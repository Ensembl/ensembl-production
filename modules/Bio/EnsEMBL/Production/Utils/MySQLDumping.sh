#!/bin/bash --

database=$1
output_dir=$2
host=$3
user=$4
password=$5
port=$6

rm -r "$output_dir/$database"
mkdir -m 777 -p "$output_dir/$database"
cd "$output_dir/$database"
echo "Dumping $database";
EXCLUDED_TABLES=(
MTMP_probestuff_helper
MTMP_evidence
MTMP_motif_feature_variation
MTMP_phenotype
MTMP_regulatory_feature_variation
MTMP_supporting_structural_variation
MTMP_transcript_variation
MTMP_variation_set_structural_variation
MTMP_variation_set_variation
)
for TABLE in "${EXCLUDED_TABLES[@]}"
do :
   IGNORED_TABLES_STRING+=" --ignore-table=${database}.${TABLE}"
done
mysqldump -T ${output_dir}/${database} ${IGNORED_TABLES_STRING} --host=$host --user=$user --password=$password --port=$port $database;
echo "Removing the individual table sql files for $database"
rm -f *.sql
echo "Dumping sql file for $database";
mysqldump --host=$host --user=$user --password=$password --port=$port ${IGNORED_TABLES_STRING} -d $database > ${output_dir}/$database/$database.sql;
echo "Gzipping txt files";
ls -1 | grep .txt | grep -v LOADER-LOG | while read file; do
        gzip -c "$file" > "$output_dir/$database/$file.gz"
        rm -f $file
done
if [ -e "$database.sql" ]; then
    echo "Gzipping existing $database.sql file"
    gzip -nc $database.sql > "$output_dir/$database/$database.sql.gz"
    rm -f $database.sql
fi
echo "Creating CHECKSUM for $database"
ls -1 *.gz | while read file; do
    sum=$(sum $file)
    echo -ne "$sum\t$file\n" >> CHECKSUMS
done

