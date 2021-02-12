#!/bin/bash
base_url="https://discord.com/api/v8"
dir=$(dirname "$0")

function fetch_data () {
    curl --silent -H "Content-Type: application/json" -H "Authorization: $token" \
        "$base_url$1"
}

function rm_tr_quotes () {
    temp="${$1%\"}"
    temp="${temp#\"}"
    echo "$temp"
}

if [ ! -d emotes ]; then
    echo -n "Enter your discord authentication token: "
    read -s token
    
    if [[ $(fetchData "/users/@me" | jq '.message') = '"401: Unauthorized"' ]]; then
        echo -e "\nIncorrect token"
        exit 1
    fi

    echo -e "\nStarting to download emotes..."

    mkdir -p emotes
    servers=$(fetchData "/users/@me/guilds" | jq '.[] | .id')

    for id in $servers; do
        id=$(rm_tr_quotes $id)
        fetchData "/guilds/$id/emojis" | jq -c '.[]'|
            while read line; do
                name=$(rm_tr_quotes $(echo $line | jq '.name'))
                emote_id=$(rm_tr_quotes $(echo $line | jq '.id'))
                printf "Downloading emote %s...\n" $name
                url="https://cdn.discordapp.com/emojis/$emote_id"
                filetype=$(curl -s -I $url | grep "^content-type: " | awk '{ print $2 }' | sed 's/.*\///g')
                filename=$(echo "$dir/emotes/$name.$filetype" | sed 's/\r//g')
                wget -q -O $filename $url
                convert -resize "48x48" $filename $filename
                
                [ -s $filename] || rm $filename
            done
    done
    
fi;

selected=$(for img in $dir/emotes/*; do
               bn=$(basename -- "$img")
               fn=":${bn%%.*}:"
               echo -e "$fn"
           done | rofi -dmenu)
           
if [ "$selected" ]; then
    selected=$(echo $selected | cut -d ":" -f 2)
    echo $selected
    real_fn=$(find emotes -type f -name "$selected.*" | head -1)
    mime_type=$(file -b --mime-type "$real_fn")

    if [[ "$mime_type" == image* ]]; then
        xclip -se c -t $mime_type -i $real_fn 
        WID=$(xdotool search --class --classname "Discord" | head -1)
        if [ "$WID" ]; then
            xdotool windowactivate $WID
            xdotool key ctrl+v
            xdotool key KP_Enter
        else
            echo "You do not have discord open"
        fi
    fi
fi
