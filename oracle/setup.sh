#!/bin/bash
# Sets up a Better MC server on an Oracle Cloud Always Free Ubuntu VM.
# It installs Java 25, unpacks the server pack, sizes RAM to the machine,
# installs Playit.gg, and runs everything as services that start on boot.
#
# Usage: ./setup.sh <server pack .zip download link, or path to the .zip>

set -e

PACK="$1"
BASE="$HOME/minecraft"
SERVER="$BASE/server"

if [ -z "$PACK" ]; then
    echo "Usage: ./setup.sh <server pack .zip download link, or path to the .zip>"
    exit 1
fi

echo "=== Better MC server setup ==="

echo "=> 1/6 Installing Java 25 and tools..."
sudo apt-get update -y
sudo apt-get install -y unzip tmux curl wget
JAVA_DIR="$BASE/java25"
case "$(uname -m)" in
    aarch64|arm64) JAVA_ARCH=aarch64; PLAYIT_ARCH=aarch64 ;;
    *) JAVA_ARCH=x64; PLAYIT_ARCH=amd64 ;;
esac
if [ ! -x "$JAVA_DIR/bin/java" ]; then
    mkdir -p "$JAVA_DIR"
    wget -q -O "$BASE/java25.tar.gz" "https://api.adoptium.net/v3/binary/latest/25/ga/linux/$JAVA_ARCH/jre/hotspot/normal/eclipse"
    tar -xzf "$BASE/java25.tar.gz" -C "$JAVA_DIR" --strip-components=1
    rm -f "$BASE/java25.tar.gz"
fi
export JAVA_HOME="$JAVA_DIR"
export PATH="$JAVA_HOME/bin:$PATH"

echo "=> 2/6 Getting the server pack..."
mkdir -p "$BASE"
if [ -f "$PACK" ]; then
    cp "$PACK" "$BASE/pack.zip"
else
    wget -O "$BASE/pack.zip" "$PACK"
fi
rm -rf "$BASE/unpack"
unzip -q -o "$BASE/pack.zip" -d "$BASE/unpack"

# The zip may keep everything inside one top-level folder.
FOUND=$(find "$BASE/unpack" -maxdepth 3 -type f \( -name 'startserver.sh' -o -name 'run.sh' -o -name 'variables.txt' -o -name '*installer*.jar' \) | head -n 1)
if [ -z "$FOUND" ]; then
    echo "!! This zip does not look like a server pack. Make sure you downloaded the SERVER pack, not the normal modpack."
    exit 1
fi
if [ -d "$SERVER" ]; then
    echo "   An old server folder exists, moving it to $SERVER.old-$(date +%s)"
    mv "$SERVER" "$SERVER.old-$(date +%s)"
fi
mv "$(dirname "$FOUND")" "$SERVER"
rm -rf "$BASE/unpack"
cd "$SERVER"

echo "=> 3/6 Configuring memory, EULA and settings..."
TOTAL_GB=$(awk '/MemTotal/ {printf "%d", $2/1024/1024 + 0.5}' /proc/meminfo)
HEAP_GB=$((TOTAL_GB - 4))
[ "$HEAP_GB" -gt 12 ] && HEAP_GB=12
[ "$HEAP_GB" -lt 4 ] && HEAP_GB=4
echo "   This machine has ${TOTAL_GB}GB RAM and $(nproc) cores, giving the server ${HEAP_GB}GB."

echo "eula=true" > eula.txt

if [ -f variables.txt ]; then
    sed -i "s/^JAVA_ARGS=.*/JAVA_ARGS=\"-Xms${HEAP_GB}G -Xmx${HEAP_GB}G -XX:+UseG1GC\"/" variables.txt
    sed -i 's/^WAIT_FOR_USER_INPUT=.*/WAIT_FOR_USER_INPUT=false/' variables.txt
    sed -i "s|^JAVA=.*|JAVA=\"$JAVA_DIR/bin/java\"|" variables.txt
fi
if [ -f user_jvm_args.txt ] || [ -f run.sh ]; then
    sed -i '/^-Xm[sx]/d' user_jvm_args.txt 2>/dev/null || true
    printf -- "-Xms%sG\n-Xmx%sG\n" "$HEAP_GB" "$HEAP_GB" >> user_jvm_args.txt
fi

set_prop() {
    if [ -f server.properties ] && grep -q "^$1=" server.properties; then
        sed -i "s/^$1=.*/$1=$2/" server.properties
    else
        echo "$1=$2" >> server.properties
    fi
}
set_prop view-distance 8
set_prop simulation-distance 6
set_prop sync-chunk-writes false

if [ -f startserver.sh ]; then
    START="./startserver.sh"
elif [ -f run.sh ]; then
    START="./run.sh nogui"
else
    INSTALLER=$(ls *installer*.jar | head -n 1)
    echo "   Installing the mod loader with $INSTALLER..."
    java -jar "$INSTALLER" --installServer
    sed -i '/^-Xm[sx]/d' user_jvm_args.txt 2>/dev/null || true
    printf -- "-Xms%sG\n-Xmx%sG\n" "$HEAP_GB" "$HEAP_GB" >> user_jvm_args.txt
    START="./run.sh nogui"
fi
chmod +x ./*.sh
echo "   The server starts with: $START"

echo "=> 4/6 Installing Playit.gg..."
wget -O "$BASE/playit" "https://github.com/playit-cloud/playit-agent/releases/download/v0.15.26/playit-linux-$PLAYIT_ARCH"
chmod +x "$BASE/playit"

echo "=> 5/6 Creating services..."
sudo tee /etc/systemd/system/minecraft.service > /dev/null << EOF
[Unit]
Description=Better MC server
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
User=$USER
WorkingDirectory=$SERVER
Environment="JAVA_HOME=$JAVA_DIR"
Environment="PATH=$JAVA_DIR/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/usr/bin/tmux new-session -d -s minecraft $START
ExecStop=/bin/bash -c 'tmux send-keys -t minecraft "stop" Enter; while tmux has-session -t minecraft 2>/dev/null; do sleep 1; done'
TimeoutStopSec=180
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/playit.service > /dev/null << EOF
[Unit]
Description=Playit.gg tunnel
After=network-online.target
Wants=network-online.target

[Service]
User=$USER
ExecStart=$BASE/playit
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

cat > "$BASE/console.sh" << 'EOF'
#!/bin/bash
echo "Opening the server console. To leave it running, press Ctrl+B, then D."
sleep 2
tmux attach -t minecraft
EOF
chmod +x "$BASE/console.sh"

sudo systemctl daemon-reload
sudo systemctl enable --now minecraft

echo "=> 6/6 Linking Playit.gg..."
echo ""
echo "   A claim link will appear below. Open it, log in to Playit, and add a"
echo "   'Minecraft Java' tunnel pointing to local port 25565."
echo "   When Playit shows your tunnel address, press Ctrl+C here."
echo ""
read -r -p "   Press Enter to start Playit..."
# Let Ctrl+C stop Playit without also stopping this script.
trap ':' INT
"$BASE/playit" || true
trap - INT
sudo systemctl enable --now playit

echo ""
echo "=== SETUP FINISHED! ==="
echo "The server is starting in the background. The first start takes a few minutes."
echo "  Open the console:      ~/minecraft/console.sh   (leave with Ctrl+B, then D)"
echo "  Restart the server:    sudo systemctl restart minecraft"
echo "  Turn the server off:   sudo systemctl stop minecraft"
echo "Both the server and Playit start by themselves when the VM reboots."
