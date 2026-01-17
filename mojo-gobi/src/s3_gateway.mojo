"""
S3-Compatible Gateway for Seaweed Blob Store
===========================================

Provides REST API compatible with Amazon S3 for blob operations.
"""

from collections import Dict, List, Optional
from python import Python, PythonObject
from seaweed_blob_store import SeaweedBlobStore
from time import time

# S3 object metadata
struct S3ObjectMetadata(Movable):
    var size: Int
    var etag: String
    var last_modified: String
    var content_type: String

    fn __init__(out self, size: Int, etag: String = "", content_type: String = "application/octet-stream"):
        self.size = size
        self.etag = etag if len(etag) > 0 else self._generate_etag()
        self.last_modified = self._current_timestamp()
        self.content_type = content_type

    fn _generate_etag(self) -> String:
        """Generate ETag (simplified MD5-like hash)."""
        return "\"" + String(Int(time() * 1000000) % 1000000) + "\""

    fn _current_timestamp(self) -> String:
        """Generate HTTP timestamp."""
        # Simplified RFC 1123 format
        return "Wed, 01 Jan 2025 00:00:00 GMT"  # Placeholder

# S3 bucket operations
struct S3Bucket(Movable):
    var name: String
    var objects: Dict[String, String]  # key -> fid
    var created_at: String

    fn __init__(out self, name: String):
        self.name = name
        self.objects = Dict[String, String]()
        self.created_at = S3ObjectMetadata(0)._current_timestamp()

    fn put_object(mut self, key: String, fid: String):
        """Store object in bucket."""
        self.objects[key] = fid

    fn get_object(self, key: String) -> Optional[String]:
        """Get object FID from bucket."""
        if key in self.objects:
            return self.objects[key]
        return None

    fn delete_object(mut self, key: String) -> Bool:
        """Remove object from bucket."""
        if key in self.objects:
            self.objects.erase(key)
            return True
        return False

    fn list_objects(self) -> List[String]:
        """List all object keys in bucket."""
        var keys = List[String]()
        for key in self.objects.keys():
            keys.append(key)
        return keys

# Main S3 Gateway
struct S3Gateway(Movable):
    var blob_store: SeaweedBlobStore
    var buckets: Dict[String, S3Bucket]
    var access_key: String
    var secret_key: String

    fn __init__(out self, blob_store: SeaweedBlobStore, access_key: String = "admin", secret_key: String = "key"):
        self.blob_store = blob_store
        self.buckets = Dict[String, S3Bucket]()
        self.access_key = access_key
        self.secret_key = secret_key

    fn create_bucket(mut self, bucket_name: String) -> Bool:
        """Create new S3 bucket."""
        if bucket_name in self.buckets:
            return False  # Bucket already exists

        self.buckets[bucket_name] = S3Bucket(bucket_name)
        return True

    fn delete_bucket(mut self, bucket_name: String) -> Bool:
        """Delete S3 bucket (must be empty)."""
        if bucket_name not in self.buckets:
            return False

        var bucket = self.buckets[bucket_name]
        if len(bucket.objects) > 0:
            return False  # Bucket not empty

        self.buckets.erase(bucket_name)
        return True

    fn put_object(mut self, bucket_name: String, key: String, data: List[UInt8], content_type: String = "application/octet-stream") -> Bool:
        """PUT object to S3 bucket."""
        if bucket_name not in self.buckets:
            if not self.create_bucket(bucket_name):
                return False

        # Store blob
        var fid = self.blob_store.put(data, key, content_type)
        if len(fid) == 0:
            return False

        # Store in bucket
        self.buckets[bucket_name].put_object(key, fid)
        return True

    fn get_object(self, bucket_name: String, key: String) -> Optional[List[UInt8]]:
        """GET object from S3 bucket."""
        if bucket_name not in self.buckets:
            return None

        var fid_opt = self.buckets[bucket_name].get_object(key)
        if not fid_opt:
            return None

        var fid = fid_opt.value()
        return self.blob_store.get(fid)

    fn delete_object(mut self, bucket_name: String, key: String) -> Bool:
        """DELETE object from S3 bucket."""
        if bucket_name not in self.buckets:
            return False

        var fid_opt = self.buckets[bucket_name].get_object(key)
        if not fid_opt:
            return False

        var fid = fid_opt.value()

        # Remove from bucket
        if not self.buckets[bucket_name].delete_object(key):
            return False

        # Mark blob as deleted
        return self.blob_store.delete(fid)

    fn head_object(self, bucket_name: String, key: String) -> Optional[S3ObjectMetadata]:
        """HEAD object to get metadata."""
        if bucket_name not in self.buckets:
            return None

        var fid_opt = self.buckets[bucket_name].get_object(key)
        if not fid_opt:
            return None

        var fid = fid_opt.value()
        var metadata_opt = self.blob_store.stat(fid)
        if not metadata_opt:
            return None

        var blob_meta = metadata_opt.value()
        var s3_meta = S3ObjectMetadata(blob_meta.size)
        s3_meta.content_type = "application/octet-stream"  # Could be enhanced
        return s3_meta

    fn list_objects(self, bucket_name: String, prefix: String = "") -> List[String]:
        """List objects in bucket with optional prefix."""
        if bucket_name not in self.buckets:
            return List[String]()

        var all_keys = self.buckets[bucket_name].list_objects()
        var filtered_keys = List[String]()

        for key in all_keys:
            if len(prefix) == 0 or key.startswith(prefix):
                filtered_keys.append(key)

        return filtered_keys

    fn list_buckets(self) -> List[String]:
        """List all buckets."""
        var bucket_names = List[String]()
        for name in self.buckets.keys():
            bucket_names.append(name)
        return bucket_names

    # HTTP Request Handlers (for integration with daemon)

    fn handle_put_request(mut self, bucket: String, key: String, data: List[UInt8], headers: Dict[String, String]) -> PythonObject:
        """Handle HTTP PUT request."""
        var content_type = headers.get("content-type", "application/octet-stream")

        if self.put_object(bucket, key, data, content_type):
            var response = PythonObject({"status": 200, "message": "OK"})
            return response
        else:
            var response = PythonObject({"status": 500, "message": "Internal Server Error"})
            return response

    fn handle_get_request(self, bucket: String, key: String) -> PythonObject:
        """Handle HTTP GET request."""
        var data_opt = self.get_object(bucket, key)
        if data_opt:
            var data = data_opt.value()
            var response = PythonObject({
                "status": 200,
                "data": PythonObject(data),
                "content_type": "application/octet-stream"
            })
            return response
        else:
            var response = PythonObject({"status": 404, "message": "Not Found"})
            return response

    fn handle_delete_request(mut self, bucket: String, key: String) -> PythonObject:
        """Handle HTTP DELETE request."""
        if self.delete_object(bucket, key):
            var response = PythonObject({"status": 204, "message": "No Content"})
            return response
        else:
            var response = PythonObject({"status": 404, "message": "Not Found"})
            return response

    fn handle_head_request(self, bucket: String, key: String) -> PythonObject:
        """Handle HTTP HEAD request."""
        var meta_opt = self.head_object(bucket, key)
        if meta_opt:
            var meta = meta_opt.value()
            var response = PythonObject({
                "status": 200,
                "size": meta.size,
                "etag": meta.etag,
                "last_modified": meta.last_modified,
                "content_type": meta.content_type
            })
            return response
        else:
            var response = PythonObject({"status": 404, "message": "Not Found"})
            return response