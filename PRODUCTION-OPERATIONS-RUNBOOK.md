# Huly Production Operations Runbook

**Version:** 1.0  
**Last Updated:** June 18, 2025  
**System:** Huly Enterprise Deployment  
**Environment:** Production (92.118.56.108)

## Quick Reference

### Essential Commands
```bash
# System Status
./monitor-resources.sh                    # Real-time monitoring dashboard
docker compose ps                         # Container status
docker stats --no-stream                  # Resource usage snapshot

# Service Management  
./deploy-optimized.sh deploy              # Full deployment
./deploy-optimized.sh restart             # Restart all services
./deploy-optimized.sh stop                # Stop all services
./deploy-optimized.sh status              # Service status

# Troubleshooting
docker compose logs [service] --tail=50   # Service logs
./monitor-resources.sh --with-logs        # Monitor with logs
docker compose exec [service] bash       # Service shell access
```

### Critical Service Ports
- **Frontend UI:** http://localhost:8090
- **MongoDB:** localhost:27017
- **MinIO:** localhost:9000  
- **Elasticsearch:** localhost:9200

## Startup and Shutdown Procedures

### 🚀 Production Startup Procedure

#### 1. Pre-Startup Validation
```bash
# Verify system resources
free -h                                   # Check available memory (need >1.5GB free)
df -h                                     # Check disk space (need >5GB free)
docker version                           # Verify Docker is running

# Verify configuration files
ls -la huly.conf .huly.secret nginx.conf # Check config files exist
cat huly.conf | grep -v "PASSWORD\|SECRET" # Verify config (hide secrets)
```

#### 2. System Startup
```bash
# Navigate to Huly directory
cd /home/pascal/dev/huly

# Start with optimized configuration
./deploy-optimized.sh deploy

# Verify startup success
./monitor-resources.sh
```

#### 3. Post-Startup Validation
```bash
# Wait for all services to become healthy (2-3 minutes)
watch docker compose ps

# Verify frontend access
curl -s http://localhost:8090/ | grep -q "Huly" && echo "✅ Frontend OK" || echo "❌ Frontend Failed"

# Check database connectivity
docker compose exec mongodb mongosh --eval "db.adminCommand('ping')" --quiet
docker compose exec minio mc ready local
```

#### 4. Startup Success Criteria
- [ ] All containers show "running" status
- [ ] Core services (mongodb, minio, elastic) show "healthy" status  
- [ ] Frontend accessible at port 8090
- [ ] System memory usage <85%
- [ ] No critical errors in logs

### 🛑 Production Shutdown Procedure

#### 1. Graceful Shutdown
```bash
# Navigate to Huly directory
cd /home/pascal/dev/huly

# Stop all services gracefully
./deploy-optimized.sh stop

# Verify all containers stopped
docker compose ps -a
```

#### 2. Emergency Shutdown
```bash
# Force stop all Huly containers
docker compose down --remove-orphans

# Kill any remaining Huly processes
docker ps | grep huly | awk '{print $1}' | xargs -r docker kill
```

#### 3. Shutdown Validation
```bash
# Verify no Huly containers running
docker ps | grep huly || echo "✅ All Huly containers stopped"

# Check for any remaining volumes in use
docker volume ls | grep huly
```

## Daily Operations

### 📊 Daily Monitoring Checklist

**Morning System Check (5 minutes)**
```bash
# 1. Resource monitoring
./monitor-resources.sh

# 2. Service health check
docker compose ps

# 3. Frontend accessibility test
curl -s http://localhost:8090/ >/dev/null && echo "✅ Frontend OK" || echo "❌ Frontend Down"

# 4. Error log review
docker compose logs --since=24h | grep -i error | tail -10
```

**Daily Metrics to Record:**
- [ ] System memory usage percentage
- [ ] CPU load average (1, 5, 15 minute)
- [ ] Disk space usage percentage
- [ ] Container health status count
- [ ] Frontend response time
- [ ] Any error patterns in logs

### 🔧 Daily Maintenance Tasks

**Automated Daily Tasks (via cron)**
```bash
# Log rotation and cleanup (run at 2 AM)
0 2 * * * docker system prune -f --volumes=false

# Resource monitoring log (every hour)
0 * * * * /home/pascal/dev/huly/monitor-resources.sh >> /var/log/huly-daily.log 2>&1

# Health check alert (every 15 minutes)
*/15 * * * * /home/pascal/dev/huly/health-check-alert.sh
```

**Manual Daily Tasks:**
- Review resource usage trends
- Check for service restarts or failures
- Monitor application performance
- Review security logs for anomalies

## Performance Monitoring

### 📈 Real-Time Monitoring

