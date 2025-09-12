#!/usr/bin/env python3
"""
Taxonomy patching script for Ensembl databases.

This script generates SQL patch files and optionally bash renaming scripts
to update species taxonomy information in Ensembl databases.
"""

import argparse
import sys
import os
import requests
import re
from typing import Dict, List, Optional, Tuple

from ensembl.utils.database.dbconnection import DBConnection
from ensembl.ncbi_taxonomy.api.utils import Taxonomy
from ensembl.core.models import Meta


class TaxonomyPatcher:
    """Handles taxonomy patching operations for Ensembl databases."""

    # Server configurations
    SERVERS = {
        'vertebrates': {
            'host': 'mysql-ens-sta-1',
            'port': 4519,
            'user': 'ensro'
        },
        'bacteria': {
            'host': 'mysql-ens-sta-4',
            'port': 4494,
            'user': 'ensro'
        },
        'default': {  # fungi, protists, metazoa, plants
            'host': 'mysql-ens-sta-3',
            'port': 4160,
            'user': 'ensro'
        }
    }

    # Species file URLs
    SPECIES_URLS = {
        'fungi': 'https://ftp.ebi.ac.uk/pub/ensemblgenomes/release-{}/fungi/species_EnsemblFungi.txt',
        'protists': 'https://ftp.ebi.ac.uk/pub/ensemblgenomes/release-{}/protists/species_EnsemblProtists.txt',
        'bacteria': 'https://ftp.ebi.ac.uk/pub/ensemblgenomes/release-{}/bacteria/species_EnsemblBacteria.txt',
        'metazoa': 'https://ftp.ebi.ac.uk/pub/ensemblgenomes/release-{}/metazoa/species_EnsemblMetazoa.txt',
        'plants': 'https://ftp.ebi.ac.uk/pub/ensemblgenomes/release-{}/plants/species_EnsemblPlants.txt',
        'vertebrates': 'https://ftp.ebi.ac.uk/pub/ensembl/release-{}/species_EnsemblVertebrates.txt'
    }

    def __init__(self, division: str, old_release: str, db_release: str,
                 old_taxid: int, new_taxid: int):
        """Initialize the taxonomy patcher.

        Args:
            division: Division name (fungi, protists, bacteria, metazoa, plants, vertebrates)
            old_release: Old release number
            db_release: Database release number
            old_taxid: Old taxonomy ID
            new_taxid: New taxonomy ID
        """
        self.division = division.lower()
        self.old_release = old_release
        self.db_release = db_release
        self.old_taxid = old_taxid
        self.new_taxid = new_taxid

        # Validate division
        if self.division not in self.SPECIES_URLS:
            raise ValueError(f"Invalid division: {division}. Must be one of: {list(self.SPECIES_URLS.keys())}")

        # Determine server configuration
        if self.division == 'vertebrates':
            self.server_config = self.SERVERS['vertebrates']
        elif self.division == 'bacteria':
            self.server_config = self.SERVERS['bacteria']
        else:
            self.server_config = self.SERVERS['default']

    def get_species_info(self) -> Dict[str, Dict]:
        """Fetch species information from FTP.

        Returns:
            Dictionary mapping species names to their metadata
        """
        url = self.SPECIES_URLS[self.division].format(self.old_release)

        try:
            response = requests.get(url)
            response.raise_for_status()
        except requests.RequestException as e:
            raise RuntimeError(f"Failed to fetch species data from {url}: {e}")

        species_data = {}
        lines = response.text.strip().split('\n')

        # Skip header line if it starts with #
        start_line = 1 if lines[0].startswith('#') else 0

        for line in lines[start_line:]:
            if not line.strip():
                continue

            parts = line.split('\t')
            if len(parts) >= 14:  # Ensure we have enough columns
                species_info = {
                    'name': parts[0],
                    'species': parts[1],
                    'division': parts[2],
                    'taxonomy_id': int(parts[3]),
                    'assembly': parts[4],
                    'assembly_accession': parts[5],
                    'genebuild': parts[6],
                    'core_db': parts[13],
                    'species_id': int(parts[14]) if parts[14].isdigit() else None
                }
                species_data[parts[1]] = species_info

        return species_data

    def find_species_by_taxid(self, species_data: Dict, taxid: int) -> Optional[Dict]:
        """Find species information by taxonomy ID.

        Args:
            species_data: Species data dictionary
            taxid: Taxonomy ID to search for

        Returns:
            Species information dict or None if not found
        """
        for species_name, info in species_data.items():
            if info['taxonomy_id'] == taxid:
                return info
        return None

    def update_database_name(self, old_db_name: str) -> str:
        """Update database name to use new release numbers.

        Args:
            old_db_name: Original database name from species file

        Returns:
            Updated database name with new release
        """
        # Pattern to match release numbers in database name
        # e.g., fungi_ascomycota4_collection_core_62_115_1 -> fungi_ascomycota4_collection_core_63_116_1
        pattern = r'_(\d+)_(\d+)_(\d+)$'

        # Replace with new release numbers
        if self.division == 'vertebrates':
            # Vertebrates: core_115_1 -> core_116_1
            new_db_name = re.sub(r'_(\d+)_(\d+)$', f'_{self.db_release}_1', old_db_name)
        else:
            # EnsemblGenomes: core_62_115_1 -> core_63_116_1
            print (old_db_name)
            new_db_name = re.sub(pattern, f'_{self.db_release.split("_")[0]}_{self.db_release.split("_")[1]}_1',
                                 old_db_name)

        return new_db_name

    def get_database_connection(self, database_name: str) -> DBConnection:
        """Create database connection for the specified database.

        Args:
            database_name: Name of the database to connect to

        Returns:
            DBConnection instance
        """
        url = f"mysql://{self.server_config['user']}@{self.server_config['host']}:{self.server_config['port']}/{database_name}"
        return DBConnection(url)

    def get_taxonomy_connection(self) -> DBConnection:
        """Create connection to taxonomy database.

        Returns:
            DBConnection instance for taxonomy database
        """
        # Assuming taxonomy database is on the same server
        url = f"mysql://{self.server_config['user']}@{self.server_config['host']}:{self.server_config['port']}/ncbi_taxonomy"
        return DBConnection(url)

    def get_lineage(self, taxid: int) -> List[Dict]:
        """Get taxonomic lineage for a given taxonomy ID.

        Args:
            taxid: Taxonomy ID

        Returns:
            List of ancestor taxonomy information
        """
        taxonomy_dbc = self.get_taxonomy_connection()

        with taxonomy_dbc.session_scope() as session:
            try:
                ancestors = Taxonomy.fetch_ancestors(session, taxid)
                # Add the taxon itself
                current_taxon = Taxonomy.fetch_node_by_id(session, taxid)

                lineage = []
                for ancestor in ancestors:
                    lineage.append({
                        'taxon_id': ancestor['taxon_id'],
                        'name': ancestor.get('name', ''),
                        'rank': ancestor.get('rank', '')
                    })

                # Add current taxon
                lineage.append({
                    'taxon_id': current_taxon.taxon_id,
                    'name': current_taxon.name,
                    'rank': getattr(current_taxon, 'rank', '')
                })

                return lineage

            except Exception as e:
                print(f"Warning: Could not fetch lineage for taxid {taxid}: {e}")
                return []

    def get_species_id_from_production_name(self, database_name: str, production_name: str) -> Optional[int]:
        """Get species_id from meta table using production name.

        Args:
            database_name: Database name
            production_name: Species production name

        Returns:
            Species ID or None if not found
        """
        dbc = self.get_database_connection(database_name)

        with dbc.session_scope() as session:
            try:
                result = session.query(Meta).filter(
                    Meta.meta_value == production_name,
                    Meta.meta_key == 'species.production_name'
                ).first()

                if result:
                    return result.species_id

                # Try alternative lookup with species.db_name
                result = session.query(Meta).filter(
                    Meta.meta_value == production_name,
                    Meta.meta_key == 'species.db_name'
                ).first()

                return result.species_id if result else None

            except Exception as e:
                print(f"Warning: Could not find species_id for {production_name}: {e}")
                return None

    def get_meta_entries_for_species(self, database_name: str, species_id: int) -> List[Dict]:
        """Get all meta table entries for a specific species.

        Args:
            database_name: Database name
            species_id: Species ID

        Returns:
            List of meta table entries for the species
        """
        dbc = self.get_database_connection(database_name)

        with dbc.session_scope() as session:
            meta_entries = session.query(Meta).filter(Meta.species_id == species_id).all()
            return [
                {
                    'meta_id': entry.meta_id,
                    'species_id': entry.species_id,
                    'meta_key': entry.meta_key,
                    'meta_value': entry.meta_value
                }
                for entry in meta_entries
            ]

    def is_collection_database(self, database_name: str) -> bool:
        """Check if database is a collection database.

        Args:
            database_name: Database name

        Returns:
            True if collection database, False otherwise
        """
        return 'collection' in database_name.lower()

    def generate_new_production_name(self, old_production_name: str, new_scientific_name: str) -> str:
        """Generate new production name based on new scientific name.

        Args:
            old_production_name: Old production name
            new_scientific_name: New scientific name

        Returns:
            New production name
        """
        # Extract the GCA part if present
        gca_match = re.search(r'(gca_\w+)', old_production_name)
        gca_part = gca_match.group(1) if gca_match else ''

        # Convert scientific name to production name format
        new_base = new_scientific_name.lower().replace(' ', '_')

        if gca_part:
            return f"{new_base}_{gca_part}"
        else:
            return new_base

    def generate_rename_script(self, old_db_name: str, new_db_name: str) -> str:
        """Generate bash script for database renaming.

        Args:
            old_db_name: Old database name
            new_db_name: New database name

        Returns:
            Bash script content
        """
        # Determine server prefix for rename command
        if self.division == 'vertebrates':
            server_prefix = 'st1'
        elif self.division == 'bacteria':
            server_prefix = 'st4'
        else:
            server_prefix = 'st3'

        script_content = f"""#!/bin/bash
# Database rename script for taxonomy update
# Generated for taxid change: {self.old_taxid} -> {self.new_taxid}
# 
# IMPORTANT: Run this script BEFORE applying the SQL patch!
# The SQL patch expects the database to be already renamed.
#
# Non-collection databases must have their database name match 
# the production name, hence this rename is required.

echo "Renaming database: {old_db_name} -> {new_db_name}"
rename_db {server_prefix} {old_db_name} {new_db_name}

if [ $? -eq 0 ]; then
    echo "Database renamed successfully. You can now apply the SQL patch."
else
    echo "Database rename failed. Do not apply the SQL patch until this succeeds."
    exit 1
fi
"""
        return script_content

    def generate_sql_patch(self, species_info: Dict, database_name: str, species_id: int,
                           meta_entries: List[Dict], old_lineage: List[Dict],
                           new_lineage: List[Dict], new_scientific_name: str) -> str:
        """Generate SQL patch file content.

        Args:
            species_info: Species information
            database_name: Target database name
            species_id: Species ID in the database
            meta_entries: Current meta table entries
            old_lineage: Old taxonomic lineage
            new_lineage: New taxonomic lineage
            new_scientific_name: New scientific name

        Returns:
            SQL patch content
        """
        sql_lines = [
            f"-- Taxonomy patch for {database_name}",
            f"-- Changing taxid from {self.old_taxid} to {self.new_taxid}",
            f"-- Species ID: {species_id}",
            f"-- Generated for release {self.db_release}",
            "",
            f"USE {database_name};",
            ""
        ]

        # Update taxonomy IDs
        sql_lines.extend([
            "-- Update taxonomy IDs",
            f"UPDATE meta SET meta_value = '{self.new_taxid}' WHERE meta_key = 'species.species_taxonomy_id' AND species_id = {species_id};",
            f"UPDATE meta SET meta_value = '{self.new_taxid}' WHERE meta_key = 'species.taxonomy_id' AND species_id = {species_id};",
            ""
        ])

        # Generate new production name
        old_production_name = species_info['species']
        new_production_name = self.generate_new_production_name(old_production_name, new_scientific_name)

        # Update species names and identifiers
        sql_lines.extend([
            "-- Update species identifiers and names",
            f"UPDATE meta SET meta_value = 'Cytospora_schulzeri_gca_003795315' WHERE meta_key = 'species.url' AND species_id = {species_id};",
            f"UPDATE meta SET meta_value = '{new_production_name}' WHERE meta_key = 'species.production_name' AND species_id = {species_id};",
            f"UPDATE meta SET meta_value = '{new_scientific_name}' WHERE meta_key = 'species.scientific_name' AND species_id = {species_id};",
            f"UPDATE meta SET meta_value = '{new_scientific_name}' WHERE meta_key = 'species.species_name' AND species_id = {species_id};",
            f"UPDATE meta SET meta_value = '{new_production_name}' WHERE meta_key = 'species.db_name' AND species_id = {species_id};",
            f"UPDATE meta SET meta_value = '{new_scientific_name}' WHERE meta_key = 'species.display_name' AND species_id = {species_id};",
            ""
        ])
        # Handle classification updates
        if old_lineage and new_lineage:
            sql_lines.append("-- Update classification")

            # Get classification entries from lineage
            old_classification = [item['name'] for item in old_lineage if item.get('name')]
            new_classification = [item['name'] for item in new_lineage if item.get('name')]

            # Delete old classification entries that are not in new lineage
            for old_name in old_classification:
                if old_name not in new_classification:
                    sql_lines.append(
                        f"DELETE FROM meta WHERE meta_value = '{old_name}' AND species_id = {species_id} AND meta_key = 'species.classification';"
                    )

            # Add new classification entries
            for new_name in new_classification:
                if new_name not in old_classification:
                    sql_lines.append(
                        f"INSERT INTO meta (species_id, meta_key, meta_value) VALUES ({species_id}, 'species.classification', '{new_name}');"
                    )

            sql_lines.append("")

        # Add new alias (don't remove old ones)
        sql_lines.extend([
            "-- Add new species alias",
            f"INSERT INTO meta (species_id, meta_key, meta_value) VALUES ({species_id}, 'species.alias', '{new_production_name}');",
            ""
        ])
        return '\n'.join(sql_lines), new_production_name

    def run(self) -> Tuple[str, Optional[str]]:
        """Run the patching process.

        Returns:
            Tuple of (sql_patch_content, bash_script_content)
        """
        print(f"Processing taxonomy change: {self.old_taxid} -> {self.new_taxid}")
        print(f"Division: {self.division}")
        print(f"Server: {self.server_config['host']}:{self.server_config['port']}")

        # Get species information
        print("Fetching species information...")
        species_data = self.get_species_info()

        # Find old species by taxid
        old_species = self.find_species_by_taxid(species_data, self.old_taxid)
        if not old_species:
            raise RuntimeError(f"Could not find species with taxonomy ID {self.old_taxid}")

        print(f"Found species: {old_species['name']} ({old_species['species']})")

        # Update database name to use new release
        old_db_name = old_species['core_db']
        updated_db_name = self.update_database_name(old_db_name)

        print(f"Database: {old_db_name} -> {updated_db_name}")

        # Check if collection database
        is_collection = self.is_collection_database(updated_db_name)

        if is_collection:
            # For collection databases, find species_id
            species_id = self.get_species_id_from_production_name(updated_db_name, old_species['species'])
            if not species_id:
                raise RuntimeError(f"Could not find species_id for {old_species['species']} in {updated_db_name}")
            print(f"Found species_id: {species_id}")
        else:
            # For non-collection databases, species_id is typically 1
            species_id = 1

        # Get meta entries for this species
        print("Fetching meta table entries...")
        meta_entries = self.get_meta_entries_for_species(updated_db_name, species_id)

        # Get lineages
        print("Fetching taxonomic lineages...")
        old_lineage = self.get_lineage(self.old_taxid)
        new_lineage = self.get_lineage(self.new_taxid)

        # Get new scientific name from new lineage
        new_scientific_name = "Unknown species"
        if new_lineage:
            species_entry = next((item for item in new_lineage if item.get('rank') == 'species'), None)
            if species_entry and species_entry.get('name'):
                new_scientific_name = species_entry['name']
        if new_scientific_name == 'Unknown species':
            raise RuntimeError(f"Could not find new species name in taxonomy db")
        # Generate SQL patch
        sql_patch, production_name = self.generate_sql_patch(
            old_species, updated_db_name, species_id, meta_entries,
            old_lineage, new_lineage, new_scientific_name
        )

        # Generate bash script if not collection and database name changed
        bash_script = None
        if not is_collection:
            pattern = r'^(.*)_(\d+_\d+_\d+)$'
            new_db_name = re.sub(pattern, f'{production_name}_\\2', updated_db_name)

            if updated_db_name != new_db_name:
                bash_script = self.generate_rename_script(updated_db_name, new_db_name)

        return sql_patch, bash_script


