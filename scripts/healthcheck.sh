#!/bin/bash
# AjudadoraBot Health Check Script
# Used by Docker HEALTHCHECK and monitoring systems

set -euo pipefail

# Configuration
API_URL="${API_URL:-http://localhost:8080}"
DATABASE_PATH="${DATABASE_PATH:-/app/data/ajudadorabot.db}"
MAX_RESPONSE_TIME="${MAX_RESPONSE_TIME:-5}"
TIMEOUT="${TIMEOUT:-10}"

# Health check function
check_api_health() {
    local start_time=$(date +%s.%N)
    
    # Check health endpoint
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time "$TIMEOUT" \
        "$API_URL/health" || echo "000")
    
    local end_time=$(date +%s.%N)
    local response_time=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
    
    if [[ "$http_code" != "200" ]]; then
        echo "UNHEALTHY: API returned HTTP $http_code"
        return 1
    fi
    
    # Check response time
    if (( $(echo "$response_time > $MAX_RESPONSE_TIME" | bc -l) )); then
        echo "UNHEALTHY: Response time ${response_time}s exceeds ${MAX_RESPONSE_TIME}s"
        return 1
    fi
    
    return 0
}

# Check database connectivity
check_database() {
    if [[ ! -f "$DATABASE_PATH" ]]; then
        echo "UNHEALTHY: Database file not found"
        return 1
    fi
    
    # Simple query test
    if ! sqlite3 "$DATABASE_PATH" "SELECT 1;" &>/dev/null; then
        echo "UNHEALTHY: Database query failed"
        return 1
    fi
    
    return 0
}

# Main health check
main() {
    local exit_code=0
    
    # Check API
    if ! check_api_health; then
        exit_code=1
    fi
    
    # Check database
    if ! check_database; then
        exit_code=1
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        echo "HEALTHY: All checks passed"
    fi
    
    exit $exit_code
}

main "$@"