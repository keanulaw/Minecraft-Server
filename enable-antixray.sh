#!/bin/bash
# Turns on Paper's built-in anti-xray for the overworld and the nether.
# Uses the settings recommended in the Paper docs (engine-mode 2).
# Start the server at least once first so the world folders exist,
# then stop it (type "stop" in the console) before running this.

cd "$(dirname "$0")" || exit 1

LEVEL=$(grep -E '^level-name=' server.properties 2>/dev/null | cut -d '=' -f 2)
LEVEL=${LEVEL:-world}

add_antixray() {
    local file="$1" block="$2"
    if [ ! -f "$file" ]; then
        echo "!! $file not found. Start the server once, stop it, then run this again."
        return 1
    fi
    if grep -q '^anticheat:' "$file"; then
        echo "=> $file already has anticheat settings, skipping."
        return 0
    fi
    printf '\n%s\n' "$block" >> "$file"
    echo "=> Anti-xray enabled in $file"
}

add_antixray "$LEVEL/paper-world.yml" "anticheat:
  anti-xray:
    enabled: true
    engine-mode: 2
    max-block-height: 64
    update-radius: 2
    lava-obscures: false
    use-permission: false
    hidden-blocks:
      - copper_ore
      - deepslate_copper_ore
      - raw_copper_block
      - gold_ore
      - deepslate_gold_ore
      - iron_ore
      - deepslate_iron_ore
      - raw_iron_block
      - coal_ore
      - deepslate_coal_ore
      - lapis_ore
      - deepslate_lapis_ore
      - mossy_cobblestone
      - obsidian
      - chest
      - diamond_ore
      - deepslate_diamond_ore
      - redstone_ore
      - deepslate_redstone_ore
      - clay
      - emerald_ore
      - deepslate_emerald_ore
      - ender_chest
    replacement-blocks:
      - stone
      - oak_planks
      - deepslate"

add_antixray "${LEVEL}_nether/paper-world.yml" "anticheat:
  anti-xray:
    enabled: true
    engine-mode: 2
    max-block-height: 128
    update-radius: 2
    lava-obscures: false
    use-permission: false
    hidden-blocks:
      - ancient_debris
      - bone_block
      - glowstone
      - magma_block
      - nether_bricks
      - nether_gold_ore
      - nether_quartz_ore
      - polished_blackstone_bricks
    replacement-blocks:
      - basalt
      - blackstone
      - gravel
      - netherrack
      - soul_sand
      - soul_soil"

echo "=== Done! Start the server again with ./start.sh ==="
