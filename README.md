# Free Minecraft Server via GitHub Codespaces

This repository contains a fully automated script template for creating and running a free Minecraft server using **GitHub Codespaces**, with specifications of up to **16GB of RAM and 4 cores**.

## Key Features
- **High Performance:** Leverages GitHub Codespaces capabilities (up to 16GB RAM).
- **100% Automated Setup:** Uses a single, self-transforming bash script (`start.sh`). Just execute it and relax. It automatically downloads the server core, sets up Java 21, bypasses the EULA, and launches the game.
- **Cross-Play & Cross-Version (Zero Config!):** The `plugins` folder is pre-loaded with `GeyserMC`, `Floodgate` and `ViaVersion`. 100% ready to play with zero manual server configuration required!
- **Public IP:** Integrated with the standalone `Playit.gg` agent, allowing anyone to access the server without manual router port forwarding.
- **Java 21 Ready:** Pre-configured to run Minecraft version 1.21.11 flawlessly.

## File Structure
To keep the repository clean and professional, everything is handled smoothly:
- `start.sh`: The main execution script. On its first run, it installs everything and then **transforms itself** into a clean server launcher.
- `plugins/`: Automatically pre-filled with essential plugins (`GeyserMC`, `Floodgate`, `ViaVersion`) so the server supports cross-play out-of-the-box.

## Usage - First Time Setup

1. **Create a New Codespace:**
   Click the green `Use this template` button in this repository, and select the **Open in a codespaces** tab.

2. **Run the Script:**
   Open the terminal at the bottom of the screen, then type the following command:
   ```bash
   ./start.sh
   ```
   Sit back and wait. The script will automatically download the required files, configure the environment, and start the Minecraft server.

3. **Claim the Server IP:**
   Once the server is running, open a second terminal tab (click the + icon or Ctrl + Shift + C) and run the newly generated Playit script:
   ```bash
   ./playit.sh
   ```
   Click the claim link provided in the terminal, log in to your Playit account, and share the public IP address with your friends!

## Usage - Second Time & Onwards
Because the setup script is smart, it has already transformed into a simple launcher. You don't need to reinstall anything when you restart your Codespace another day.

1. Open the primary terminal and start the server:
   ```bash
   ./start.sh
   ```

2. Open a second terminal and start the network tunnel:
   ```bash
   ./playit.sh
   ```

## Limitations & Drawbacks
While this method is powerful and free, it comes with a few limitations you should be aware of:

- **Monthly Quota:** GitHub free accounts have a monthly limit for Codespaces (usually around 120 core-hours and 15GB of storage per month). Always stop your Codespace from the GitHub dashboard when you are done playing so you don't waste your quota.

- **Inactivity Timeout:** Codespaces will automatically shut down and hibernate if you close the browser tab or if there is no interaction for a certain period.

- **Dynamic IP:** Unless you pay for a custom domain on Playit.gg, your server IP might change if you create a new agent.