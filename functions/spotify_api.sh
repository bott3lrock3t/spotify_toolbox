#!/bin/bash
# spotify_api.sh - Utility functions for Spotify API calls

# Usage: spotify_api_get <endpoint> [<access_token>]
spotify_api_get() {
    local endpoint="$1"
    local token="${2:-$SPOTIFY_ACCESS_TOKEN}"
    curl -s -X GET "https://api.spotify.com/v1/$endpoint" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json"
}

# Usage: spotify_api_post <endpoint> <data_json> [<access_token>]
spotify_api_post() {
    local endpoint="$1"
    local data_json="$2"
    local token="${3:-$SPOTIFY_ACCESS_TOKEN}"
    curl -s -X POST "https://api.spotify.com/v1/$endpoint" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "$data_json"
}

# Add more utility functions as needed
