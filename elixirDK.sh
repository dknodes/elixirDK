#!/bin/bash

# Color codes and icons
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
RESET='\033[0m'

ICON_TELEGRAM="🚀"
ICON_INSTALL="🛠️"
ICON_DELETE="🗑️"
ICON_UPDATE="🔄"
ICON_LOGS="📄"
ICON_CONFIG="⚙️"
ICON_EXIT="🚪"

# ASCII Art Header
display_ascii() {
    echo -e "    ${RED}    ____  __ __    _   ______  ____  ___________${RESET}"
    echo -e "    ${GREEN}   / __ \\/ //_/   / | / / __ \\/ __ \\/ ____/ ___/${RESET}"
    echo -e "    ${BLUE}  / / / / ,<     /  |/ / / / / / / / __/  \\__ \\ ${RESET}"
    echo -e "    ${YELLOW} / /_/ / /| |   / /|  / /_/ / /_/ / /___ ___/ / ${RESET}"
    echo -e "    ${MAGENTA}/_____/_/ |_|  /_/ |_/\____/_____/_____//____/  ${RESET}"
    echo -e "    ${MAGENTA}${ICON_TELEGRAM} Follow us on Telegram: https://t.me/dknodes${RESET}"
    echo -e "    ${MAGENTA}📢 Follow us on Twitter: https://x.com/dknodes${RESET}"
}

# Menu Borders
draw_top_border() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
}

draw_middle_border() {
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"
}

draw_bottom_border() {
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"
}

# Function to check and install Docker
check_and_install_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}🐳 Docker not found. Installing Docker...${RESET}"
        sudo apt-get update -y
        sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update -y && sudo apt-get install -y docker-ce docker-ce-cli containerd.io
        sudo systemctl enable docker
        sudo systemctl start docker
    else
        echo -e "${GREEN}✔️  Docker is already installed!${RESET}"
    fi
}

get_external_ip() {
    echo -e "${BLUE}🌐 Fetching external IP address...${RESET}"
    EXTERNAL_IP=$(curl -4 -s ifconfig.me)
    if [ -z "$EXTERNAL_IP" ]; then
        echo -e "${RED}❌ Failed to fetch external IP address.${RESET}"
        read -p "Please manually enter your external IP address: " EXTERNAL_IP
    fi
    echo -e "${GREEN}✔️  External IP address: $EXTERNAL_IP${RESET}"
}

install_nodes() {
    # Check and install Docker
    check_and_install_docker
    # read -p "Press Enter to continue..."

    # Create .env file
    ENV_DIR="$HOME/elixirDK"
    ENV_FILE="$ENV_DIR/.env"

    echo -e "${YELLOW}Please enter your configuration:${RESET}"
    read -p "Node Name: " NODE_NAME
    read -p "Metamask Address: " METAMASK_ADDRESS
    read -p "Private Key (without '0x'): " PRIVATE_KEY

    get_external_ip

    echo -e "${YELLOW}Configuration entered:${RESET}"
    echo -e "${CYAN}Node Name: ${RESET}${NODE_NAME}"
    echo -e "${CYAN}Metamask Address: ${RESET}${METAMASK_ADDRESS}"
    echo -e "${CYAN}Private Key: ${RESET}${PRIVATE_KEY}"
    echo -e "${CYAN}External IP Address: ${RESET}${EXTERNAL_IP}"

    read -p "Does this look correct? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" ]]; then
        echo -e "${YELLOW}Please manually enter your external IP address:${RESET}"
        read -p "External IP Address: " EXTERNAL_IP
        echo -e "${CYAN}Updated External IP Address: ${RESET}${EXTERNAL_IP}"
    fi

    if [ ! -d "$ENV_DIR" ]; then
        echo -e "${BLUE}📂 Creating directory $ENV_DIR...${RESET}"
        mkdir -p "$ENV_DIR" || { echo -e "${RED}❌ Failed to create directory $ENV_DIR.${RESET}"; exit 1; }
    fi

    echo -e "${BLUE}📝 Creating .env file at $ENV_FILE...${RESET}"
    cat <<EOF > "$ENV_FILE"
STRATEGY_EXECUTOR_DISPLAY_NAME=$NODE_NAME
STRATEGY_EXECUTOR_BENEFICIARY=$METAMASK_ADDRESS
SIGNER_PRIVATE_KEY=$PRIVATE_KEY
STRATEGY_EXECUTOR_IP_ADDRESS=$EXTERNAL_IP
EOF
    echo -e "${GREEN}✔️  .env file successfully created!${RESET}"


    # Pull Docker images
    echo -e "${CYAN}📥 Pulling Docker images...${RESET}"
    docker pull elixirprotocol/validator:testnet-3 || { echo -e "${RED}❌ Failed to pull Testnet image.${RESET}"; exit 1; }
    docker pull elixirprotocol/validator || { echo -e "${RED}❌ Failed to pull Mainnet image.${RESET}"; exit 1; }


    # Run Docker containers
    echo -e "${CYAN}🚀 Running Testnet Node...${RESET}"
    docker run -d \
        --name elixir-testnet \
        --platform linux/amd64 \
        --env-file "$ENV_FILE" \
        --env ENV=testnet-3 \
        -p 17690:17690 \
        --restart unless-stopped \
        elixirprotocol/validator:testnet-3 || { echo -e "${RED}❌ Failed to start Testnet Node.${RESET}"; return; }
    echo -e "${GREEN}✔️ Testnet Node started.${RESET}"


    echo -e "${CYAN}🚀 Running Mainnet Node...${RESET}"
    docker run -d \
        --name elixir-mainnet \
        --platform linux/amd64 \
        --env-file "$ENV_FILE" \
        --env ENV=prod \
        -p 17691:17690 \
        --restart unless-stopped \
        elixirprotocol/validator || { echo -e "${RED}❌ Failed to start Mainnet Node.${RESET}"; return; }
    echo -e "${GREEN}✔️ Mainnet Node started.${RESET}"
    
    read -p "Press Enter to continue..."
    echo -e "${GREEN}✔️  Both nodes have been successfully installed and started!${RESET}"
    
}


