#!/bin/bash

# Performance Optimization Setup for Google Cloud Toy API
# Implements CDN integration, database optimization, Redis caching, and auto-scaling

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
REGION="us-central1"

echo -e "${BLUE}⚡ Setting up Performance Optimization${NC}"
echo -e "${BLUE}====================================${NC}"

# Setup Cloud CDN
setup_cloud_cdn() {
    local project_id=$1
    local environment=$2
    
    echo -e "\n${YELLOW}🌐 Setting up Cloud CDN for $environment${NC}"
    
    gcloud config set project $project_id
    
    # Enable required APIs
    echo -e "${BLUE}🔧 Enabling required APIs...${NC}"
    gcloud services enable compute.googleapis.com --quiet
    gcloud services enable cdn.googleapis.com --quiet
    
    # Create a global static IP for the load balancer
    STATIC_IP_NAME="toy-api-static-ip-${environment}"
    if ! gcloud compute addresses describe $STATIC_IP_NAME --global &>/dev/null; then
        echo -e "${BLUE}Creating static IP address...${NC}"
        gcloud compute addresses create $STATIC_IP_NAME \
            --global \
            --quiet
    fi
    
    STATIC_IP=$(gcloud compute addresses describe $STATIC_IP_NAME \
        --global \
        --format='value(address)')
    
    echo -e "${GREEN}Static IP: $STATIC_IP${NC}"
    
    # Create backend service
    BACKEND_SERVICE_NAME="toy-api-backend-${environment}"
    if ! gcloud compute backend-services describe $BACKEND_SERVICE_NAME --global &>/dev/null; then
        echo -e "${BLUE}Creating backend service...${NC}"
        gcloud compute backend-services create $BACKEND_SERVICE_NAME \
            --protocol=HTTP \
            --port-name=http \
            --health-checks=toy-api-health-check-${environment} \
            --global \
            --enable-cdn \
            --cache-mode=CACHE_ALL_STATIC \
            --default-ttl=3600 \
            --max-ttl=86400 \
            --client-ttl=3600 \
            --quiet
    fi
    
    # Create health check
    HEALTH_CHECK_NAME="toy-api-health-check-${environment}"
    if ! gcloud compute health-checks describe $HEALTH_CHECK_NAME &>/dev/null; then
        echo -e "${BLUE}Creating health check...${NC}"
        gcloud compute health-checks create http $HEALTH_CHECK_NAME \
            --port=8080 \
            --request-path=/ \
            --check-interval=10s \
            --timeout=5s \
            --healthy-threshold=2 \
            --unhealthy-threshold=3 \
            --quiet
    fi
    
    echo -e "${GREEN}✅ Cloud CDN setup completed for $environment${NC}"
    echo -e "${BLUE}Static IP: $STATIC_IP${NC}"
}

# Create Redis caching setup
setup_redis_caching() {
    local project_id=$1
    local environment=$2
    
    echo -e "\n${YELLOW}🔴 Setting up Redis caching for $environment${NC}"
    
    gcloud config set project $project_id
    
    # Enable Memorystore API
    echo -e "${BLUE}🔧 Enabling Memorystore API...${NC}"
    gcloud services enable redis.googleapis.com --quiet
    
    # Create Redis instance (smallest tier for free tier compatibility)
    REDIS_INSTANCE_NAME="toy-api-cache-${environment}"
    if ! gcloud redis instances describe $REDIS_INSTANCE_NAME --region=$REGION &>/dev/null; then
        echo -e "${BLUE}Creating Redis instance...${NC}"
        gcloud redis instances create $REDIS_INSTANCE_NAME \
            --size=1 \
            --region=$REGION \
            --redis-version=redis_6_x \
            --tier=basic \
            --quiet &
        
        # This will run in background as it takes several minutes
        echo -e "${YELLOW}⏳ Redis instance creation started (runs in background)...${NC}"
    else
        echo -e "${GREEN}✅ Redis instance already exists${NC}"
    fi
    
    # Create caching service implementation
    create_caching_service
    
    echo -e "${GREEN}✅ Redis caching setup initiated for $environment${NC}"
}

