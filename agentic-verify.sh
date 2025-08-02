#!/bin/bash

# Agentic Verification Script  
# Verifies all resources have been cleaned up successfully

set -e

echo "🔍 AGENTIC CLEANUP VERIFICATION"
echo "==============================="

PROJECTS=("toy-api-dev" "toy-api-stage" "toy-api-prod")
REMAINING_RESOURCES=0

for project in "${PROJECTS[@]}"; do
    echo ""
    echo "✅ VERIFYING PROJECT: $project"
    echo "----------------------------"
    
    gcloud config set project $project --quiet
    
    # Check Cloud Run Services
    SERVICES=$(gcloud run services list --format="value(metadata.name)" 2>/dev/null | wc -l)
    echo "🏃 Cloud Run Services: $SERVICES"
    REMAINING_RESOURCES=$((REMAINING_RESOURCES + SERVICES))
    
    # Check Build Triggers
    TRIGGERS=$(gcloud builds triggers list --format="value(id)" 2>/dev/null | wc -l)
    echo "🔨 Build Triggers: $TRIGGERS"
    REMAINING_RESOURCES=$((REMAINING_RESOURCES + TRIGGERS))
    
    # Check Container Images
    IMAGES=$(gcloud container images list --format="value(name)" 2>/dev/null | wc -l)
    echo "📦 Container Images: $IMAGES"
    REMAINING_RESOURCES=$((REMAINING_RESOURCES + IMAGES))
    
    # Check Secrets
    SECRETS=$(gcloud secrets list --format="value(name)" 2>/dev/null | wc -l)
    echo "🔐 Secrets: $SECRETS"
    REMAINING_RESOURCES=$((REMAINING_RESOURCES + SECRETS))
    
    # Check Static IPs
    GLOBAL_IPS=$(gcloud compute addresses list --global --format="value(name)" 2>/dev/null | wc -l)
    REGIONAL_IPS=$(gcloud compute addresses list --regions=us-central1 --format="value(name)" 2>/dev/null | wc -l)
    TOTAL_IPS=$((GLOBAL_IPS + REGIONAL_IPS))
    echo "🌐 Static IP Addresses: $TOTAL_IPS"
    REMAINING_RESOURCES=$((REMAINING_RESOURCES + TOTAL_IPS))
    
    # Check Storage Buckets (only count non-artifacts buckets)
    BUCKETS=$(gsutil ls -p $project 2>/dev/null | grep -v "gs://artifacts\." | wc -l || echo "0")
    echo "🪣 Storage Buckets: $BUCKETS"
    REMAINING_RESOURCES=$((REMAINING_RESOURCES + BUCKETS))
done

echo ""
echo "📊 VERIFICATION SUMMARY"
echo "======================="

if [ $REMAINING_RESOURCES -eq 0 ]; then
    echo "🎉 SUCCESS: All resources have been cleaned up!"
    echo "💰 Billing impact: $0/month"
    echo ""
    echo "📋 FINAL STATUS:"
    echo "  ✅ Cloud Run services: 0"
    echo "  ✅ Build triggers: 0"  
    echo "  ✅ Container images: 0"
    echo "  ✅ Secrets: 0"
    echo "  ✅ Static IP addresses: 0"
    echo "  ✅ Storage buckets: 0"
    echo ""
    echo "🏁 CLEANUP COMPLETE - No ongoing costs!"
else
    echo "⚠️  WARNING: $REMAINING_RESOURCES resources still remain"
    echo "This may result in minimal ongoing costs"
    echo ""
    echo "Run discovery again to see what remains:"
    echo "./agentic-discovery.sh"
fi

echo ""
echo "🗂️ PROJECTS STATUS:"
for project in "${PROJECTS[@]}"; do
    echo "  📁 $project: Available (empty projects have no cost)"
done

echo ""
echo "💡 OPTIONAL NEXT STEPS:"
echo "  1. Keep projects for future use (no cost for empty projects)"
echo "  2. Delete projects entirely (irreversible):"
echo "     gcloud projects delete toy-api-dev"
echo "     gcloud projects delete toy-api-stage" 
echo "     gcloud projects delete toy-api-prod"