#!/bin/bash
# AjudadoraBot Database Backup Script
# Supports SQLite backup with cloud storage integration

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATABASE_PATH="${DATABASE_PATH:-/app/data/ajudadorabot.db}"
BACKUP_DIR="${BACKUP_DIR:-/app/backups}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
CLOUD_BACKUP_ENABLED="${CLOUD_BACKUP_ENABLED:-false}"
AWS_S3_BUCKET="${AWS_S3_BUCKET:-}"
BACKUP_ENCRYPTION_KEY="${BACKUP_ENCRYPTION_KEY:-}"
NOTIFICATION_WEBHOOK="${NOTIFICATION_WEBHOOK:-}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${BACKUP_DIR}/backup.log"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    send_notification "❌ Backup Failed" "$1" "error"
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

# Create backup directory
create_backup_dir() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR" || error_exit "Failed to create backup directory: $BACKUP_DIR"
        log "Created backup directory: $BACKUP_DIR"
    fi
}

# Check database integrity
check_database_integrity() {
    log "Checking database integrity..."
    
    if [[ ! -f "$DATABASE_PATH" ]]; then
        error_exit "Database file not found: $DATABASE_PATH"
    fi
    
    # SQLite integrity check
    if ! sqlite3 "$DATABASE_PATH" "PRAGMA integrity_check;" | grep -q "ok"; then
        error_exit "Database integrity check failed"
    fi
    
    log "Database integrity check passed"
}

# Create SQLite backup
create_sqlite_backup() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_filename="ajudadorabot_backup_${timestamp}.db"
    local backup_path="$BACKUP_DIR/$backup_filename"
    
    log "Creating SQLite backup: $backup_filename"
    
    # Create backup using SQLite .backup command (online backup)
    sqlite3 "$DATABASE_PATH" ".backup '$backup_path'" || error_exit "Failed to create SQLite backup"
    
    # Verify backup
    if ! sqlite3 "$backup_path" "PRAGMA integrity_check;" | grep -q "ok"; then
        rm -f "$backup_path"
        error_exit "Backup verification failed"
    fi
    
    local backup_size=$(du -h "$backup_path" | cut -f1)
    log "Backup created successfully: $backup_filename (Size: $backup_size)"
    
    # Compress backup
    gzip "$backup_path" || error_exit "Failed to compress backup"
    backup_path="${backup_path}.gz"
    
    # Encrypt backup if encryption key is provided
    if [[ -n "$BACKUP_ENCRYPTION_KEY" ]]; then
        log "Encrypting backup..."
        openssl enc -aes-256-cbc -salt -in "$backup_path" -out "${backup_path}.enc" -k "$BACKUP_ENCRYPTION_KEY" || error_exit "Failed to encrypt backup"
        rm -f "$backup_path"
        backup_path="${backup_path}.enc"
        log "Backup encrypted successfully"
    fi
    
    echo "$backup_path"
}

# Upload to cloud storage
upload_to_cloud() {
    local backup_path="$1"
    local filename=$(basename "$backup_path")
    
    if [[ "$CLOUD_BACKUP_ENABLED" != "true" ]] || [[ -z "$AWS_S3_BUCKET" ]]; then
        log "Cloud backup disabled or S3 bucket not configured"
        return 0
    fi
    
    log "Uploading backup to S3: s3://$AWS_S3_BUCKET/backups/$filename"
    
    # Upload to S3 with server-side encryption
    aws s3 cp "$backup_path" "s3://$AWS_S3_BUCKET/backups/$filename" \
        --server-side-encryption AES256 \
        --storage-class STANDARD_IA \
        --metadata "created-by=ajudadorabot-backup,backup-type=sqlite,timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        || error_exit "Failed to upload backup to S3"
    
    log "Backup uploaded to cloud storage successfully"
}

