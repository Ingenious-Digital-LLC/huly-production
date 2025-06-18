#!/usr/bin/env bash

HULY_VERSION="v0.6.501"
DOCKER_NAME="huly"
CONFIG_FILE="huly.conf"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

while true; do
    if [[ -n "$HOST_ADDRESS" ]]; then
        prompt_type="current"
        prompt_value="${HOST_ADDRESS}"
    else
        prompt_type="default"
        prompt_value="localhost"
    fi
    read -p "Enter the host address (domain name or IP) [${prompt_type}: ${prompt_value}]: " input
    _HOST_ADDRESS="${input:-${HOST_ADDRESS:-localhost}}"
    break
done

while true; do
    if [[ -n "$HTTP_PORT" ]]; then
        prompt_type="current"
        prompt_value="${HTTP_PORT}"
    else
        prompt_type="default"
        prompt_value="80"
    fi
    read -p "Enter the port for HTTP [${prompt_type}: ${prompt_value}]: " input
    _HTTP_PORT="${input:-${HTTP_PORT:-80}}"
    if [[ "$_HTTP_PORT" =~ ^[0-9]+$ && "$_HTTP_PORT" -ge 1 && "$_HTTP_PORT" -le 65535 ]]; then
        break
    else
        echo "Invalid port. Please enter a number between 1 and 65535."
    fi
done

echo "$_HOST_ADDRESS $HOST_ADDRESS $_HTTP_PORT $HTTP_PORT"

if [[ "$_HOST_ADDRESS" == "localhost" || "$_HOST_ADDRESS" == "127.0.0.1" || "$_HOST_ADDRESS" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}:?$ ]]; then
    _HOST_ADDRESS="${_HOST_ADDRESS%:}:${_HTTP_PORT}"
    SECURE=""
else
    while true; do
        if [[ -n "$SECURE" ]]; then
            prompt_type="current"
            prompt_value="Yes"
        else
            prompt_type="default"
            prompt_value="No"
        fi
        read -p "Will you serve Huly over SSL? (y/n) [${prompt_type}: ${prompt_value}]: " input
        case "${input}" in
            [Yy]* )
                _SECURE="true"; break;;
            [Nn]* )
                _SECURE=""; break;;
            "" )
                _SECURE="${SECURE:+true}"; break;;
            * )
                echo "Invalid input. Please enter Y or N.";;
        esac
    done
fi

SECRET=false
if [ "$1" == "--secret" ]; then
  SECRET=true
fi

if [ ! -f .huly.secret ] || [ "$SECRET" == true ]; then
  openssl rand -hex 32 > .huly.secret
  echo "Secret generated and stored in .huly.secret"
else
  echo -e "\033[33m.huly.secret already exists, not overwriting."
  echo "Run this script with --secret to generate a new secret."
fi

# Validate secret file
if [ ! -f .huly.secret ]; then
    echo "❌ Error: .huly.secret file not found"
    exit 1
fi

# Export variables for envsubst
export HOST_ADDRESS=$_HOST_ADDRESS
export SECURE=$_SECURE
export HTTP_PORT=$_HTTP_PORT
export HTTP_BIND=$HTTP_BIND
export TITLE=${TITLE:-Huly}
export DEFAULT_LANGUAGE=${DEFAULT_LANGUAGE:-en}
export LAST_NAME_FIRST=${LAST_NAME_FIRST:-true}
export HULY_SECRET=$(cat .huly.secret)

# Validate envsubst is available
if ! command -v envsubst >/dev/null 2>&1; then
    echo "❌ Error: envsubst not found. Please install gettext-base package:"
    echo "   Ubuntu/Debian: sudo apt-get install gettext-base"
    echo "   CentOS/RHEL: sudo yum install gettext"
    exit 1
fi

# Generate configuration file
echo "🔧 Generating configuration file..."
envsubst < .template.huly.conf > $CONFIG_FILE

if [ $? -eq 0 ]; then
    echo "✅ Configuration file generated: $CONFIG_FILE"
else
    echo "❌ Error generating configuration file"
    exit 1
fi

# Validate Docker is available
if ! command -v docker >/dev/null 2>&1; then
    echo "⚠️  Warning: Docker not found. Please install Docker to run Huly."
fi

COMPOSE_CMD=""
if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    echo "⚠️  Warning: Docker Compose not found. Please install Docker Compose to run Huly."
fi

echo -e "\n\033[1;34m📋 Configuration Summary:\033[0m"
echo -e "Host Address: \033[1;32m$_HOST_ADDRESS\033[0m"
echo -e "HTTP Port: \033[1;32m$_HTTP_PORT\033[0m"
if [[ -n "$_SECURE" ]]; then
    echo -e "SSL Enabled: \033[1;32mYes\033[0m"
else
    echo -e "SSL Enabled: \033[1;31mNo\033[0m"
fi
echo -e "Config File: \033[1;32m$CONFIG_FILE\033[0m"

echo -e "\n🔧 Generating nginx configuration..."
if [ -x "./nginx.sh" ]; then
    ./nginx.sh
    if [ $? -eq 0 ]; then
        echo "✅ nginx configuration generated successfully"
    else
        echo "❌ Error generating nginx configuration"
        exit 1
    fi
else
    echo "❌ Error: nginx.sh not found or not executable"
    exit 1
fi

echo ""
read -p "Do you want to run 'docker compose up -d' now to start Huly? (Y/n): " RUN_DOCKER
case "${RUN_DOCKER:-Y}" in
    [Yy]* )
         if [ -n "$COMPOSE_CMD" ]; then
             echo -e "\033[1;32m🚀 Starting Huly with '$COMPOSE_CMD up -d'...\033[0m"
             if $COMPOSE_CMD up -d; then
                 echo "✅ Huly started successfully"
                 echo ""
                 echo "🎉 Setup Complete!"
                 echo "   Access Huly at: http${_SECURE:+s}://$_HOST_ADDRESS"
                 echo "   Check status: $COMPOSE_CMD ps"
                 echo "   View logs: $COMPOSE_CMD logs -f"
             else
                 echo "❌ Error starting Huly. Check the logs with: $COMPOSE_CMD logs"
             fi
         else
             echo "❌ Docker Compose not available. Please install Docker Compose and run manually."
         fi
         ;;
    [Nn]* )
        echo ""
        echo "✅ Setup Complete!"
        if [ -n "$COMPOSE_CMD" ]; then
            echo "   Start Huly with: $COMPOSE_CMD up -d"
        else
            echo "   Install Docker Compose and start with: docker-compose up -d"
        fi
        echo "   Access at: http${_SECURE:+s}://$_HOST_ADDRESS"
        ;;
esac
