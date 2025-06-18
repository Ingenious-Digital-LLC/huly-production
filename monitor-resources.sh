#!/bin/bash

# Huly Resource Monitoring Script
# Provides real-time monitoring of Docker containers and system resources

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="${1:-compose.optimized.yml}"
LOG_FILE="/tmp/huly-resource-monitor.log"
ALERT_MEMORY_THRESHOLD=90  # Alert if memory usage > 90%
ALERT_CPU_THRESHOLD=80     # Alert if CPU usage > 80%

print_header() {
    echo -e "${BLUE}===========================================${NC}"
    echo -e "${BLUE}    Huly Resource Monitoring Dashboard    ${NC}"
    echo -e "${BLUE}===========================================${NC}"
    echo "$(date)"
    echo ""
}

check_system_resources() {
    echo -e "${YELLOW}System Resources:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Memory usage
    local mem_info=$(free -h | awk 'NR==2{printf "Memory: %s/%s (%.1f%%)", $3,$2,$3*100/$2 }')
    echo -e "  💾 $mem_info"
    
    # CPU load
    local cpu_load=$(uptime | awk -F'load average:' '{ print $2 }' | sed 's/^[ \t]*//')
    echo -e "  🖥️  CPU Load: $cpu_load"
    
    # Disk usage
    local disk_usage=$(df -h / | awk 'NR==2 {printf "Disk: %s/%s (%s)", $3, $2, $5}')
    echo -e "  💿 $disk_usage"
    
    # Swap usage
    local swap_info=$(free -h | awk 'NR==3{printf "Swap: %s/%s", $3,$2 }')
    echo -e "  🔄 $swap_info"
    
    echo ""
}

check_docker_resources() {
    echo -e "${YELLOW}Docker Container Resources:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Header
    printf "%-15s %-12s %-12s %-12s %-10s\n" "SERVICE" "CPU %" "MEMORY" "NET I/O" "STATUS"
    echo "────────────────────────────────────────────────────────────────────"
    
    # Get containers from the compose file
    local project_name=$(grep "^name:" "$COMPOSE_FILE" | cut -d':' -f2 | tr -d ' ')
    
    if [[ -z "$project_name" ]]; then
        project_name="huly"
    fi
    
    # Get running containers
    local containers=$(docker ps --filter "name=${project_name}" --format "{{.Names}}" 2>/dev/null || echo "")
    
    if [[ -z "$containers" ]]; then
        echo -e "  ${RED}No running containers found for project: $project_name${NC}"
        return
    fi
    
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            # Get container stats
            local stats=$(docker stats "$container" --no-stream --format "{{.CPUPerc}};{{.MemUsage}};{{.NetIO}}" 2>/dev/null || echo "N/A;N/A;N/A")
            local cpu=$(echo "$stats" | cut -d';' -f1)
            local memory=$(echo "$stats" | cut -d';' -f2)
            local network=$(echo "$stats" | cut -d';' -f3)
            
            # Get container status
            local status=$(docker inspect "$container" --format "{{.State.Status}}" 2>/dev/null || echo "unknown")
            
            # Color based on status
            local status_color=""
            case "$status" in
                "running") status_color="${GREEN}$status${NC}" ;;
                "exited") status_color="${RED}$status${NC}" ;;
                *) status_color="${YELLOW}$status${NC}" ;;
            esac
            
            # Extract service name
            local service_name=$(echo "$container" | sed "s/${project_name}[_-]//" | sed 's/[_-][0-9]*$//')
            
            printf "%-15s %-12s %-12s %-12s %-10s\n" "$service_name" "$cpu" "$memory" "$network" "$(echo -e "$status_color")"
        fi
    done <<< "$containers"
    
    echo ""
}