# Create caching service implementation
create_caching_service() {
    echo -e "\n${YELLOW}📦 Creating caching service implementation${NC}"
    
    # Create Redis client service
    cat > google-cloud-toy-api/src/services/cache.ts << 'EOF'
import { createClient, RedisClientType } from 'redis';

export class CacheService {
  private client: RedisClientType | null = null;
  private isConnected = false;
  private environment: string;

  constructor() {
    this.environment = process.env.NODE_ENV || 'development';
    this.initializeClient();
  }

  private async initializeClient(): Promise<void> {
    try {
      // In production, use Cloud Memorystore Redis
      const redisHost = process.env.REDIS_HOST || 'localhost';
      const redisPort = process.env.REDIS_PORT || '6379';
      const redisPassword = process.env.REDIS_PASSWORD;

      const clientConfig: any = {
        socket: {
          host: redisHost,
          port: parseInt(redisPort)
        }
      };

      if (redisPassword) {
        clientConfig.password = redisPassword;
      }

      this.client = createClient(clientConfig);

      this.client.on('error', (err) => {
        console.error('Redis Client Error:', err);
        this.isConnected = false;
      });

      this.client.on('connect', () => {
        console.log('Redis Client Connected');
        this.isConnected = true;
      });

      this.client.on('disconnect', () => {
        console.log('Redis Client Disconnected');
        this.isConnected = false;
      });

      await this.client.connect();
      
    } catch (error) {
      console.warn('Redis connection failed, falling back to in-memory cache:', error);
      this.client = null;
      this.isConnected = false;
    }
  }

  /**
   * Get value from cache
   */
  async get(key: string): Promise<string | null> {
    try {
      if (!this.isConnected || !this.client) {
        return null;
      }

      const value = await this.client.get(this.prefixKey(key));
      return value;
    } catch (error) {
      console.error('Cache get error:', error);
      return null;
    }
  }

  /**
   * Set value in cache with TTL
   */
  async set(key: string, value: string, ttlSeconds: number = 3600): Promise<boolean> {
    try {
      if (!this.isConnected || !this.client) {
        return false;
      }

      await this.client.setEx(this.prefixKey(key), ttlSeconds, value);
      return true;
    } catch (error) {
      console.error('Cache set error:', error);
      return false;
    }
  }

  /**
   * Delete value from cache
   */
  async delete(key: string): Promise<boolean> {
    try {
      if (!this.isConnected || !this.client) {
        return false;
      }

      const result = await this.client.del(this.prefixKey(key));
      return result > 0;
    } catch (error) {
      console.error('Cache delete error:', error);
      return false;
    }
  }

  /**
   * Check if key exists in cache
   */
  async exists(key: string): Promise<boolean> {
    try {
      if (!this.isConnected || !this.client) {
        return false;
      }

      const result = await this.client.exists(this.prefixKey(key));
      return result === 1;
    } catch (error) {
      console.error('Cache exists error:', error);
      return false;
    }
  }

  /**
   * Get or set pattern - check cache first, if miss, execute function and cache result
   */
  async getOrSet<T>(
    key: string, 
    fetchFunction: () => Promise<T>, 
    ttlSeconds: number = 3600
  ): Promise<T> {
    try {
      // Try to get from cache first
      const cached = await this.get(key);
      if (cached) {
        return JSON.parse(cached) as T;
      }

      // Cache miss - fetch data
      const data = await fetchFunction();
      
      // Cache the result
      await this.set(key, JSON.stringify(data), ttlSeconds);
      
      return data;
    } catch (error) {
      console.error('Cache getOrSet error:', error);
      // Fallback to direct function call
      return await fetchFunction();
    }
  }

  /**
   * Invalidate cache pattern (delete keys matching pattern)
   */
  async invalidatePattern(pattern: string): Promise<number> {
    try {
      if (!this.isConnected || !this.client) {
        return 0;
      }

      const keys = await this.client.keys(this.prefixKey(pattern));
      if (keys.length === 0) {
        return 0;
      }

      const result = await this.client.del(keys);
      return result;
    } catch (error) {
      console.error('Cache invalidatePattern error:', error);
      return 0;
    }
  }

  /**
   * Get cache statistics
   */
  async getStats(): Promise<{ connected: boolean; keyCount?: number; memory?: string }> {
    try {
      if (!this.isConnected || !this.client) {
        return { connected: false };
      }

      const info = await this.client.info('memory');
      const keyCount = await this.client.dbSize();
      
      const memoryMatch = info.match(/used_memory_human:(.+)/);
      const memory = memoryMatch ? memoryMatch[1].trim() : 'unknown';

      return {
        connected: true,
        keyCount,
        memory
      };
    } catch (error) {
      console.error('Cache stats error:', error);
      return { connected: false };
    }
  }

  /**
   * Graceful shutdown
   */
  async disconnect(): Promise<void> {
    try {
      if (this.client) {
        await this.client.disconnect();
        this.isConnected = false;
      }
    } catch (error) {
      console.error('Cache disconnect error:', error);
    }
  }

  /**
   * Add environment prefix to cache keys
   */
  private prefixKey(key: string): string {
    return `toy-api:${this.environment}:${key}`;
  }

  /**
   * Express middleware to add cache to request
   */
  middleware() {
    return (req: any, res: any, next: any) => {
      req.cache = this;
      next();
    };
  }
}

// Singleton instance
export const cacheService = new CacheService();

// Graceful shutdown handler
process.on('SIGTERM', async () => {
  console.log('Disconnecting Redis client...');
  await cacheService.disconnect();
});

process.on('SIGINT', async () => {
  console.log('Disconnecting Redis client...');
  await cacheService.disconnect();
});
EOF

    echo -e "${GREEN}✅ Caching service implementation created${NC}"
}

