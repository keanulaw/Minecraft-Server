#!/bin/bash
# Better MC [BMC6] server for GitHub Codespaces.
# First time:  ./bettermc.sh "<server pack .zip download link, or path to the .zip>"
# After that:  ./bettermc.sh
# Needs the 4-core / 16GB Codespace machine. Stop the Paper server first,
# both use port 25565.

cd "$(dirname "$0")" || exit 1
ROOT="$(pwd)"
SERVER="$ROOT/bettermc"
JAVA_DIR="$ROOT/java25"

if [ ! -x "$JAVA_DIR/bin/java" ]; then
    echo "=> Installing Java 25..."
    case "$(uname -m)" in
        aarch64|arm64) ARCH=aarch64 ;;
        *) ARCH=x64 ;;
    esac
    rm -rf "$JAVA_DIR" java25.tar.gz
    wget -q -O java25.tar.gz "https://api.adoptium.net/v3/binary/latest/25/ga/linux/$ARCH/jre/hotspot/normal/eclipse" || {
        echo "!! Could not download Java 25."; exit 1; }
    mkdir -p "$JAVA_DIR"
    tar -xzf java25.tar.gz -C "$JAVA_DIR" --strip-components=1
    rm -f java25.tar.gz
fi
export JAVA_HOME="$JAVA_DIR"
export PATH="$JAVA_HOME/bin:$PATH"

if [ ! -f "$SERVER/.start-command" ]; then
    echo "=== Setting up Better MC ==="
    PACK="$1"
    if [ -z "$PACK" ]; then
        PACK=$(ls -t ./*[Ss]erver[Pp]ack*.zip 2>/dev/null | head -n 1)
    fi
    if [ -z "$PACK" ]; then
        echo "Usage: ./bettermc.sh \"<server pack .zip download link, or path to the .zip>\""
        exit 1
    fi

    echo "=> Getting the server pack..."
    if [ -f "$PACK" ]; then
        cp "$PACK" pack.zip
    else
        wget -O pack.zip "$PACK" || { echo "!! Download failed. Check the link."; exit 1; }
    fi
    rm -rf unpack
    unzip -q -o pack.zip -d unpack || { echo "!! That file is not a valid .zip."; exit 1; }
    rm -f pack.zip

    # The zip may keep everything inside one top-level folder.
    FOUND=$(find unpack -maxdepth 3 -type f \( -name 'startserver.sh' -o -name 'run.sh' -o -name 'variables.txt' -o -name '*installer*.jar' \) | head -n 1)
    if [ -z "$FOUND" ]; then
        rm -rf unpack
        echo "!! This zip does not look like a server pack. Download the SERVER pack, not the normal modpack."
        exit 1
    fi
    rm -rf "$SERVER"
    mv "$(dirname "$FOUND")" "$SERVER"
    rm -rf unpack
    cd "$SERVER" || exit 1

    TOTAL_GB=$(awk '/MemTotal/ {printf "%d", $2/1024/1024 + 0.5}' /proc/meminfo)
    HEAP_GB=$((TOTAL_GB - 5))
    [ "$HEAP_GB" -gt 12 ] && HEAP_GB=12
    if [ "$HEAP_GB" -lt 8 ]; then
        echo "!! This Codespace has ${TOTAL_GB}GB RAM. Better MC needs the 4-core / 16GB machine."
        echo "   Change it at github.com/codespaces -> ... -> Change machine type, then run this again."
        HEAP_GB=6
    fi
    echo "=> Giving the server ${HEAP_GB}GB of RAM."

    echo "eula=true" > eula.txt
    if [ -f variables.txt ]; then
        sed -i "s|^JAVA_ARGS=.*|JAVA_ARGS=\"-Xms${HEAP_GB}G -Xmx${HEAP_GB}G -XX:+UseG1GC\"|" variables.txt
        sed -i "s|^JAVA=.*|JAVA=\"$JAVA_DIR/bin/java\"|" variables.txt
        sed -i 's|^WAIT_FOR_USER_INPUT=.*|WAIT_FOR_USER_INPUT=false|' variables.txt
    fi

    if [ -f startserver.sh ]; then
        START="./startserver.sh"
    else
        if [ ! -f run.sh ]; then
            INSTALLER=$(ls ./*installer*.jar | head -n 1)
            echo "=> Installing the mod loader..."
            java -jar "$INSTALLER" --installServer || { echo "!! Mod loader install failed."; exit 1; }
        fi
        START="./run.sh nogui"
    fi
    if [ -f run.sh ] || [ -f user_jvm_args.txt ]; then
        sed -i '/^-Xm[sx]/d' user_jvm_args.txt 2>/dev/null
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
    set_prop pause-when-empty-seconds 60

    chmod +x ./*.sh
    echo "$START" > .start-command
    echo "=== Setup finished! Starting Better MC (the first start takes several minutes) ==="
fi

cd "$SERVER" || exit 1
exec $(cat .start-command)