check_health_status() {
    echo -e "${YELLOW}Health Check Status:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local project_name=$(grep "^name:" "$COMPOSE_FILE" | cut -d':' -f2 | tr -d ' ')
    
    if [[ -z "$project_name" ]]; then
        project_name="huly"
    fi
    
    local containers=$(docker ps --filter "name=${project_name}" --format "{{.Names}}" 2>/dev/null || echo "")
    
    if [[ -z "$containers" ]]; then
        echo -e "  ${RED}No running containers found${NC}"
        return
    fi
    
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            local health=$(docker inspect "$container" --format "{{.State.Health.Status}}" 2>/dev/null || echo "none")
            local service_name=$(echo "$container" | sed "s/${project_name}[_-]//" | sed 's/[_-][0-9]*$//')
            
            case "$health" in
                "healthy") echo -e "  ✅ ${service_name}: ${GREEN}healthy${NC}" ;;
                "unhealthy") echo -e "  ❌ ${service_name}: ${RED}unhealthy${NC}" ;;
                "starting") echo -e "  🔄 ${service_name}: ${YELLOW}starting${NC}" ;;
                "none") echo -e "  ⚪ ${service_name}: no health check" ;;
                *) echo -e "  ❓ ${service_name}: ${health}" ;;
            esac
        fi
    done <<< "$containers"
    
    echo ""
}

check_resource_alerts() {
    echo -e "${YELLOW}Resource Alerts:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local alerts_found=false
    
    # Check system memory
    local mem_percent=$(free | awk 'NR==2{printf "%.1f", $3*100/$2 }')
    if (( $(echo "$mem_percent > $ALERT_MEMORY_THRESHOLD" | bc -l) )); then
        echo -e "  🚨 ${RED}HIGH MEMORY USAGE: ${mem_percent}%${NC}"
        alerts_found=true
    fi
    
    # Check system load
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local cpu_cores=$(nproc)
    local load_percent=$(echo "scale=1; $load_avg * 100 / $cpu_cores" | bc)
    
    if (( $(echo "$load_percent > $ALERT_CPU_THRESHOLD" | bc -l) )); then
        echo -e "  🚨 ${RED}HIGH CPU LOAD: ${load_percent}%${NC}"
        alerts_found=true
    fi
    
    # Check disk space
    local disk_percent=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $disk_percent -gt 85 ]]; then
        echo -e "  🚨 ${RED}HIGH DISK USAGE: ${disk_percent}%${NC}"
        alerts_found=true
    fi
    
    if [[ "$alerts_found" == "false" ]]; then
        echo -e "  ✅ ${GREEN}All systems within normal parameters${NC}"
    fi
    
    echo ""
}

show_logs() {
    echo -e "${YELLOW}Recent Container Logs (last 10 lines):${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local project_name=$(grep "^name:" "$COMPOSE_FILE" | cut -d':' -f2 | tr -d ' ')
    
    if [[ -z "$project_name" ]]; then
        project_name="huly"
    fi
    
    local containers=$(docker ps --filter "name=${project_name}" --format "{{.Names}}" 2>/dev/null || echo "")
    
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            local service_name=$(echo "$container" | sed "s/${project_name}[_-]//" | sed 's/[_-][0-9]*$//')
            echo -e "  📝 ${service_name}:"
            docker logs "$container" --tail 3 2>/dev/null | sed 's/^/    /' || echo "    No logs available"
            echo ""
        fi
    done <<< "$containers"
}

save_metrics() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local mem_percent=$(free | awk 'NR==2{printf "%.1f", $3*100/$2 }')
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    
    echo "$timestamp,$mem_percent,$load_avg" >> "$LOG_FILE"
}

# Main execution
main() {
    clear
    print_header
    check_system_resources
    check_docker_resources
    check_health_status
    check_resource_alerts
    
    if [[ "${1:-}" == "--with-logs" ]]; then
        show_logs
    fi
    
    save_metrics
    
    echo -e "${BLUE}===========================================${NC}"
    echo "Monitor log: $LOG_FILE"
    echo "Run with --with-logs to see container logs"
    echo "Run with --watch to monitor continuously"
    echo -e "${BLUE}===========================================${NC}"
}

# Handle watch mode
if [[ "${1:-}" == "--watch" ]]; then
    while true; do
        main
        sleep 5
    done
else
    main "$@"
fi