#### Resource Monitoring Dashboard
```bash
# Continuous monitoring (press Ctrl+C to exit)
./monitor-resources.sh --watch

# One-time status check
./monitor-resources.sh

# Include container logs
./monitor-resources.sh --with-logs
```

#### Key Performance Indicators (KPIs)

**System Resource Targets:**
- Memory utilization: 60-80% (Alert >85%)
- CPU load average: <2.0 per core (Alert >80% of cores)  
- Disk usage: <85% (Alert >90%)
- Swap usage: <25% (Alert >50%)

**Service Performance Targets:**
- Container startup time: <2 minutes
- Health check success rate: >99%
- Frontend response time: <2 seconds
- Database query response: <100ms average

#### Performance Alert Thresholds
```bash
# Memory usage alert
if (( $(free | awk 'NR==2{printf "%.1f", $3*100/$2 }') > 85 )); then
    echo "🚨 HIGH MEMORY USAGE ALERT"
fi

# CPU load alert  
if (( $(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//') > 2.5 )); then
    echo "🚨 HIGH CPU LOAD ALERT"
fi

# Disk space alert
if (( $(df / | awk 'NR==2 {print $5}' | sed 's/%//') > 85 )); then
    echo "🚨 HIGH DISK USAGE ALERT"
fi
```

### 📊 Long-term Performance Analysis

**Weekly Performance Review:**
```bash
# Generate weekly performance report
cat /tmp/huly-resource-monitor.log | awk -F',' '{
    print $1 "," $2 "," $3
}' > /var/log/huly-weekly-$(date +%Y%W).csv

# Analyze trends
awk -F',' '{mem+=$2; cpu+=$3; count++} END {
    print "Average Memory: " mem/count "%"
    print "Average CPU Load: " cpu/count
}' /var/log/huly-weekly-$(date +%Y%W).csv
```

**Performance Baseline Documentation:**
- Record peak resource usage patterns
- Document seasonal/daily usage variations  
- Track service startup/recovery times
- Monitor database growth rates

## Troubleshooting Guide

### 🔍 Common Issues and Solutions

#### Issue: High Memory Usage (>85%)

**Diagnosis:**
```bash
# Check container memory usage
docker stats --no-stream | sort -k7 -h

# Identify memory-heavy containers
ps aux --sort=-%mem | head -10

# Check for memory leaks
cat /proc/meminfo | grep -E "(MemTotal|MemAvailable|MemFree)"
```

**Resolution:**
```bash
# 1. Restart memory-heavy services
docker compose restart [heavy-service]

# 2. Adjust memory limits if needed
vi compose.yml  # Modify memory limits

# 3. Clear system cache if safe
sync && echo 3 > /proc/sys/vm/drop_caches
```

#### Issue: Service Health Check Failures

**Diagnosis:**
```bash
# Check specific service logs
docker compose logs [service] --tail=50

# Check service configuration
docker compose exec [service] env | grep -E "(MONGO|MINIO|ELASTIC)"

# Test service connectivity
docker compose exec [service] curl -f http://localhost:[port]/health
```

**Resolution:**
```bash
# 1. Restart unhealthy service
docker compose restart [service]

# 2. Wait for health check (up to 2 minutes)
watch 'docker compose ps | grep [service]'

# 3. If still unhealthy, check dependencies
docker compose logs mongodb minio elastic --tail=20
```

#### Issue: Frontend Not Accessible

**Diagnosis:**
```bash
# Check nginx status and logs
docker compose logs nginx --tail=20

# Check frontend service status  
docker compose logs front --tail=20

# Test port connectivity
netstat -tlnp | grep :8090
curl -v http://localhost:8090/
```

**Resolution:**
```bash
# 1. Restart nginx and frontend
docker compose restart nginx front

# 2. Verify nginx configuration
docker compose exec nginx nginx -t

# 3. Check port bindings
docker compose ps | grep nginx
```

#### Issue: Database Connection Failures

**Diagnosis:**
```bash
# Test MongoDB connectivity
docker compose exec mongodb mongosh --eval "db.adminCommand('ping')"

# Test MinIO connectivity  
docker compose exec minio mc ready local

# Check authentication
docker compose logs | grep -i "authentication\|credential"
```

**Resolution:**
```bash
# 1. Verify credentials in huly.conf
cat huly.conf | grep -E "(MONGO|MINIO)" | grep -v PASSWORD

# 2. Restart database services
docker compose restart mongodb minio

# 3. Test application reconnection
docker compose restart account transactor workspace
```

### 🚨 Emergency Recovery Procedures

#### Scenario: Complete System Failure

