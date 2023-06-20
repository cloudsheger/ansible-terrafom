#!/bin/bash

set -x
# resize some volumess

expand_volume="RootVG/rootVol"
root_partition=$(lvs --noheadings -o devices "$expand_volume" | head -n1 | sed 's/(.*//' | xargs readlink -f)
root_partition_num=$(grep -o '[0-9]*$' <<< "$root_partition")
root_device=$(lsblk -pno pkname "$root_partition" | head -n1)

/usr/bin/growpart "$root_device" "$root_partition_num" \
    && pvresize "$root_partition" \
    && lvresize --resizefs --size +25G "$expand_volume" \
    || echo "Unable to expand $expand_volume size" 2> /dev/null

lvresize --resizefs --size +25G /dev/RootVG/homeVol

lvresize --resizefs --size +6G /dev/RootVG/varVol