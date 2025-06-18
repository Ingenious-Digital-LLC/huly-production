#!/bin/bash

# Load configuration if not already set (allows for environment overrides)
if [ -z "$HOST_ADDRESS" ] && [ -f "huly.conf" ]; then
    source "huly.conf"
fi

# Validate required variables
if [ -z "$HOST_ADDRESS" ]; then
    echo "Error: HOST_ADDRESS not set. Please run setup.sh first or export HOST_ADDRESS."
    exit 1
fi

# Check for --recreate flag
RECREATE=false
if [ "$1" == "--recreate" ]; then
    RECREATE=true
fi

# Set nginx listen port based on SECURE setting
if [[ -n "$SECURE" ]]; then
    export NGINX_LISTEN_PORT="443 ssl"
    echo "Configuring for SSL (port 443)"
else
    export NGINX_LISTEN_PORT="80"
    echo "Configuring for HTTP (port 80)"
fi

# Handle nginx.conf recreation or updating
if [ "$RECREATE" == true ] || [ ! -f "nginx.conf" ]; then
    if [ "$RECREATE" == true ]; then
        echo "Recreating nginx.conf from template..."
    else
        echo "nginx.conf not found, creating from template..."
    fi
    
    # Generate nginx.conf using manual substitution to preserve nginx variables
    sed -e "s/\${NGINX_LISTEN_PORT:-80}/$NGINX_LISTEN_PORT/g" \
        -e "s/\${HOST_ADDRESS:-localhost}/$HOST_ADDRESS/g" \
        -e 's/\$\$/$/g' \
        .template.nginx.conf > nginx.conf
    
    if [ $? -eq 0 ]; then
        echo "✅ nginx.conf generated successfully"
    else
        echo "❌ Error generating nginx.conf"
        exit 1
    fi
else
    echo "nginx.conf already exists. Use --recreate to regenerate."
fi

# Add SSL redirect block for HTTPS configurations
if [[ -n "$SECURE" ]]; then
    # Check if redirect block already exists
    if ! grep -q "return 301 https" nginx.conf; then
        echo "Adding HTTP to HTTPS redirect block..."
        cat >> nginx.conf << EOF

# HTTP to HTTPS redirect
server {
    listen 80;
    server_name ${HOST_ADDRESS};
    return 301 https://\$host\$request_uri;
}
EOF
        echo "✅ HTTPS redirect block added"
    fi
    echo "⚠️  Note: Make sure to configure SSL certificates for HTTPS"
fi

echo ""
echo "📋 Configuration Summary:"
echo "   Host: ${HOST_ADDRESS}"
echo "   SSL: ${SECURE:+Enabled}${SECURE:-Disabled}"
echo "   Port: ${NGINX_LISTEN_PORT}"
echo ""

# Validate generated config
echo "🔍 Validating nginx configuration..."
if command -v nginx >/dev/null 2>&1; then
    if nginx -t -c "$(pwd)/nginx.conf" 2>/dev/null; then
        echo "✅ nginx configuration is valid"
    else
        echo "⚠️  nginx configuration test failed (this is normal if nginx isn't installed)"
        echo "   Configuration will be validated when nginx starts in the container"
    fi
else
    echo "ℹ️  nginx not installed locally - configuration will be validated in container"
fi

# Offer to reload nginx if it's running
if command -v nginx >/dev/null 2>&1 && pgrep nginx >/dev/null; then
    read -p "Do you want to reload nginx now? (Y/n): " RUN_NGINX
    case "${RUN_NGINX:-Y}" in  
        [Yy]* )  
            echo -e "\033[1;32mReloading nginx...\033[0m"
            sudo nginx -s reload
            ;;
        [Nn]* )
            echo "You can reload nginx later with: sudo nginx -s reload"
            ;;
    esac
else
    # Determine correct compose command
    if command -v docker-compose >/dev/null 2>&1; then
        echo "ℹ️  Use 'docker-compose restart nginx' to apply configuration changes"
    elif docker compose version >/dev/null 2>&1; then
        echo "ℹ️  Use 'docker compose restart nginx' to apply configuration changes"
    else
        echo "ℹ️  Install Docker Compose to manage containers"
    fi
fi