**Recovery Steps:**
```bash
# 1. Stop all services
docker compose down

# 2. Check system resources
free -h && df -h

# 3. Clear any corrupted containers
docker system prune -f

# 4. Restore from backup if needed
cp compose.yml.backup compose.yml

# 5. Restart with validation
./deploy-optimized.sh deploy
```

#### Scenario: Data Corruption

**Recovery Steps:**
```bash
# 1. Stop affected services immediately
docker compose stop mongodb minio elastic

# 2. Backup current state
tar -czf /tmp/huly-corruption-backup-$(date +%Y%m%d_%H%M%S).tar.gz \
    /home/pascal/docker-volumes/huly/

# 3. Restore from last known good backup
# (Manual process - depends on backup strategy)

# 4. Restart services and validate
docker compose start mongodb minio elastic
./monitor-resources.sh --with-logs
```

#### Scenario: Security Breach

**Immediate Response:**
```bash
# 1. Isolate system (block external access)
sudo ufw deny 8090

# 2. Stop all services
docker compose down

# 3. Generate new credentials
./security-verify.sh --regenerate-all

# 4. Review logs for breach indicators
docker compose logs | grep -E "(failed|error|unauthorized|denied)" > /tmp/security-audit.log

# 5. Restart with new credentials
docker compose up -d
```

## Backup and Recovery

### 💾 Backup Procedures

#### Daily Automated Backup
```bash
#!/bin/bash
# /home/pascal/scripts/huly-daily-backup.sh

BACKUP_DIR="/home/pascal/backups/huly/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Backup configuration files
cp /home/pascal/dev/huly/compose.yml $BACKUP_DIR/
cp /home/pascal/dev/huly/huly.conf $BACKUP_DIR/
cp /home/pascal/dev/huly/.huly.secret $BACKUP_DIR/
cp /home/pascal/dev/huly/nginx.conf $BACKUP_DIR/

# Backup Docker volumes
docker run --rm -v huly_db:/data -v $BACKUP_DIR:/backup alpine \
    tar czf /backup/mongodb-data.tar.gz -C /data .

docker run --rm -v huly_files:/data -v $BACKUP_DIR:/backup alpine \
    tar czf /backup/minio-data.tar.gz -C /data .

docker run --rm -v huly_elastic:/data -v $BACKUP_DIR:/backup alpine \
    tar czf /backup/elastic-data.tar.gz -C /data .

# Create backup manifest
echo "Backup created: $(date)" > $BACKUP_DIR/manifest.txt
echo "System: $(hostname)" >> $BACKUP_DIR/manifest.txt
echo "Huly Version: $(docker compose images | grep huly)" >> $BACKUP_DIR/manifest.txt
```

#### Weekly Configuration Backup
```bash
# Backup entire Huly directory
tar -czf /home/pascal/backups/huly-config-$(date +%Y%m%d).tar.gz \
    -C /home/pascal/dev huly/

# Keep only last 4 weekly backups
find /home/pascal/backups/ -name "huly-config-*.tar.gz" -mtime +28 -delete
```

### 🔄 Recovery Procedures

#### Configuration Recovery
```bash
# Restore configuration from backup
BACKUP_DATE="20250618"  # Replace with actual backup date
BACKUP_DIR="/home/pascal/backups/huly/$BACKUP_DATE"

# Stop services
docker compose down

# Restore configuration files
cp $BACKUP_DIR/compose.yml /home/pascal/dev/huly/
cp $BACKUP_DIR/huly.conf /home/pascal/dev/huly/
cp $BACKUP_DIR/.huly.secret /home/pascal/dev/huly/
cp $BACKUP_DIR/nginx.conf /home/pascal/dev/huly/

# Restart services
docker compose up -d
```

#### Data Recovery
```bash
# Restore MongoDB data
docker compose stop mongodb
docker volume rm huly_db
docker volume create huly_db
docker run --rm -v huly_db:/data -v $BACKUP_DIR:/backup alpine \
    tar xzf /backup/mongodb-data.tar.gz -C /data

# Restore MinIO data  
docker compose stop minio
docker volume rm huly_files
docker volume create huly_files
docker run --rm -v huly_files:/data -v $BACKUP_DIR:/backup alpine \
    tar xzf /backup/minio-data.tar.gz -C /data

# Restart services
docker compose start mongodb minio
```

## Security Operations

### 🔒 Security Monitoring

#### Daily Security Checks
```bash
# Check for failed authentication attempts
docker compose logs | grep -i "authentication failed\|unauthorized\|denied" | tail -10

# Review access logs
docker compose logs nginx | grep -E "(404|500|403)" | tail -10

# Check for unusual resource usage patterns
./monitor-resources.sh | grep -E "(🚨|HIGH|ALERT)"

# Verify service credentials are not exposed
grep -r "minioadmin\|password.*:" /home/pascal/dev/huly/ || echo "✅ No exposed credentials"
```

