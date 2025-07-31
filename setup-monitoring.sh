#!/bin/bash

# Setup Monitoring and Alerting for Google Cloud Toy API
# Configures Cloud Monitoring, alerting policies, and dashboards

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID_DEV="toy-api-dev"
PROJECT_ID_STAGING="toy-api-staging"
PROJECT_ID_PROD="toy-api-prod"
NOTIFICATION_EMAIL=""  # REQUIRED: Set your email for alerts
REGION="us-central1"
SERVICE_NAME="toy-api-service"

echo -e "${BLUE}🚀 Setting up Monitoring and Alerting${NC}"
echo -e "${BLUE}===================================${NC}"

# Check if notification email is set
if [ -z "$NOTIFICATION_EMAIL" ]; then
    echo -e "${RED}❌ Error: NOTIFICATION_EMAIL is not set${NC}"
    echo -e "${YELLOW}Please edit this script and set your email address:${NC}"
    echo -e "${YELLOW}NOTIFICATION_EMAIL=\"your-email@example.com\"${NC}"
    exit 1
fi

# Setup monitoring for a project
setup_monitoring() {
    local project_id=$1
    local environment=$2
    
    echo -e "\n${YELLOW}📊 Setting up monitoring for $environment environment${NC}"
    echo -e "${YELLOW}Project: $project_id${NC}"
    
    # Set current project
    gcloud config set project $project_id
    
    # Enable required APIs
    echo -e "${BLUE}🔧 Enabling required APIs...${NC}"
    gcloud services enable monitoring.googleapis.com --quiet
    gcloud services enable logging.googleapis.com --quiet
    gcloud services enable clouderrorreporting.googleapis.com --quiet
    gcloud services enable cloudtrace.googleapis.com --quiet
    
    echo -e "${GREEN}✅ APIs enabled for $environment${NC}"
}

# Create notification channel
create_notification_channel() {
    local project_id=$1
    local environment=$2
    
    echo -e "\n${YELLOW}📧 Creating notification channel for $environment${NC}"
    
    gcloud config set project $project_id
    
    # Check if notification channel already exists
    EXISTING_CHANNEL=$(gcloud alpha monitoring channels list \
        --filter="displayName:'Email Alerts - $environment'" \
        --format="value(name)" 2>/dev/null || echo "")
    
    if [ ! -z "$EXISTING_CHANNEL" ]; then
        echo -e "${YELLOW}⚠️  Notification channel already exists: $EXISTING_CHANNEL${NC}"
        echo $EXISTING_CHANNEL
        return 0
    fi
    
    # Create notification channel
    cat > /tmp/notification-channel-${environment}.json << EOF
{
  "type": "email",
  "displayName": "Email Alerts - $environment",
  "description": "Email notifications for $environment environment alerts",
  "labels": {
    "email_address": "$NOTIFICATION_EMAIL"
  },
  "enabled": true
}
EOF
    
    CHANNEL_NAME=$(gcloud alpha monitoring channels create \
        --channel-content-from-file=/tmp/notification-channel-${environment}.json \
        --format="value(name)")
    
    echo -e "${GREEN}✅ Notification channel created: $CHANNEL_NAME${NC}"
    rm /tmp/notification-channel-${environment}.json
    echo $CHANNEL_NAME
}

