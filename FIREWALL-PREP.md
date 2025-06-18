# Firewall Configuration for Huly Deployment

## Current Port Usage Analysis
- Port 3000: Already in use (Solana Dashboard)
- Port 8080: Already in use (Node.js application)
- Port 6379: Redis (localhost only)

## Recommended Firewall Rules (UFW)

### Enable UFW
```bash
sudo ufw enable
```

### Basic Rules
```bash
# Allow SSH
sudo ufw allow ssh

# Allow HTTP (for Huly web interface)
sudo ufw allow 80/tcp

# Allow HTTPS (for SSL/TLS)
sudo ufw allow 443/tcp

# Allow specific ports for Huly services if needed
sudo ufw allow 8081/tcp  # Alternative port for Huly if 80 is occupied
```

### Docker-specific Rules
```bash
# Allow Docker subnet (if needed for external access)
sudo ufw allow from 172.17.0.0/16
sudo ufw allow from 172.19.0.0/16
```

### Rate Limiting (Recommended)
```bash
# Rate limit HTTP to prevent abuse
sudo ufw limit 80/tcp
sudo ufw limit 443/tcp
```

## Port Conflicts to Resolve
1. Port 3000: Currently used by Solana Dashboard
   - Huly may need this port
   - Consider moving Solana Dashboard to different port

2. Port 8080: Currently used by Node.js app
   - May conflict with Huly admin interfaces
   - Monitor during deployment

## Status: PREPARED (Not Applied)
These rules are prepared but NOT applied yet. Apply after Huly deployment testing.