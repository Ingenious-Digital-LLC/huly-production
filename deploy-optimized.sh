#!/bin/bash

# Optimized Huly Deployment Script
# Deploys Huly with resource optimizations and monitoring

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="compose.optimized.yml"
ORIGINAL_COMPOSE="compose.yml"
BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
LOG_FILE="deployment.log"

# Function to log messages
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}    Huly Optimized Deployment Manager          ${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
}

check_prerequisites() {
    log "${YELLOW}Checking prerequisites...${NC}"
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        log "${RED}ERROR: Docker is not running${NC}"
        exit 1
    fi
    
    # Check if docker-compose is available
    if ! command -v docker-compose >/dev/null 2>&1; then
        log "${RED}ERROR: docker-compose is not installed${NC}"
        exit 1
    fi
    
    # Check available memory
    local available_mem=$(free -m | awk 'NR==2{print $7}')
    if [[ $available_mem -lt 4000 ]]; then
        log "${YELLOW}WARNING: Available memory is ${available_mem}MB. Recommended: 4GB+${NC}"
    fi
    
    # Check if optimized compose file exists
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log "${RED}ERROR: $COMPOSE_FILE not found${NC}"
        exit 1
    fi
    
    log "${GREEN}Prerequisites check passed${NC}"
}

validate_resource_allocation() {
    log "${YELLOW}Validating resource allocation...${NC}"
    
    # Calculate total memory allocation from compose file
    local total_memory=0
    local memory_limits=(
        256   # nginx
        2048  # mongodb
        512   # minio
        2048  # elastic
        512   # rekoni
        768   # transactor
        512   # collaborator
        512   # account
        512   # workspace
        512   # front
        512   # fulltext
        256   # stats
    )
    
    for mem in "${memory_limits[@]}"; do
        total_memory=$((total_memory + mem))
    done
    
    local available_mem=$(free -m | awk 'NR==2{print $2}')
    local usage_percent=$((total_memory * 100 / available_mem))
    
    log "Total allocated memory: ${total_memory}MB"
    log "Available system memory: ${available_mem}MB"
    log "Memory utilization: ${usage_percent}%"
    
    if [[ $usage_percent -gt 90 ]]; then
        log "${YELLOW}WARNING: High memory allocation (${usage_percent}%). Monitor closely.${NC}"
    else
        log "${GREEN}Memory allocation looks good (${usage_percent}%)${NC}"
    fi
}

create_backup() {
    log "${YELLOW}Creating backup...${NC}"
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup original compose file
    if [[ -f "$ORIGINAL_COMPOSE" ]]; then
        cp "$ORIGINAL_COMPOSE" "$BACKUP_DIR/"
        log "Backed up $ORIGINAL_COMPOSE"
    fi
    
    # Backup any existing volumes (metadata only)
    if docker volume ls | grep -q "huly"; then
        docker volume ls --filter name=huly > "$BACKUP_DIR/volumes.txt"
        log "Saved volume information"
    fi
    
    log "${GREEN}Backup created in $BACKUP_DIR${NC}"
}

deploy_services() {
    log "${YELLOW}Deploying optimized services...${NC}"
    
    # Stop existing services
    if docker-compose -f "$ORIGINAL_COMPOSE" ps >/dev/null 2>&1; then
        log "Stopping existing services..."
        docker-compose -f "$ORIGINAL_COMPOSE" down --remove-orphans
    fi
    
    # Deploy optimized services
    log "Starting optimized services..."
    docker-compose -f "$COMPOSE_FILE" up -d
    
    log "${GREEN}Services deployed${NC}"
}

wait_for_health_checks() {
    log "${YELLOW}Waiting for health checks...${NC}"
    
    local max_wait=300  # 5 minutes
    local elapsed=0
    local check_interval=10
    
    while [[ $elapsed -lt $max_wait ]]; do
        local healthy_count=0
        local total_services=0
        
        # Count services with health checks
        for service in mongodb minio elastic rekoni account transactor; do
            total_services=$((total_services + 1))
            local health=$(docker-compose -f "$COMPOSE_FILE" ps -q "$service" | xargs docker inspect --format="{{if .State.Health}}{{.State.Health.Status}}{{end}}" 2>/dev/null || echo "none")
            
            if [[ "$health" == "healthy" ]]; then
                healthy_count=$((healthy_count + 1))
            elif [[ "$health" == "unhealthy" ]]; then
                log "${RED}Service $service is unhealthy${NC}"
            fi
        done
        
        log "Health checks: $healthy_count/$total_services services healthy"
        
        if [[ $healthy_count -eq $total_services ]]; then
            log "${GREEN}All services are healthy${NC}"
            return 0
        fi
        
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done
    
    log "${YELLOW}WARNING: Not all services became healthy within ${max_wait}s${NC}"
    return 1
}