# Create alerting policies
create_alerting_policies() {
    local project_id=$1
    local environment=$2
    local notification_channel=$3
    
    echo -e "\n${YELLOW}🚨 Creating alerting policies for $environment${NC}"
    
    gcloud config set project $project_id
    
    # 1. High Error Rate Alert (>5% errors in 5 minutes)
    cat > /tmp/alert-error-rate-${environment}.yaml << EOF
displayName: "High Error Rate - $environment"
documentation:
  content: "Error rate is above 5% for the last 5 minutes in $environment"
  mimeType: "text/markdown"
conditions:
  - displayName: "Error rate > 5%"
    conditionThreshold:
      filter: 'resource.type="cloud_run_revision" AND resource.labels.service_name="${SERVICE_NAME}-${environment}" AND metric.type="run.googleapis.com/request_count"'
      comparison: COMPARISON_GREATER_THAN
      thresholdValue: 0.05
      duration: 300s
      aggregations:
        - alignmentPeriod: 60s
          perSeriesAligner: ALIGN_RATE
          crossSeriesReducer: REDUCE_MEAN
          groupByFields:
            - "resource.label.service_name"
notificationChannels:
  - "$notification_channel"
alertStrategy:
  autoClose: 86400s
enabled: true
EOF
    
    gcloud alpha monitoring policies create --policy-from-file=/tmp/alert-error-rate-${environment}.yaml
    echo -e "${GREEN}✅ Error rate alert policy created${NC}"
    
    # 2. High Response Time Alert (>3s average in 5 minutes)
    cat > /tmp/alert-response-time-${environment}.yaml << EOF
displayName: "High Response Time - $environment"
documentation:
  content: "Average response time is above 3 seconds for the last 5 minutes in $environment"
  mimeType: "text/markdown"
conditions:
  - displayName: "Response time > 3s"
    conditionThreshold:
      filter: 'resource.type="cloud_run_revision" AND resource.labels.service_name="${SERVICE_NAME}-${environment}" AND metric.type="run.googleapis.com/request_latencies"'
      comparison: COMPARISON_GREATER_THAN
      thresholdValue: 3000
      duration: 300s
      aggregations:
        - alignmentPeriod: 60s
          perSeriesAligner: ALIGN_MEAN
          crossSeriesReducer: REDUCE_MEAN
          groupByFields:
            - "resource.label.service_name"
notificationChannels:
  - "$notification_channel"
alertStrategy:
  autoClose: 86400s
enabled: true
EOF
    
    gcloud alpha monitoring policies create --policy-from-file=/tmp/alert-response-time-${environment}.yaml
    echo -e "${GREEN}✅ Response time alert policy created${NC}"
    
    # 3. Service Down Alert (no requests in 10 minutes)
    cat > /tmp/alert-service-down-${environment}.yaml << EOF
displayName: "Service Down - $environment"
documentation:
  content: "No requests received for the last 10 minutes in $environment - service may be down"
  mimeType: "text/markdown"
conditions:
  - displayName: "No requests in 10 minutes"
    conditionThreshold:
      filter: 'resource.type="cloud_run_revision" AND resource.labels.service_name="${SERVICE_NAME}-${environment}" AND metric.type="run.googleapis.com/request_count"'
      comparison: COMPARISON_LESS_THAN
      thresholdValue: 1
      duration: 600s
      aggregations:
        - alignmentPeriod: 300s
          perSeriesAligner: ALIGN_RATE
          crossSeriesReducer: REDUCE_SUM
          groupByFields:
            - "resource.label.service_name"
notificationChannels:
  - "$notification_channel"
alertStrategy:
  autoClose: 86400s
enabled: true
EOF
    
    gcloud alpha monitoring policies create --policy-from-file=/tmp/alert-service-down-${environment}.yaml
    echo -e "${GREEN}✅ Service down alert policy created${NC}"
    
    # 4. High Memory Usage Alert (>80% memory)
    cat > /tmp/alert-memory-usage-${environment}.yaml << EOF
displayName: "High Memory Usage - $environment"
documentation:
  content: "Memory usage is above 80% for the last 5 minutes in $environment"
  mimeType: "text/markdown"
conditions:
  - displayName: "Memory usage > 80%"
    conditionThreshold:
      filter: 'resource.type="cloud_run_revision" AND resource.labels.service_name="${SERVICE_NAME}-${environment}" AND metric.type="run.googleapis.com/container/memory/utilizations"'
      comparison: COMPARISON_GREATER_THAN
      thresholdValue: 0.8
      duration: 300s
      aggregations:
        - alignmentPeriod: 60s
          perSeriesAligner: ALIGN_MEAN
          crossSeriesReducer: REDUCE_MEAN
          groupByFields:
            - "resource.label.service_name"
notificationChannels:
  - "$notification_channel"
alertStrategy:
  autoClose: 86400s
enabled: true
EOF
    
    gcloud alpha monitoring policies create --policy-from-file=/tmp/alert-memory-usage-${environment}.yaml
    echo -e "${GREEN}✅ Memory usage alert policy created${NC}"
    
    # Clean up temp files
    rm /tmp/alert-*-${environment}.yaml
    
    echo -e "${GREEN}✅ All alerting policies created for $environment${NC}"
}

