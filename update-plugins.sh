#!/bin/bash
# Downloads the latest Geyser, Floodgate and ViaVersion into plugins/.
# Stop the server (type "stop" in the console) before running this.

cd "$(dirname "$0")/plugins" || exit 1

download() {
    local name="$1" url="$2"
    echo "=> Updating $name..."
    if wget -q -O "$name.jar.tmp" "$url" && [ -s "$name.jar.tmp" ]; then
        mv "$name.jar.tmp" "$name.jar"
        echo "   $name updated."
    else
        rm -f "$name.jar.tmp"
        echo "   !! Could not download $name, keeping the current version."
    fi
}

download Geyser "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot"
download Floodgate "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot"

VIA_URL=$(curl -s https://api.github.com/repos/ViaVersion/ViaVersion/releases/latest \
    | grep -o '"browser_download_url": *"[^"]*\.jar"' | head -n 1 | cut -d '"' -f 4)
if [ -n "$VIA_URL" ]; then
    download ViaVersion "$VIA_URL"
else
    echo "!! Could not find the latest ViaVersion release, keeping the current version."
fi

echo "=== Done! Start the server again with ./start.sh ==="
