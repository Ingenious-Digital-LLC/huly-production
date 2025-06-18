# Huly Disaster Recovery and Risk Mitigation Plan

**Version:** 1.0  
**Last Updated:** June 18, 2025  
**System:** Huly Production Environment  
**Recovery Time Objective (RTO):** 2 hours  
**Recovery Point Objective (RPO):** 24 hours

## Executive Summary

This document outlines comprehensive disaster recovery procedures and risk mitigation strategies for the Huly production environment. The plan addresses various failure scenarios, from individual service failures to complete system disasters, ensuring business continuity and minimal data loss.

## Risk Assessment Matrix

### High-Probability, High-Impact Risks

| Risk | Probability | Impact | Mitigation Strategy | Response Time |
|------|-------------|--------|-------------------|---------------|
| **Service Container Failure** | High | Medium | Auto-restart policies, health checks | 1-5 minutes |
| **Database Connection Issues** | Medium | High | Connection pooling, retry logic | 5-15 minutes |
| **Resource Exhaustion** | Medium | High | Resource limits, monitoring alerts | 15-30 minutes |
| **Configuration Corruption** | Low | High | Configuration backups, validation | 30-60 minutes |

### Medium-Probability, High-Impact Risks

| Risk | Probability | Impact | Mitigation Strategy | Response Time |
|------|-------------|--------|-------------------|---------------|
| **Database Corruption** | Low | Very High | Daily backups, RAID storage | 1-4 hours |
| **Security Breach** | Low | Very High | Secure credentials, access monitoring | 15 minutes |
| **Hardware Failure** | Low | High | Cloud deployment, redundancy | 2-24 hours |
| **Network Outage** | Medium | Medium | Multiple connectivity paths | 1-2 hours |

### Low-Probability, Very High-Impact Risks

| Risk | Probability | Impact | Mitigation Strategy | Response Time |
|------|-------------|--------|-------------------|---------------|
| **Complete Data Loss** | Very Low | Catastrophic | Off-site backups, versioning | 4-8 hours |
| **Ransomware Attack** | Low | Very High | Isolated backups, security hardening | 2-4 hours |
| **Natural Disaster** | Very Low | Catastrophic | Geographic distribution | 24-48 hours |

## Service-Level Recovery Procedures

### 🔧 Individual Service Recovery

#### MongoDB Recovery
```bash
# Scenario: MongoDB container failure
# Symptoms: Application unable to connect to database

# 1. Immediate Assessment
docker compose logs mongodb --tail=50
docker compose ps | grep mongodb

# 2. Quick Recovery Attempt
docker compose restart mongodb

# 3. Wait for health check (up to 2 minutes)
watch 'docker compose ps | grep mongodb'

# 4. If restart fails, check resources
docker stats mongodb --no-stream
free -h

# 5. If resource issue, clear cache and restart
sync && echo 3 > /proc/sys/vm/drop_caches
docker compose restart mongodb

# 6. Verify connectivity
docker compose exec mongodb mongosh --eval "db.adminCommand('ping')"

# Recovery Time: 2-5 minutes
# Data Loss: None (persistent volumes)
```

#### MinIO Recovery
```bash
# Scenario: MinIO service failure
# Symptoms: File upload/download failures

# 1. Check service status
docker compose logs minio --tail=50
docker compose ps | grep minio

# 2. Restart service
docker compose restart minio

# 3. Verify health
docker compose exec minio mc ready local

# 4. Test bucket access
docker compose exec minio mc ls local/

# 5. If data corruption suspected
docker compose stop minio
docker volume inspect huly_files
# Restore from backup if needed

# Recovery Time: 1-3 minutes
# Data Loss: None (persistent volumes)
```