# Create custom dashboard
create_custom_dashboard() {
    local project_id=$1
    local environment=$2
    
    echo -e "\n${YELLOW}📈 Creating custom dashboard for $environment${NC}"
    
    gcloud config set project $project_id
    
    # Create dashboard configuration
    cat > /tmp/dashboard-${environment}.json << EOF
{
  "displayName": "Toy API - $environment Environment",
  "mosaicLayout": {
    "tiles": [
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "Request Rate",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${SERVICE_NAME}-${environment}\" AND metric.type=\"run.googleapis.com/request_count\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_RATE",
                      "crossSeriesReducer": "REDUCE_SUM"
                    }
                  }
                },
                "targetAxis": "Y1"
              }
            ],
            "timeshiftDuration": "0s",
            "yAxis": {
              "label": "Requests/second",
              "scale": "LINEAR"
            }
          }
        }
      },
      {
        "width": 6,
        "height": 4,
        "xPos": 6,
        "widget": {
          "title": "Response Latency",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${SERVICE_NAME}-${environment}\" AND metric.type=\"run.googleapis.com/request_latencies\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_MEAN",
                      "crossSeriesReducer": "REDUCE_MEAN"
                    }
                  }
                },
                "targetAxis": "Y1"
              }
            ],
            "yAxis": {
              "label": "Latency (ms)",
              "scale": "LINEAR"
            }
          }
        }
      },
      {
        "width": 6,
        "height": 4,
        "yPos": 4,
        "widget": {
          "title": "Memory Usage",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${SERVICE_NAME}-${environment}\" AND metric.type=\"run.googleapis.com/container/memory/utilizations\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_MEAN",
                      "crossSeriesReducer": "REDUCE_MEAN"
                    }
                  }
                },
                "targetAxis": "Y1"
              }
            ],
            "yAxis": {
              "label": "Memory %",
              "scale": "LINEAR"
            }
          }
        }
      },
      {
        "width": 6,
        "height": 4,
        "xPos": 6,
        "yPos": 4,
        "widget": {
          "title": "CPU Usage",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${SERVICE_NAME}-${environment}\" AND metric.type=\"run.googleapis.com/container/cpu/utilizations\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_MEAN",
                      "crossSeriesReducer": "REDUCE_MEAN"
                    }
                  }
                },
                "targetAxis": "Y1"
              }
            ],
            "yAxis": {
              "label": "CPU %",
              "scale": "LINEAR"
            }
          }
        }
      }
    ]
  }
}
EOF
    
    # Create the dashboard
    DASHBOARD_NAME=$(gcloud monitoring dashboards create \
        --config-from-file=/tmp/dashboard-${environment}.json \
        --format="value(name)")
    
    echo -e "${GREEN}✅ Dashboard created: $DASHBOARD_NAME${NC}"
    echo -e "${BLUE}View at: https://console.cloud.google.com/monitoring/dashboards/custom/${DASHBOARD_NAME##*/}?project=$project_id${NC}"
    
    rm /tmp/dashboard-${environment}.json
}

# Setup uptime checks
create_uptime_checks() {
    local project_id=$1
    local environment=$2
    local notification_channel=$3
    
    echo -e "\n${YELLOW}🔍 Creating uptime checks for $environment${NC}"
    
    gcloud config set project $project_id
    
    # Get the service URL
    SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME}-${environment} \
        --region=$REGION \
        --format="value(status.url)" 2>/dev/null || echo "")
    
    if [ -z "$SERVICE_URL" ]; then
        echo -e "${YELLOW}⚠️  Service not deployed yet, skipping uptime check creation${NC}"
        return 0
    fi
    
    # Create uptime check
    cat > /tmp/uptime-check-${environment}.json << EOF
{
  "displayName": "Toy API Health Check - $environment",
  "monitoredResource": {
    "type": "uptime_url",
    "labels": {
      "project_id": "$project_id",
      "host": "${SERVICE_URL#https://}"
    }
  },
  "httpCheck": {
    "path": "/",
    "port": 443,
    "useSsl": true,
    "validateSsl": true
  },
  "period": "300s",
  "timeout": "10s",
  "contentMatchers": [
    {
      "content": "Hello World",
      "matcher": "CONTAINS_STRING"
    }
  ],
  "selectedRegions": [
    "USA_IOWA",
    "EUROPE_LONDON",
    "ASIA_PACIFIC_SINGAPORE"
  ]
}
EOF
    
    UPTIME_CHECK_ID=$(gcloud monitoring uptime-checks create \
        --uptime-check-from-file=/tmp/uptime-check-${environment}.json \
        --format="value(name)")
    
    echo -e "${GREEN}✅ Uptime check created: $UPTIME_CHECK_ID${NC}"
    
    # Create uptime alert policy
    cat > /tmp/uptime-alert-${environment}.yaml << EOF
displayName: "Uptime Check Failed - $environment"
documentation:
  content: "Uptime check failed for $environment environment"
  mimeType: "text/markdown"
