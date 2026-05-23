#!/bin/bash
# spotify_authenticate.sh - Authenticate with Spotify API (Authorization Code with PKCE)


# Cross-platform: Always resolve config.json relative to the menu.sh script location (project root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
CONFIG_FILE="$PROJECT_ROOT/config.json"
# On Windows Git Bash, convert possible Windows path to Unix style
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
	CONFIG_FILE="$(cd "$PROJECT_ROOT" && pwd -W 2>/dev/null || pwd)/config.json"
fi
if [[ ! -f "$CONFIG_FILE" ]]; then
	echo "config.json not found in project root ($PROJECT_ROOT). Please create it."
	exit 1
fi
SPOTIFY_CLIENT_ID=$(jq -r '.SPOTIFY_CLIENT_ID' "$CONFIG_FILE")
SPOTIFY_REDIRECT_URI=$(jq -r '.SPOTIFY_REDIRECT_URI' "$CONFIG_FILE")
SPOTIFY_SCOPES=$(jq -r '.SPOTIFY_SCOPES' "$CONFIG_FILE")
if [[ -z "$SPOTIFY_CLIENT_ID" || "$SPOTIFY_CLIENT_ID" == "YOUR_CLIENT_ID" ]]; then
	echo "SPOTIFY_CLIENT_ID is not set in config.json. Please update it with your Spotify app's Client ID."
	exit 1
fi

# Generates a code verifier and code challenge for PKCE
generate_pkce() {
	CODE_VERIFIER=$(head -c 64 /dev/urandom | base64 | tr -d /=+ | cut -c -128)
	CODE_CHALLENGE=$(echo -n "$CODE_VERIFIER" | openssl dgst -sha256 -binary | base64 | tr -d /=+ | tr 'A-Z' 'a-z' | cut -c -43)
}

spotify_authenticate() {
	generate_pkce
	AUTH_URL="https://accounts.spotify.com/authorize?client_id=$SPOTIFY_CLIENT_ID&response_type=code&redirect_uri=$SPOTIFY_REDIRECT_URI&scope=$SPOTIFY_SCOPES&code_challenge_method=S256&code_challenge=$CODE_CHALLENGE"
	echo "Open the following URL in your browser and authorize the app:"
	echo "$AUTH_URL"
	echo "After authorization, paste the 'code' parameter from the redirected URL:"
	read -rp "Code: " AUTH_CODE
	# Exchange code for access token
	TOKEN_RESPONSE=$(curl -s -X POST "https://accounts.spotify.com/api/token" \
		-H "Content-Type: application/x-www-form-urlencoded" \
		-d "client_id=$SPOTIFY_CLIENT_ID" \
		-d "grant_type=authorization_code" \
		-d "code=$AUTH_CODE" \
		-d "redirect_uri=$SPOTIFY_REDIRECT_URI" \
		-d "code_verifier=$CODE_VERIFIER")
	export SPOTIFY_ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
	export SPOTIFY_REFRESH_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.refresh_token')
	echo "Access token set."
}
