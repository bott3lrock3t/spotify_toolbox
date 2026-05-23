# Spotify Toolbox Utility

A Bash-based menu-driven toolbox for interacting with the Spotify Web API, including authentication, remix creation, and playlist generation.

## Features
- Authenticate with Spotify (OAuth2, PKCE)
- Create remix requests for tracks
- Loop remix requests to generate a playlist of remixes
- Modular, extensible design
- All functions auto-imported via `modules/spotify_tools.sh`
- Optionally save credentials encrypted locally


## Prerequisites

- Bash (macOS, Linux, or Windows with Git Bash/WSL)
- `curl`, `jq`, `openssl`, `base64`
- A Spotify Developer App (get your Client ID at https://developer.spotify.com/dashboard)

### Quick Install (Recommended)

Run the following script to install all required dependencies:

```sh
bash functions/install_prerequisites.sh
```


#### Windows
- On Windows, use [Chocolatey](https://chocolatey.org/) or [Scoop](https://scoop.sh/) to install missing tools if prompted.
   - Example (with Chocolatey):
      ```sh
      choco install jq curl openssl base64
      ```
   - Example (with Scoop):
      ```sh
      scoop install jq curl openssl coreutils
      ```

**Troubleshooting Chocolatey Installation Issues**


If you see errors like `choco: command not found` or the script says Chocolatey is installed but not working, **try closing and reopening your terminal (or VS Code) first before attempting a complete reinstall**. Sometimes, a new terminal session is all that's needed for changes to take effect.

If that doesn't resolve the issue, follow these steps:

1. **Check if Chocolatey is really installed:**
   - Open PowerShell and run:
     ```powershell
     Test-Path C:\ProgramData\chocolatey\bin\choco.exe
     ```
   - If it returns `False`, Chocolatey is not installed correctly.

2. **Fix a broken Chocolatey install:**
   - If the folder `C:\ProgramData\chocolatey` exists but `choco.exe` does not, you must remove the broken install before reinstalling.
   - Open PowerShell as Administrator and run:
     ```powershell
     Move-Item -Path "C:\ProgramData\chocolatey" -Destination "C:\ProgramData\chocolatey_backup"
     ```
   - Then reinstall Chocolatey:
     ```powershell
     Set-ExecutionPolicy Bypass -Scope Process -Force; `
     [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; `
     iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
     ```
   - After installation, open a new terminal and run:
     ```powershell
     choco --version
     ```
   - If it works, you can delete the backup folder:
     ```powershell
     Remove-Item -Recurse -Force "C:\ProgramData\chocolatey_backup"
     ```

3. **Add Chocolatey to your PATH if needed:**
   - If `choco.exe` exists but is not found, add it to your PATH:
     ```powershell
     [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\ProgramData\chocolatey\bin", [EnvironmentVariableTarget]::User)
     ```
   - Restart your terminal and try again.

#### macOS
- Uses Homebrew: `brew install jq curl openssl coreutils`

#### Ubuntu/Debian
- Uses apt: `sudo apt-get install jq curl openssl coreutils`

#### Fedora
- Uses dnf: `sudo dnf install jq curl openssl coreutils`

#### Arch
- Uses pacman: `sudo pacman -Sy jq curl openssl coreutils`


## Setup
1. Clone this repo and enter the `spotify_toolbox` directory.
2. Copy your Spotify app credentials into `config.json` in the root directory:
   ```json
   {
     "SPOTIFY_CLIENT_ID": "YOUR_CLIENT_ID",
     "SPOTIFY_REDIRECT_URI": "http://localhost:8888/callback",
     "SPOTIFY_SCOPES": "playlist-modify-public playlist-modify-private user-read-private"
   }
   ```
   - Replace `YOUR_CLIENT_ID` with your actual Client ID from the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard).
   - You can find your Client ID by creating an app in the Spotify Developer Dashboard, then copying the value from your app's settings.
3. (Optional) To save credentials encrypted locally, set `SPOTIFY_CRED_FILE` in your environment. The script will use `openssl` to encrypt/decrypt tokens.

## Usage

1. Run the menu:
   ```sh
   bash menu.sh
   ```
2. Follow the prompts to authenticate, create remixes, or generate a playlist of remixes.
3. If you see an error about `SPOTIFY_CLIENT_ID` not being set, make sure you have updated `config.json` with your actual Client ID.


### Saving Credentials Encrypted
- On first authentication, tokens are saved to `${SPOTIFY_CRED_FILE:-$HOME/.spotify_creds.enc}` encrypted with a passphrase you provide.
- On subsequent runs, the script will prompt for the passphrase to decrypt and reuse tokens.

---

## Troubleshooting & Important Setup Notes

### 1. Fixes and Common Issues

- **Chocolatey not found or not working:**
  - Try closing and reopening your terminal (or VS Code) before reinstalling Chocolatey.
  - See the Windows troubleshooting section above for more details.
- **Menu not showing up after install:**
  - Fixed by updating the install script to use `return 0` instead of `exit 0` when sourced.
- **Debug output/noise in menu:**
  - Debug output is now disabled by default. If you need to debug, add `set -x` at the top of `menu.sh`.

### 2. Creating Your `config.json`

Your `config.json` should look like this:

```json
{
  "SPOTIFY_CLIENT_ID": "[YOUR_CLIENT_ID]",
  "SPOTIFY_REDIRECT_URI": "http://127.0.0.1:8888/callback",
  "SPOTIFY_SCOPES": "playlist-modify-public playlist-modify-private user-read-private"
}
```

- Replace `YOUR_CLIENT_ID` with your actual Client ID from the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard).
- In your Spotify app settings, add the redirect URI exactly as shown above (`http://127.0.0.1:8888/callback`).
- If Spotify does not allow this URI, see the next section.

### 3. Spotify Redirect URI Issues

- If you see an error like `redirect_uri: Not matching configuration` or `This redirect URI is not secure`, Spotify may require HTTPS or a different localhost address.
- Try using `http://127.0.0.1:8888/callback` instead of `http://localhost:8888/callback` in both your `config.json` and your Spotify app settings.
- If Spotify still does not allow it, you may need to use a tunneling service (like [ngrok](https://ngrok.com/) or [localhost.run](https://localhost.run)) to provide a secure HTTPS redirect URI. Update both your `config.json` and Spotify app settings accordingly.

### 4. Manual Authentication (Copying the Code)

When authenticating, the script will open a URL in your browser. After you log in and authorize, Spotify will redirect to something like:

```
http://127.0.0.1:8888/callback?code=YOUR_CODE_HERE
```

You will see a browser error like "This site can’t be reached" or "connection refused". **This is expected!**

**What to do:**

1. Copy the value of the `code` parameter from the URL in your browser’s address bar (everything after `code=`).
2. Paste this code into the terminal when the script prompts: `After authorization, paste the 'code' parameter from the redirected URL:`
3. The script will continue and complete authentication.

---

## Extending the Toolbox
- Add new Bash scripts to the `functions/` folder; they will be auto-imported.
- Use `modules/spotify_tools.sh` to import all functions in your scripts.

## Troubleshooting
- Ensure all dependencies are installed: `jq`, `curl`, `openssl`, `base64`.
- If authentication fails, check your Client ID and redirect URI in your Spotify Developer App settings.

## License
MIT
