#!/bin/bash --
srv=""
db=""

usage() {
    echo "Usage: $0 -s <server> -d <db>" 1>&2
}

chk=0
while getopts ":s:d:" opt; do
    case $opt in
    s)
    srv=$OPTARG
    ;;
    d)
    db=$OPTARG
    ;;
    \?)
    echo "Invalid option: -$OPTARG" >&2
    usage
    exit 1
    ;;
    :)
    echo "Option -$OPTARG requires an argument." >&2
    usage
    exit 1
    ;;
    esac
done
shift $(($OPTIND-1))
if [ -z "$srv" ] || [ -z "$db" ]; then
    usage;
    exit 1;
fi

mysql $($srv details mysql) $db -e "select 1" >& /dev/null || {
    echo "$db not found on $srv" 1>&2
    exit 1
};
exit 0
