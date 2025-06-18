#!/bin/bash

# Huly Database Infrastructure Health Monitor
# Monitors the health of core database services

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="compose.optimized.yml"
MONGO_USER="admin"
MONGO_PASS="B26ppVvQYhB3MtxrDR040JzidriNbc5J"

print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}    Huly Database Infrastructure Health Check   ${NC}"
    echo -e "${BLUE}    $(date '+%Y-%m-%d %H:%M:%S')                    ${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
}

check_service_status() {
    local service=$1
    local status=$(docker-compose -f "$COMPOSE_FILE" ps -q "$service" | xargs docker inspect --format="{{.State.Status}}" 2>/dev/null || echo "not_found")
    
    if [[ "$status" == "running" ]]; then
        echo -e "${GREEN}✅ $service: Running${NC}"
        return 0
    else
        echo -e "${RED}❌ $service: $status${NC}"
        return 1
    fi
}

check_mongodb_connection() {
    echo -n "Testing MongoDB connection... "
    if docker exec huly-mongodb-1 mongosh --quiet --host localhost:27017 -u "$MONGO_USER" -p "$MONGO_PASS" --authenticationDatabase admin --eval "db.adminCommand('ping').ok" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Connected${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed${NC}"
        return 1
    fi
}

check_minio_health() {
    echo -n "Testing MinIO health... "
    if docker exec huly-minio-1 curl -sf http://localhost:9000/minio/health/live >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Healthy${NC}"
        return 0
    else
        echo -e "${RED}❌ Unhealthy${NC}"
        return 1
    fi
}

check_elasticsearch_health() {
    echo -n "Testing Elasticsearch health... "
    local health=$(docker exec huly-elastic-1 curl -s http://localhost:9200/_cluster/health 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    
    if [[ "$health" == "green" ]]; then
        echo -e "${GREEN}✅ Green${NC}"
        return 0
    elif [[ "$health" == "yellow" ]]; then
        echo -e "${YELLOW}⚠️ Yellow${NC}"
        return 0
    else
        echo -e "${RED}❌ Red or Unavailable${NC}"
        return 1
    fi
}

show_resource_usage() {
    echo -e "\n${BLUE}Resource Usage:${NC}"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" | grep huly | head -10
}

show_health_summary() {
    echo -e "\n${BLUE}Health Summary:${NC}"
    docker-compose -f "$COMPOSE_FILE" ps mongodb minio elastic 2>/dev/null | tail -n +2
}

main() {
    print_header
    
    # Check service statuses
    echo -e "${BLUE}Service Status Check:${NC}"
    local all_healthy=true
    
    for service in mongodb minio elastic; do
        if ! check_service_status "$service"; then
            all_healthy=false
        fi
    done
    
    echo ""
    
    # Check connectivity
    echo -e "${BLUE}Connectivity Tests:${NC}"
    if ! check_mongodb_connection; then
        all_healthy=false
    fi
    
    if ! check_minio_health; then
        all_healthy=false
    fi
    
    if ! check_elasticsearch_health; then
        all_healthy=false
    fi
    
    show_resource_usage
    show_health_summary
    
    echo ""
    if [[ "$all_healthy" == true ]]; then
        echo -e "${GREEN}🎉 All database services are healthy!${NC}"
        exit 0
    else
        echo -e "${RED}⚠️ Some services have issues. Check logs with:${NC}"
        echo "docker-compose -f $COMPOSE_FILE logs [service_name]"
        exit 1
    fi
}

# Handle command line options
case "${1:-check}" in
    "check")
        main
        ;;
    "watch")
        while true; do
            clear
            main
            echo -e "\n${YELLOW}Refreshing in 30 seconds... (Ctrl+C to stop)${NC}"
            sleep 30
        done
        ;;
    "logs")
        service="${2:-}"
        if [[ -n "$service" ]]; then
            docker-compose -f "$COMPOSE_FILE" logs -f "$service"
        else
            docker-compose -f "$COMPOSE_FILE" logs -f
        fi
        ;;
    *)
        echo "Usage: $0 [check|watch|logs [service]]"
        echo "  check  - Run health check once (default)"
        echo "  watch  - Continuous monitoring"
        echo "  logs   - Show service logs"
        exit 1
        ;;
esac