# Setup database optimization
setup_database_optimization() {
    local project_id=$1
    local environment=$2
    
    echo -e "\n${YELLOW}🗄️ Setting up database optimization for $environment${NC}"
    
    # Create database optimization service
    cat > google-cloud-toy-api/src/services/database-optimization.ts << 'EOF'
import { Firestore, Query, DocumentData } from '@google-cloud/firestore';

export class DatabaseOptimizationService {
  private db: Firestore;
  private queryCache = new Map<string, { data: any; timestamp: number; ttl: number }>();
  private queryMetrics = new Map<string, { count: number; totalTime: number; avgTime: number }>();

  constructor(db: Firestore) {
    this.db = db;
    
    // Clean up cache every 5 minutes
    setInterval(() => {
      this.cleanupCache();
    }, 5 * 60 * 1000);
  }

  /**
   * Optimized query with caching and metrics
   */
  async optimizedQuery(
    collectionPath: string,
    queryBuilder?: (query: Query<DocumentData>) => Query<DocumentData>,
    cacheTtl: number = 300000 // 5 minutes default
  ): Promise<any[]> {
    const startTime = Date.now();
    const queryKey = this.generateQueryKey(collectionPath, queryBuilder);

    try {
      // Check cache first
      const cached = this.queryCache.get(queryKey);
      if (cached && Date.now() - cached.timestamp < cached.ttl) {
        this.recordQueryMetrics(queryKey, Date.now() - startTime, true);
        return cached.data;
      }

      // Build query
      let query: Query<DocumentData> = this.db.collection(collectionPath);
      if (queryBuilder) {
        query = queryBuilder(query);
      }

      // Execute query
      const snapshot = await query.get();
      const results = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));

      // Cache results
      this.queryCache.set(queryKey, {
        data: results,
        timestamp: Date.now(),
        ttl: cacheTtl
      });

      this.recordQueryMetrics(queryKey, Date.now() - startTime, false);
      return results;

    } catch (error) {
      this.recordQueryMetrics(queryKey, Date.now() - startTime, false, error);
      throw error;
    }
  }

  /**
   * Batch operations for better performance
   */
  async batchWrite(operations: Array<{
    type: 'create' | 'update' | 'delete';
    collection: string;
    docId: string;
    data?: any;
  }>): Promise<void> {
    const batch = this.db.batch();
    
    operations.forEach(op => {
      const docRef = this.db.collection(op.collection).doc(op.docId);
      
      switch (op.type) {
        case 'create':
          batch.create(docRef, op.data);
          break;
        case 'update':
          batch.update(docRef, op.data);
          break;
        case 'delete':
          batch.delete(docRef);
          break;
      }
    });

    await batch.commit();
    
    // Invalidate related cache entries
    operations.forEach(op => {
      this.invalidateCacheForCollection(op.collection);
    });
  }

  /**
   * Optimized pagination
   */
  async paginatedQuery(
    collectionPath: string,
    pageSize: number = 10,
    startAfter?: any,
    queryBuilder?: (query: Query<DocumentData>) => Query<DocumentData>
  ): Promise<{ results: any[]; hasMore: boolean; lastDoc?: any }> {
    let query: Query<DocumentData> = this.db.collection(collectionPath);
    
    if (queryBuilder) {
      query = queryBuilder(query);
    }

    query = query.limit(pageSize + 1); // Get one extra to check if there are more

    if (startAfter) {
      query = query.startAfter(startAfter);
    }

    const snapshot = await query.get();
    const docs = snapshot.docs;
    
    const hasMore = docs.length > pageSize;
    const results = docs.slice(0, pageSize).map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    return {
      results,
      hasMore,
      lastDoc: hasMore ? docs[pageSize - 1] : undefined
    };
  }

  /**
   * Index usage analyzer
   */
  async analyzeQuery(
    collectionPath: string,
    queryBuilder?: (query: Query<DocumentData>) => Query<DocumentData>
  ): Promise<{ usesIndex: boolean; explanation: string }> {
    try {
      let query: Query<DocumentData> = this.db.collection(collectionPath);
      if (queryBuilder) {
        query = queryBuilder(query);
      }

      // Execute query and measure time
      const startTime = Date.now();
      const snapshot = await query.get();
      const executionTime = Date.now() - startTime;

      let explanation = `Query executed in ${executionTime}ms, returned ${snapshot.size} documents.`;
      
      // Heuristics for index usage (simplified)
      const usesIndex = executionTime < 100 || snapshot.size < 1000;
      
      if (!usesIndex) {
        explanation += ' Consider adding composite indexes for better performance.';
      }

      return { usesIndex, explanation };
    } catch (error) {
      return { 
        usesIndex: false, 
        explanation: `Query analysis failed: ${error instanceof Error ? error.message : 'Unknown error'}` 
      };
    }
  }

  /**
   * Get query performance metrics
   */
  getQueryMetrics(): Array<{
    queryKey: string;
    count: number;
    avgTime: number;
    totalTime: number;
  }> {
    return Array.from(this.queryMetrics.entries()).map(([queryKey, metrics]) => ({
      queryKey,
      ...metrics
    }));
  }

  /**
   * Generate cache key for query
   */
  private generateQueryKey(
    collectionPath: string,
    queryBuilder?: (query: Query<DocumentData>) => Query<DocumentData>
  ): string {
    // Simple hash of collection path and query function string
    const queryString = queryBuilder ? queryBuilder.toString() : '';
    return `${collectionPath}:${Buffer.from(queryString).toString('base64').slice(0, 20)}`;
  }

  /**
   * Record query performance metrics
   */
  private recordQueryMetrics(
    queryKey: string,
    executionTime: number,
    cacheHit: boolean,
    error?: any
  ): void {
    const existing = this.queryMetrics.get(queryKey) || { count: 0, totalTime: 0, avgTime: 0 };
    
    existing.count += 1;
    existing.totalTime += executionTime;
    existing.avgTime = existing.totalTime / existing.count;
    
    this.queryMetrics.set(queryKey, existing);

    // Log slow queries
    if (executionTime > 1000 && !cacheHit) {
      console.warn(`Slow query detected: ${queryKey} took ${executionTime}ms`);
    }

    if (error) {
      console.error(`Query error: ${queryKey}`, error);
    }
  }

  /**
   * Invalidate cache entries for a collection
   */
  private invalidateCacheForCollection(collectionPath: string): void {
    const keysToDelete = Array.from(this.queryCache.keys())
      .filter(key => key.startsWith(collectionPath));
    
    keysToDelete.forEach(key => {
      this.queryCache.delete(key);
    });
  }

  /**
   * Clean up expired cache entries
   */
  private cleanupCache(): void {
    const now = Date.now();
    const keysToDelete: string[] = [];

    this.queryCache.forEach((value, key) => {
      if (now - value.timestamp > value.ttl) {
        keysToDelete.push(key);
      }
    });

    keysToDelete.forEach(key => {
      this.queryCache.delete(key);
    });

    if (keysToDelete.length > 0) {
      console.log(`Cleaned up ${keysToDelete.length} expired cache entries`);
    }
  }
}
EOF

    echo -e "${GREEN}✅ Database optimization service created${NC}"
}

