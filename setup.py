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
            "ensprod-dc-parser=scripts.dcparse:main",
            "ensprod-dc-stat=scripts.dcstat:main",
            "ensprod-meta-species=scripts.meta_hive_species:main",
            "ensprod-check-ftp=scripts.checkftpfiles:main",
        ]
    }    
)