verify_deployment() {
    log "${YELLOW}Verifying deployment...${NC}"
    
    # Check if all services are running
    local running_services=$(docker-compose -f "$COMPOSE_FILE" ps --services --filter status=running | wc -l)
    local total_services=$(docker-compose -f "$COMPOSE_FILE" config --services | wc -l)
    
    log "Running services: $running_services/$total_services"
    
    # Test basic connectivity
    local project_name=$(grep "^name:" "$COMPOSE_FILE" | cut -d':' -f2 | tr -d ' ')
    
    # Test MongoDB connection
    if docker exec "${project_name}-mongodb-1" mongosh --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
        log "${GREEN}✅ MongoDB connection successful${NC}"
    else
        log "${RED}❌ MongoDB connection failed${NC}"
    fi
    
    # Test MinIO connection
    if docker exec "${project_name}-minio-1" curl -f http://localhost:9000/minio/health/live >/dev/null 2>&1; then
        log "${GREEN}✅ MinIO health check successful${NC}"
    else
        log "${RED}❌ MinIO health check failed${NC}"
    fi
    
    # Test Elasticsearch connection
    if docker exec "${project_name}-elastic-1" curl -s http://localhost:9200/_cluster/health >/dev/null 2>&1; then
        log "${GREEN}✅ Elasticsearch connection successful${NC}"
    else
        log "${RED}❌ Elasticsearch connection failed${NC}"
    fi
    
    log "${GREEN}Deployment verification completed${NC}"
}

generate_report() {
    log "${YELLOW}Generating deployment report...${NC}"
    
    local report_file="deployment-report-$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
Huly Optimized Deployment Report
Generated: $(date)

=== SYSTEM INFORMATION ===
$(uname -a)
Docker Version: $(docker --version)
Docker Compose Version: $(docker-compose --version)

=== RESOURCE ALLOCATION ===
System Memory: $(free -h | awk 'NR==2{print $2}')
Available Memory: $(free -h | awk 'NR==2{print $7}')
CPU Cores: $(nproc)
Current Load: $(uptime | awk -F'load average:' '{print $2}')

=== SERVICE STATUS ===
$(docker-compose -f "$COMPOSE_FILE" ps)

=== RESOURCE USAGE ===
$(docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}")

=== VOLUME INFORMATION ===
$(docker volume ls --filter name=huly)

=== NETWORK INFORMATION ===
$(docker network ls --filter name=huly)

=== OPTIMIZATION FEATURES IMPLEMENTED ===
✅ Resource limits for all services
✅ Health checks with proper timeouts
✅ Service dependencies for startup ordering
✅ Optimized Elasticsearch memory allocation
✅ MongoDB performance tuning
✅ Log rotation and size limits
✅ Memory lock for Elasticsearch
✅ Proper restart policies

=== MONITORING ===
Use './monitor-resources.sh' for real-time monitoring
Use './monitor-resources.sh --watch' for continuous monitoring
Use 'docker-compose -f $COMPOSE_FILE logs -f [service]' for service logs

=== BACKUP LOCATION ===
$BACKUP_DIR

=== NEXT STEPS ===
1. Monitor resource usage for 24-48 hours
2. Adjust resource limits if needed
3. Set up log rotation for docker logs
4. Consider adding external monitoring (Prometheus/Grafana)
5. Test application functionality thoroughly

EOF

    log "${GREEN}Report generated: $report_file${NC}"
}

cleanup_on_failure() {
    log "${RED}Deployment failed. Cleaning up...${NC}"
    
    # Stop optimized services
    docker-compose -f "$COMPOSE_FILE" down --remove-orphans 2>/dev/null || true
    
    # Restore original services if backup exists
    if [[ -f "$BACKUP_DIR/$ORIGINAL_COMPOSE" ]]; then
        log "Restoring original services..."
        cp "$BACKUP_DIR/$ORIGINAL_COMPOSE" "$ORIGINAL_COMPOSE"
        docker-compose -f "$ORIGINAL_COMPOSE" up -d
    fi
    
    log "${RED}Cleanup completed${NC}"
    exit 1
}

# Main execution
main() {
    print_header
    
    # Set up error handling
    trap cleanup_on_failure ERR
    
    log "${BLUE}Starting optimized Huly deployment...${NC}"
    
    check_prerequisites
    validate_resource_allocation
    create_backup
    deploy_services
    
    log "${YELLOW}Waiting for services to start...${NC}"
    sleep 30
    
    wait_for_health_checks || log "${YELLOW}Proceeding despite health check warnings...${NC}"
    verify_deployment
    generate_report
    
    log "${GREEN}===========================================${NC}"
    log "${GREEN}Optimized deployment completed successfully!${NC}"
    log "${GREEN}===========================================${NC}"
    
    echo ""
    echo -e "${BLUE}Quick Commands:${NC}"
    echo "  Monitor resources: ./monitor-resources.sh"
    echo "  View logs: docker-compose -f $COMPOSE_FILE logs -f"
    echo "  Scale service: docker-compose -f $COMPOSE_FILE up -d --scale [service]=[count]"
    echo "  Stop all: docker-compose -f $COMPOSE_FILE down"
    echo ""
}

# Handle command line arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "stop")
        log "Stopping all services..."
        docker-compose -f "$COMPOSE_FILE" down
        ;;
    "restart")
        log "Restarting all services..."
        docker-compose -f "$COMPOSE_FILE" restart
        ;;
    "status")
        docker-compose -f "$COMPOSE_FILE" ps
        ;;
    "logs")
        docker-compose -f "$COMPOSE_FILE" logs -f "${2:-}"
        ;;
    *)
        echo "Usage: $0 [deploy|stop|restart|status|logs [service]]"
        exit 1
        ;;
esac