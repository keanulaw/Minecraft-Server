#!/bin/bash

{
    echo "=== Starting automatic server setup ==="
    
    echo "=> 1/4 Installing Java 21..."
    sudo apt update -y
    sudo apt install -y openjdk-21-jre-headless
    
    export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
    export PATH=$JAVA_HOME/bin:$PATH
    
    if ! grep -q 'JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64' ~/.bashrc; then
        echo 'export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64' >> ~/.bashrc
        echo 'export PATH=$JAVA_HOME/bin:$PATH' >> ~/.bashrc
    fi

    echo "=> 2/4 Installing Playit.gg..."
    wget -O playit-standalone https://github.com/playit-cloud/playit-agent/releases/download/v0.15.26/playit-linux-amd64
    chmod +x playit-standalone
    
    echo "=> 3/4 Installing Minecraft Server 1.21.11..."
    wget -O server.jar https://fill-data.papermc.io/v1/objects/e708e8c132dc143ffd73528cccb9532e2eb17628b1a0eee74469bf466c7003f8/paper-1.21.11-116.jar
    
    echo "=> 4/4 Final Configuration & EULA Bypass..."
    echo "eula=true" > eula.txt
    
    cat << 'EOF' > playit.sh
#!/bin/bash
echo "=> Starting Playit.gg..."
./playit-standalone
EOF
    chmod +x playit.sh

    cat << 'EOF' > start.sh
#!/bin/bash
source ~/.bashrc
echo "=> Starting Minecraft Server..."
java -Xmx8G -Xms7G -jar server.jar nogui
EOF
    chmod +x start.sh

    echo "=== SETUP FINISHED! ==="
    echo "-> Server will start in 3 seconds..."
    sleep 3
    
    exec java -Xmx8G -Xms7G -jar server.jar nogui
}