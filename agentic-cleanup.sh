#!/bin/bash

# Agentic Resource Cleanup Script
# Automatically cleans up Google Cloud resources safely

set -e

echo "🗑️ AGENTIC RESOURCE CLEANUP"
echo "============================"

PROJECTS=("toy-api-dev" "toy-api-stage" "toy-api-prod")
CLEANUP_COUNT=0

for project in "${PROJECTS[@]}"; do
    echo ""
    echo "🧹 CLEANING PROJECT: $project"
    echo "------------------------------"
    
    gcloud config set project $project --quiet
    
    # Clean Cloud Run Services
    echo "🏃 Deleting Cloud Run services..."
    SERVICES=$(gcloud run services list --format="value(metadata.name)" 2>/dev/null)
    if [ -n "$SERVICES" ]; then
        for service in $SERVICES; do
            echo "  Deleting service: $service"
            gcloud run services delete $service --region=us-central1 --quiet
            CLEANUP_COUNT=$((CLEANUP_COUNT + 1))
        done
    else
        echo "  No Cloud Run services to delete"
    fi
    
    # Clean Build Triggers
    echo "🔨 Deleting build triggers..."
    TRIGGERS=$(gcloud builds triggers list --format="value(id)" 2>/dev/null)
    if [ -n "$TRIGGERS" ]; then
        for trigger in $TRIGGERS; do
            echo "  Deleting trigger: $trigger"
            gcloud builds triggers delete $trigger --quiet
            CLEANUP_COUNT=$((CLEANUP_COUNT + 1))
        done
    else
        echo "  No build triggers to delete"
    fi
    
    # Clean Container Images  
    echo "📦 Deleting container images..."
    IMAGES=$(gcloud container images list --format="value(name)" 2>/dev/null)
    if [ -n "$IMAGES" ]; then
        for image in $IMAGES; do
            echo "  Deleting image: $image"
            gcloud container images delete $image --force-delete-tags --quiet
            CLEANUP_COUNT=$((CLEANUP_COUNT + 1))
        done
    else
        echo "  No container images to delete"
    fi
    
    # Clean Secrets
    echo "🔐 Deleting secrets..."
    SECRETS=$(gcloud secrets list --format="value(name)" 2>/dev/null)
    if [ -n "$SECRETS" ]; then
        for secret in $SECRETS; do
            echo "  Deleting secret: $secret"
            gcloud secrets delete $secret --quiet
            CLEANUP_COUNT=$((CLEANUP_COUNT + 1))
        done
    else
        echo "  No secrets to delete"
    fi
    
    # Clean Static IP Addresses
    echo "🌐 Deleting static IP addresses..."
    # Global addresses
    GLOBAL_IPS=$(gcloud compute addresses list --global --format="value(name)" 2>/dev/null)
    if [ -n "$GLOBAL_IPS" ]; then
        for ip in $GLOBAL_IPS; do
            echo "  Deleting global IP: $ip"
            gcloud compute addresses delete $ip --global --quiet
            CLEANUP_COUNT=$((CLEANUP_COUNT + 1))
        done
    fi
    
    # Regional addresses
    REGIONAL_IPS=$(gcloud compute addresses list --regions=us-central1 --format="value(name)" 2>/dev/null)
    if [ -n "$REGIONAL_IPS" ]; then
        for ip in $REGIONAL_IPS; do
            echo "  Deleting regional IP: $ip"
            gcloud compute addresses delete $ip --region=us-central1 --quiet
            CLEANUP_COUNT=$((CLEANUP_COUNT + 1))
        done
    fi
    
    if [ -z "$GLOBAL_IPS" ] && [ -z "$REGIONAL_IPS" ]; then
        echo "  No static IP addresses to delete"
    fi
    
    # Clean Storage Buckets (with caution)
    echo "🪣 Deleting storage buckets..."
    BUCKETS=$(gsutil ls -p $project 2>/dev/null | grep -v "gs://artifacts\." || true)
    if [ -n "$BUCKETS" ]; then
        for bucket in $BUCKETS; do
            # Only delete buckets that look like source buckets (safe to delete)
            if [[ $bucket == *"sources"* ]] || [[ $bucket == *"cloudfunctions"* ]]; then
                echo "  Deleting bucket: $bucket"
                gsutil rm -r $bucket 2>/dev/null || echo "    Bucket already empty or permission denied"
                CLEANUP_COUNT=$((CLEANUP_COUNT + 1))
            else
                echo "  Skipping bucket (not a source bucket): $bucket"
            fi
        done
    else
        echo "  No storage buckets to delete"
    fi
done

echo ""
echo "✅ CLEANUP COMPLETE"
echo "==================="
echo "Total resources cleaned: $CLEANUP_COUNT"
echo ""
echo "Next step: Run ./agentic-verify.sh to confirm cleanup"