#### Elasticsearch Recovery
```bash
# Scenario: Elasticsearch service failure
# Symptoms: Search functionality not working

# 1. Check cluster status
docker compose logs elastic --tail=50
curl -s http://localhost:9200/_cluster/health

# 2. Restart if unhealthy
docker compose restart elastic

# 3. Wait for cluster recovery (may take 2-5 minutes)
watch 'curl -s http://localhost:9200/_cluster/health | jq .status'

# 4. If persistent issues, check JVM heap
docker stats elastic --no-stream

# 5. Adjust heap size if needed (in compose.yml)
# ES_JAVA_OPTS: -Xms512m -Xmx1536m

# Recovery Time: 3-10 minutes
# Data Loss: None (persistent volumes)
```

#### Application Service Recovery
```bash
# Scenario: Front/Account/Transactor service failure
# Symptoms: Specific functionality not working

# 1. Identify failed service
docker compose ps | grep unhealthy

# 2. Check service logs
docker compose logs [service] --tail=50

# 3. Restart specific service
docker compose restart [service]

# 4. Monitor health check recovery
watch 'docker compose ps | grep [service]'

# 5. If persistent failure, check dependencies
docker compose logs mongodb minio elastic --tail=20

# Recovery Time: 1-3 minutes
# Data Loss: None
```

### 🔄 Multi-Service Recovery

#### Database Cluster Recovery
```bash
# Scenario: All database services failing
# Symptoms: Complete application failure

# 1. Stop all application services
docker compose stop front account transactor workspace collaborator fulltext rekoni stats

# 2. Focus on database recovery
docker compose restart mongodb minio elastic

# 3. Wait for database stability (5-10 minutes)
while ! docker compose exec mongodb mongosh --eval "db.adminCommand('ping')" &>/dev/null; do
    echo "Waiting for MongoDB..."
    sleep 10
done

while ! docker compose exec minio mc ready local &>/dev/null; do
    echo "Waiting for MinIO..."
    sleep 10
done

# 4. Restart application services one by one
docker compose start transactor  # Core service first
sleep 30
docker compose start account workspace
sleep 30
docker compose start front collaborator fulltext rekoni stats

# Recovery Time: 10-20 minutes
# Data Loss: None if volumes intact
```

#### Complete Stack Recovery
```bash
# Scenario: All services failing
# Symptoms: Complete system unavailability

# 1. Stop everything
docker compose down

# 2. Check system resources
free -h && df -h
docker system df

# 3. Clean up if needed
docker system prune -f

# 4. Check configuration integrity
docker compose config

# 5. Start infrastructure services first
docker compose up -d mongodb minio elastic

# 6. Wait for infrastructure stability
sleep 300  # 5 minutes

# 7. Start application services
docker compose up -d

# 8. Monitor recovery
./monitor-resources.sh --watch

# Recovery Time: 15-30 minutes
# Data Loss: None if volumes intact
```

## Data Recovery Procedures

### 📂 Backup Recovery

#### Configuration Recovery
```bash
# Scenario: Configuration files corrupted
# Symptoms: Services failing to start with config errors

# 1. Stop all services
docker compose down

# 2. Identify latest good backup
ls -la /home/pascal/backups/huly/ | grep $(date +%Y%m%d)

# 3. Restore configuration files
BACKUP_DATE="20250618"  # Use actual backup date
cp /home/pascal/backups/huly/$BACKUP_DATE/compose.yml ./
cp /home/pascal/backups/huly/$BACKUP_DATE/huly.conf ./
cp /home/pascal/backups/huly/$BACKUP_DATE/.huly.secret ./
cp /home/pascal/backups/huly/$BACKUP_DATE/nginx.conf ./

# 4. Validate configuration
docker compose config

# 5. Restart services
docker compose up -d

# Recovery Time: 5-15 minutes
# Data Loss: Configuration changes since backup
```

#### Database Data Recovery
```bash
# Scenario: Database corruption or data loss
# Symptoms: Data inconsistency or missing data

# 1. Stop affected database service
docker compose stop mongodb  # or minio/elastic

# 2. Backup current state (even if corrupted)
docker run --rm -v huly_db:/data -v $(pwd):/backup alpine \
    tar czf /backup/corrupted-db-$(date +%Y%m%d_%H%M%S).tar.gz -C /data .

# 3. Remove corrupted volume
docker volume rm huly_db

# 4. Create new volume
docker volume create huly_db

# 5. Restore from backup
BACKUP_DATE="20250618"  # Use latest good backup
docker run --rm -v huly_db:/data \
    -v /home/pascal/backups/huly/$BACKUP_DATE:/backup alpine \
    tar xzf /backup/mongodb-data.tar.gz -C /data

# 6. Start service
docker compose start mongodb

# 7. Verify data integrity
docker compose exec mongodb mongosh --eval "db.adminCommand('ping')"

# Recovery Time: 30-60 minutes
# Data Loss: Up to 24 hours (since last backup)
```

