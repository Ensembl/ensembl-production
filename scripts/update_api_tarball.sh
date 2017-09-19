#!/bin/bash --

dir=$1
ftp_dir=$2
if [ ! -d "$dir" ]; then
    mkdir $dir
fi
if [ ! -d "$ftp_dir" ]; then
    echo "Could not find FTP directory $ftp_dir" 1>&2 
    exit 1
fi
cd $dir
list="ensembl ensembl-io ensembl-tools ensembl-variation ensembl-funcgen ensembl-compara"
for repo in $list; do
    branch=$(curl -s https://api.github.com/repos/Ensembl/$repo | json_reformat | grep default_branch | sed -e 's/.*: "\(.*\)".*/\1/')
    if [ ! -d "$repo" ]; then
        git clone -b $branch https://github.com/Ensembl/$repo || {
            echo "Could not clone $repo" 1>&2 
            exit 2
        }
    else
        cd $repo
        git checkout $branch
        git fetch || {
            echo "Could not fetch $repo" 1>&2 
            exit 2
        }
        git checkout $branch || {
            echo "Could not checkout $repo $branch" 1>&2 
            exit 2
        }
        git pull || {
            echo "Could not pull $repo" 1>&2 
            exit 2
        }
        cd -
    fi    
done
tarball=ensembl-api.tar.gz
rm -f $tarball
tar cvzf $tarball $list --exclude="*/.*" 
tgt_tarball="$ftp_dir/$tarball"
if ! cmp --silent $tarball $tgt_tarball; then
    echo "Updating $tgt_tarball"
    cp $tarball $tgt_tarball
fi