def main():
    """Main function to run the taxonomy patcher."""
    parser = argparse.ArgumentParser(
        description='Generate taxonomy patches for Ensembl databases'
    )
    parser.add_argument('division',
                        choices=['fungi', 'protists', 'bacteria', 'metazoa', 'plants', 'vertebrates'],
                        help='Division name')
    parser.add_argument('old_release', help='Old release number')
    parser.add_argument('db_release', help='Database release number (e.g., "63_116")')
    parser.add_argument('old_taxid', type=int, help='Old taxonomy ID')
    parser.add_argument('new_taxid', type=int, help='New taxonomy ID')
    parser.add_argument('--output-dir', default='.', help='Output directory for generated files')
    parser.add_argument('--tracking-file', default='used_production_names.txt',
                        help='File to track used production names')

    args = parser.parse_args()

    # Create patcher instance
    patcher = TaxonomyPatcher(
        args.division, args.old_release, args.db_release,
        args.old_taxid, args.new_taxid
    )

    # Run patching process with tracking file
    tracking_file_path = os.path.join(args.output_dir, args.tracking_file)
    sql_patch, bash_script = patcher.run()

    # Generate output filenames
    base_filename = f"taxa_{args.old_taxid}_{args.new_taxid}"
    sql_filename = f"{base_filename}.sql"
    bash_filename = f"{base_filename}.sh"

    # Write SQL patch file
    sql_path = os.path.join(args.output_dir, sql_filename)
    with open(sql_path, 'w') as f:
        f.write(sql_patch)
    print(f"SQL patch written to: {sql_path}")

    # Write bash script if needed
    if bash_script:
        bash_path = os.path.join(args.output_dir, bash_filename)
        with open(bash_path, 'w') as f:
            f.write(bash_script)
        os.chmod(bash_path, 0o755)  # Make executable
        print(f"Bash script written to: {bash_path}")

    print("Patching complete!")



if __name__ == '__main__':
    main()