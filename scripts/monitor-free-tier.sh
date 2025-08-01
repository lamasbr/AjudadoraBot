#!/bin/bash
# Bash script for monitoring Azure Free Tier usage and costs
# This script helps track usage against free tier limits to avoid unexpected charges

set -e

# Configuration
APP_NAME="ajudadorabot"
ENVIRONMENT="production"
RESOURCE_GROUP="${APP_NAME}-${ENVIRONMENT}-rg"
APP_SERVICE_NAME="${APP_NAME}-${ENVIRONMENT}-app"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Free tier limits
FREE_TIER_COMPUTE_MINUTES_PER_DAY=60
FREE_TIER_STORAGE_GB=1
FREE_TIER_BANDWIDTH_MB_PER_DAY=165
FREE_TIER_KEY_VAULT_OPERATIONS_PER_MONTH=25000
DATADOG_FREE_TIER_HOSTS=5
DATADOG_FREE_RETENTION_DAYS=1

print_header() {
    echo -e "${CYAN}======================================${NC}"
    echo -e "${CYAN}🔍 Azure Free Tier Usage Monitor${NC}"
    echo -e "${CYAN}======================================${NC}"
    echo -e "${BLUE}App: ${APP_NAME}${NC}"
    echo -e "${BLUE}Environment: ${ENVIRONMENT}${NC}"
    echo -e "${BLUE}Resource Group: ${RESOURCE_GROUP}${NC}"
    echo ""
}

check_azure_login() {
    echo -e "${BLUE}🔐 Checking Azure login status...${NC}"
    if ! az account show &>/dev/null; then
        echo -e "${RED}❌ Not logged in to Azure. Please run 'az login'${NC}"
        exit 1
    fi
    
    local subscription_name=$(az account show --query name -o tsv)
    echo -e "${GREEN}✅ Logged in to Azure${NC}"
    echo -e "${BLUE}📋 Subscription: ${subscription_name}${NC}"
    echo ""
}

check_resource_group() {
    echo -e "${BLUE}📦 Checking resource group...${NC}"
    if ! az group show --name "$RESOURCE_GROUP" &>/dev/null; then
        echo -e "${RED}❌ Resource group '$RESOURCE_GROUP' not found${NC}"
        exit 1
    fi
    
    local location=$(az group show --name "$RESOURCE_GROUP" --query location -o tsv)
    echo -e "${GREEN}✅ Resource group exists${NC}"
    echo -e "${BLUE}📍 Location: ${location}${NC}"
    echo ""
}

check_app_service_plan() {
    echo -e "${BLUE}🖥️  Checking App Service Plan...${NC}"
    
    local app_service_plan=$(az appservice plan list --resource-group "$RESOURCE_GROUP" --query "[0]" -o json 2>/dev/null)
    
    if [ "$app_service_plan" == "null" ] || [ -z "$app_service_plan" ]; then
        echo -e "${RED}❌ No App Service Plan found${NC}"
        return 1
    fi
    
    local plan_name=$(echo "$app_service_plan" | jq -r '.name')
    local sku_name=$(echo "$app_service_plan" | jq -r '.sku.name')
    local sku_tier=$(echo "$app_service_plan" | jq -r '.sku.tier')
    
    echo -e "${BLUE}📊 Plan: ${plan_name}${NC}"
    echo -e "${BLUE}💰 SKU: ${sku_name} (${sku_tier})${NC}"
    
    if [ "$sku_name" == "F1" ]; then
        echo -e "${GREEN}✅ Using Free tier (F1)${NC}"
        echo -e "${CYAN}📋 Free tier limits:${NC}"
        echo -e "   • ${FREE_TIER_COMPUTE_MINUTES_PER_DAY} minutes compute/day"
        echo -e "   • ${FREE_TIER_STORAGE_GB} GB storage"
        echo -e "   • ${FREE_TIER_BANDWIDTH_MB_PER_DAY} MB bandwidth/day"
    else
        echo -e "${RED}⚠️  NOT using free tier! Current: ${sku_name}${NC}"
        echo -e "${YELLOW}💸 This may incur charges${NC}"
    fi
    echo ""
}