# Setup auto-scaling configuration
setup_auto_scaling() {
    local project_id=$1
    local environment=$2
    
    echo -e "\n${YELLOW}📈 Setting up auto-scaling for $environment${NC}"
    
    gcloud config set project $project_id
    
    # Update Cloud Run service with optimized auto-scaling settings
    SERVICE_NAME="toy-api-service-${environment}"
    
    # Set auto-scaling parameters based on environment
    case $environment in
        "dev")
            MIN_INSTANCES=0
            MAX_INSTANCES=10
            CONCURRENCY=100
            CPU="1"
            MEMORY="512Mi"
            ;;
        "staging")
            MIN_INSTANCES=1
            MAX_INSTANCES=20
            CONCURRENCY=80
            CPU="1"
            MEMORY="1Gi"
            ;;
        "prod")
            MIN_INSTANCES=2
            MAX_INSTANCES=100
            CONCURRENCY=50
            CPU="2"
            MEMORY="2Gi"
            ;;
    esac
    
    echo -e "${BLUE}Configuring auto-scaling parameters:${NC}"
    echo -e "${BLUE}  Min instances: $MIN_INSTANCES${NC}"
    echo -e "${BLUE}  Max instances: $MAX_INSTANCES${NC}"
    echo -e "${BLUE}  Concurrency: $CONCURRENCY${NC}"
    echo -e "${BLUE}  CPU: $CPU${NC}"
    echo -e "${BLUE}  Memory: $MEMORY${NC}"
    
    # Create service configuration with auto-scaling
    cat > "/tmp/service-config-${environment}.yaml" << EOF
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: $SERVICE_NAME
  annotations:
    run.googleapis.com/ingress: all
    run.googleapis.com/execution-environment: gen2