conditions:
  - displayName: "Uptime check failure"
    conditionThreshold:
      filter: "resource.type=\"uptime_url\" AND metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\""
      comparison: COMPARISON_EQUAL
      thresholdValue: 0
      duration: 300s
      aggregations:
        - alignmentPeriod: 300s
          perSeriesAligner: ALIGN_FRACTION_TRUE
          crossSeriesReducer: REDUCE_MEAN
notificationChannels:
  - "$notification_channel"
alertStrategy:
  autoClose: 86400s
enabled: true
EOF
    
    gcloud alpha monitoring policies create --policy-from-file=/tmp/uptime-alert-${environment}.yaml
    echo -e "${GREEN}✅ Uptime alert policy created${NC}"
    
    rm /tmp/uptime-check-${environment}.json /tmp/uptime-alert-${environment}.yaml
}

# Main setup process
main() {
    echo -e "${BLUE}Starting monitoring and alerting setup...${NC}\n"
    
    # Check prerequisites
    if ! command -v gcloud &> /dev/null; then
        echo -e "${RED}❌ gcloud CLI not found. Please install Google Cloud SDK.${NC}"
        exit 1
    fi
    
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        echo -e "${RED}❌ Not authenticated with gcloud. Please run 'gcloud auth login'${NC}"
        exit 1
    fi
    
    # Show configuration
    echo -e "${BLUE}Configuration:${NC}"
    echo -e "Notification Email: ${YELLOW}$NOTIFICATION_EMAIL${NC}"
    echo -e "Dev Project: ${YELLOW}$PROJECT_ID_DEV${NC}"
    
    read -p "Press Enter to continue or Ctrl+C to abort..."
    
    # Setup dev environment
    echo -e "\n${BLUE}=== Setting up DEV environment monitoring ===${NC}"
    setup_monitoring $PROJECT_ID_DEV "dev"
    NOTIFICATION_CHANNEL_DEV=$(create_notification_channel $PROJECT_ID_DEV "dev")
    create_alerting_policies $PROJECT_ID_DEV "dev" "$NOTIFICATION_CHANNEL_DEV"
    create_custom_dashboard $PROJECT_ID_DEV "dev"
    create_uptime_checks $PROJECT_ID_DEV "dev" "$NOTIFICATION_CHANNEL_DEV"
    
    # Ask about other environments
    echo -e "\n${BLUE}Do you want to setup monitoring for staging environment? (y/n)${NC}"
    read -r setup_staging
    if [[ $setup_staging == "y" || $setup_staging == "Y" ]]; then
        echo -e "\n${BLUE}=== Setting up STAGING environment monitoring ===${NC}"
        setup_monitoring $PROJECT_ID_STAGING "staging"
        NOTIFICATION_CHANNEL_STAGING=$(create_notification_channel $PROJECT_ID_STAGING "staging")
        create_alerting_policies $PROJECT_ID_STAGING "staging" "$NOTIFICATION_CHANNEL_STAGING"
        create_custom_dashboard $PROJECT_ID_STAGING "staging"
        create_uptime_checks $PROJECT_ID_STAGING "staging" "$NOTIFICATION_CHANNEL_STAGING"
    fi
    
    echo -e "\n${BLUE}Do you want to setup monitoring for production environment? (y/n)${NC}"
    read -r setup_prod
    if [[ $setup_prod == "y" || $setup_prod == "Y" ]]; then
        echo -e "\n${BLUE}=== Setting up PRODUCTION environment monitoring ===${NC}"
        setup_monitoring $PROJECT_ID_PROD "prod"
        NOTIFICATION_CHANNEL_PROD=$(create_notification_channel $PROJECT_ID_PROD "prod")
        create_alerting_policies $PROJECT_ID_PROD "prod" "$NOTIFICATION_CHANNEL_PROD"
        create_custom_dashboard $PROJECT_ID_PROD "prod"
        create_uptime_checks $PROJECT_ID_PROD "prod" "$NOTIFICATION_CHANNEL_PROD"
    fi
    
    echo -e "\n${GREEN}🎉 Monitoring and alerting setup completed!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${BLUE}What was configured:${NC}"
    echo -e "✅ Cloud Monitoring enabled"
    echo -e "✅ Email notification channels"
    echo -e "✅ Alerting policies (error rate, response time, service down, memory)"
    echo -e "✅ Custom dashboards with key metrics"
    echo -e "✅ Uptime monitoring with external checks"
    echo -e "\n${BLUE}Access your monitoring at:${NC}"
    echo -e "${YELLOW}https://console.cloud.google.com/monitoring?project=$PROJECT_ID_DEV${NC}"
    echo -e "\n${BLUE}Next: Set up security enhancements${NC}"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi