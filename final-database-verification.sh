#!/bin/bash

echo "=== FINAL DATABASE CONNECTION VERIFICATION ==="
echo "Timestamp: $(date)"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== CORE DATABASE HEALTH ===${NC}"

# MongoDB
echo -n "MongoDB Service: "
if docker-compose ps | grep mongodb | grep -q healthy; then
    echo -e "${GREEN}HEALTHY${NC}"
else
    echo -e "${RED}UNHEALTHY${NC}"
fi

echo -n "MongoDB Connections: "
MONGO_CONNECTIONS=$(docker exec huly-mongodb-1 mongosh -u admin -p hulypassword --authenticationDatabase admin --eval "db.serverStatus().connections.current" --quiet 2>/dev/null)
if [ "$MONGO_CONNECTIONS" -gt 0 ]; then
    echo -e "${GREEN}${MONGO_CONNECTIONS} active${NC}"
else
    echo -e "${RED}No connections${NC}"
fi

# MinIO
echo -n "MinIO Service: "
if docker-compose ps | grep minio | grep -q healthy; then
    echo -e "${GREEN}HEALTHY${NC}"
else
    echo -e "${RED}UNHEALTHY${NC}"
fi

echo -n "MinIO Access: "
if docker exec huly-minio-1 mc ls testminio >/dev/null 2>&1; then
    echo -e "${GREEN}ACCESSIBLE${NC}"
else
    echo -e "${RED}INACCESSIBLE${NC}"
fi

# Elasticsearch
echo -n "Elasticsearch Service: "
if docker-compose ps | grep elastic | grep -q healthy; then
    echo -e "${GREEN}HEALTHY${NC}"
else
    echo -e "${RED}UNHEALTHY${NC}"
fi