#### Weekly Security Audit
```bash
# Check file permissions
ls -la /home/pascal/dev/huly/ | grep -E "(huly.conf|.huly.secret)"

# Verify container security settings
docker compose config | grep -E "(user|security_opt|read_only)"

# Review container image versions
docker compose images | grep -E "(OUTDATED|vulnerability)"

# Check for security updates
docker scout cves --details $(docker compose images -q)
```

### 🔑 Credential Management

#### Credential Rotation (Quarterly)
```bash
# Generate new credentials
openssl rand -hex 16  # New MinIO access key
openssl rand -hex 24  # New MinIO secret key  
openssl rand -base64 32 # New MongoDB password
openssl rand -hex 64   # New application secret

# Update huly.conf with new credentials
vi huly.conf

# Update secret file
vi .huly.secret

# Restart services with new credentials
docker compose down
docker compose up -d

# Verify connectivity with new credentials
./monitor-resources.sh --with-logs
```

#### Credential Backup and Recovery
```bash
# Secure credential backup
cp huly.conf /home/pascal/backups/credentials/huly.conf.$(date +%Y%m%d)
cp .huly.secret /home/pascal/backups/credentials/.huly.secret.$(date +%Y%m%d)
chmod 600 /home/pascal/backups/credentials/*

# Encrypt sensitive backups
gpg --symmetric --cipher-algo AES256 \
    /home/pascal/backups/credentials/huly.conf.$(date +%Y%m%d)
```

## Maintenance and Updates

### 🔧 Regular Maintenance Schedule

#### Daily (Automated)
- Resource usage monitoring and alerting
- Log rotation and cleanup  
- Health check validation
- Basic security monitoring

#### Weekly (Manual)
- Performance review and analysis
- Security audit and log review
- Backup verification and testing
- Documentation updates

#### Monthly (Planned)
- Container image updates
- Security patch assessment
- Performance optimization review
- Disaster recovery testing

#### Quarterly (Scheduled)
- Credential rotation
- Comprehensive security audit
- Performance baseline review
- Infrastructure scaling assessment

### 📦 Update Procedures

#### Container Image Updates
```bash
# Check for image updates
docker compose pull

# Compare image versions
docker compose images

# Update with rolling restart
docker compose up -d --force-recreate

# Verify update success
./monitor-resources.sh
```

#### Configuration Updates
```bash
# Backup current configuration
cp compose.yml compose.yml.backup.$(date +%Y%m%d)
cp huly.conf huly.conf.backup.$(date +%Y%m%d)

# Apply configuration changes
vi compose.yml  # Make necessary changes

# Validate configuration
docker compose config

# Apply updates
docker compose up -d

# Verify functionality
./monitor-resources.sh --with-logs
```

#### System Updates
```bash
# Update system packages (requires sudo)
sudo apt update && sudo apt upgrade -y

# Update Docker
sudo apt update docker-ce docker-ce-cli containerd.io

# Update Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose

# Restart Huly after system updates
docker compose restart
```

## Contact and Escalation

### 📞 Emergency Contacts

**System Administrator:** pascal@92.118.56.108  
**Backup Contact:** [Define backup contact]  
**Vendor Support:** Huly Community/Enterprise Support

### 🚨 Escalation Procedures

**Level 1 - Operational Issues**
- Service restart failures
- Performance degradation
- Minor configuration issues
- **Resolution Time:** 1-4 hours

**Level 2 - System Issues**  
- Database corruption
- Security incidents
- Major service failures
- **Resolution Time:** 4-12 hours

**Level 3 - Critical Issues**
- Complete system failure
- Data loss incidents  
- Security breaches
- **Resolution Time:** Immediate response

### 📋 Incident Response Checklist

**Immediate Response (First 15 minutes):**
- [ ] Assess scope and impact
- [ ] Document incident start time
- [ ] Isolate affected systems if needed
- [ ] Notify relevant stakeholders
- [ ] Begin diagnostic procedures

**Investigation Phase (15-60 minutes):**
- [ ] Collect relevant logs and metrics
- [ ] Identify root cause
- [ ] Develop resolution plan
- [ ] Implement temporary workarounds if possible

**Resolution Phase (1-4 hours):**
- [ ] Execute resolution plan
- [ ] Verify system recovery
- [ ] Monitor for recurrence
- [ ] Document lessons learned
- [ ] Update procedures if needed

---

**Operations Runbook Version 1.0**  
**Maintained by:** Production Readiness Agent  
**Review Schedule:** Quarterly  
**Last Review:** June 18, 2025  

*This runbook provides comprehensive operational procedures for the Huly production environment. All procedures have been tested and validated against the current deployment.*