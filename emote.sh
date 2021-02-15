#!/bin/bash

set -e

base_url="https://discord.com/api/v8"
dir=$(dirname "$0")
data_file=$dir/emote_data
emote_col=$dir/emotes
thumbnail_path=$emote_col/gif_thumbnails
window_class="Discord"
colon=false

function show_help () {
        echo "Usage: $(basename "$0") [OPTION...]"
        echo -e "A script to open a discord emote menu\n"
        echo "Options:"
        echo -e "-w, --window-class [class]         Window class to send the emote to. Set to \"Discord\" by default"
        echo -e "-r, --rofi-config  [file]          Specify a custom config file for the rofi menu"
        echo -e "-a, --add-emote    [image] [name?] Load emote into collection"
        echo -e "-d, --delete-emote [name]          Remove emote from collection"

        echo -e "-u, --update-emotes                Download new emotes"
        echo -e "-c, --colon                        Display colon at the beginning and end of emote name."
        echo -e "-h, --help                         Display this help menu\n"
        exit 0
}

function die () {
        echo -e $1
        exit 1
}

function resize () {
        convert -resize "48x48" $1 $1
}


function fetch_data () {
        curl --silent -H "Content-Type: application/json" -H "Authorization: $token" \
                "$base_url$1"
}

function rm_tr_quotes () {
        echo "$1" | sed -e 's/^"//' -e 's/"$//'
}

function invalid_option () {
        die "Incorrect usage."
}

function add_emote () {
        if [ ! -f $1 ]; then
                die "Image does not exist."
        fi

        basename=$(basename $1)
        emote_name=${basename%%.*}

        if [ -f $emote_col/$basename ]; then
                die "Emote already exists."
        fi

        if [ ! -z $2 ]; then
                emote_name=$2
        fi

        cp $1 $emote_col
        resize $emote_col/$basename
        echo "$emote_name $emote_col/$basename 0" >> $data_file
        exit 0
}

function remove_emote () {
        image_path=$(grep $1 $data_file | awk '{ print $2 }')
        if [ ! $image_path ]; then
                die "Emote does not exist."
        fi
        rm $image_path
        sed -i "/^$1/d" $data_file
        exit 0
}

while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
                -a|--add-emote)
                        [ -z "$2" ] && invalid_option
                        add_emote  $2 $3
                        ;;
                -d|--remove-emote)
                        [ -z "$2" ] && invalid_option
                        remove_emote $2
                        ;;
                -r|--rofi-config)
                        [ -z "$2" ] && invalid_option
                        rofi_config=$(rm_tr_quotes "$2")
                        shift
                        shift
                        ;;
                -w|--window-class)
                        [ -z "$2" ] && invalid_option
                        window_class=$(rm_tr_quotes "$2")
                        shift
                        shift
                        ;;
                -u|--update-emotes)
                        update_emotes=true
                        shift
                        ;;
                -c|--colon)
                        colon=true
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
                die "\nIncorrect token"
        fi

        echo -e "\nStarting to download emotes..."

        mkdir -p $thumbnail_path

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

rofi_cmd=(rofi -dmenu -i -p "Emote:" -sort -show-icons)

[ ! -z ${rofi_config+x} ] && rofi_cmd+=(-config "$rofi_config")

selected=$(sort -k 3 -r $data_file | \
        while read entry; do
                origname=$(echo $entry | awk '{print $1}')
                [ "$colon" = true ] && name=":${origname%%.*}:" || name="$origname"
                img=$(echo $entry | awk '{print $2}')
                [ ${img##*.} = "gif" ] && img=emotes/gif_thumbnails/$origname.png
                img=$(realpath $dir/$img)
                echo -e "$name\0icon\x1f$img"
        done | ${rofi_cmd[@]})

if [ "$selected" ]; then
        [ "$colon" = true ] && selected=$(echo $selected | cut -d ":" -f 2)
        real_fn=$dir/$(grep "^$selected " $data_file | awk '{print $2}')
        if [ -f "$real_fn" ]; then
                mime_type=$(file -b --mime-type "$real_fn")
                # increments usage counter
                sed -E -i 's/(^'"$selected"') (.*) ([0-9]*)/echo "\1 \2 $((\3+1))"/ge' $data_file

                if [[ "$mime_type" == image/png ]]; then
                        xclip -se c -t image/png -i $real_fn 
                        WID=$(xdotool search --class --onlyvisible --limit 1 "$window_class")
                        if [ "$WID" ]; then
                                xdotool windowactivate $WID
                                xdotool key ctrl+v
                                xdotool key KP_Enter
                        else
                                die "You do not have discord open"
                        fi
                else
                        dragon $real_fn --and-exit # temporary fix since gifs aren't getting copied to the clipboard
                fi
        else
                die "Invalid emote name"
        fi
fi
