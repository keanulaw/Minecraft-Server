#!/bin/bash
# Run this in Oracle Cloud Shell. It keeps trying to create an Always Free
# Ampere server until Oracle has capacity, then prints how to connect.
#
# Usage: ./create-server.sh [OCPUS] [MEMORY_GB]    (default: 4 24, the Always Free maximum)

OCPUS="${1:-4}"
MEMORY="${2:-24}"
NAME="minecraft"
SHAPE="VM.Standard.A1.Flex"
KEY="$HOME/.ssh/minecraft_key"
WAIT=90
LOG="$HOME/create-server.log"
PIDFILE="$HOME/create-server.pid"

if [ "$OCPUS" -gt 4 ] || [ "$MEMORY" -gt 24 ]; then
    echo "!! Always Free allows at most 4 OCPUs and 24GB. Stopping so you are not charged."
    exit 1
fi

echo "=== Oracle Always Free server creator ($OCPUS OCPU, ${MEMORY}GB) ==="

# --- Account ---
TENANCY="${OCI_TENANCY:-}"
if [ -z "$TENANCY" ]; then
    TENANCY=$(oci iam compartment list --all --query 'data[0]."compartment-id"' --raw-output 2>/dev/null)
fi
if [ -z "$TENANCY" ] || [ "$TENANCY" = "null" ]; then
    echo "Could not find your tenancy ID automatically."
    echo "Find it in the console: profile icon (top right) -> Tenancy -> OCID -> Copy."
    read -r -p "Paste your tenancy OCID: " TENANCY
fi

# --- Keep running in the background, so a Cloud Shell disconnect does not stop it ---
if [ -z "$CREATE_SERVER_BG" ]; then
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        echo "=> Already running in the background. Showing its progress."
    else
        CREATE_SERVER_BG=1 OCI_TENANCY="$TENANCY" nohup "$(readlink -f "$0")" "$OCPUS" "$MEMORY" > "$LOG" 2>&1 &
        echo $! > "$PIDFILE"
        echo "=> Started in the background."
    fi
    echo "   Press Ctrl+C to stop watching. It keeps trying either way."
    echo "   To watch again later: tail -f $LOG"
    echo ""
    sleep 2
    tail -n 30 -f "$LOG"
    exit 0
fi

# --- Stop if the server already exists ---
EXISTING=$(oci compute instance list --compartment-id "$TENANCY" --display-name "$NAME" \
    --query 'data[?"lifecycle-state"!=`TERMINATED` && "lifecycle-state"!=`TERMINATING`] | [0].id' --raw-output 2>/dev/null)
if [ -n "$EXISTING" ] && [ "$EXISTING" != "null" ]; then
    echo "=> You already have a server named '$NAME'. Skipping creation."
    INSTANCE="$EXISTING"
fi

