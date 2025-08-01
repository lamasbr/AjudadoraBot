#!/bin/bash
# AjudadoraBot Cleanup and Maintenance Script
# Handles log rotation, temporary file cleanup, and system maintenance

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${LOG_DIR:-/app/logs}"
TEMP_DIR="${TEMP_DIR:-/tmp}"
DATABASE_PATH="${DATABASE_PATH:-/app/data/ajudadorabot.db}"
MAX_LOG_SIZE="${MAX_LOG_SIZE:-100M}"
LOG_RETENTION_DAYS="${LOG_RETENTION_DAYS:-30}"
TEMP_FILE_RETENTION_HOURS="${TEMP_FILE_RETENTION_HOURS:-24}"
DATABASE_VACUUM_THRESHOLD="${DATABASE_VACUUM_THRESHOLD:-10}"  # Percentage of free pages

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Check disk space
check_disk_space() {
    local path="$1"
    local threshold="${2:-90}"  # Default 90% threshold
    
    local usage=$(df "$path" | awk 'NR==2 {print int($5)}')
    
    if [[ $usage -gt $threshold ]]; then
        log "WARNING: Disk usage for $path is ${usage}% (threshold: ${threshold}%)"
        return 1
    else
        log "Disk usage for $path is ${usage}% (healthy)"
        return 0
    fi
}

# Clean old log files
cleanup_logs() {
    log "Starting log cleanup..."
    
    if [[ ! -d "$LOG_DIR" ]]; then
        log "Log directory not found: $LOG_DIR"
        return 0
    fi
    
    # Find and remove old log files
    local cleaned_files=0
    
    # Remove files older than retention period
    while IFS= read -r -d '' file; do
        rm -f "$file"
        ((cleaned_files++))
        log "Removed old log file: $(basename "$file")"
    done < <(find "$LOG_DIR" -name "*.log*" -type f -mtime +$LOG_RETENTION_DAYS -print0 2>/dev/null || true)
    
    # Rotate large current log files
    while IFS= read -r file; do
        local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
        local max_size_bytes
        
        # Convert MAX_LOG_SIZE to bytes
        if [[ "$MAX_LOG_SIZE" =~ ^([0-9]+)([KMG]?)$ ]]; then
            local number="${BASH_REMATCH[1]}"
            local unit="${BASH_REMATCH[2]}"
            case "$unit" in
                "K") max_size_bytes=$((number * 1024)) ;;
                "M") max_size_bytes=$((number * 1024 * 1024)) ;;
                "G") max_size_bytes=$((number * 1024 * 1024 * 1024)) ;;
                *) max_size_bytes=$number ;;
            esac
        else
            max_size_bytes=104857600  # 100MB default
        fi
        
        if [[ $size -gt $max_size_bytes ]]; then
            local timestamp=$(date '+%Y%m%d_%H%M%S')
            local rotated_name="${file}.${timestamp}"
            
            mv "$file" "$rotated_name"
            gzip "$rotated_name"
            touch "$file"  # Create new empty log file
            
            log "Rotated large log file: $(basename "$file") -> $(basename "$rotated_name").gz"
            ((cleaned_files++))
        fi
    done < <(find "$LOG_DIR" -name "*.log" -type f 2>/dev/null || true)
    
    log "Log cleanup completed. Files processed: $cleaned_files"
}

# Clean temporary files
cleanup_temp_files() {
    log "Starting temporary file cleanup..."
    
    local cleaned_files=0
    local temp_patterns=(
        "/tmp/ajudadorabot*"
        "/tmp/*.tmp"
        "/app/temp/*"
        "/var/tmp/ajudadorabot*"
    )
    
    for pattern in "${temp_patterns[@]}"; do
        # Find files older than retention period
        while IFS= read -r -d '' file; do
            if [[ -f "$file" ]]; then
                rm -f "$file"
                ((cleaned_files++))
                log "Removed temp file: $file"
            elif [[ -d "$file" ]]; then
                rm -rf "$file"
                ((cleaned_files++))
                log "Removed temp directory: $file"
            fi
        done < <(find $(dirname "$pattern") -name "$(basename "$pattern")" -type f -mmin +$((TEMP_FILE_RETENTION_HOURS * 60)) -print0 2>/dev/null || true)
    done
    
    log "Temporary file cleanup completed. Files processed: $cleaned_files"
}