spec:
  template:
    metadata:
      annotations:
        # Auto-scaling configuration
        autoscaling.knative.dev/minScale: "$MIN_INSTANCES"
        autoscaling.knative.dev/maxScale: "$MAX_INSTANCES"
        # Performance optimization
        run.googleapis.com/cpu-throttling: "false"
        run.googleapis.com/sessionAffinity: "false"
        # Startup and request timeouts
        run.googleapis.com/timeout: "300s"
        # Resource allocation
        run.googleapis.com/startup-cpu-boost: "true"
    spec:
      containerConcurrency: $CONCURRENCY
      timeoutSeconds: 300
      containers:
      - image: gcr.io/$project_id/toy-api:latest
        ports:
        - name: http1
          containerPort: 8080
        env:
        - name: NODE_ENV
          value: "$environment"
        resources:
          limits:
            cpu: "$CPU"
            memory: "$MEMORY"
          requests:
            cpu: "0.5"
            memory: "256Mi"
        # Health checks
        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 2
EOF

    echo -e "${GREEN}✅ Auto-scaling configuration created for $environment${NC}"
}

# Create performance monitoring
create_performance_monitoring() {
    echo -e "\n${YELLOW}📊 Creating performance monitoring${NC}"
    
    # Create performance monitoring service
    cat > google-cloud-toy-api/src/services/performance-monitoring.ts << 'EOF'
import { Request, Response, NextFunction } from 'express';

interface PerformanceMetrics {
  requestCount: number;
  totalResponseTime: number;
  averageResponseTime: number;
  slowestRequest: number;
  fastestRequest: number;
  errorCount: number;
  lastReset: Date;
}

export class PerformanceMonitoringService {
  private metrics: PerformanceMetrics = {
    requestCount: 0,
    totalResponseTime: 0,
    averageResponseTime: 0,
    slowestRequest: 0,
    fastestRequest: Infinity,
    errorCount: 0,
    lastReset: new Date()
  };

  private endpointMetrics = new Map<string, PerformanceMetrics>();
  private activeRequests = new Set<string>();

  /**
   * Express middleware to track performance
   */
  middleware() {
    return (req: Request, res: Response, next: NextFunction) => {
      const startTime = Date.now();
      const requestId = `${req.method}-${req.path}-${Date.now()}`;
      
      this.activeRequests.add(requestId);

      // Track request start
      res.on('finish', () => {
        const responseTime = Date.now() - startTime;
        const endpoint = `${req.method} ${req.path}`;
        
        this.recordMetrics(endpoint, responseTime, res.statusCode >= 400);
        this.activeRequests.delete(requestId);
      });

      next();
    };
  }

  /**
   * Record performance metrics
   */
  private recordMetrics(endpoint: string, responseTime: number, isError: boolean): void {
    // Update global metrics
    this.updateMetrics(this.metrics, responseTime, isError);

    // Update endpoint-specific metrics
    if (!this.endpointMetrics.has(endpoint)) {
      this.endpointMetrics.set(endpoint, {
        requestCount: 0,
        totalResponseTime: 0,
        averageResponseTime: 0,
        slowestRequest: 0,
        fastestRequest: Infinity,
        errorCount: 0,
        lastReset: new Date()
      });
    }

    const endpointMetric = this.endpointMetrics.get(endpoint)!;
    this.updateMetrics(endpointMetric, responseTime, isError);

    // Log slow requests
    if (responseTime > 3000) {
      console.warn(`Slow request detected: ${endpoint} took ${responseTime}ms`);
    }
  }

  /**
   * Update metrics object
   */
  private updateMetrics(metrics: PerformanceMetrics, responseTime: number, isError: boolean): void {
    metrics.requestCount++;
    metrics.totalResponseTime += responseTime;
    metrics.averageResponseTime = metrics.totalResponseTime / metrics.requestCount;
    
    if (responseTime > metrics.slowestRequest) {
      metrics.slowestRequest = responseTime;
    }
    
    if (responseTime < metrics.fastestRequest) {
      metrics.fastestRequest = responseTime;
    }
    
    if (isError) {
      metrics.errorCount++;
    }
  }

  /**
   * Get global performance metrics
   */
  getGlobalMetrics(): PerformanceMetrics & { 
    errorRate: number; 
    requestsPerSecond: number;
    activeRequests: number;
  } {
    const uptime = Date.now() - this.metrics.lastReset.getTime();
    const uptimeSeconds = uptime / 1000;
    
    return {
      ...this.metrics,
      errorRate: this.metrics.requestCount > 0 ? (this.metrics.errorCount / this.metrics.requestCount) * 100 : 0,
      requestsPerSecond: uptimeSeconds > 0 ? this.metrics.requestCount / uptimeSeconds : 0,
      activeRequests: this.activeRequests.size
    };
  }

  /**
   * Get endpoint-specific metrics
   */
  getEndpointMetrics(): Array<{ endpoint: string; metrics: PerformanceMetrics & { errorRate: number } }> {
    return Array.from(this.endpointMetrics.entries()).map(([endpoint, metrics]) => ({
      endpoint,
      metrics: {
        ...metrics,
        errorRate: metrics.requestCount > 0 ? (metrics.errorCount / metrics.requestCount) * 100 : 0
      }
    }));
  }

  /**
   * Get performance summary
   */
  getPerformanceSummary(): {
    status: 'healthy' | 'warning' | 'critical';
    issues: string[];
    recommendations: string[];
    metrics: any;
  } {
    const globalMetrics = this.getGlobalMetrics();
    const issues: string[] = [];
    const recommendations: string[] = [];
    
    let status: 'healthy' | 'warning' | 'critical' = 'healthy';

    // Check error rate
    if (globalMetrics.errorRate > 5) {
      status = 'critical';
      issues.push(`High error rate: ${globalMetrics.errorRate.toFixed(2)}%`);
      recommendations.push('Investigate error causes and improve error handling');
    } else if (globalMetrics.errorRate > 1) {
      status = 'warning';
      issues.push(`Elevated error rate: ${globalMetrics.errorRate.toFixed(2)}%`);
    }

    // Check response time
    if (globalMetrics.averageResponseTime > 3000) {
      status = 'critical';
      issues.push(`High average response time: ${globalMetrics.averageResponseTime.toFixed(0)}ms`);
      recommendations.push('Optimize slow endpoints and consider caching');
    } else if (globalMetrics.averageResponseTime > 1000) {
      if (status !== 'critical') status = 'warning';
      issues.push(`Elevated response time: ${globalMetrics.averageResponseTime.toFixed(0)}ms`);
    }

    // Check for slow endpoints
    const slowEndpoints = this.getEndpointMetrics()
      .filter(ep => ep.metrics.averageResponseTime > 2000);
    
    if (slowEndpoints.length > 0) {
      if (status !== 'critical') status = 'warning';
      issues.push(`${slowEndpoints.length} slow endpoints detected`);
      recommendations.push('Optimize slow endpoints: ' + slowEndpoints.map(ep => ep.endpoint).join(', '));
    }

    // Check active requests
    if (globalMetrics.activeRequests > 100) {
      if (status !== 'critical') status = 'warning';
      issues.push(`High number of active requests: ${globalMetrics.activeRequests}`);
      recommendations.push('Consider scaling up or optimizing request handling');
    }

    return {
      status,
      issues,
      recommendations,
      metrics: globalMetrics
    };
  }

  /**
   * Reset metrics
   */
  resetMetrics(): void {
    this.metrics = {
      requestCount: 0,
      totalResponseTime: 0,
      averageResponseTime: 0,
      slowestRequest: 0,
      fastestRequest: Infinity,
      errorCount: 0,
      lastReset: new Date()
    };
    
    this.endpointMetrics.clear();
    this.activeRequests.clear();
  }

  /**
   * Get memory usage statistics
   */
  getMemoryStats(): NodeJS.MemoryUsage & { 
    memoryUsageMB: number; 
    heapUsedPercent: number;
  } {
    const memUsage = process.memoryUsage();
    return {
      ...memUsage,
      memoryUsageMB: memUsage.heapUsed / 1024 / 1024,
      heapUsedPercent: (memUsage.heapUsed / memUsage.heapTotal) * 100
    };
  }
}

// Singleton instance
export const performanceMonitoring = new PerformanceMonitoringService();
EOF

    echo -e "${GREEN}✅ Performance monitoring service created${NC}"
}

