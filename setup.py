from setuptools import find_namespace_packages, setup

with open('VERSION') as f:
    version = f.read()

setup(
    name='ensembl-production',
    version=version,
    packages=find_namespace_packages(where='src/python'),
    package_dir={"": "src/python"},
    license='Apache 2.0',
    include_package_data=True,
    zip_safe=False,
    entry_points={
        "console_scripts": [
            "dc-parser=scripts.dcparse:main",
            "dc-stat=scripts.dcstat:main",
            "meta-hive-species=scripts.meta_hive_species:main",
        ]
    }    
)