# Database maintenance
database_maintenance() {
    log "Starting database maintenance..."
    
    if [[ ! -f "$DATABASE_PATH" ]]; then
        log "Database not found: $DATABASE_PATH"
        return 0
    fi
    
    # Check database integrity
    log "Checking database integrity..."
    if ! sqlite3 "$DATABASE_PATH" "PRAGMA integrity_check;" | grep -q "ok"; then
        error_exit "Database integrity check failed!"
    fi
    
    # Get database statistics
    local db_size=$(stat -f%z "$DATABASE_PATH" 2>/dev/null || stat -c%s "$DATABASE_PATH")
    local page_count=$(sqlite3 "$DATABASE_PATH" "PRAGMA page_count;")
    local freelist_count=$(sqlite3 "$DATABASE_PATH" "PRAGMA freelist_count;")
    local free_percentage=0
    
    if [[ $page_count -gt 0 ]]; then
        free_percentage=$(( (freelist_count * 100) / page_count ))
    fi
    
    log "Database stats - Size: $(numfmt --to=iec $db_size), Pages: $page_count, Free pages: $freelist_count (${free_percentage}%)"
    
    # Vacuum if needed
    if [[ $free_percentage -gt $DATABASE_VACUUM_THRESHOLD ]]; then
        log "Database has ${free_percentage}% free pages, running VACUUM..."
        
        local start_time=$(date +%s)
        sqlite3 "$DATABASE_PATH" "VACUUM;"
        local duration=$(($(date +%s) - start_time))
        
        local new_size=$(stat -f%z "$DATABASE_PATH" 2>/dev/null || stat -c%s "$DATABASE_PATH")
        local size_saved=$((db_size - new_size))
        
        log "VACUUM completed in ${duration}s. Space saved: $(numfmt --to=iec $size_saved)"
    else
        log "Database vacuum not needed (${free_percentage}% free pages < ${DATABASE_VACUUM_THRESHOLD}% threshold)"
    fi
    
    # Analyze database for query optimization
    log "Analyzing database for query optimization..."
    sqlite3 "$DATABASE_PATH" "ANALYZE;"
    
    # Update statistics
    sqlite3 "$DATABASE_PATH" "PRAGMA optimize;"
    
    log "Database maintenance completed"
}

# Clean Docker resources (if running in Docker)
cleanup_docker() {
    if ! command -v docker &> /dev/null; then
        log "Docker not available, skipping Docker cleanup"
        return 0
    fi
    
    log "Starting Docker cleanup..."
    
    # Remove unused containers
    local removed_containers=$(docker container prune -f --filter "until=24h" 2>/dev/null | grep "Total reclaimed space" | sed 's/.*: //' || echo "0B")
    
    # Remove unused images
    local removed_images=$(docker image prune -f --filter "until=24h" 2>/dev/null | grep "Total reclaimed space" | sed 's/.*: //' || echo "0B")
    
    # Remove unused volumes (be careful with this)
    # local removed_volumes=$(docker volume prune -f 2>/dev/null | grep "Total reclaimed space" | sed 's/.*: //' || echo "0B")
    
    # Remove unused networks
    docker network prune -f &>/dev/null || true
    
    log "Docker cleanup completed. Containers: $removed_containers, Images: $removed_images"
}

# System resource monitoring
monitor_resources() {
    log "System resource monitoring:"
    
    # CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' 2>/dev/null || echo "N/A")
    
    # Memory usage
    local mem_info=$(free -h | grep "Mem:" 2>/dev/null || echo "N/A N/A N/A")
    local mem_used=$(echo $mem_info | awk '{print $3}')
    local mem_total=$(echo $mem_info | awk '{print $2}')
    
    # Load average
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | trim 2>/dev/null || echo "N/A")
    
    log "  CPU Usage: ${cpu_usage}%"
    log "  Memory: ${mem_used}/${mem_total}"
    log "  Load Average:${load_avg}"
    
    # Disk usage for important paths
    for path in "/" "/app" "/var/log"; do
        if [[ -d "$path" ]]; then
            check_disk_space "$path" 85
        fi
    done
}

