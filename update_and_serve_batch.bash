#!/bin/bash

# Strictness guards
set -e
set -o errexit
shopt -s -o errexit

st=~/staging
BA=~/cbzbatch

# Create staging dir
mkdir -p $st
rm -fr $st

# Clear existing batches
mkdir -p $BA
rm -fr $BA/*

sedscript=$(sed -n -Ee "/^EOF$/{x;s/\n/;/g;p;d};/^[^#]/{H;d}" <<__here
# Copy full path to hold
h

# Set up ln command with the file's original path delimited by a newline in the buffer
s/^(.*)$/ln -sT\n\1/

# Swap to the stored full path
x

# Extract last three elements in path, series/chapter #(.version)/page #.jpg
# then add staging directory prefix
# then insert zeros in front of chapter, version (whether it was there or not) and page #
s/^.*\/([^\/]+)\/[^\/[:digit:]]*([[:digit:]]+)[\.]?([[:digit:]]*)[^\/]*\/([^\/]+$)/${st//\//\\/}\/\1\n0000\2.00\3\/0000\4/

# Remove extraneous zeros to cause leftpadding,
# remove path slash,
# and insert a newline delimiter between the series name and the filename
s_(.*)\n0*([[:digit:]]{4,})\.0*([[:digit:]]{2,})/0*([[:digit:]]{4,}.+$)_\1\n\2\3\4_

# Append the series name and file name to the ln command in the buffer with a newline in front
H

# Extract only the series name (part before the newline) into a mkdir command and execute it
s_(.*)\n.*_mkdir -p \"\1\"_e

# Swap to the ln command in the buffer
x

# Remove all the newline delimiters, surround paths with quotes and execute the ln command
s/^(.*)\n(.*)\n(.*)\n(.*)$/\1 \"\2\" \"\3\/\4\"/e
EOF
__here
)

link() {
	echo -e "\t $1"

	# Pipe all the jpegs, filtering some junk files with grep,
	# Code generation with sed, filter unique lines,
	# Launch nested parallel execution
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
#rm -r $st

cd $BA
python -m 'http.server'
