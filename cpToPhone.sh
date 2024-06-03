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

echo Copying files to $dest | tee output.log

#Converts all .flac files in the playlist to variable bitrate (V0) .mp3 and saves them in the destinaiton folder
while read -u 10 line; do
  #Read sometimes doesn't get the whole line
  oldFile=$(grep -F "$line" $1)
  if [ "$line" != "$oldFile" ]; then printf "Read line error: $line\n" | tee -a output.log; fi
  if (( $(grep -c . <<<"$oldFile") > 1 )); then
    echo ERROR: Found more than one line in "$line"
    continue
  fi

  #Skip the line if the extension is not flac
  ext=${oldFile##*.}
  if [ "${ext,,}" != "flac" ]; then continue; fi 

  #sets the destination filename by replacing the starting ../ with the $dest path
  newDest=$(echo "$oldFile" | sed -e "s|^\.\.|$dest|")
  newFile=${newDest/%flac/mp3}

  #create the path for each file that will be converted. ffmpeg will throw an error if the path doesn't already exist
  mkdir -p "$(dirname "$newFile")"

  #If the mp3 version of the flac is older than the flac or doesn't exist in the destination, convert it from Flac to variable bitrate mp3
  if [ "$oldFile" -nt "$newFile" ]; then 
    echo Converting $oldFile | tee -a output.log | tee -a test.txt
    ffmpeg -y -i "$oldFile" -qscale:a 0 "$newFile" 2>> output.log
    sleep 1
    
    #Check if error running command
    if [ $? -ne 0 ]; then
      echo Conversion failed | tee -a output.log
      echo old: "$oldFile" | tee -a output.log
      echo new: "$newFile" | tee -a output.log
      tail -4 output.log | head -1
      echo | tee -a output.log
    fi
    
    #Check if conversion did not complete properly (sometime converted mp3s will be cut short)
    oldDer=$(ffprobe -loglevel error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$oldFile")
    newDer=$(ffprobe -loglevel error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$newFile")
    if [ $oldDer == $newDer ]; then echo Conversion corrupt - $oldFile | tee -a output.log; fi
    
    #Extract the lyrics with this command 
    #ffprobe -loglevel error -show_entries format_tags=lyrics,lyrics-eng,lyrics-XXX -of default=noprint_wrappers=1:nokey=1 file.mp3
  fi
  
  if [ ! -f "${newFile/%flac/mp3}" ]; then echo Not copied - $oldFile | tee -a output.log; fi
done 10<$1

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
while read line; do
  ext=${line##*.}
  if [ "${ext,,}" == "flac" ]; then continue; fi 
  cp -auv --parents "$line" "$dest"/Playlists
done <$1

#Copy the playlist file over, converting the .flac extenstion to match the newly converted mp3
sed s/\.flac$/\.mp3/g $1 >$dest/Playlists/$1

#List files that failed to convert
find $dest -size 0 | tee -a output.log
find $dest -size 0 -delete

#Cleanup log file if nothing was output
if [ "$(wc -l output.log)" == "1 output.log" ]; then rm output.log; fi