get_app_service_metrics() {
    echo -e "${BLUE}📊 Getting App Service metrics (last 24 hours)...${NC}"
    
    local app_service_id=$(az webapp show --name "$APP_SERVICE_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv 2>/dev/null)
    
    if [ -z "$app_service_id" ]; then
        echo -e "${RED}❌ App Service '$APP_SERVICE_NAME' not found${NC}"
        return 1
    fi
    
    local end_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local start_time=$(date -u -d '24 hours ago' +"%Y-%m-%dT%H:%M:%SZ")
    
    echo -e "${BLUE}🕒 Time range: ${start_time} to ${end_time}${NC}"
    
    # CPU Usage
    echo -e "${CYAN}🔄 Checking CPU usage...${NC}"
    local cpu_data=$(az monitor metrics list \
        --resource "$app_service_id" \
        --metric "CpuPercentage" \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --interval PT1H \
        --aggregation Average \
        --query "value[0].timeseries[0].data" -o json 2>/dev/null)
    
    if [ "$cpu_data" != "null" ] && [ -n "$cpu_data" ]; then
        local avg_cpu=$(echo "$cpu_data" | jq '[.[].average] | add / length' 2>/dev/null | cut -d. -f1)
        if [ -n "$avg_cpu" ] && [ "$avg_cpu" != "null" ]; then
            echo -e "   CPU Average: ${avg_cpu}%"
            
            if [ "$avg_cpu" -gt 80 ]; then
                echo -e "   ${RED}⚠️  High CPU usage detected${NC}"
            elif [ "$avg_cpu" -gt 60 ]; then
                echo -e "   ${YELLOW}⚠️  Moderate CPU usage${NC}"
            else
                echo -e "   ${GREEN}✅ CPU usage normal${NC}"
            fi
        fi
    fi
    
    # Memory Usage
    echo -e "${CYAN}🧠 Checking Memory usage...${NC}"
    local memory_data=$(az monitor metrics list \
        --resource "$app_service_id" \
        --metric "MemoryPercentage" \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --interval PT1H \
        --aggregation Average \
        --query "value[0].timeseries[0].data" -o json 2>/dev/null)
    
    if [ "$memory_data" != "null" ] && [ -n "$memory_data" ]; then
        local avg_memory=$(echo "$memory_data" | jq '[.[].average] | add / length' 2>/dev/null | cut -d. -f1)
        if [ -n "$avg_memory" ] && [ "$avg_memory" != "null" ]; then
            echo -e "   Memory Average: ${avg_memory}%"
            
            if [ "$avg_memory" -gt 85 ]; then
                echo -e "   ${RED}⚠️  High memory usage detected${NC}"
            elif [ "$avg_memory" -gt 70 ]; then
                echo -e "   ${YELLOW}⚠️  Moderate memory usage${NC}"
            else
                echo -e "   ${GREEN}✅ Memory usage normal${NC}"
            fi
        fi
    fi
    
    # Bandwidth Usage (Data Out)
    echo -e "${CYAN}🌐 Checking Bandwidth usage...${NC}"
    local bandwidth_data=$(az monitor metrics list \
        --resource "$app_service_id" \
        --metric "BytesSent" \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --interval PT1H \
        --aggregation Total \
        --query "value[0].timeseries[0].data" -o json 2>/dev/null)
    
    if [ "$bandwidth_data" != "null" ] && [ -n "$bandwidth_data" ]; then
        local total_bytes=$(echo "$bandwidth_data" | jq '[.[].total] | add' 2>/dev/null)
        if [ -n "$total_bytes" ] && [ "$total_bytes" != "null" ]; then
            local total_mb=$(echo "scale=2; $total_bytes / 1048576" | bc)
            local usage_percent=$(echo "scale=1; $total_mb * 100 / $FREE_TIER_BANDWIDTH_MB_PER_DAY" | bc)
            
            echo -e "   Data Out (24h): ${total_mb} MB"
            echo -e "   Daily limit usage: ${usage_percent}% (${FREE_TIER_BANDWIDTH_MB_PER_DAY} MB limit)"
            
            if (( $(echo "$usage_percent > 90" | bc -l) )); then
                echo -e "   ${RED}⚠️  Approaching daily bandwidth limit!${NC}"
                echo -e "   ${YELLOW}💡 Consider optimizing static assets${NC}"
            elif (( $(echo "$usage_percent > 70" | bc -l) )); then
                echo -e "   ${YELLOW}⚠️  High bandwidth usage${NC}"
            else
                echo -e "   ${GREEN}✅ Bandwidth usage normal${NC}"
            fi
        fi
    fi
    
    # Request Count
    echo -e "${CYAN}📨 Checking Request count...${NC}"
    local request_data=$(az monitor metrics list \
        --resource "$app_service_id" \
        --metric "Requests" \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --interval PT1H \
        --aggregation Total \
        --query "value[0].timeseries[0].data" -o json 2>/dev/null)
    
    if [ "$request_data" != "null" ] && [ -n "$request_data" ]; then
        local total_requests=$(echo "$request_data" | jq '[.[].total] | add' 2>/dev/null)
        if [ -n "$total_requests" ] && [ "$total_requests" != "null" ]; then
            echo -e "   Total Requests (24h): ${total_requests}"
        fi
    fi
    
    echo ""
}

check_storage_usage() {
    echo -e "${BLUE}💾 Checking Storage usage...${NC}"
    
    # Check if storage account exists (optional in our setup)
    local storage_account=$(az storage account list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv 2>/dev/null)
    
    if [ -n "$storage_account" ] && [ "$storage_account" != "null" ]; then
        echo -e "${BLUE}📦 Storage Account: ${storage_account}${NC}"
        
        # Get storage usage (requires storage account key)
        local storage_key=$(az storage account keys list --resource-group "$RESOURCE_GROUP" --account-name "$storage_account" --query "[0].value" -o tsv 2>/dev/null)
        
        if [ -n "$storage_key" ]; then
            local usage_mb=$(az storage account show-usage --name "$storage_account" --query "usedCapacity" -o tsv 2>/dev/null)
            if [ -n "$usage_mb" ] && [ "$usage_mb" != "null" ]; then
                local usage_gb=$(echo "scale=2; $usage_mb / 1024" | bc)
                local usage_percent=$(echo "scale=1; $usage_gb * 100 / $FREE_TIER_STORAGE_GB" | bc)
                
                echo -e "   Storage Used: ${usage_gb} GB"
                echo -e "   Storage Limit Usage: ${usage_percent}% (${FREE_TIER_STORAGE_GB} GB limit)"
                
                if (( $(echo "$usage_percent > 90" | bc -l) )); then
                    echo -e "   ${RED}⚠️  Approaching storage limit!${NC}"
                elif (( $(echo "$usage_percent > 70" | bc -l) )); then
                    echo -e "   ${YELLOW}⚠️  High storage usage${NC}"
                else
                    echo -e "   ${GREEN}✅ Storage usage normal${NC}"
                fi
            fi
        fi
    else
        echo -e "${BLUE}📦 Using App Service local storage (included in 1GB limit)${NC}"
        echo -e "${CYAN}💡 SQLite database stored in /home/data${NC}"
    fi
    echo ""
}

check_key_vault_usage() {
    echo -e "${BLUE}🔐 Checking Key Vault usage...${NC}"
    
    local key_vault=$(az keyvault list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv 2>/dev/null)
    
    if [ -n "$key_vault" ] && [ "$key_vault" != "null" ]; then
        echo -e "${BLUE}🔑 Key Vault: ${key_vault}${NC}"
        
        # Count secrets
        local secret_count=$(az keyvault secret list --vault-name "$key_vault" --query "length(@)" -o tsv 2>/dev/null)
        if [ -n "$secret_count" ]; then
            echo -e "   Secrets stored: ${secret_count}"
        fi
        
        echo -e "${CYAN}📋 Free tier limit: ${FREE_TIER_KEY_VAULT_OPERATIONS_PER_MONTH} operations/month${NC}"
        echo -e "${YELLOW}💡 Monitor Key Vault operations in Azure portal${NC}"
    else
        echo -e "${YELLOW}⚠️  No Key Vault found${NC}"
    fi
    echo ""
}

check_datadog_integration() {
    echo -e "${BLUE}📊 Checking Datadog integration...${NC}"
    
    # Check environment variables in app service
    local dd_api_key_set=$(az webapp config appsettings list --name "$APP_SERVICE_NAME" --resource-group "$RESOURCE_GROUP" --query "[?name=='DD_API_KEY'].value" -o tsv 2>/dev/null)
    
    if [ -n "$dd_api_key_set" ]; then
        echo -e "${GREEN}✅ Datadog API key configured${NC}"
        echo -e "${CYAN}📋 Datadog free tier limits:${NC}"
        echo -e "   • ${DATADOG_FREE_TIER_HOSTS} hosts maximum"
        echo -e "   • ${DATADOG_FREE_RETENTION_DAYS} day log retention"
        echo -e "${YELLOW}💡 Monitor host count in Datadog dashboard${NC}"
    else
        echo -e "${YELLOW}⚠️  Datadog API key not found in app settings${NC}"
    fi
    echo ""
}

generate_cost_report() {
    echo -e "${BLUE}📄 Generating cost optimization report...${NC}"
    
    local report_file="free-tier-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
Azure Free Tier Cost Report
Generated: $(date)
App: $APP_NAME
Environment: $ENVIRONMENT
Resource Group: $RESOURCE_GROUP

=== Free Tier Limits ===
App Service Plan: F1 (Free)
- Compute: $FREE_TIER_COMPUTE_MINUTES_PER_DAY minutes/day
- Storage: $FREE_TIER_STORAGE_GB GB
- Bandwidth: $FREE_TIER_BANDWIDTH_MB_PER_DAY MB/day
- Custom domains: 0
- SSL certificates: Shared only

Key Vault: Standard (Free operations)
- Operations: $FREE_TIER_KEY_VAULT_OPERATIONS_PER_MONTH/month

Datadog: Free tier
- Hosts: $DATADOG_FREE_TIER_HOSTS maximum
- Retention: $DATADOG_FREE_RETENTION_DAYS day

=== Recommendations ===
1. Monitor daily bandwidth usage to avoid overages
2. Use SQLite with local storage to minimize costs
3. Implement caching for static assets
4. Monitor Key Vault operations usage
5. Keep Datadog host count under $DATADOG_FREE_TIER_HOSTS
6. Use GitHub Container Registry (free) instead of ACR
7. Disable unnecessary app service features
8. Monitor compute time to stay under 60 min/day limit

=== Cost Optimization Checklist ===
[ ] App Service Plan is F1 (Free tier)
[ ] AlwaysOn is disabled (not available on F1)
[ ] Using GitHub Container Registry
[ ] Static assets are cached and optimized
[ ] SQLite database is used instead of Azure SQL
[ ] Minimal logging retention (3-7 days)
[ ] No staging slots (F1 limitation)
[ ] No custom domains (F1 limitation)
[ ] Datadog host count ≤ $DATADOG_FREE_TIER_HOSTS
[ ] Key Vault operations < $FREE_TIER_KEY_VAULT_OPERATIONS_PER_MONTH/month

EOF

    echo -e "${GREEN}✅ Report generated: ${report_file}${NC}"
    echo ""
}

show_recommendations() {
    echo -e "${CYAN}💡 Cost Optimization Recommendations:${NC}"
    echo ""
    echo -e "${YELLOW}1. Monitor Usage Daily:${NC}"
    echo -e "   • Run this script daily to track usage"
    echo -e "   • Set up Azure alerts for metric thresholds"
    echo ""
    echo -e "${YELLOW}2. Optimize Static Assets:${NC}"
    echo -e "   • Use CDN or optimize images to reduce bandwidth"
    echo -e "   • Enable compression for JS/CSS files"
    echo ""
    echo -e "${YELLOW}3. Database Optimization:${NC}"
    echo -e "   • SQLite is optimal for free tier"
    echo -e "   • Implement regular cleanup of old data"
    echo ""
    echo -e "${YELLOW}4. Monitoring Strategy:${NC}"
    echo -e "   • Use Datadog free tier efficiently"
    echo -e "   • Focus on critical metrics only"
    echo ""
    echo -e "${YELLOW}5. Backup Strategy:${NC}"
    echo -e "   • Manual exports instead of automated backups"
    echo -e "   • Use GitHub for code and configuration backups"
    echo ""
}

# Main execution
main() {
    print_header
    check_azure_login
    check_resource_group
    check_app_service_plan
    get_app_service_metrics
    check_storage_usage
    check_key_vault_usage
    check_datadog_integration
    generate_cost_report
    show_recommendations
    
    echo -e "${GREEN}🎉 Free tier monitoring completed!${NC}"
    echo -e "${BLUE}💡 Run this script regularly to track usage and avoid unexpected charges${NC}"
}

# Check for required tools
if ! command -v az &> /dev/null; then
    echo -e "${RED}❌ Azure CLI is not installed${NC}"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}❌ jq is not installed${NC}"
    exit 1
fi

if ! command -v bc &> /dev/null; then
    echo -e "${RED}❌ bc is not installed${NC}"
    exit 1
fi

# Run main function
main "$@"