# Clean old backups
cleanup_old_backups() {
    log "Cleaning up backups older than $BACKUP_RETENTION_DAYS days..."
    
    # Local cleanup
    find "$BACKUP_DIR" -name "ajudadorabot_backup_*.db*" -type f -mtime +$BACKUP_RETENTION_DAYS -delete || log "Warning: Failed to clean some local backups"
    
    # Cloud cleanup (if enabled)
    if [[ "$CLOUD_BACKUP_ENABLED" == "true" ]] && [[ -n "$AWS_S3_BUCKET" ]]; then
        local cutoff_date=$(date -u -d "$BACKUP_RETENTION_DAYS days ago" +%Y-%m-%d)
        aws s3 ls "s3://$AWS_S3_BUCKET/backups/" --recursive \
            | awk "\$1 < \"$cutoff_date\" {print \$4}" \
            | xargs -I {} aws s3 rm "s3://$AWS_S3_BUCKET/{}" 2>/dev/null || log "Warning: Failed to clean some cloud backups"
    fi
    
    log "Backup cleanup completed"
}

# Create backup manifest
create_backup_manifest() {
    local backup_path="$1"
    local manifest_file="$BACKUP_DIR/backup_manifest.json"
    local filename=$(basename "$backup_path")
    local backup_size=$(stat -f%z "$backup_path" 2>/dev/null || stat -c%s "$backup_path")
    local backup_hash=$(sha256sum "$backup_path" | cut -d' ' -f1)
    
    # Create or update manifest
    local manifest_entry=$(cat <<EOF
{
    "filename": "$filename",
    "path": "$backup_path",
    "size": $backup_size,
    "sha256": "$backup_hash",
    "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "database_path": "$DATABASE_PATH",
    "encrypted": $([ -n "$BACKUP_ENCRYPTION_KEY" ] && echo "true" || echo "false"),
    "cloud_uploaded": $([ "$CLOUD_BACKUP_ENABLED" == "true" ] && echo "true" || echo "false")
}
EOF
    )
    
    # Add to manifest array
    if [[ -f "$manifest_file" ]]; then
        # Remove the last closing bracket and add new entry
        sed -i '$ s/]//' "$manifest_file"
        echo ",$manifest_entry]" >> "$manifest_file"
    else
        echo "[$manifest_entry]" > "$manifest_file"
    fi
    
    log "Backup manifest updated"
}

# Health check function
health_check() {
    local exit_code=0
    
    # Check if database is accessible
    if ! sqlite3 "$DATABASE_PATH" "SELECT 1;" &>/dev/null; then
        log "ERROR: Database is not accessible"
        exit_code=1
    fi
    
    # Check disk space (ensure at least 1GB free)
    local available_space=$(df "$BACKUP_DIR" | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 1048576 ]]; then  # 1GB in KB
        log "WARNING: Low disk space for backups"
        exit_code=1
    fi
    
    # Check recent backup exists (within last 25 hours)
    local recent_backup=$(find "$BACKUP_DIR" -name "ajudadorabot_backup_*.db*" -mtime -1 | head -1)
    if [[ -z "$recent_backup" ]]; then
        log "WARNING: No recent backup found"
        exit_code=1
    fi
    
    exit $exit_code
}

# Main function
main() {
    local start_time=$(date +%s)
    
    log "Starting AjudadoraBot database backup process..."
    
    # Handle different modes
    case "${1:-backup}" in
        "backup")
            check_dependencies
            create_backup_dir
            check_database_integrity
            
            local backup_path
            backup_path=$(create_sqlite_backup)
            
            upload_to_cloud "$backup_path"
            create_backup_manifest "$backup_path"
            cleanup_old_backups
            
            local duration=$(($(date +%s) - start_time))
            local success_message="Backup completed successfully in ${duration}s. File: $(basename "$backup_path")"
            log "$success_message"
            send_notification "✅ Backup Successful" "$success_message" "success"
            ;;
            
        "health")
            health_check
            ;;
            
        "list")
            log "Available backups:"
            ls -la "$BACKUP_DIR"/ajudadorabot_backup_*.db* 2>/dev/null || log "No backups found"
            ;;
            
        "verify")
            local backup_file="$2"
            if [[ -z "$backup_file" ]]; then
                error_exit "Please specify backup file to verify"
            fi
            
            log "Verifying backup: $backup_file"
            # Add verification logic here
            ;;
            
        *)
            echo "Usage: $0 {backup|health|list|verify <file>}"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"