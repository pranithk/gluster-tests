#!/bin/bash
function reset_mdata_entry() {
filepath=$1
changelogs=$(getfattr -h -d -m . -e hex $filepath 2>/dev/null | grep trusted.afr.*-client-)
for changelog in $changelogs;
do
        #echo $changelog
        read key value <<<$(echo $changelog | tr "=" "\n")
        #0x consumes till index 2 in the string
        datalog=${value:2:8}
        mdatalog=${value:10:8}
        resetlog="00000000"
        if [ $resetlog = $mdatalog ]
        then
                continue
        fi
        entrylog=${value:18:8}
        #echo $datalog
        #echo $resetlog
        #echo $entrylog
        cmd="setfattr -h -n $key -v 0x$datalog$resetlog$entrylog $filepath"
        #echo $cmd
        $cmd
        echo $filepath
done
}
function reset_mdata_recurse {

prune=""
gfid_str=$(getfattr -h -n trusted.gfid -e hex $path 2>/dev/null | grep trusted.gfid)
if [ "trusted.gfid=0x00000000000000000000000000000001" = $gfid_str ]
then
        prune="-path $path/.glusterfs -prune  -o -print"
fi

crawl_cmd="find $path $prune"

for filepath in `$crawl_cmd`
do
        reset_mdata_entry $filepath
done
#echo "crawl command used: $crawl_cmd"
}

#remove trailing slash
path=${1%/}
rec="-r"
read -d '' usage <<EOF
Usage: $0 <path> [$rec]
$rec is optional option for recursing on the <path>
EOF

if [ -z $path ];
then
        echo "${usage}"
        exit
fi

if [ ! -e $path ]
then
        echo "'$path' does not exist"
        exit
fi

if [ ! -z $2 ] && [ $2 != $rec ]
then
        echo "${usage}"
        exit
elif [ ! -z $2 ] && [ $2 = $rec ] && [ -d $path ]
then
        reset_mdata_recurse $path
else
        reset_mdata_entry $path
fi
