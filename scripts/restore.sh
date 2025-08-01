#!/bin/bash
# AjudadoraBot Database Restore Script
# Supports SQLite restore from local and cloud backups

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATABASE_PATH="${DATABASE_PATH:-/app/data/ajudadorabot.db}"
BACKUP_DIR="${BACKUP_DIR:-/app/backups}"
CLOUD_BACKUP_ENABLED="${CLOUD_BACKUP_ENABLED:-false}"
AWS_S3_BUCKET="${AWS_S3_BUCKET:-}"
BACKUP_ENCRYPTION_KEY="${BACKUP_ENCRYPTION_KEY:-}"
NOTIFICATION_WEBHOOK="${NOTIFICATION_WEBHOOK:-}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${BACKUP_DIR}/restore.log"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    send_notification "❌ Restore Failed" "$1" "error"
    exit 1
}

# Send notification function
send_notification() {
    local title="$1"
    local message="$2"
    local level="${3:-info}"
    
    if [[ -n "$NOTIFICATION_WEBHOOK" ]]; then
        curl -s -X POST "$NOTIFICATION_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"text\":\"**$title**\n$message\",\"level\":\"$level\"}" \
            || log "Warning: Failed to send notification"
    fi
}

# Check dependencies
check_dependencies() {
    local deps=("sqlite3" "gzip" "openssl")
    
    if [[ "$CLOUD_BACKUP_ENABLED" == "true" ]]; then
        deps+=("aws")
    fi
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error_exit "Required dependency '$dep' is not installed"
        fi
    done
}

# List available backups
list_backups() {
    log "Available local backups:"
    
    local backups=($(find "$BACKUP_DIR" -name "ajudadorabot_backup_*.db*" -type f | sort -r))
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        log "No local backups found"
    else
        for i in "${!backups[@]}"; do
            local backup="${backups[$i]}"
            local filename=$(basename "$backup")
            local size=$(du -h "$backup" | cut -f1)
            local date=$(stat -f%Sm -t%Y-%m-%d\ %H:%M:%S "$backup" 2>/dev/null || stat -c%y "$backup" | cut -d' ' -f1-2)
            printf "%2d. %s (Size: %s, Date: %s)\n" $((i+1)) "$filename" "$size" "$date"
        done
    fi
    
    # List cloud backups if enabled
    if [[ "$CLOUD_BACKUP_ENABLED" == "true" ]] && [[ -n "$AWS_S3_BUCKET" ]]; then
        log "Available cloud backups:"
        aws s3 ls "s3://$AWS_S3_BUCKET/backups/" --recursive | grep "ajudadorabot_backup_" || log "No cloud backups found"
    fi
}

# Download backup from cloud
download_from_cloud() {
    local backup_filename="$1"
    local local_path="$BACKUP_DIR/$backup_filename"
    
    if [[ "$CLOUD_BACKUP_ENABLED" != "true" ]] || [[ -z "$AWS_S3_BUCKET" ]]; then
        error_exit "Cloud backup not enabled or S3 bucket not configured"
    fi
    
    log "Downloading backup from S3: s3://$AWS_S3_BUCKET/backups/$backup_filename"
    
    aws s3 cp "s3://$AWS_S3_BUCKET/backups/$backup_filename" "$local_path" \
        || error_exit "Failed to download backup from S3"
    
    log "Backup downloaded successfully: $local_path"
    echo "$local_path"
}

# Decrypt backup if encrypted
decrypt_backup() {
    local backup_path="$1"
    
    if [[ "$backup_path" != *.enc ]]; then
        echo "$backup_path"
        return 0
    fi
    
    if [[ -z "$BACKUP_ENCRYPTION_KEY" ]]; then
        error_exit "Backup is encrypted but no decryption key provided"
    fi
    
    log "Decrypting backup..."
    local decrypted_path="${backup_path%.enc}"
    
    openssl enc -aes-256-cbc -d -in "$backup_path" -out "$decrypted_path" -k "$BACKUP_ENCRYPTION_KEY" \
        || error_exit "Failed to decrypt backup"
    
    log "Backup decrypted successfully"
    echo "$decrypted_path"
}

# Decompress backup
decompress_backup() {
    local backup_path="$1"
    
    if [[ "$backup_path" != *.gz ]]; then
        echo "$backup_path"
        return 0
    fi
    
    log "Decompressing backup..."
    
    gunzip "$backup_path" || error_exit "Failed to decompress backup"
    
    local decompressed_path="${backup_path%.gz}"
    log "Backup decompressed successfully: $decompressed_path"
    echo "$decompressed_path"
}