### 🔄 Point-in-Time Recovery

#### MongoDB Point-in-Time Recovery
```bash
# Scenario: Need to recover to specific point in time
# Note: Requires MongoDB replica set (future enhancement)

# Current capability: Daily backup recovery
# Future enhancement: Enable MongoDB oplog for point-in-time recovery

# 1. Identify recovery point
ls -la /home/pascal/backups/huly/

# 2. Stop MongoDB
docker compose stop mongodb

# 3. Restore to closest backup before desired time
# (Follow database data recovery procedure above)

# Recovery Time: 30-60 minutes
# Data Loss: Up to 24 hours
```

#### MinIO Object Recovery
```bash
# Scenario: Accidental file deletion or corruption
# Note: MinIO versioning not currently enabled

# Current capability: Full backup restore
# Future enhancement: Enable MinIO versioning

# 1. Stop MinIO
docker compose stop minio

# 2. Restore full bucket from backup
# (Follow database data recovery procedure for MinIO)

# Recovery Time: 15-45 minutes
# Data Loss: Files created/modified since backup
```

## Security Incident Response

### 🚨 Security Breach Response

#### Immediate Response (0-15 minutes)
```bash
# 1. Isolate system
sudo ufw deny 8090  # Block external access
docker network disconnect bridge huly-nginx-1  # Isolate if needed

# 2. Stop all services
docker compose down

# 3. Capture evidence
docker compose logs > /tmp/security-incident-$(date +%Y%m%d_%H%M%S).log
cp -r /home/pascal/dev/huly /tmp/huly-evidence-$(date +%Y%m%d_%H%M%S)

# 4. Analyze compromise indicators
grep -E "(failed|unauthorized|denied|error)" /tmp/security-incident-*.log

# 5. Assess scope
docker volume ls | grep huly  # Check if data volumes compromised
```

#### Credential Compromise Response (15-60 minutes)
```bash
# 1. Generate new credentials immediately
./security-verify.sh --regenerate-all

# 2. Update all configuration files
vi huly.conf  # Update with new credentials
vi .huly.secret  # Update application secret

# 3. Rebuild containers with new credentials
docker compose down
docker compose up -d

# 4. Verify new credentials working
./monitor-resources.sh --with-logs

# 5. Monitor for continued breach attempts
tail -f /var/log/auth.log | grep -E "(failed|denied)"
```

#### Data Integrity Validation (1-4 hours)
```bash
# 1. Check database integrity
docker compose exec mongodb mongosh --eval "
    db.runCommand({dbStats: 1});
    db.adminCommand('validate', 'collection_name');
"

# 2. Verify file integrity
docker compose exec minio mc ls -r local/huly/

# 3. Check for unauthorized changes
diff -r /home/pascal/backups/huly/$(date +%Y%m%d) /home/pascal/dev/huly/

# 4. Validate user data
# (Application-specific validation procedures)

# 5. Document incident
echo "Security incident: $(date)" >> /var/log/huly-incidents.log
```

## System-Level Disaster Recovery

### 💥 Complete System Failure

