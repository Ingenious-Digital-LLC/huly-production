# Huly Nginx Deployment Instructions

## SOLUTION IMPLEMENTED: Docker Nginx Container

### Executive Summary
✅ **Nginx deployment strategy solved and implemented**
✅ **Port conflicts resolved** (using port 8090 instead of 80/8080)
✅ **Docker configuration corrected** (fixed .huly.nginx mounting)
✅ **Environment configured** (huly.conf and secret generated)
✅ **Ready for full deployment**

---

## Configuration Files Updated

### 1. Port Conflict Resolution
**Problem**: Ports 3000 and 8080 were already in use
**Solution**: Configured Huly to use port 8090

**Files Modified**:
- `/home/pascal/dev/huly/huly.conf` - Updated with port 8090
- `/home/pascal/dev/huly/compose.yml` - Fixed nginx config mounting

### 2. Nginx Configuration
**nginx service in compose.yml**:
```yaml
nginx:
  image: "nginx:1.21.3"
  ports:
    - "0.0.0.0:8090:80"
  volumes:
    - ./.huly.nginx:/etc/nginx/conf.d/default.conf
  restart: unless-stopped
```

**Complete nginx configuration in `.huly.nginx`**:
- Main frontend proxy (/ → front:8080)
- Account service (/_accounts → account:3000)
- Collaborator WebSocket (/_collaborator → collaborator:3078)
- Transactor WebSocket (/_transactor → transactor:3333)
- Rekoni service (/_rekoni → rekoni:4004)
- Stats service (/_stats → stats:4900)

---

## Step-by-Step Deployment Instructions

### Prerequisites
✅ Docker and docker-compose installed
✅ Port 8090 available (verified no conflicts)
✅ Configuration files created

### Step 1: Verify Configuration
```bash
cd /home/pascal/dev/huly

# Verify all required files exist
ls -la huly.conf .huly.secret .huly.nginx compose.yml

# Check docker-compose configuration
docker-compose config --services
```

### Step 2: Start Backend Services First
```bash
# Start all services except nginx initially
docker-compose up -d mongodb minio elastic

# Wait for services to be ready (especially elasticsearch)
docker-compose logs -f elastic
# Wait for "started" message, then Ctrl+C
```

### Step 3: Start Application Services
```bash
# Start the Huly application services
docker-compose up -d rekoni transactor collaborator account workspace front fulltext stats

# Monitor startup
docker-compose ps
```

### Step 4: Start Nginx
```bash
# Once all backend services are running, start nginx
docker-compose up -d nginx

# Verify nginx starts successfully
docker-compose logs nginx
```

### Step 5: Verify Deployment
```bash
# Check all services are running
docker-compose ps

# Test nginx is listening on port 8090
netstat -tlnp | grep :8090

# Test basic connectivity
curl -I http://localhost:8090
```

### Step 6: Access Huly
- **URL**: http://localhost:8090
- **Account setup**: Follow the on-screen setup wizard

---

## Testing and Verification

### 1. Container Health Check
```bash
# Verify all containers are running
docker-compose ps

# Expected output: All services should show "Up" status
```

### 2. Port Verification
```bash
# Confirm nginx is listening on 8090
ss -tlnp | grep :8090
```

### 3. Route Testing
```bash
# Test main application
curl -I http://localhost:8090/

# Test account service
curl -I http://localhost:8090/_accounts/

# Test stats service
curl -I http://localhost:8090/_stats/
```

### 4. WebSocket Testing
- Open browser to http://localhost:8090
- Open browser developer tools → Network tab
- Look for WebSocket connections to `/_collaborator` and `/_transactor`

---

## Troubleshooting

### Nginx Container Restarts
**Issue**: nginx container shows "Restarting"
**Cause**: Backend services not available yet
**Solution**: Start backend services first, then nginx

```bash
# Check which services nginx needs
docker-compose logs nginx

# Start services in dependency order
docker-compose up -d mongodb minio elastic
docker-compose up -d rekoni transactor collaborator account workspace front fulltext stats
docker-compose up -d nginx
```

### Port Conflicts
**Issue**: Port 8090 already in use
**Solution**: Change port in huly.conf and restart

```bash
# Edit huly.conf
sed -i 's/HTTP_PORT=8090/HTTP_PORT=8091/' huly.conf

# Restart nginx
docker-compose restart nginx
```

### Configuration Issues
**Issue**: nginx configuration errors
**Solution**: Check .huly.nginx file integrity

```bash
# Verify nginx config file
ls -la .huly.nginx
docker-compose exec nginx nginx -t
```

---

## Production Considerations

### SSL/HTTPS Setup
To enable SSL, modify `huly.conf`:
```bash
SECURE=true
HOST_ADDRESS=yourdomain.com
```

### Firewall Configuration
```bash
# Open port 8090 (or your chosen port)
sudo ufw allow 8090/tcp
```

### Domain Setup
1. Point your domain to server IP
2. Update `HOST_ADDRESS` in `huly.conf`
3. Add SSL certificates to nginx configuration

---

## Alternative: Traefik Deployment

If you prefer Traefik over nginx:
1. Use the `/home/pascal/dev/huly/traefik/` directory
2. Follow the Traefik setup instructions
3. Traefik provides automatic SSL with Let's Encrypt

---

## Files Summary

**Configuration Files Created/Modified**:
- `/home/pascal/dev/huly/huly.conf` - Main configuration (port 8090)
- `/home/pascal/dev/huly/.huly.secret` - Generated secret key
- `/home/pascal/dev/huly/compose.yml` - Fixed nginx volume mount
- `/home/pascal/dev/huly/.huly.nginx` - Complete nginx configuration (unchanged)

**Documentation Created**:
- `/home/pascal/dev/huly/nginx-deployment-strategy.md` - Strategy overview
- `/home/pascal/dev/huly/NGINX-DEPLOYMENT-INSTRUCTIONS.md` - This file

**Ready for deployment**: All nginx challenges solved and configured for port 8090 operation.