# Verify backup integrity
verify_backup() {
    local backup_path="$1"
    
    log "Verifying backup integrity..."
    
    if [[ ! -f "$backup_path" ]]; then
        error_exit "Backup file not found: $backup_path"
    fi
    
    # Check if it's a valid SQLite database
    if ! sqlite3 "$backup_path" "PRAGMA integrity_check;" | grep -q "ok"; then
        error_exit "Backup integrity check failed"
    fi
    
    # Check if it has expected tables
    local table_count=$(sqlite3 "$backup_path" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';")
    if [[ $table_count -lt 1 ]]; then
        error_exit "Backup appears to be empty or corrupted"
    fi
    
    log "Backup integrity verification passed"
}

# Create database backup before restore
create_pre_restore_backup() {
    if [[ ! -f "$DATABASE_PATH" ]]; then
        log "No existing database to backup"
        return 0
    fi
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local pre_restore_backup="$BACKUP_DIR/pre_restore_backup_${timestamp}.db"
    
    log "Creating pre-restore backup: $pre_restore_backup"
    
    sqlite3 "$DATABASE_PATH" ".backup '$pre_restore_backup'" || error_exit "Failed to create pre-restore backup"
    
    log "Pre-restore backup created successfully"
    echo "$pre_restore_backup"
}

# Restore database
restore_database() {
    local backup_path="$1"
    local create_backup="${2:-true}"
    
    log "Starting database restore from: $backup_path"
    
    # Create pre-restore backup
    local pre_restore_backup=""
    if [[ "$create_backup" == "true" ]]; then
        pre_restore_backup=$(create_pre_restore_backup)
    fi
    
    # Stop application (if running in container)
    if command -v systemctl &> /dev/null; then
        log "Stopping AjudadoraBot service..."
        systemctl stop ajudadorabot || log "Warning: Failed to stop service (may not be running)"
    fi
    
    # Create database directory if it doesn't exist
    local db_dir=$(dirname "$DATABASE_PATH")
    mkdir -p "$db_dir"
    
    # Restore database
    log "Copying backup to database location..."
    cp "$backup_path" "$DATABASE_PATH" || error_exit "Failed to restore database"
    
    # Set proper permissions
    chmod 644 "$DATABASE_PATH"
    if command -v chown &> /dev/null; then
        chown app:app "$DATABASE_PATH" 2>/dev/null || log "Warning: Could not set database ownership"
    fi
    
    # Verify restored database
    verify_backup "$DATABASE_PATH"
    
    # Start application
    if command -v systemctl &> /dev/null; then
        log "Starting AjudadoraBot service..."
        systemctl start ajudadorabot || log "Warning: Failed to start service"
    fi
    
    local success_message="Database restored successfully from: $(basename "$backup_path")"
    log "$success_message"
    
    if [[ -n "$pre_restore_backup" ]]; then
        log "Pre-restore backup available at: $pre_restore_backup"
    fi
    
    send_notification "✅ Restore Successful" "$success_message" "success"
}

# Interactive backup selection
select_backup() {
    local backups=($(find "$BACKUP_DIR" -name "ajudadorabot_backup_*.db*" -type f | sort -r))
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        error_exit "No local backups found. Use 'list' command to see available backups."
    fi
    
    echo "Available backups:"
    for i in "${!backups[@]}"; do
        local backup="${backups[$i]}"
        local filename=$(basename "$backup")
        local size=$(du -h "$backup" | cut -f1)
        local date=$(stat -f%Sm -t%Y-%m-%d\ %H:%M:%S "$backup" 2>/dev/null || stat -c%y "$backup" | cut -d' ' -f1-2)
        printf "%2d. %s (Size: %s, Date: %s)\n" $((i+1)) "$filename" "$size" "$date"
    done
    
    echo ""
    read -p "Select backup number (1-${#backups[@]}): " selection
    
    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [[ $selection -lt 1 ]] || [[ $selection -gt ${#backups[@]} ]]; then
        error_exit "Invalid selection"
    fi
    
    echo "${backups[$((selection-1))]}"
}

# Point-in-time recovery simulation
point_in_time_recovery() {
    local target_date="$1"
    
    log "Searching for backup closest to: $target_date"
    
    # Find backup closest to target date
    local target_timestamp=$(date -d "$target_date" +%s 2>/dev/null || error_exit "Invalid date format")
    local closest_backup=""
    local closest_diff=999999999
    
    local backups=($(find "$BACKUP_DIR" -name "ajudadorabot_backup_*.db*" -type f))
    
    for backup in "${backups[@]}"; do
        local backup_date=$(basename "$backup" | sed 's/ajudadorabot_backup_\([0-9]*_[0-9]*\).*/\1/' | sed 's/_/ /')
        local backup_timestamp=$(date -d "${backup_date:0:8} ${backup_date:9:2}:${backup_date:11:2}:${backup_date:13:2}" +%s 2>/dev/null || continue)
        
        local diff=$((target_timestamp - backup_timestamp))
        if [[ $diff -ge 0 ]] && [[ $diff -lt $closest_diff ]]; then
            closest_diff=$diff
            closest_backup="$backup"
        fi
    done
    
    if [[ -z "$closest_backup" ]]; then
        error_exit "No suitable backup found for point-in-time recovery"
    fi
    
    log "Found closest backup: $(basename "$closest_backup") ($(($closest_diff / 3600)) hours before target)"
    echo "$closest_backup"
}

# Main function
main() {
    local start_time=$(date +%s)
    
    log "Starting AjudadoraBot database restore process..."
    
    check_dependencies
    
    case "${1:-}" in
        "list")
            list_backups
            ;;
            
        "interactive")
            local selected_backup
            selected_backup=$(select_backup)
            
            echo ""
            read -p "Are you sure you want to restore from this backup? (y/N): " confirm
            if [[ "$confirm" == "y" ]] || [[ "$confirm" == "Y" ]]; then
                local processed_backup
                processed_backup=$(decrypt_backup "$selected_backup")
                processed_backup=$(decompress_backup "$processed_backup")
                verify_backup "$processed_backup"
                restore_database "$processed_backup"
            else
                log "Restore cancelled by user"
            fi
            ;;
            
        "file")
            local backup_file="$2"
            if [[ -z "$backup_file" ]]; then
                error_exit "Please specify backup file path"
            fi
            
            local processed_backup
            processed_backup=$(decrypt_backup "$backup_file")
            processed_backup=$(decompress_backup "$processed_backup")
            verify_backup "$processed_backup"
            restore_database "$processed_backup"
            ;;
            
        "cloud")
            local cloud_backup="$2"
            if [[ -z "$cloud_backup" ]]; then
                error_exit "Please specify cloud backup filename"
            fi
            
            local downloaded_backup
            downloaded_backup=$(download_from_cloud "$cloud_backup")
            
            local processed_backup
            processed_backup=$(decrypt_backup "$downloaded_backup")
            processed_backup=$(decompress_backup "$processed_backup")
            verify_backup "$processed_backup"
            restore_database "$processed_backup"
            ;;
            
        "point-in-time")
            local target_date="$2"
            if [[ -z "$target_date" ]]; then
                error_exit "Please specify target date (YYYY-MM-DD HH:MM:SS)"
            fi
            
            local closest_backup
            closest_backup=$(point_in_time_recovery "$target_date")
            
            echo ""
            read -p "Restore from this backup? (y/N): " confirm
            if [[ "$confirm" == "y" ]] || [[ "$confirm" == "Y" ]]; then
                local processed_backup
                processed_backup=$(decrypt_backup "$closest_backup")
                processed_backup=$(decompress_backup "$processed_backup")
                verify_backup "$processed_backup"
                restore_database "$processed_backup"
            else
                log "Restore cancelled by user"
            fi
            ;;
            
        "verify")
            local backup_file="$2"
            if [[ -z "$backup_file" ]]; then
                error_exit "Please specify backup file to verify"
            fi
            
            local processed_backup
            processed_backup=$(decrypt_backup "$backup_file")
            processed_backup=$(decompress_backup "$processed_backup")
            verify_backup "$processed_backup"
            log "Backup verification completed successfully"
            ;;
            
        *)
            cat << EOF
Usage: $0 <command> [options]

Commands:
  list                          List available backups
  interactive                   Interactive backup selection and restore
  file <backup_path>           Restore from specific backup file
  cloud <backup_filename>      Restore from cloud backup
  point-in-time <date>         Find and restore closest backup to date
  verify <backup_path>         Verify backup integrity

Examples:
  $0 list
  $0 interactive
  $0 file /app/backups/ajudadorabot_backup_20240101_120000.db.gz
  $0 cloud ajudadorabot_backup_20240101_120000.db.gz.enc
  $0 point-in-time "2024-01-01 12:00:00"
  $0 verify /app/backups/ajudadorabot_backup_20240101_120000.db
EOF
            exit 1
            ;;
    esac
    
    local duration=$(($(date +%s) - start_time))
    log "Restore process completed in ${duration}s"
}

# Run main function with all arguments
main "$@"