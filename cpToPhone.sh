#!/bin/bash
#Copies files in m3u playlist to a destination (only if they are newer [using cp -u] )

#check if script was run with proper number of arguments
if [ ! "$1" ]; then echo "Script needs a playlist argument" && exit 1; fi
if [ ! "$2" ]; then echo "Script needs to know who's phone" && exit 1; fi

#adjusts the root part of the destination path based on if this is running from the server or from an NFS mount
root="/srv/6912da68-13d3-48c5-9deb-739a2024e7b9/blue/docs"
if [ ! -d /srv/6912da68-13d3-48c5-9deb-739a2024e7b9/blue/docs ]; then root=/mnt/cloudnas/docs;fi

#set destination variable using second argument
if [[ "$2" == [Kk]yle ]]; then dest=$root/kyle/Music/Phone; fi
if [[ "$2" == [Aa]llynn ]]; then dest=$root/Allynn/Music/Phone; fi

echo dest - $dest | tee output.log

#Converts all .flac files in the playlist to variable bitrate (V0) .mp3 and saves them in the destinaiton folder
grep "\.flac$" "$1" | while read b; do
  #'while read' often only gets part of the line, running grep will return the full line
  if [[ "$(grep "$b" "$1" | wc -l)" -eq 1 ]]; then
    a="$(grep "$b" "$1")"
  else
    echo Too many results for "$b" | tee -a output.log
  fi 

  #creates the destination filename by replacing the starting ../ with the $dest path
  new=$(echo "$a" | sed -e "s|^\.\.|$dest|")

  #create the path for each file that will be converted. ffmpeg will throw an error if the path doesn't already exist
  mkdir -p "$(dirname "$new")"

  #If the mp3 version of the flac is older than the flac or doesn't exist in the destination, convert it from Flac to variable bitrate mp3
  if [ "$a" -nt "${new[@]/%flac/mp3}" ]; then 
    echo Converting $a | tee -a output.log
    ffmpeg -y -i "$a" -qscale:a 0 "${new[@]/%flac/mp3}" 2>> output.log
    #Extract the lyrics with this command 
    #ffprobe -loglevel error -show_entries format_tags=lyrics,lyrics-eng,lyrics-XXX -of default=noprint_wrappers=1:nokey=1 file.mp3
    if [ $? -ne 0 ]; then
      echo Conversion failed | tee -a output.log
      echo old - $a | tee -a output.log
      echo new - "${new[@]/%flac/mp3}" | tee -a output.log
      tail -4 output.log | head -1
      echo | tee -a output.log
    fi
  fi
done

#Converts all existing .flac files in the dest folder
find "$dest" -type f -name *.flac | while read a; do
  #If the mp3 version of the flac doesn't exist in the destination, convert it from Flac to variable mp3
  if [ ! -f "${a[@]/%flac/mp3}" ]; then 
    echo Converting $a | tee -a output.log
    ffmpeg -i "$a" -qscale:a 0 "${a[@]/%flac/mp3}" 2>> output.log
    if [ $? -ne 0 ]; then
      echo Conversion failed | tee -a output.log
      echo $a | tee -a output.log
      tail -3 output.log | head -1
      echo | tee -a output.log
    fi
  else
    echo Converted. Safe to remove $a | tee -a output.log
  fi
done

#Copy anything that isn't a flac file over (only if it's newer [cp -u])
grep -v "\.flac$" "$1" | while read line; do
	cp -auv --parents "$line" "$dest"/Playlists
done

#Copy the playlist file over, converting the .flac extenstion to match the newly converted mp3
sed s/\.flac$/\.mp3/g $1 >$dest/Playlists/$1

if [ ! -f "${new[@]/%flac/mp3}" ]; then echo Not copied - $a | tee -a output.log; fi
