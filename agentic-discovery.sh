#!/bin/bash

# Agentic Resource Discovery Script
# Automatically discovers all resources across toy-api projects

set -e

echo "🔍 AGENTIC RESOURCE DISCOVERY"
echo "=============================="

PROJECTS=("toy-api-dev" "toy-api-stage" "toy-api-prod")
TOTAL_RESOURCES=0

for project in "${PROJECTS[@]}"; do
    echo ""
    echo "📋 PROJECT: $project"
    echo "-------------------"
    
    gcloud config set project $project --quiet
    
    # Cloud Run Services
    echo "🏃 Cloud Run Services:"
    SERVICES=$(gcloud run services list --format="value(metadata.name)" 2>/dev/null | wc -l)
    echo "  Count: $SERVICES"
    if [ $SERVICES -gt 0 ]; then
        gcloud run services list --format="table(metadata.name,status.url,status.conditions[0].status)"
        TOTAL_RESOURCES=$((TOTAL_RESOURCES + SERVICES))
    fi
    
    # Build Triggers
    echo "🔨 Build Triggers:"
    TRIGGERS=$(gcloud builds triggers list --format="value(id)" 2>/dev/null | wc -l)
    echo "  Count: $TRIGGERS"
    if [ $TRIGGERS -gt 0 ]; then
        gcloud builds triggers list --format="table(name,github.owner,github.name,status)"
        TOTAL_RESOURCES=$((TOTAL_RESOURCES + TRIGGERS))
    fi
    
    # Container Images
    echo "📦 Container Images:"
    IMAGES=$(gcloud container images list --format="value(name)" 2>/dev/null | wc -l)
    echo "  Count: $IMAGES"
    if [ $IMAGES -gt 0 ]; then
        gcloud container images list --format="table(name,tags)"
        TOTAL_RESOURCES=$((TOTAL_RESOURCES + IMAGES))
    fi
    
    # Secrets
    echo "🔐 Secrets:"
    SECRETS=$(gcloud secrets list --format="value(name)" 2>/dev/null | wc -l)
    echo "  Count: $SECRETS"
    if [ $SECRETS -gt 0 ]; then
        gcloud secrets list --format="table(name,createTime)"
        TOTAL_RESOURCES=$((TOTAL_RESOURCES + SECRETS))
    fi
    
    # Static IPs
    echo "🌐 Static IP Addresses:"
    GLOBAL_IPS=$(gcloud compute addresses list --global --format="value(name)" 2>/dev/null | wc -l)
    REGIONAL_IPS=$(gcloud compute addresses list --regions=us-central1 --format="value(name)" 2>/dev/null | wc -l)
    TOTAL_IPS=$((GLOBAL_IPS + REGIONAL_IPS))
    echo "  Global: $GLOBAL_IPS, Regional: $REGIONAL_IPS, Total: $TOTAL_IPS"
    if [ $TOTAL_IPS -gt 0 ]; then
        gcloud compute addresses list --format="table(name,region,address,status)"
        TOTAL_RESOURCES=$((TOTAL_RESOURCES + TOTAL_IPS))
    fi
    
    # Storage Buckets
    echo "🪣 Storage Buckets:"
    BUCKETS=$(gsutil ls -p $project 2>/dev/null | wc -l)
    echo "  Count: $BUCKETS"
    if [ $BUCKETS -gt 0 ]; then
        gsutil ls -p $project
        TOTAL_RESOURCES=$((TOTAL_RESOURCES + BUCKETS))
    fi
done

echo ""
echo "📊 DISCOVERY SUMMARY"
echo "==================="
echo "Total billable resources found: $TOTAL_RESOURCES"
echo ""

if [ $TOTAL_RESOURCES -eq 0 ]; then
    echo "✅ No resources to clean up!"
    exit 0
else
    echo "🗑️ Resources ready for cleanup: $TOTAL_RESOURCES"
    echo ""
    echo "Next step: Run ./agentic-cleanup.sh"
fi