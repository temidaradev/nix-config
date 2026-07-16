#!/bin/bash

MUSIC_STATE=$(osascript -e 'tell application "Music" to if it is running then return player state as string' 2>/dev/null)

if [ "$MUSIC_STATE" = "playing" ]; then
  APP="Music"
  STATE="playing"
  TITLE=$(osascript -e 'tell application "Music" to return name of current track' 2>/dev/null)
  ARTIST=$(osascript -e 'tell application "Music" to return artist of current track' 2>/dev/null)
  ALBUM=$(osascript -e 'tell application "Music" to return album of current track' 2>/dev/null)
  
  # Get artwork and save to temp file
  ARTWORK_PATH="/tmp/sketchybar_music_artwork.jpg"
  osascript -e "tell application \"Music\"
    set artworkData to raw data of artwork 1 of current track
    set artworkFile to open for access POSIX file \"$ARTWORK_PATH\" with write permission
    write artworkData to artworkFile
    close access artworkFile
  end tell" 2>/dev/null
  
  if [ -f "$ARTWORK_PATH" ]; then
    ARTWORK="$ARTWORK_PATH"
  fi
else
  STATE="stopped"
fi

if [ -n "$TITLE" ] && [ "$TITLE" != "" ] && [ "$STATE" = "playing" ]; then
  sketchybar --set media.cover \
             drawing=on \
             background.image="$ARTWORK" \
             background.image.scale=0.045
  
  sketchybar --set media.artist \
             drawing=on \
             label="$ARTIST"
  
  sketchybar --set media.title \
             drawing=on \
             label="$TITLE"
else
  sketchybar --set media.cover drawing=off
  sketchybar --set media.artist drawing=off
  sketchybar --set media.title drawing=off
fi