#### Hardware/OS Failure Recovery
```bash
# Scenario: Complete server failure, new hardware/OS

# 1. Install base system (Ubuntu 24.04)
# 2. Install Docker and Docker Compose
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
sudo usermod -aG docker $USER

# 3. Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 4. Restore Huly directory
mkdir -p /home/pascal/dev
cd /home/pascal/dev
tar -xzf /backup/huly-config-YYYYMMDD.tar.gz

# 5. Restore Docker volumes
docker volume create huly_db
docker volume create huly_files  
docker volume create huly_elastic

# 6. Restore data from backups
docker run --rm -v huly_db:/data -v /backup:/backup alpine \
    tar xzf /backup/mongodb-data.tar.gz -C /data
docker run --rm -v huly_files:/data -v /backup:/backup alpine \
    tar xzf /backup/minio-data.tar.gz -C /data
docker run --rm -v huly_elastic:/data -v /backup:/backup alpine \
    tar xzf /backup/elastic-data.tar.gz -C /data

# 7. Start services
cd /home/pascal/dev/huly
docker compose up -d

# Recovery Time: 2-4 hours
# Data Loss: Up to 24 hours
```

#### Migration to New Server
```bash
# Scenario: Planned migration to new hardware

# Phase 1: Prepare new server (parallel to production)
# - Install OS and Docker
# - Configure network and firewall
# - Create user accounts and permissions

# Phase 2: Data migration
# 1. Create final backup on old server
cd /home/pascal/dev/huly
./backup-script.sh --full

# 2. Stop services (planned downtime begins)
docker compose down

# 3. Transfer backup to new server
rsync -avz /home/pascal/backups/ new-server:/home/pascal/backups/
rsync -avz /home/pascal/dev/huly/ new-server:/home/pascal/dev/huly/

# 4. Start services on new server
ssh new-server "cd /home/pascal/dev/huly && docker compose up -d"

# 5. Update DNS/load balancer to point to new server
# 6. Verify functionality on new server
# 7. Decommission old server

# Recovery Time: 1-2 hours (planned downtime)
# Data Loss: None (planned migration)
```

### 🌊 Natural Disaster Recovery

#### Geographic Disaster Response
```bash
# Scenario: Regional outage affecting primary data center

# Current limitation: Single-site deployment
# Recommended enhancement: Multi-region deployment

# Immediate response (if backup site available):
# 1. Activate backup site
# 2. Restore from latest off-site backup
# 3. Update DNS to point to backup site
# 4. Notify users of service restoration

# Current recovery procedure:
# 1. Establish new infrastructure in different region
# 2. Follow complete system failure recovery
# 3. Restore from latest off-site backup

# Recovery Time: 4-24 hours (depending on backup location)
# Data Loss: Up to 24 hours
```

## Monitoring and Alerting for DR

### 🔔 Automated Alert Configuration

#### Critical System Alerts
```bash
# Memory usage alert (>85%)
* * * * * /home/pascal/scripts/memory-alert.sh

# Disk space alert (>90%)
0 * * * * /home/pascal/scripts/disk-alert.sh

# Service health alert
*/5 * * * * /home/pascal/scripts/health-alert.sh

# Database connectivity alert
*/10 * * * * /home/pascal/scripts/db-connectivity-alert.sh
```

#### Backup Validation Alerts
```bash
# Daily backup verification
0 3 * * * /home/pascal/scripts/backup-verify.sh

# Weekly backup restore test
0 4 * * 0 /home/pascal/scripts/backup-restore-test.sh

# Monthly disaster recovery drill
0 6 1 * * /home/pascal/scripts/dr-drill.sh
```

### 📊 Recovery Metrics Tracking

#### Key Metrics to Monitor
- **Recovery Time Actual (RTA):** Time to restore service
- **Recovery Point Actual (RPA):** Amount of data lost
- **Mean Time to Recovery (MTTR):** Average recovery time
- **Service Availability:** Percentage uptime
- **Backup Success Rate:** Percentage of successful backups

#### Monthly DR Report Template
```bash
# Generate monthly DR metrics report
cat > /var/log/huly-dr-report-$(date +%Y%m).txt << EOF
Huly Disaster Recovery Report - $(date +"%B %Y")

Service Availability: XX.XX%
Number of Incidents: X
Average Recovery Time: XX minutes
Backup Success Rate: XX.XX%
Data Loss Events: X

Incidents This Month:
- Date: Description, RTO: XX min, RPO: XX hours

Backup Statistics:
- Daily backups: XX/XX successful
- Weekly backups: XX/XX successful
- Restore tests: XX/XX successful

Recommendations:
- [List any improvements needed]

Next DR drill scheduled: [Date]
EOF
```