# Application-specific cleanup
app_specific_cleanup() {
    log "Starting application-specific cleanup..."
    
    # Clean expired user sessions (if applicable)
    if sqlite3 "$DATABASE_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name='UserSessions';" | grep -q "UserSessions"; then
        local expired_sessions=$(sqlite3 "$DATABASE_PATH" "DELETE FROM UserSessions WHERE ExpiresAt < datetime('now'); SELECT changes();")
        log "Cleaned $expired_sessions expired user sessions"
    fi
    
    # Clean old error logs (if applicable)
    if sqlite3 "$DATABASE_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name='ErrorLogs';" | grep -q "ErrorLogs"; then
        local old_errors=$(sqlite3 "$DATABASE_PATH" "DELETE FROM ErrorLogs WHERE CreatedAt < datetime('now', '-30 days'); SELECT changes();")
        log "Cleaned $old_errors old error log entries"
    fi
    
    # Clean old analytics data (if applicable)
    if sqlite3 "$DATABASE_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name='Interactions';" | grep -q "Interactions"; then
        local old_interactions=$(sqlite3 "$DATABASE_PATH" "DELETE FROM Interactions WHERE CreatedAt < datetime('now', '-90 days'); SELECT changes();")
        log "Cleaned $old_interactions old interaction records"
    fi
    
    log "Application-specific cleanup completed"
}

# Generate cleanup report
generate_report() {
    local report_file="$LOG_DIR/cleanup_report_$(date '+%Y%m%d').log"
    
    cat > "$report_file" << EOF
AjudadoraBot Cleanup Report
Generated: $(date)
==========================

System Information:
- Hostname: $(hostname)
- Uptime: $(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')
- Kernel: $(uname -r)

Disk Usage:
$(df -h | grep -E '^/dev/')

Database Information:
- Database Size: $(numfmt --to=iec $(stat -f%z "$DATABASE_PATH" 2>/dev/null || stat -c%s "$DATABASE_PATH"))
- Last Modified: $(stat -f%Sm "$DATABASE_PATH" 2>/dev/null || stat -c%y "$DATABASE_PATH")

Cleanup Actions Performed:
- Log cleanup: $(find "$LOG_DIR" -name "*.log*" -type f | wc -l) files remaining
- Temp file cleanup: Completed
- Database maintenance: Completed
- System monitoring: Completed

EOF

    log "Cleanup report generated: $report_file"
}

# Health check
health_check() {
    local issues=0
    
    log "Running health check..."
    
    # Check disk space
    if ! check_disk_space "/" 90; then
        ((issues++))
    fi
    
    # Check database
    if [[ -f "$DATABASE_PATH" ]]; then
        if ! sqlite3 "$DATABASE_PATH" "SELECT 1;" &>/dev/null; then
            log "ERROR: Database is not accessible"
            ((issues++))
        fi
    else
        log "WARNING: Database file not found"
        ((issues++))
    fi
    
    # Check log directory
    if [[ ! -d "$LOG_DIR" ]]; then
        log "WARNING: Log directory not found"
        ((issues++))
    fi
    
    if [[ $issues -eq 0 ]]; then
        log "Health check passed - no issues found"
        return 0
    else
        log "Health check failed - $issues issues found"
        return 1
    fi
}

# Main function
main() {
    local start_time=$(date +%s)
    
    log "Starting AjudadoraBot cleanup and maintenance..."
    
    case "${1:-full}" in
        "logs")
            cleanup_logs
            ;;
        "temp")
            cleanup_temp_files
            ;;
        "database"|"db")
            database_maintenance
            ;;
        "docker")
            cleanup_docker
            ;;
        "health")
            health_check
            exit $?
            ;;
        "monitor")
            monitor_resources
            ;;
        "full")
            monitor_resources
            cleanup_logs
            cleanup_temp_files
            database_maintenance
            app_specific_cleanup
            cleanup_docker
            generate_report
            ;;
        *)
            cat << EOF
Usage: $0 <command>

Commands:
  logs       Clean old log files only
  temp       Clean temporary files only
  database   Run database maintenance only
  docker     Clean Docker resources only
  health     Run health check
  monitor    Monitor system resources
  full       Run complete cleanup (default)

Examples:
  $0 full
  $0 logs
  $0 health
EOF
            exit 1
            ;;
    esac
    
    local duration=$(($(date +%s) - start_time))
    log "Cleanup process completed in ${duration}s"
}

# Run main function with all arguments
main "$@"