#!/bin/bash

echo "=== DATABASE CONNECTION HEALER - COMPREHENSIVE HEALTH CHECK ==="
echo "Timestamp: $(date)"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test MongoDB
echo "=== MONGODB CONNECTIVITY TEST ==="
echo -n "MongoDB Ping: "
if docker exec huly-mongodb-1 mongosh --eval "db.adminCommand('ping')" --quiet >/dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

echo -n "MongoDB Authentication: "
if docker exec huly-mongodb-1 mongosh -u admin -p hulypassword --authenticationDatabase admin --eval "db.runCommand({listCollections: 1})" --quiet >/dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

echo "MongoDB Connections:"
docker exec huly-mongodb-1 mongosh -u admin -p hulypassword --authenticationDatabase admin --eval "db.serverStatus().connections" --quiet 2>/dev/null || echo -e "${RED}Failed to get connection stats${NC}"
echo

# Test MinIO
echo "=== MINIO CONNECTIVITY TEST ==="
echo -n "MinIO Health Check: "
if docker exec huly-minio-1 curl -s http://localhost:9000/minio/health/live >/dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

echo -n "MinIO Admin Access: "
if docker exec huly-minio-1 mc alias set testminio http://localhost:9000 hulyuser hulysecretkey123 >/dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi
echo

# Test Elasticsearch
echo "=== ELASTICSEARCH CONNECTIVITY TEST ==="
echo -n "Elasticsearch Health: "
ELASTIC_HEALTH=$(docker exec huly-elastic-1 curl -s http://localhost:9200/_cluster/health | jq -r '.status' 2>/dev/null)
if [ "$ELASTIC_HEALTH" = "green" ] || [ "$ELASTIC_HEALTH" = "yellow" ]; then
    echo -e "${GREEN}PASS (${ELASTIC_HEALTH})${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

echo "Elasticsearch Cluster Status:"
docker exec huly-elastic-1 curl -s http://localhost:9200/_cluster/health 2>/dev/null | jq '.' 2>/dev/null || echo -e "${RED}Failed to get cluster status${NC}"
echo

# Test Application Service Database Connectivity
echo "=== APPLICATION SERVICES DATABASE CONNECTIVITY ==="

services=("account" "transactor" "front" "fulltext" "workspace")
for service in "${services[@]}"; do
    echo -n "Service $service database connectivity: "
    
    # Check if service is running and healthy
    if docker-compose ps | grep "huly-${service}-1" | grep "healthy" >/dev/null 2>&1; then
        echo -e "${GREEN}SERVICE HEALTHY${NC}"
        
        # Test MongoDB connection from the service
        if docker exec "huly-${service}-1" nslookup mongodb >/dev/null 2>&1; then
            echo "  - MongoDB DNS resolution: ${GREEN}PASS${NC}"
        else
            echo "  - MongoDB DNS resolution: ${RED}FAIL${NC}"
        fi
        
        # Test MinIO connection from the service
        if docker exec "huly-${service}-1" nslookup minio >/dev/null 2>&1; then
            echo "  - MinIO DNS resolution: ${GREEN}PASS${NC}"
        else
            echo "  - MinIO DNS resolution: ${RED}FAIL${NC}"
        fi
        
    else
        echo -e "${RED}SERVICE UNHEALTHY${NC}"
    fi
    echo
done

# Overall Service Status
echo "=== OVERALL SERVICE STATUS ==="
docker-compose ps

echo
echo "=== DATABASE HEALING SUMMARY ==="
MONGO_STATUS=$(docker-compose ps | grep mongodb | grep healthy >/dev/null && echo "HEALTHY" || echo "UNHEALTHY")
MINIO_STATUS=$(docker-compose ps | grep minio | grep healthy >/dev/null && echo "HEALTHY" || echo "UNHEALTHY")
ELASTIC_STATUS=$(docker-compose ps | grep elastic | grep healthy >/dev/null && echo "HEALTHY" || echo "UNHEALTHY")

echo "MongoDB: $MONGO_STATUS"
echo "MinIO: $MINIO_STATUS" 
echo "Elasticsearch: $ELASTIC_STATUS"

HEALTHY_SERVICES=$(docker-compose ps | grep healthy | wc -l)
TOTAL_SERVICES=$(docker-compose ps | grep -v "NAME" | wc -l)
echo "Application Services: $HEALTHY_SERVICES/$TOTAL_SERVICES healthy"

if [ "$MONGO_STATUS" = "HEALTHY" ] && [ "$MINIO_STATUS" = "HEALTHY" ] && [ "$ELASTIC_STATUS" = "HEALTHY" ]; then
    echo -e "${GREEN}DATABASE HEALING: COMPLETE SUCCESS${NC}"
else
    echo -e "${YELLOW}DATABASE HEALING: PARTIAL SUCCESS${NC}"
fi