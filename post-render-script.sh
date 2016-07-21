#!/bin/bash
#
# post-render-script.sh
#   A script to run after a Kdenlive/MLT rendering job has finished. This
#   script then looks for (iTunes-compatible) meta data to be added to
#   the newly rendered video file. The rendered file MUST be an MP4 container
#   with a file name ending in .mp4. The meta data is taken from a text
#   file with the same file name as the rendered file, but ending in .meta.
#   This meta data file can be located anywhere below $METADATADIR. A good
#   place may be with the folder containing your Kdenlive project. This
#   script can also add a single cover art, if present. In order to find
#   the cover art image file, it needs to have the same file name as the
#   rendered file but with -cover.jpeg, -cover.jpg, or -cover.png.
#
#   For example:
#   - rendered file is in /home/foo/video/bar-video.mp4
#   - meta data file is searched for as bar-video.meta
#   - cover art image file is searched for as bar-video-cover.jpeg, etc.
#
# Adjust METADATADIR to your needs; for instance, this may point to then
# root folder of your Kdenlive projects -- so you can keep the metadata
# and cover art picture files together with the particular Kdenlive project.
#
# License:
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
METADATADIR=~/kdenlive
if [[ $# -eq 0 ]]
then
    echo "usage: post-render-script.sh notification [metadataroot]"
    echo "  notification -- a rendering finished notification message"
    echo "  metadataroot -- optionally specifiy folder from which to search"
    echo "                  for meta data and cover image files."
    echo "                  If unspecified, default is:"
    echo "                  $METADATADIR"
    exit 1
fi
if [[ ! -z "$2" ]]
then
    METADATADIR="$2"
fi
#
shopt -s globstar
#
# Ensure that the rendering message handed over to us as the first parameter
# seems to contain the file name of an MP4 container, that is we see a
# ".mp4" file extension.
#
rendfile="$1"
if [[ $rendfile =~ .mp4 ]]
then
    #
    # Extract the path+name of the rendered video file from the "rendering
    # of yada yada yada finished" message and place it in $rendfile.
    #
    rendfile=${rendfile#*/}     # remove everything up to the first slash that
                                # starts the path+name of the rendered file.
    rendfile=${rendfile%.mp4*}  # remove everything after the file name, but
                                # for this we need a known anchor, so lock
                                # onto the .mp4 suffix.
    rendfile="/${rendfile}.mp4" # put back what we needed to nibble off before.
    #echo "Rendered file: $rendfile"
    #
    # Extract only the filename without path and without file extension as
    # we will this as the stem of the metadata and cover art files we will
    # try to find in a few seconds. Again, we rely on bash-internal functions.
    #
    metadatastem=${rendfile##*/} # nibble of everything up to the final slash
                                 # before the filename+extension.
    metadatastem=${metadatastem%\.mp4} # finally nibble of the extension too.
    #echo "Meta data file: $metadatastem"
    #
    # Try to find the metadata and cover art files associated with the
    # video file that was just rendered successfully.
    #
    IFS="" locations=(${METADATADIR}/**/${metadatastem}.meta)
    #echo "Found: ${locations[*]}"
    #
    # Make sure we really found only one meta data file and also make sure
    # that the only result isn't the glob itself.
    #
    if [[ !($locations =~ "**") && (${#locations[@]} -eq 1) ]]
    then
        #
        # Read in the meta data file and construct the command line arguments
        # to be used on AtomicParsley.
        #
        metadatafile=${locations[0]}
        opts=()
        while IFS="=" read -r key value; do
            #echo "$key: $value"
            opts+=("--${key}")
            opts+=("$value")
        done <"${metadatafile}"
        #echo "AtomicParsley: ${opts[*]}"
        #
        # Check if there's also cover art available from the place where
        # we found the meta data file. Try to locate a file with the same
        # stem as the meta data file and with "-cover" appended. For the
        # image type, be liberal in that you accept .png/.jpeg/.jpg
        # -- but no mixed case allowed ;)
        #
        coverartstem="${metadatafile%.meta}-cover"
        coverartfile="$coverartstem.jpeg"
        [[ ! -f "$coverartfile" ]] && coverartfile="$coverartstem.jpg"
        [[ ! -f "$coverartfile" ]] && coverartfile="$coverartstem.png"
        #
        # If we have found cover art, then tell AtomicParsley to add it to
        # the freshly rendered video file too. In any case, always add the
        # meta data.
        #
        if [[ -f "$coverartfile" ]]
        then
            echo "with cover art from: $coverartfile"
            AtomicParsley "$rendfile" --overWrite --artwork REMOVE_ALL  --artwork "$coverartfile" "${opts[@]}"
        else
            #echo "without cover art"
            AtomicParsley "$rendfile" --overWrite --artwork REMOVE_ALL "${opts[@]}"
        fi
        r=$?
        if [ $r -ne 0 ]
        then
            notify-send --urgency=critical -t 0 "Adding meta data to rendered file <i>${rendfile}</i> failed!"
        else
            notify-send --urgency=normal "Meta data added to rendered file <i>${rendfile}</i>."
        fi
    else
        #echo "No meta data found."
        :
    fi
fi