if [ -z "$INSTANCE" ]; then
    AD=$(oci iam availability-domain list --compartment-id "$TENANCY" --query 'data[0].name' --raw-output)
    echo "=> Availability domain: $AD"

    # --- Network: reuse a public subnet, or create one ---
    SUBNET=$(oci network subnet list --compartment-id "$TENANCY" \
        --query 'data[?"prohibit-public-ip-on-vnic"==`false`] | [0].id' --raw-output 2>/dev/null)
    if [ -z "$SUBNET" ] || [ "$SUBNET" = "null" ]; then
        echo "=> Creating a network..."
        VCN=$(oci network vcn create --compartment-id "$TENANCY" --cidr-blocks '["10.0.0.0/16"]' \
            --display-name minecraft-vcn --wait-for-state AVAILABLE --query 'data.id' --raw-output)
        IGW=$(oci network internet-gateway create --compartment-id "$TENANCY" --vcn-id "$VCN" \
            --is-enabled true --display-name minecraft-igw --wait-for-state AVAILABLE --query 'data.id' --raw-output)
        RT=$(oci network vcn get --vcn-id "$VCN" --query 'data."default-route-table-id"' --raw-output)
        oci network route-table update --rt-id "$RT" --force \
            --route-rules "[{\"destination\":\"0.0.0.0/0\",\"destinationType\":\"CIDR_BLOCK\",\"networkEntityId\":\"$IGW\"}]" > /dev/null
        SUBNET=$(oci network subnet create --compartment-id "$TENANCY" --vcn-id "$VCN" --cidr-block 10.0.0.0/24 \
            --display-name minecraft-subnet --wait-for-state AVAILABLE --query 'data.id' --raw-output)
    fi
    echo "=> Network ready."

    # --- Ubuntu 24.04 image for Ampere ---
    IMAGE=$(oci compute image list --compartment-id "$TENANCY" --operating-system "Canonical Ubuntu" \
        --operating-system-version "24.04" --shape "$SHAPE" --sort-by TIMECREATED --sort-order DESC \
        --query 'data[?!contains("display-name", `Minimal`)] | [0].id' --raw-output)
    if [ -z "$IMAGE" ] || [ "$IMAGE" = "null" ]; then
        echo "!! Could not find the Ubuntu 24.04 image. Send this output to Claude."
        exit 1
    fi
    echo "=> Ubuntu 24.04 image found."

    # --- SSH key, kept in Cloud Shell so you can connect from here ---
    if [ ! -f "$KEY" ]; then
        mkdir -p "$HOME/.ssh"
        ssh-keygen -t rsa -b 4096 -N "" -f "$KEY" -q
        echo "=> Created an SSH key at $KEY"
    fi

    # --- Keep trying until there is capacity ---
    TRY=1
    while true; do
        echo "=> Attempt $TRY ($(date '+%H:%M:%S'))..."
        OUT=$(oci compute instance launch --compartment-id "$TENANCY" --availability-domain "$AD" \
            --shape "$SHAPE" --shape-config "{\"ocpus\":$OCPUS,\"memoryInGBs\":$MEMORY}" \
            --image-id "$IMAGE" --subnet-id "$SUBNET" --assign-public-ip true \
            --display-name "$NAME" --ssh-authorized-keys-file "$KEY.pub" \
            --query 'data.id' --raw-output 2>&1)
        if [[ "$OUT" == ocid1.instance.* ]]; then
            INSTANCE="$OUT"
            echo "=> Success! The server is being created."
            break
        elif echo "$OUT" | grep -qi "capacity"; then
            echo "   Out of capacity. Trying again in ${WAIT}s."
        elif echo "$OUT" | grep -qi "TooManyRequests"; then
            echo "   Oracle asked to slow down. Waiting 5 minutes."
            sleep 210
        elif echo "$OUT" | grep -qi "LimitExceeded"; then
            echo "!! Oracle says you reached your limit. You may already have an Ampere server,"
            echo "   or the account is still being set up. Check Compute -> Instances."
            rm -f "$PIDFILE"
            exit 1
        else
            echo "!! Unexpected error. Send this to Claude:"
            echo "$OUT"
            rm -f "$PIDFILE"
            exit 1
        fi
        TRY=$((TRY + 1))
        sleep "$WAIT"
    done
fi
rm -f "$PIDFILE"

# --- Wait for it to start and show the IP ---
echo "=> Waiting for the server to start..."
for _ in $(seq 1 60); do
    STATE=$(oci compute instance get --instance-id "$INSTANCE" --query 'data."lifecycle-state"' --raw-output)
    [ "$STATE" = "RUNNING" ] && break
    sleep 10
done
IP=$(oci compute instance list-vnics --instance-id "$INSTANCE" --query 'data[0]."public-ip"' --raw-output)

echo ""
echo "=== YOUR SERVER IS READY! ==="
echo "Public IP: $IP"
echo ""
echo "Connect to it from this Cloud Shell with:"
echo "  ssh -i $KEY ubuntu@$IP"
echo "(If it says 'Connection refused', wait a minute and try again.)"
