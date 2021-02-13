#!/bin/bash

base_url="https://discord.com/api/v8"
dir=$(dirname "$0")
data_file=$dir/emote_data
emote_col=$dir/emotes
thumbnail_path=$emote_col/gif_thumbnails
window_class="Discord"

function show_help () {
    echo "Usage: $(basename "$0") [OPTION...]"
    echo -e "A script to open a discord emote menu\n"
    echo "Options:"
    echo -e "-c, --rofi-config\tSpecify a custom config file for the rofi menu"
    echo -e "-u, --update-emotes\tDownload new emotes"
    echo -e "-w, --window-class\tWindow class to send the emote to. Default value is \"Discord\""
    echo -e "-h, --help\t\tDisplay this help menu\n"
    exit 0
}

function fetch_data () {
    curl --silent -H "Content-Type: application/json" -H "Authorization: $token" \
        "$base_url$1"
}

function rm_tr_quotes () {
    echo "$1" | sed -e 's/^"//' -e 's/"$//'
}

function invalid_option () {
    echo "Incorrect usage."
    exit 1
}


while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -c|--rofi-config)
            [ -z "$2" ] && invalid_option
            rofi_config="$2"
            shift
            shift
            ;;
        -w|--window-class)
            [ -z "$2" ] && invalid_option
            window_class="$2"
            shift
            shift
            ;;
        -u|--update-emotes)
            update_emotes=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *) 
            invalid_option
        ;;
    esac
done

if [ ! -d $emote_col ] || [ "$update_emotes" = true ]; then
    echo -n "Enter your discord authentication token: "
    read -s token
    
    if [[ $(fetch_data "/users/@me" | jq '.message') = '"401: Unauthorized"' ]]; then
        echo -e "\nIncorrect token"
        exit 1
    fi

    echo -e "\nStarting to download emotes..."

    mkdir -p $thumbnail_path
    if [ -f $data_file ]; then
        truncate -s 0 $data_file
    fi

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
                full_fn=$dir/$filename
                if [ ! -f $filename ]; then
                    echo "Downloading $name..."
                    wget -q -O $full_fn $url
                    convert -resize "48x48" $full_fn $full_fn
                    # create thumbnail to display in rofi
                    # not sure why it wouldn't let me compare filetype
                    [  ${full_fn##*.} = "gif" ] && convert $full_fn -delete 1--1 $thumbnail_path/$name.png
                    [ -s $full_fn ] || rm $full_fn
                    echo "$name $filename 0" >> $data_file
                else
                    echo "Skipping $name..."
                fi
            done
    done
fi;

rofi_cmd=(rofi -dmenu -i -p "Emote:" -no-custom -sort -show-icons)

if [ ! -z ${rofi_config+x} ]; then
    rofi_cmd+=(-config "$rofi_config")
fi

selected=$(sort -k 3 -r $data_file | \
    while read entry; do
        origname=$(echo $entry | awk '{print $1}')
        name=":${origname%%.*}:"
        img=$(echo $entry | awk '{print $2}')
        [ ${img##*.} = "gif" ] && img=emotes/gif_thumbnails/$origname.png
        if [ $PWD != $HOME ] && [ $PWD != $dir ]; then
            img=$(realpath $dir/$img)
        else 
            img=$dir/$img
        fi
        echo -e "$name\0icon\x1f$img"
    done | ${rofi_cmd[@]})

if [ "$selected" ]; then
    selected=$(echo $selected | cut -d ":" -f 2)
    real_fn=$dir/$(grep "^$selected " $data_file | awk '{print $2}')
    mime_type=$(file -b --mime-type "$real_fn")
    # increments usage counter
    sed -E -i 's/(^'"$selected"') (.*) ([0-9]*)/echo "\1 \2 $((\3+1))"/ge' $data_file

    if [[ "$mime_type" == image/png ]]; then
        xclip -se c -t image/png -i $real_fn 
        WID=$(xdotool search --class --onlyvisible --maxdepth 1 --limit 1 "$window_class")
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