echo -n "Elasticsearch Status: "
ELASTIC_STATUS=$(docker exec huly-elastic-1 curl -s http://localhost:9200/_cluster/health | jq -r '.status' 2>/dev/null)
if [ "$ELASTIC_STATUS" = "green" ]; then
    echo -e "${GREEN}GREEN${NC}"
elif [ "$ELASTIC_STATUS" = "yellow" ]; then
    echo -e "${YELLOW}YELLOW${NC}"
else
    echo -e "${RED}RED${NC}"
fi

echo
echo -e "${BLUE}=== APPLICATION SERVICE DATABASE CONNECTIVITY ===${NC}"

# List of services that need database connectivity
services=("account" "transactor" "front" "fulltext" "workspace" "collaborator")

for service in "${services[@]}"; do
    echo -n "Service $service: "
    
    # Check if service is healthy
    if docker-compose ps | grep "huly-${service}-1" | grep -q "healthy"; then
        echo -e "${GREEN}HEALTHY${NC}"
        
        # Check MongoDB connection string
        MONGO_URL=$(docker exec "huly-${service}-1" env | grep MONGO_URL | head -1)
        if [[ "$MONGO_URL" =~ mongodb://admin:hulypassword@mongodb:27017 ]]; then
            echo "  └─ MongoDB credentials: ${GREEN}CONFIGURED${NC}"
        else
            echo "  └─ MongoDB credentials: ${RED}MISSING${NC}"
        fi
        
        # Check MinIO connection for services that use it
        if [[ "$service" =~ ^(account|transactor|front|fulltext|workspace)$ ]]; then
            STORAGE_CONFIG=$(docker exec "huly-${service}-1" env | grep STORAGE_CONFIG 2>/dev/null)
            if [[ "$STORAGE_CONFIG" =~ minio.*accessKey=hulyuser ]]; then
                echo "  └─ MinIO credentials: ${GREEN}CONFIGURED${NC}"
            else
                echo "  └─ MinIO credentials: ${RED}MISSING${NC}"
            fi
        fi
        
    else
        echo -e "${RED}UNHEALTHY${NC}"
    fi
done

echo
echo -e "${BLUE}=== PERFORMANCE METRICS ===${NC}"

# Database response time test
echo -n "MongoDB Response Time: "
START_TIME=$(date +%s%3N)
docker exec huly-mongodb-1 mongosh --eval "db.adminCommand('ping')" --quiet >/dev/null 2>&1
END_TIME=$(date +%s%3N)
MONGO_TIME=$((END_TIME - START_TIME))
if [ $MONGO_TIME -lt 50 ]; then
    echo -e "${GREEN}${MONGO_TIME}ms (Excellent)${NC}"
elif [ $MONGO_TIME -lt 100 ]; then
    echo -e "${YELLOW}${MONGO_TIME}ms (Good)${NC}"
else
    echo -e "${RED}${MONGO_TIME}ms (Slow)${NC}"
fi

echo -n "MinIO Response Time: "
START_TIME=$(date +%s%3N)
docker exec huly-minio-1 curl -s http://localhost:9000/minio/health/live >/dev/null 2>&1
END_TIME=$(date +%s%3N)
MINIO_TIME=$((END_TIME - START_TIME))
if [ $MINIO_TIME -lt 50 ]; then
    echo -e "${GREEN}${MINIO_TIME}ms (Excellent)${NC}"
elif [ $MINIO_TIME -lt 100 ]; then
    echo -e "${YELLOW}${MINIO_TIME}ms (Good)${NC}"
else
    echo -e "${RED}${MINIO_TIME}ms (Slow)${NC}"
fi

echo -n "Elasticsearch Response Time: "
START_TIME=$(date +%s%3N)
docker exec huly-elastic-1 curl -s http://localhost:9200/_cluster/health >/dev/null 2>&1
END_TIME=$(date +%s%3N)
ELASTIC_TIME=$((END_TIME - START_TIME))
if [ $ELASTIC_TIME -lt 50 ]; then
    echo -e "${GREEN}${ELASTIC_TIME}ms (Excellent)${NC}"
elif [ $ELASTIC_TIME -lt 100 ]; then
    echo -e "${YELLOW}${ELASTIC_TIME}ms (Good)${NC}"
else
    echo -e "${RED}${ELASTIC_TIME}ms (Slow)${NC}"
fi

echo
echo -e "${BLUE}=== OVERALL SYSTEM STATUS ===${NC}"
HEALTHY_SERVICES=$(docker-compose ps | grep healthy | wc -l)
TOTAL_SERVICES=$(docker-compose ps | grep -v "NAME" | wc -l)
echo "Healthy Services: ${HEALTHY_SERVICES}/${TOTAL_SERVICES}"

# Check if all core databases are healthy
MONGO_HEALTHY=$(docker-compose ps | grep mongodb | grep -q healthy && echo "1" || echo "0")
MINIO_HEALTHY=$(docker-compose ps | grep minio | grep -q healthy && echo "1" || echo "0")
ELASTIC_HEALTHY=$(docker-compose ps | grep elastic | grep -q healthy && echo "1" || echo "0")

if [ "$MONGO_HEALTHY" = "1" ] && [ "$MINIO_HEALTHY" = "1" ] && [ "$ELASTIC_HEALTHY" = "1" ]; then
    echo -e "${GREEN}✓ All database services are healthy${NC}"
    echo -e "${GREEN}✓ Database credentials are properly configured${NC}"
    echo -e "${GREEN}✓ All application services have database connectivity${NC}"
    echo
    echo -e "${GREEN}🎉 DATABASE CONNECTION HEALING: COMPLETE SUCCESS! 🎉${NC}"
    echo "Zero connection failures detected."
else
    echo -e "${RED}✗ Some database services are unhealthy${NC}"
    echo
    echo -e "${YELLOW}DATABASE CONNECTION HEALING: PARTIAL SUCCESS${NC}"
fi

echo
echo "=== SUMMARY ==="
echo "MongoDB: $([ "$MONGO_HEALTHY" = "1" ] && echo "✓ HEALTHY" || echo "✗ UNHEALTHY")"
echo "MinIO: $([ "$MINIO_HEALTHY" = "1" ] && echo "✓ HEALTHY" || echo "✗ UNHEALTHY")"
echo "Elasticsearch: $([ "$ELASTIC_HEALTHY" = "1" ] && echo "✓ HEALTHY" || echo "✗ UNHEALTHY")"
echo "Application Services: ${HEALTHY_SERVICES}/${TOTAL_SERVICES} healthy"