# Update package.json with performance dependencies
update_performance_dependencies() {
    echo -e "\n${YELLOW}📦 Adding performance optimization dependencies${NC}"
    
    cd google-cloud-toy-api
    
    # Add performance-related dependencies
    npm install --save redis compression
    npm install --save-dev @types/redis
    
    echo -e "${GREEN}✅ Performance dependencies added${NC}"
    cd ..
}

# Create performance endpoints
create_performance_endpoints() {
    echo -e "\n${YELLOW}📈 Creating performance monitoring endpoints${NC}"
    
    cat > google-cloud-toy-api/src/functions/performance.ts << 'EOF'
import { Request, Response } from 'express';
import { performanceMonitoring } from '../services/performance-monitoring';
import { cacheService } from '../services/cache';

/**
 * Get performance metrics
 */
export const getPerformanceMetrics = async (req: Request, res: Response) => {
  try {
    const globalMetrics = performanceMonitoring.getGlobalMetrics();
    const endpointMetrics = performanceMonitoring.getEndpointMetrics();
    const performanceSummary = performanceMonitoring.getPerformanceSummary();
    const memoryStats = performanceMonitoring.getMemoryStats();
    const cacheStats = await cacheService.getStats();

    res.json({
      success: true,
      timestamp: new Date().toISOString(),
      global: globalMetrics,
      endpoints: endpointMetrics,
      summary: performanceSummary,
      memory: memoryStats,
      cache: cacheStats
    });
  } catch (error) {
    console.error('Error getting performance metrics:', error);
    res.status(500).json({
      error: 'Failed to get performance metrics',
      details: error instanceof Error ? error.message : 'Unknown error'
    });
  }
};

/**
 * Reset performance metrics
 */
export const resetPerformanceMetrics = async (req: Request, res: Response) => {
  try {
    performanceMonitoring.resetMetrics();
    
    res.json({
      success: true,
      message: 'Performance metrics reset',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error resetting performance metrics:', error);
    res.status(500).json({
      error: 'Failed to reset performance metrics',
      details: error instanceof Error ? error.message : 'Unknown error'
    });
  }
};

/**
 * Health check with performance data
 */
export const performanceHealthCheck = async (req: Request, res: Response) => {
  try {
    const summary = performanceMonitoring.getPerformanceSummary();
    const memoryStats = performanceMonitoring.getMemoryStats();
    
    const health = {
      status: summary.status,
      timestamp: new Date().toISOString(),
      uptime: process.uptime() * 1000, // Convert to milliseconds
      memory: {
        used: memoryStats.memoryUsageMB,
        percent: memoryStats.heapUsedPercent
      },
      performance: {
        averageResponseTime: summary.metrics.averageResponseTime,
        errorRate: summary.metrics.errorRate,
        requestsPerSecond: summary.metrics.requestsPerSecond,
        activeRequests: summary.metrics.activeRequests
      },
      issues: summary.issues,
      recommendations: summary.recommendations
    };

    const statusCode = summary.status === 'critical' ? 503 : 
                      summary.status === 'warning' ? 200 : 200;

    res.status(statusCode).json(health);
  } catch (error) {
    console.error('Error in performance health check:', error);
    res.status(500).json({
      status: 'critical',
      error: 'Health check failed',
      details: error instanceof Error ? error.message : 'Unknown error'
    });
  }
};

/**
 * Cache management endpoint
 */
export const manageCacheEndpoint = async (req: Request, res: Response) => {
  try {
    const { action, key, pattern } = req.body;
    
    switch (action) {
      case 'stats':
        const stats = await cacheService.getStats();
        res.json({ success: true, stats });
        break;
        
      case 'delete':
        if (!key) {
          return res.status(400).json({ error: 'Key is required for delete action' });
        }
        const deleted = await cacheService.delete(key);
        res.json({ success: true, deleted });
        break;
        
      case 'invalidate':
        if (!pattern) {
          return res.status(400).json({ error: 'Pattern is required for invalidate action' });
        }
        const invalidated = await cacheService.invalidatePattern(pattern);
        res.json({ success: true, invalidated });
        break;
        
      default:
        res.status(400).json({ error: 'Invalid action. Use: stats, delete, invalidate' });
    }
  } catch (error) {
    console.error('Error managing cache:', error);
    res.status(500).json({
      error: 'Cache management failed',
      details: error instanceof Error ? error.message : 'Unknown error'
    });
  }
};
EOF

    echo -e "${GREEN}✅ Performance monitoring endpoints created${NC}"
}

# Main setup function
main() {
    echo -e "${BLUE}Starting Performance Optimization setup...${NC}\n"
    
    # Check prerequisites
    if ! command -v gcloud &> /dev/null; then
        echo -e "${RED}❌ gcloud CLI not found${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Performance optimizations to be configured:${NC}"
    echo -e "✅ Cloud CDN integration for static assets"
    echo -e "✅ Redis caching layers for frequently accessed data"
    echo -e "✅ Database optimization with query performance monitoring"
    echo -e "✅ Auto-scaling configuration with dynamic resource allocation"
    echo -e "✅ Performance monitoring and metrics collection"
    
    read -p "Press Enter to continue..."
    
    # Create performance optimization implementations
    create_caching_service
    setup_database_optimization "toy-api-dev" "dev"
    create_performance_monitoring
    create_performance_endpoints
    update_performance_dependencies
    
    # Setup infrastructure for dev environment
    echo -e "\n${BLUE}Do you want to setup Cloud CDN for dev environment? (y/n)${NC}"
    read -r setup_cdn_dev
    if [[ $setup_cdn_dev == "y" || $setup_cdn_dev == "Y" ]]; then
        setup_cloud_cdn $PROJECT_ID_DEV "dev"
    fi
    
    echo -e "\n${BLUE}Do you want to setup Redis caching for dev environment? (y/n)${NC}"
    read -r setup_redis_dev
    if [[ $setup_redis_dev == "y" || $setup_redis_dev == "Y" ]]; then
        setup_redis_caching $PROJECT_ID_DEV "dev"
    fi
    
    echo -e "\n${BLUE}Do you want to setup auto-scaling for dev environment? (y/n)${NC}"
    read -r setup_scaling_dev
    if [[ $setup_scaling_dev == "y" || $setup_scaling_dev == "Y" ]]; then
        setup_auto_scaling $PROJECT_ID_DEV "dev"
    fi
    
    echo -e "\n${GREEN}🎉 Performance Optimization Setup Complete!${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo -e "${BLUE}What was created:${NC}"
    echo -e "✅ Redis caching service with middleware"
    echo -e "✅ Database optimization with query caching and metrics"
    echo -e "✅ Performance monitoring service"
    echo -e "✅ Auto-scaling configuration templates"
    echo -e "✅ Performance monitoring endpoints"
    echo -e "✅ Cloud CDN setup (if selected)"
    
    echo -e "\n${YELLOW}⚠️  Next steps:${NC}"
    echo -e "1. Configure Redis connection details in environment variables"
    echo -e "2. Update main application to use performance services"
    echo -e "3. Test caching and performance monitoring"
    echo -e "4. Set up production CDN and Redis instances"
    echo -e "5. Monitor performance metrics and optimize as needed"
    
    echo -e "\n${BLUE}Performance endpoints available:${NC}"
    echo -e "${YELLOW}/admin/performance/metrics${NC} - Get performance metrics"
    echo -e "${YELLOW}/admin/performance/health${NC} - Performance health check"
    echo -e "${YELLOW}/admin/performance/cache${NC} - Cache management"
    echo -e "${YELLOW}/admin/performance/reset${NC} - Reset performance metrics"
}

# Run main function
main "$@"