## Testing and Validation

### 🧪 Disaster Recovery Drills

#### Monthly Service Recovery Drill
```bash
#!/bin/bash
# /home/pascal/scripts/dr-drill-service.sh

echo "Starting monthly service recovery drill: $(date)"

# Simulate MongoDB failure
docker compose stop mongodb
echo "MongoDB stopped at $(date)"

# Wait 30 seconds
sleep 30

# Recover MongoDB
docker compose start mongodb
echo "MongoDB recovery initiated at $(date)"

# Monitor recovery
start_time=$(date +%s)
while ! docker compose exec mongodb mongosh --eval "db.adminCommand('ping')" &>/dev/null; do
    sleep 5
done
end_time=$(date +%s)
recovery_time=$((end_time - start_time))

echo "MongoDB recovery completed in ${recovery_time} seconds"
echo "Drill completed: $(date)"
```

#### Quarterly Full Recovery Drill
```bash
#!/bin/bash
# /home/pascal/scripts/dr-drill-full.sh

echo "Starting quarterly full recovery drill: $(date)"

# Create test environment backup
docker compose down
cp -r /home/pascal/dev/huly /home/pascal/dev/huly-drill-backup

# Simulate complete failure
docker volume rm huly_db huly_files huly_elastic
rm -f compose.yml huly.conf .huly.secret nginx.conf

# Test recovery procedures
# (Follow complete system recovery procedure)

# Restore original environment
docker compose down
rm -rf /home/pascal/dev/huly
mv /home/pascal/dev/huly-drill-backup /home/pascal/dev/huly
docker compose up -d

echo "Full recovery drill completed: $(date)"
```

### ✅ Recovery Validation Checklist

#### Post-Recovery Validation
- [ ] **All Services Running:** All containers in healthy state
- [ ] **Database Connectivity:** All databases responding correctly
- [ ] **Frontend Accessible:** UI loading and responsive
- [ ] **User Authentication:** Login functionality working
- [ ] **Data Integrity:** Sample data validation successful
- [ ] **Performance Acceptable:** Response times within normal range
- [ ] **Monitoring Active:** All monitoring and alerting functional
- [ ] **Backup Processes:** Automated backups functioning

#### Recovery Documentation
```bash
# Document recovery event
cat >> /var/log/huly-recovery.log << EOF
Recovery Event: $(date)
Incident Type: [Type]
Start Time: [Time]
End Time: [Time]
Recovery Time: [Duration]
Data Loss: [Amount]
Root Cause: [Cause]
Actions Taken: [Actions]
Lessons Learned: [Lessons]
Follow-up Required: [Actions]
EOF
```

## Contact Information and Escalation

### 🆘 Emergency Response Team

#### Primary Contacts
- **System Administrator:** pascal@92.118.56.108
- **Technical Lead:** Production Readiness Agent  
- **Backup Administrator:** [Define based on organization]

#### Escalation Matrix
| Severity | Response Time | Contact Level |
|----------|---------------|---------------|
| **P1 - Critical** | 15 minutes | All team members |
| **P2 - High** | 1 hour | System admin + tech lead |
| **P3 - Medium** | 4 hours | System admin |
| **P4 - Low** | 24 hours | Standard support |

#### 24/7 Emergency Procedures
1. **Immediate Response:** System administrator (primary)
2. **Escalation Path:** Technical lead → Management → Vendor support
3. **Communication:** Status updates every 30 minutes during P1 incidents
4. **Documentation:** All actions logged in incident tracking system

---

**Disaster Recovery Plan Version 1.0**  
**Maintained by:** Production Readiness Agent  
**Review Schedule:** Quarterly  
**Last Tested:** [Date of last DR drill]  
**Next Review:** September 18, 2025

*This disaster recovery plan provides comprehensive procedures for recovering from various failure scenarios. All procedures should be tested regularly and updated based on operational experience.*