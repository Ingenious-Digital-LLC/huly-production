#!/bin/bash

# Database Health Monitor - Continuous monitoring script
# Run with: ./database-health-monitor.sh [interval_seconds]

INTERVAL=${1:-30}  # Default 30 seconds
LOG_FILE="/home/pascal/dev/huly/database-health.log"

echo "=== DATABASE HEALTH MONITOR ==="
echo "Monitoring interval: ${INTERVAL} seconds"
echo "Log file: ${LOG_FILE}"
echo "Press Ctrl+C to stop"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

check_database_health() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Check MongoDB
    if docker exec huly-mongodb-1 mongosh --eval "db.adminCommand('ping')" --quiet >/dev/null 2>&1; then
        MONGO_STATUS="HEALTHY"
        MONGO_CONNECTIONS=$(docker exec huly-mongodb-1 mongosh -u admin -p hulypassword --authenticationDatabase admin --eval "db.serverStatus().connections.current" --quiet 2>/dev/null)
    else
        MONGO_STATUS="UNHEALTHY"
        MONGO_CONNECTIONS="0"
    fi
    
    # Check MinIO
    if docker exec huly-minio-1 curl -s http://localhost:9000/minio/health/live >/dev/null 2>&1; then
        MINIO_STATUS="HEALTHY"
    else
        MINIO_STATUS="UNHEALTHY"
    fi
    
    # Check Elasticsearch
    ELASTIC_HEALTH=$(docker exec huly-elastic-1 curl -s http://localhost:9200/_cluster/health | jq -r '.status' 2>/dev/null)
    if [ "$ELASTIC_HEALTH" = "green" ] || [ "$ELASTIC_HEALTH" = "yellow" ]; then
        ELASTIC_STATUS="HEALTHY ($ELASTIC_HEALTH)"
    else
        ELASTIC_STATUS="UNHEALTHY"
    fi
    
    # Check application services
    HEALTHY_SERVICES=$(docker-compose ps | grep healthy | wc -l)
    TOTAL_SERVICES=$(docker-compose ps | grep -v "NAME" | wc -l)
    
    # Log status
    log_message "MongoDB: $MONGO_STATUS (${MONGO_CONNECTIONS} connections) | MinIO: $MINIO_STATUS | Elasticsearch: $ELASTIC_STATUS | Services: ${HEALTHY_SERVICES}/${TOTAL_SERVICES}"
    
    # Display status with colors
    echo -n "$timestamp - "
    
    if [ "$MONGO_STATUS" = "HEALTHY" ]; then
        echo -ne "${GREEN}MongoDB: OK${NC} "
    else
        echo -ne "${RED}MongoDB: FAIL${NC} "
    fi
    
    if [ "$MINIO_STATUS" = "HEALTHY" ]; then
        echo -ne "${GREEN}MinIO: OK${NC} "
    else
        echo -ne "${RED}MinIO: FAIL${NC} "
    fi
    
    if [[ "$ELASTIC_STATUS" =~ HEALTHY ]]; then
        echo -ne "${GREEN}Elasticsearch: OK${NC} "
    else
        echo -ne "${RED}Elasticsearch: FAIL${NC} "
    fi
    
    echo "Services: ${HEALTHY_SERVICES}/${TOTAL_SERVICES}"
    
    # Alert if any database is unhealthy
    if [ "$MONGO_STATUS" != "HEALTHY" ] || [ "$MINIO_STATUS" != "HEALTHY" ] || [[ ! "$ELASTIC_STATUS" =~ HEALTHY ]]; then
        log_message "⚠️  ALERT: Database health issue detected!"
        echo -e "${RED}⚠️  ALERT: Database health issue detected!${NC}"
    fi
}

# Initialize log file
echo "# Database Health Monitor Log" > "$LOG_FILE"
log_message "Database health monitoring started"

# Main monitoring loop
while true; do
    check_database_health
    sleep "$INTERVAL"
done