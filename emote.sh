#!/bin/bash
base_url="https://discord.com/api/v8"
dir=$(dirname "$0")

function fetch_data () {
    curl --silent -H "Content-Type: application/json" -H "Authorization: $token" \
        "$base_url$1"
}

function rm_tr_quotes () {
    echo "$1" | sed -e 's/^"//' -e 's/"$//'
}

if [ ! -d emotes ]; then
    echo -n "Enter your discord authentication token: "
    read -s token
    
    if [[ $(fetch_data "/users/@me" | jq '.message') = '"401: Unauthorized"' ]]; then
        echo -e "\nIncorrect token"
        exit 1
    fi

    echo -e "\nStarting to download emotes..."

    mkdir -p emotes
    servers=$(fetch_data "/users/@me/guilds" | jq '.[] | .id')

    for id in $servers; do
        id=$(rm_tr_quotes $id)
        fetch_data "/guilds/$id/emojis" | jq -c '.[]'|
            while read line; do
                name=$(rm_tr_quotes $(echo $line | jq '.name'))
                emote_id=$(rm_tr_quotes $(echo $line | jq '.id'))
                url="https://cdn.discordapp.com/emojis/$emote_id"
                filetype=$(curl -s -I $url | grep "^content-type: " | awk '{ print $2 }' | sed 's/.*\///g')
                filename=$(echo "emotes/$name.$filetype" | sed 's/\r//g')
                if [ ! -f $filename ]; then
                    echo "Downloading $name..."
                    wget -q -O $filename $url
                    convert -resize "48x48" $filename $filename
                    [ -s $filename ] || rm $filename
                    echo "$name \"$filename\" 0" >> emote_data
                else
                    echo "Skipping $name...\n"
                fi
            done
    done
fi;

selected=$(sort -k 3 -r $dir/emote_data | awk '{ print $1 }' | \
    while read entry; do
        name=":${entry%%.*}:"
        echo $name
    done | rofi -dmenu -i -p "Emote:" -no-custom -sort)

if [ "$selected" ]; then
    selected=$(echo $selected | cut -d ":" -f 2)
    real_fn=$dir/$(rm_tr_quotes $(grep "^$selected " $dir/emote_data | awk '{print $2}'))
    mime_type=$(file -b --mime-type "$real_fn")

    sed -E -i 's/(^'"$selected"') (".*") ([0-9]*)/echo "\1 \"\2\" $((\3+1))"/ge' emote_data

    if [[ "$mime_type" == image/png ]]; then
        xclip -se c -t image/png -i $real_fn 
        WID=$(xdotool search --class --classname "Discord" | head -1)
        if [ "$WID" ]; then
            xdotool windowactivate $WID
            xdotool key ctrl+v
            xdotool key KP_Enter
        else
            echo "You do not have discord open"
            exit 1
        fi
    else
        dragon $real_fn --and-exit # temporary fix since gifs aren't getting copied to the clipboard
    fi
fi