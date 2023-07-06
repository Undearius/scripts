#!/bin/bash
#Attempts to find and correct songs not found in the playlist file.
#(e.g. the file extension is different or the name has been updated)
#This script doesn't seem to work on NFS shares because of sed's use of temp files

#Search for file without extension ($2) in directory ($1)
#If it's not found there, then search in the root Music folder
function Ffind {
	find "$1" -type f -iname "$2.*" 2> /dev/null
	if [ $? -ne 0 ]; then
		find .. -type f -iname "$2.*"
	fi
}

#check if script was run with an argument
if [ ! "$1" ]; then echo "Script needs a playlist argument" && exit 1; fi

cat "$1" | while read line; do #Read each line of the playlist file
	if [ ! -f "$line" ]; then #If the file doesn't exist
		echo Analysing $line
		#Strip the path from the line
		filename=$(basename "$line")
		#Pass the path and filename without extension to the function
		replacement=$(Ffind  "$(dirname "$line")" "${filename%.*}")

		#Check if the function did not return anything
		if [ ! "$replacement" ]; then
			echo "Error: File not found"
			echo $line 
			echo
			continue
		fi

		echo old- $line
		echo new- $replacement
		echo

		#Escape special characters in variables to be used with sed
		line="$(<<< "$line" sed -e 's`[][&\\/.*^$]`\\&`g')"
		replacement="$(<<< "$replacement" sed -e 's`[][&\\/.*^$]`\\&`g')"

		#replace the filepath in playlist file
		sed -i "s/$line/$replacement/" "$1"
	fi
done