# Update Node
handle_update_node() {
    NODE_NAME="$1"
    IMAGE="$2"
    ENV_VALUE="$3"
    PORT="$4"

    #Get current ENV
    ENV_DIR="$HOME/elixirDK"
    ENV_FILE="$ENV_DIR/.env"

    echo -e "${BLUE}🛑 Stopping node ${NODE_NAME}...${RESET}"
    docker stop "$NODE_NAME" || echo -e "${YELLOW}⚠️ Node ${NODE_NAME} is already stopped.${RESET}"

    echo -e "${RED}🗑 Removing old container ${NODE_NAME}...${RESET}"
    docker rm "$NODE_NAME" || echo -e "${YELLOW}⚠️ Container ${NODE_NAME} is already removed.${RESET}"

    echo -e "${CYAN}📥 Pulling new Docker image for ${NODE_NAME}...${RESET}"
    docker pull "$IMAGE" || { echo -e "${RED}❌ Failed to pull new Docker image for ${NODE_NAME}.${RESET}"; return; }

    echo -e "${GREEN}🚀 Starting updated node ${NODE_NAME}...${RESET}"
    docker run -d \
        --name "$NODE_NAME" \
        --platform linux/amd64 \
        --env-file "$ENV_FILE" \
        --env ENV="$ENV_VALUE" \
        -p "$PORT" \
        --restart unless-stopped \
        "$IMAGE" || { echo -e "${RED}❌ Failed to start updated node ${NODE_NAME}.${RESET}"; return; }

    echo -e "${GREEN}✔️ Node ${NODE_NAME} successfully updated and restarted!${RESET}"
    
}

handle_update_testnet() {
    handle_update_node "elixir-testnet" "elixirprotocol/validator:testnet-3" "testnet-3" "17690:17690"
    read -p "Press Enter to continue..."
}

handle_update_mainnet() {
    handle_update_node "elixir-mainnet" "elixirprotocol/validator" "prod" "17691:17690"
    read -p "Press Enter to continue..."
}

handle_delete_nodes() {
    echo -e "${RED}🛑 Stopping and removing all nodes...${RESET}"
    docker stop elixir-testnet elixir-mainnet 2>/dev/null || echo -e "${YELLOW}⚠️ Nodes are already stopped.${RESET}"
    docker rm elixir-testnet elixir-mainnet 2>/dev/null || echo -e "${YELLOW}⚠️ Containers are already removed.${RESET}"
    echo -e "${GREEN}✔️ Nodes successfully deleted.${RESET}"
    read -p "Press Enter to continue..."
}

handle_view_logs() {
    NODE_NAME="$1"
    echo -e "${GREEN}Fetching logs for ${NODE_NAME}...${RESET}"
    docker logs -f "$NODE_NAME"
    read -p "Press Enter to return to the main menu..."
}

handle_view_config() {
    ENV_FILE="$HOME/elixirDK/.env"
    if [ -f "$ENV_FILE" ]; then
        echo -e "${CYAN}Configuration File:${RESET}"
        cat "$ENV_FILE"
    else
        echo -e "${RED}Configuration file not found.${RESET}"
    fi
    read -p "Press Enter to return to the main menu..."
}

# Show Menu
show_menu() {
    clear
    draw_top_border
    display_ascii
    draw_middle_border
    echo -e "    ${YELLOW}Please choose an option:${RESET}"
    echo
    echo -e "    ${CYAN}1.${RESET} ${ICON_INSTALL} Install Nodes"
    echo -e "    ${CYAN}2.${RESET} ${ICON_DELETE} Delete Nodes"
    echo -e "    ${CYAN}3.${RESET} ${ICON_UPDATE} Update Testnet Node"
    echo -e "    ${CYAN}4.${RESET} ${ICON_UPDATE} Update Mainnet Node"
    echo -e "    ${CYAN}5.${RESET} ${ICON_LOGS} View Testnet Logs"
    echo -e "    ${CYAN}6.${RESET} ${ICON_LOGS} View Mainnet Logs"
    echo -e "    ${CYAN}7.${RESET} ${ICON_CONFIG} View Config File"
    echo -e "    ${CYAN}8.${RESET} ${ICON_CONFIG} Edit Config File"
    echo -e "    ${CYAN}0.${RESET} ${ICON_EXIT} Exit"
    echo
    draw_bottom_border
    echo -ne "    ${YELLOW}Enter your choice [0-8]:${RESET} "
    read choice
}

# Main Loop
while true; do
    show_menu
    case $choice in
        1) install_nodes ;;
        2) handle_delete_nodes ;;
        3) handle_update_testnet ;;
        4) handle_update_mainnet ;;
        5) handle_view_logs "elixir-testnet" ;;
        6) handle_view_logs "elixir-mainnet" ;;
        7) handle_view_config ;;
        8) nano "$HOME/elixirDK/.env" ;;
        0) echo -e "${GREEN}Exiting...${RESET}" && exit 0 ;;
        *) echo -e "${RED}Invalid choice, please try again.${RESET}" ;;
    esac
done
