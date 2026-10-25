# Better MC Server on Oracle Cloud (Free, 24/7)

Oracle Cloud's Always Free tier gives you a server with **4 cores and 24GB RAM**, with no monthly hour limit. That is enough to run the **Better MC [NEOFORGE] BMC5** modpack for a group of friends.

You do the clicking in Oracle's website (about 15 minutes). One script does everything else.

## Step 1 - Create an Oracle Cloud account
1. Go to https://www.oracle.com/cloud/free/ and click **Start for free**.
2. Pick a **Home Region** close to you and your friends. You cannot change it later.
3. Finish signing up. Oracle asks for a card to check you are a real person. Always Free resources are not charged.

## Step 2 - Create the server
1. In the Oracle Cloud console, open the menu (☰) and go to **Compute → Instances → Create instance**.
2. **Name:** `minecraft`
3. **Image and shape → Edit:**
   - **Change image:** choose **Canonical Ubuntu 24.04**.
   - **Change shape:** choose **Ampere → VM.Standard.A1.Flex**, then set **4 OCPUs** and **24 GB memory**. It should say *Always Free-eligible*.
4. **Add SSH keys:** choose **Generate a key pair for me** and click **Save private key**. Keep this file. You need it to connect.
5. Click **Create**.
   - If you see **Out of capacity**, change the **Availability domain** in the Placement section and try again, or try again later. This is common, keep trying.
   - Or let a script keep trying for you: open **Cloud Shell** (the `>_` icon at the top right of the console) and run:
     ```bash
     curl -fsSLO https://raw.githubusercontent.com/keanulaw/Minecraft-Server/claude/bold-pasteur-61vjre/oracle/create-server.sh
     chmod +x create-server.sh
     ./create-server.sh
     ```
     It retries every minute until Oracle has room, then prints the IP and the `ssh` command to connect from Cloud Shell. If Cloud Shell disconnects, open it again and run `./create-server.sh` again.
6. When the instance is **Running**, copy its **Public IP address**.

## Step 3 - Get the server pack download link
1. Open the Better MC [NEOFORGE] BMC5 page on CurseForge and go to **Files**.
2. Open the latest file and download its **Server Pack** (not the normal modpack file).
3. In your browser's downloads list, right-click the download and **Copy link address**.

## Step 4 - Connect and run the setup
1. On Windows, open **PowerShell** (on Mac, open **Terminal**) and connect, using the key file you saved and your IP:
   ```bash
   ssh -i "C:\Users\YOU\Downloads\ssh-key-XXXX.key" ubuntu@YOUR_IP
   ```
   Type `yes` if it asks about the fingerprint.
2. Run these three commands, pasting your server pack link inside the quotes:
   ```bash
   curl -fsSLO https://raw.githubusercontent.com/keanulaw/Minecraft-Server/claude/bold-pasteur-61vjre/oracle/setup.sh
   chmod +x setup.sh
   ./setup.sh "PASTE_SERVER_PACK_LINK_HERE"
   ```
   Do not run it with `sudo`. It asks for permission by itself when needed.
3. At the end, the script starts Playit and shows a **claim link**. Open it, log in to Playit, and add a **Minecraft Java** tunnel to local port **25565**. When Playit shows your tunnel address, press **Ctrl+C**. Playit keeps running in the background from then on.

That's it. The server and Playit run 24/7 and start by themselves if the VM restarts. You can close PowerShell.

## Joining
Every player needs the same modpack installed:
1. Install the **CurseForge app**, search for **Better MC [NEOFORGE] BMC5**, and install the **same version** as the server.
2. Launch it and join with your Playit address.

Give the game at least 6GB of RAM in the CurseForge app settings.

## Managing the server
Connect with `ssh` like in Step 4, then:

| What | Command |
|---|---|
| Open the server console | `~/minecraft/console.sh` (leave it running with **Ctrl+B**, then **D**) |
| Restart the server | `sudo systemctl restart minecraft` |
| Turn the server off | `sudo systemctl stop minecraft` |
| Turn it back on | `sudo systemctl start minecraft` |

Typing `stop` in the console restarts the server after 10 seconds. To turn it off for real, use `sudo systemctl stop minecraft`.

## Keeping it free
- Oracle can reclaim Always Free servers that sit **idle for 7 days** (very low CPU use). If that worries you, upgrade your account to **Pay As You Go** in Billing. You are still not charged while you stay inside the Always Free limits (4 OCPUs and 24GB in total), and idle reclaiming no longer applies. Setting a small budget alert in **Billing → Budgets** gives extra peace of mind.
- Do not create extra instances or change the shape beyond 4 OCPUs and 24GB, or you may leave the free tier.
