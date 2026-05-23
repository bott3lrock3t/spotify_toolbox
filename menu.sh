# Export all tracks eligible for AI remixing
export_ai_remixable_ids() {
	read -rp "Enter search keywords for eligible tracks: " keywords
	url_encode() { jq -nr --arg v "$1" '$v|@uri'; }
	query=$(url_encode "$keywords")
	results=$(spotify_api_get "search?q=$query&type=track&limit=50")
	# Try to filter by can_remix or similar field
	eligible=$(echo "$results" | jq '[.tracks.items[] | select(.can_remix == true)]')
	count=$(echo "$eligible" | jq 'length')
	if [[ "$count" -eq 0 ]]; then
		echo "No eligible tracks found or the API does not provide a 'can_remix' field."
		echo "Raw API response: $results"
		return 1
	fi
	out_file="ai_remixable_track_ids.json"
	echo "$eligible" | jq '[.[].id]' > "$out_file"
	echo "All eligible AI remixable track IDs exported to $out_file"
}
#!/bin/bash
# menu.sh - Spotify Toolbox Menu



# Check prerequisites before importing tools
missing=()
for cmd in jq curl openssl base64; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		missing+=("$cmd")
	fi
done

if [[ ${#missing[@]} -ne 0 ]]; then
	echo "Missing prerequisites: ${missing[*]}"
	read -rp "Would you like to install all prerequisites now? [Y/n] " yn
	yn=${yn:-Y}
	if [[ "$yn" =~ ^[Yy]$ ]]; then
		bash functions/install_prerequisites.sh || {
			echo "Automatic installation failed. Please install manually and rerun the script.";
			exit 1;
		}
		echo "Please restart this script after installation."
		exit 0
	else
		echo "Cannot continue without required tools: ${missing[*]}"
		exit 1
	fi
fi

# Import all Spotify tools (auto-imports all functions)
if ! source modules/spotify_tools.sh; then
	echo "Error sourcing modules/spotify_tools.sh. Continuing without extra functions."
fi

# Credential encryption helpers
SPOTIFY_CRED_FILE="${SPOTIFY_CRED_FILE:-$HOME/.spotify_creds.enc}"

save_encrypted_creds() {
	local token="$1"
	local refresh="$2"
	read -rsp "Set a passphrase to encrypt credentials: " passphrase; echo
	echo -e "$token\n$refresh" | openssl enc -aes-256-cbc -pbkdf2 -salt -out "$SPOTIFY_CRED_FILE" -pass pass:"$passphrase"
	echo "Credentials saved to $SPOTIFY_CRED_FILE"
}

load_encrypted_creds() {
	read -rsp "Enter passphrase to decrypt credentials: " passphrase; echo
	local creds
	creds=$(openssl enc -d -aes-256-cbc -pbkdf2 -in "$SPOTIFY_CRED_FILE" -pass pass:"$passphrase" 2>/dev/null)
	if [[ $? -ne 0 ]]; then
		echo "Failed to decrypt credentials."
		return 1
	fi
	export SPOTIFY_ACCESS_TOKEN=$(echo "$creds" | sed -n 1p)
	export SPOTIFY_REFRESH_TOKEN=$(echo "$creds" | sed -n 2p)
	echo "Credentials loaded."
}

authenticate_with_encrypted_creds() {
	if [[ -f "$SPOTIFY_CRED_FILE" ]]; then
		load_encrypted_creds || return 1
	else
		echo "No encrypted credentials found. Starting authentication..."
		spotify_authenticate
		save_encrypted_creds "$SPOTIFY_ACCESS_TOKEN" "$SPOTIFY_REFRESH_TOKEN"
	fi
}



# Helper to print green text
green() { echo -e "\033[0;32m$1\033[0m"; }

# Check authentication and get profile name
get_spotify_profile() {
	if [[ -n "$SPOTIFY_ACCESS_TOKEN" ]]; then
		profile_json=$(spotify_api_get "me")
		profile_name=$(echo "$profile_json" | jq -r '.display_name // .id // empty')
		if [[ -n "$profile_name" && "$profile_name" != "null" ]]; then
			echo "$profile_name"
		else
			echo "?"
		fi
	else
		echo ""
	fi
}



# Search for tracks and export all found IDs to a JSON file

search_tracks_and_export() {
	read -rp "Enter search keywords: " keywords
	# URL encode the keywords
	url_encode() { jq -nr --arg v "$1" '$v|@uri'; }
	query=$(url_encode "$keywords")
	results=$(spotify_api_get "search?q=$query&type=track&limit=50")
	# Check for errors or empty results
	track_count=$(echo "$results" | jq '.tracks.items | length' 2>/dev/null)
	if [[ -z "$track_count" || "$track_count" == "null" || "$track_count" -eq 0 ]]; then
		echo "No tracks found or error in search."
		echo "Raw API response: $results"
		return 1
	fi
	echo "Results:"
	echo "$results" | jq -r '.tracks.items[] | "[\(.id)] \(.name) - \(.artists[0].name)"'
	out_file="track_ids.json"
	jq -n --argjson ids "$(echo "$results" | jq '[.tracks.items[].id]')" '{track_ids: $ids}' > "$out_file"
	echo "All found track IDs exported to $out_file"
}

# Batch remix and playlist creation

# Import track IDs and playlist name from JSON, batch remix, and add to playlist
batch_remix_from_json() {
	read -rp "Enter path to JSON file (with playlist_name and track_ids): " json_file
	if [[ ! -f "$json_file" ]]; then
		echo "File not found: $json_file"
		return 1
	fi
	playlist_name=$(jq -r '.playlist_name' "$json_file")
	ids=($(jq -r '.track_ids[]' "$json_file"))
	if [[ -z "$playlist_name" || ${#ids[@]} -eq 0 ]]; then
		echo "Invalid JSON format. Must contain playlist_name and track_ids."
		return 1
	fi
	read -rp "Remix params (JSON): " remix_params
	user_id=$(spotify_api_get "me" | jq -r '.id')
	playlist_id=$(spotify_api_get "me/playlists?limit=50" | jq -r --arg name "$playlist_name" '.items[] | select(.name==$name) | .id')
	if [[ -z "$playlist_id" ]]; then
		create_resp=$(spotify_api_post "users/$user_id/playlists" "{\"name\":\"$playlist_name\"}")
		playlist_id=$(echo "$create_resp" | jq -r '.id')
		echo "Created playlist $playlist_name ($playlist_id)"
	else
		echo "Using existing playlist $playlist_name ($playlist_id)"
	fi
	for tid in "${ids[@]}"; do
		remix_resp=$(create_remix "$tid" "$remix_params")
		remix_id=$(echo "$remix_resp" | jq -r '.id')
		if [[ -n "$remix_id" && "$remix_id" != "null" ]]; then
			spotify_api_post "playlists/$playlist_id/tracks" "{\"uris\":[\"spotify:track:$remix_id\"]}" > /dev/null
			echo "Added remix of $tid ($remix_id) to $playlist_name"
		else
			echo "Remix failed for $tid"
		fi
	done
	echo "All done."
}



# Export all available remix track IDs to a file
export_remix_ids() {
	echo "Searching for tracks with 'remix' in the title..."
	results=$(spotify_api_get "search?q=remix&type=track&limit=50")
	track_count=$(echo "$results" | jq '.tracks.items | length' 2>/dev/null)
	if [[ -z "$track_count" || "$track_count" == "null" || "$track_count" -eq 0 ]]; then
		echo "No remix tracks found or error in search."
		echo "Raw API response: $results"
		return 1
	fi
	out_file="remix_track_ids.json"
	jq -n --argjson ids "$(echo "$results" | jq '[.tracks.items[].id]')" '{track_ids: $ids}' > "$out_file"
	echo "All found remix track IDs exported to $out_file"
}

main_menu() {
	while true; do
		clear
		authed_msg=""
		profile_name=""
		if [[ -n "$SPOTIFY_ACCESS_TOKEN" ]]; then
			profile_name=$(get_spotify_profile)
			if [[ -n "$profile_name" && "$profile_name" != "?" ]]; then
				authed_msg="$(green "Authenticated as: $profile_name")"
			else
				authed_msg="$(green "Authenticated")"
			fi
		else
			authed_msg="Not authenticated"
		fi
		echo "--- Spotify Toolbox Menu ---"
		echo "$authed_msg"
		echo "1) Authenticate with Spotify (manual)"
		echo "2) Authenticate with encrypted credentials file"
		echo "3) Search for Tracks and Export IDs"
		echo "4) Batch Remix Tracks from JSON"
		echo "5) Export All Remix Track IDs (title search)"
		echo "6) Export All AI Remixable Track IDs (API eligible)"
		echo "7) Exit"
		read -rp "Choose an option: " choice
		case $choice in
			1)
				spotify_authenticate
				;;
			2)
				authenticate_with_encrypted_creds
				;;
			3)
				search_tracks_and_export
				;;
			4)
				batch_remix_from_json
				;;
			5)
				export_remix_ids
				;;
			6)
				export_ai_remixable_ids
				;;
			7)
				exit 0
				;;
			*)
				echo "Invalid option."
				;;
		esac
	done
}

main_menu
