# Discord emote menu

A bash script, for those of us who don't have nitro, that lets you use Discord emotes from any of your servers. It opens a rofi menu with all the emotes from your servers and automatically sends the selected emote to the discord window. Frequency based ordering is also implemented.

## Setup

The first time you run this script, it will download all the emotes in advance. To do this, an API token is required. [Here's](https://github.com/Tyrrrz/DiscordChatExporter/wiki/Obtaining-Token-and-Channel-IDs#how-to-get-a-user-token) a quick guide that tells you how to obtain your token.

## Dependencies

This script depends on a few other utilities:

- `jq` - Parses json response from Discord API
- `imagemagick` - For resizing emotes to regular size
- `rofi` - For displaying the emote menu
- `xdotool` - Sending input to windows
- `xclip` - Clipboard management
- `dragon` - As of now, since gifs aren't getting copied to the clipboard, dragon is used as a temporary solution to drag and drop the gif

## Usage

```
Usage: emote.sh [OPTION...]
A script to open a discord emote menu

Options:
-w, --window-class      Window class to send the emote to. Default value is "Discord"
-r, --rofi-config       Specify a custom config file for the rofi menu
-u, --update-emotes     Download new emotes
-c, --colon             Display colon at the beginning and end of emote name.
-h, --help              Display this help menu
```
