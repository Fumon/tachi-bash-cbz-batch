#!/bin/bash

# Strictness guards
set -e
set -o errexit
shopt -s -o errexit

st=staging
BA=cbzbatch

# Create staging dir
mkdir -p $st
rm -fr $st

# Clear existing batches
mkdir -p $BA
rm -fr $BA/*

sedscript=$(sed -n -Ee "/^EOF$/{x;s/\n/;/g;p;d};/^[^#]/{H;d}" <<__here
# Copy to hold
h

# Set up ln command with original path as first argument
s/^(.*)$/ln -sT\n\1/

# Swap to hold
x

# Extract last three elements in path, (series/chapter #/page #.jpg)
# then add staging directory prefix
# and leftpad chapter and page with zeros
s/^.*\/([^\/]+)\/[^\/[:digit:]]*([[:digit:]]+)[^\/]*\/([^\/]+$)/$st\/\1\n0000\2\/0000\3/

# Remove extraneous zeros and remove slash
s_(.*)\n0*([[:digit:]]{4,})/0*([[:digit:]]{4,}.+$)_\1\n\2\3_

# Append to ln command in hold
H

# Extract series name into mkdir command
s_(.*)\n.*_mkdir -p \"\1\"_e

# Swap
x

# Final cleanup and insert staging path
s/^(.*)\n(.*)\n(.*)\n(.*)$/\1 \"\2\" \"\3\/\4\"/e
EOF
__here
)

link() {
	echo -e "\t $1"

	# Pipe all the jpegs, filtering some junk files with grep,
	# Run generated commands with sed
	find "$1" -type f -name *.jpg | grep -v \.trashed | sed -n -Ee "$2"
}


compress() {
	series=$(basename "$1")
	sCh=$(ls -1 "$1" | head -1)
	sCh=${sCh:0:4}
	eCh=$(ls -1 "$1" | tail -1)
	eCh=${eCh:0:4}
	range="$sCh-$eCh"
	echo -e "\t$series: $range"

	7z a -l -tzip "$BA/$series $range.cbz" "$1/*" > /dev/null
}

export sedscript
export BA
export -f link
export -f compress

echo '/// Begin Linking \\\'
find ~/T/downloads/*/*/* -type d -print0 | parallel -0 "link {} \"$sedscript\""
echo '\\\ Finished Linking ///'

echo "--- Compressing ---"
find $st/* -type d -print0 | parallel -0 compress "{}"
echo "--- DONE ---"


# Remove Staging
rm -r $st

cd $BA
python -m 'http.server'
