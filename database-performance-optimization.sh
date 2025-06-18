#!/bin/bash

echo "=== DATABASE PERFORMANCE OPTIMIZATION ==="
echo "Optimizing MongoDB connection pools and performance settings"
echo

# MongoDB optimization
echo "Optimizing MongoDB..."
docker exec huly-mongodb-1 mongosh -u admin -p hulypassword --authenticationDatabase admin --eval '
db.adminCommand({
  setParameter: 1,
  internalDocumentSourceCursorBatchSizeBytes: 16777216,
  internalDocumentSourceLookupBatchSizeBytes: 16777216,
  internalQueryPlanOrChildrenIndependently: 1
});

// Create index for common operations
db.getSiblingDB("huly").workspaces.createIndex({"workspaceId": 1});
db.getSiblingDB("huly").accounts.createIndex({"email": 1});
' --quiet

echo "MongoDB optimization completed."

# MinIO optimization - warm up connection
echo "Warming up MinIO connections..."
docker exec huly-minio-1 mc ls testminio >/dev/null 2>&1

echo "MinIO connections warmed up."

# Elasticsearch optimization
echo "Optimizing Elasticsearch..."
docker exec huly-elastic-1 curl -s -X PUT "localhost:9200/_cluster/settings" -H 'Content-Type: application/json' -d'
{
  "persistent": {
    "indices.recovery.max_bytes_per_sec": "100mb",
    "cluster.routing.allocation.cluster_concurrent_rebalance": 6,
    "cluster.routing.allocation.node_concurrent_recoveries": 6
  }
}' >/dev/null

echo "Elasticsearch optimization completed."

echo
echo "=== PERFORMANCE OPTIMIZATION COMPLETE ==="
echo "All database services have been optimized for better performance."