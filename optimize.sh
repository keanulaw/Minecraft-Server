#!/bin/bash
# Tunes the server for a small group of friends: lower view/simulation
# distance, Aikar's JVM flags with RAM sized to this machine, and the
# Chunky plugin for pre-generating the world.
# Run ./start.sh once first, then stop the server before running this.

cd "$(dirname "$0")" || exit 1

if [ ! -f server.jar ] || [ ! -f server.properties ]; then
    echo "!! Run ./start.sh once first so the server is installed, stop it, then run this again."
    exit 1
fi

# --- 1. server.properties ---
set_prop() {
    if grep -q "^$1=" server.properties; then
        sed -i "s/^$1=.*/$1=$2/" server.properties
    else
        echo "$1=$2" >> server.properties
    fi
    echo "   $1=$2"
}
echo "=> Updating server.properties..."
set_prop view-distance 8
set_prop simulation-distance 6
set_prop sync-chunk-writes false

# --- 2. start.sh with Aikar's flags ---
TOTAL_GB=$(awk '/MemTotal/ {printf "%d", $2/1024/1024 + 0.5}' /proc/meminfo)
HEAP_GB=$((TOTAL_GB - 4))
[ "$HEAP_GB" -gt 10 ] && HEAP_GB=10
[ "$HEAP_GB" -lt 2 ] && HEAP_GB=2
echo "=> This machine has ${TOTAL_GB}GB RAM and $(nproc) cores, giving the server ${HEAP_GB}GB."

cat << EOF > start.sh
#!/bin/bash
source ~/.bashrc
echo "=> Starting Minecraft Server..."
java -Xms${HEAP_GB}G -Xmx${HEAP_GB}G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true -jar server.jar nogui
EOF
chmod +x start.sh
echo "   start.sh updated."

# --- 3. Chunky (world pre-generation) ---
if [ -f plugins/Chunky.jar ]; then
    echo "=> Chunky is already installed."
else
    echo "=> Installing Chunky..."
    CHUNKY_URL=$(curl -s 'https://api.modrinth.com/v2/project/chunky/version?loaders=%5B%22paper%22%5D' \
        | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["files"][0]["url"])' 2>/dev/null)
    if [ -n "$CHUNKY_URL" ] && wget -q -O plugins/Chunky.jar.tmp "$CHUNKY_URL" && [ -s plugins/Chunky.jar.tmp ]; then
        mv plugins/Chunky.jar.tmp plugins/Chunky.jar
        echo "   Chunky installed."
    else
        rm -f plugins/Chunky.jar.tmp
        echo "   !! Could not download Chunky. You can get it from https://modrinth.com/plugin/chunky"
    fi
fi

echo "=== Done! Start the server again with ./start.sh ==="
