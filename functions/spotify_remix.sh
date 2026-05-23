#!/bin/bash
# spotify_remix.sh - Functions for Spotify Remix API

# Usage: create_remix <track_id> <remix_params_json>
create_remix() {
    local track_id="$1"
    local remix_params_json="$2"
    spotify_api_post "tracks/$track_id/remix" "$remix_params_json"
}

# Usage: loop_remix <track_id> <remix_params_json> <count>
loop_remix() {
    local track_id="$1"
    local remix_params_json="$2"
    local count="$3"
    local playlist_id="$4"
    for ((i=0;i<$count;i++)); do
        remix_response=$(create_remix "$track_id" "$remix_params_json")
        remix_track_id=$(echo "$remix_response" | jq -r '.id')
        # Add to playlist if playlist_id provided
        if [[ -n "$playlist_id" && -n "$remix_track_id" ]]; then
            spotify_api_post "playlists/$playlist_id/tracks" "{\"uris\":[\"spotify:track:$remix_track_id\"]}" > /dev/null
        fi
        echo "Remix $((i+1)): $remix_track_id"
    done
}
