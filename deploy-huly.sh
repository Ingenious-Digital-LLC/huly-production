#!/bin/bash

echo "🚀 Huly Deployment Script - Nginx Docker Solution"
echo "=================================================="

# Check prerequisites
echo "📋 Checking prerequisites..."
if ! command -v docker-compose &> /dev/null; then
    echo "❌ docker-compose not found. Please install docker-compose first."
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "❌ Docker daemon not running. Please start Docker first."
    exit 1
fi

echo "✅ Docker and docker-compose are available"

# Check port availability
echo "🔍 Checking port 8090 availability..."
if netstat -tlnp 2>/dev/null | grep -q ":8090 " || ss -tlnp 2>/dev/null | grep -q ":8090 "; then
    echo "⚠️  Port 8090 is already in use. Deployment may fail."
    echo "To use a different port, edit HTTP_PORT in huly.conf"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✅ Port 8090 is available"
fi

# Verify configuration files
echo "📁 Verifying configuration files..."
required_files=("huly.conf" ".huly.secret" ".huly.nginx" "compose.yml")
for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Required file missing: $file"
        exit 1
    fi
done
echo "✅ All required files present"

# Show configuration summary
echo "⚙️  Configuration Summary:"
echo "   Host: $(grep HOST_ADDRESS huly.conf | cut -d= -f2)"
echo "   Port: $(grep HTTP_PORT huly.conf | cut -d= -f2)"
echo "   SSL:  $(grep SECURE= huly.conf | cut -d= -f2 | sed 's/^$/disabled/')"

echo ""
echo "🐳 Starting Huly Deployment..."
echo "================================"

# Step 1: Pull images
echo "1️⃣  Pulling Docker images..."
docker-compose pull

# Step 2: Start infrastructure services
echo "2️⃣  Starting infrastructure services (MongoDB, MinIO, Elasticsearch)..."
docker-compose up -d mongodb minio elastic

# Wait for Elasticsearch
echo "⏳ Waiting for Elasticsearch to be ready..."
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if docker-compose exec -T elastic curl -s http://localhost:9200/_cluster/health &>/dev/null; then
        echo "✅ Elasticsearch is ready"
        break
    fi
    echo "   Waiting... ($((attempt + 1))/$max_attempts)"
    sleep 10
    attempt=$((attempt + 1))
done

if [ $attempt -eq $max_attempts ]; then
    echo "❌ Elasticsearch failed to start within timeout"
    echo "Check logs: docker-compose logs elastic"
    exit 1
fi

# Step 3: Start application services
echo "3️⃣  Starting application services..."
docker-compose up -d rekoni transactor collaborator account workspace front fulltext stats

# Step 4: Start nginx
echo "4️⃣  Starting nginx reverse proxy..."
docker-compose up -d nginx

# Step 5: Verify deployment
echo "5️⃣  Verifying deployment..."
sleep 5

echo ""
echo "📊 Service Status:"
docker-compose ps

echo ""
echo "🔍 Final Verification:"

# Check if nginx is running
if docker-compose ps nginx | grep -q "Up"; then
    echo "✅ Nginx is running"
    
    # Test connectivity
    if curl -s -I http://localhost:8090 >/dev/null 2>&1; then
        echo "✅ Huly is accessible at http://localhost:8090"
    else
        echo "⚠️  Huly may still be starting up. Please wait a moment and try accessing http://localhost:8090"
    fi
else
    echo "❌ Nginx failed to start"
    echo "Check logs: docker-compose logs nginx"
fi

echo ""
echo "🎉 Deployment Complete!"
echo "======================="
echo "Access Huly at: http://localhost:8090"
echo ""
echo "Useful commands:"
echo "  View logs:     docker-compose logs [service]"
echo "  Stop all:      docker-compose down"
echo "  Restart:       docker-compose restart [service]"
echo "  Status:        docker-compose ps"
echo ""
echo "For troubleshooting, see: NGINX-DEPLOYMENT-INSTRUCTIONS.md"