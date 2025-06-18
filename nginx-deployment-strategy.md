# Nginx Deployment Strategy for Huly

## Strategy: Docker Nginx Container (Recommended)

### Why Docker Nginx?
- **Clean Isolation**: No conflicts with system nginx
- **Easy Management**: Part of Docker Compose stack
- **Pre-configured**: Templates already exist
- **Port Flexibility**: Easy to remap ports

### Port Conflict Resolution

**Current Conflicts Detected:**
- Port 3000: In use (likely by another service)
- Port 8080: In use by Node.js process (PID 1234819)

**Solution: Use Alternative Ports**
- HTTP Port: 8090 (instead of 80)
- Alternative: 8081 (instead of 8080 if needed)

### Configuration Files

1. **compose.yml**: Nginx service already configured
2. **.huly.nginx**: Complete nginx configuration with all routes
3. **.template.nginx.conf**: Template for system nginx (not used in Docker approach)

### Docker Nginx Configuration

The existing `.huly.nginx` file contains a complete nginx configuration with:
- Main frontend proxy (front:8080)
- Account service (_accounts -> account:3000) 
- Collaborator service (_collaborator -> collaborator:3078)
- Transactor service (_transactor -> transactor:3333)
- Rekoni service (_rekoni -> rekoni:4004)
- Stats service (_stats -> stats:4900)
- WebSocket support for real-time features

### Environment Variables Required

```bash
DOCKER_NAME=huly
HTTP_BIND=0.0.0.0  # Bind to all interfaces
HTTP_PORT=8090     # Use port 8090 to avoid conflicts
HOST_ADDRESS=localhost:8090
SECURE=             # Leave empty for HTTP
HULY_VERSION=v0.6.501
SECRET=<generated>
```

## Implementation Steps

1. **Create Configuration File**: Generate huly.conf with proper ports
2. **Generate Secret**: Create .huly.secret file
3. **Start Docker Stack**: Run docker compose up -d
4. **Verify Services**: Check all containers are running
5. **Test Access**: Verify nginx proxying works

## Testing Strategy

1. **Container Health**: Ensure nginx container starts successfully
2. **Port Binding**: Verify port 8090 is accessible
3. **Proxy Testing**: Test each route (_accounts, _collaborator, etc.)
4. **WebSocket Testing**: Verify real-time features work
5. **Frontend Access**: Confirm main application loads

## Troubleshooting

- **Port Conflicts**: Use netstat/ss to identify conflicting services
- **Docker Issues**: Check container logs with `docker compose logs nginx`
- **Configuration**: Verify .huly.nginx file is properly mounted
- **Permissions**: Ensure file permissions allow Docker access

## Production Considerations

- **SSL/TLS**: Add SECURE=true and configure certificates
- **Domain**: Replace localhost with actual domain name
- **Firewall**: Open required ports (8090 or 443 for SSL)
- **Monitoring**: Add health checks and logging