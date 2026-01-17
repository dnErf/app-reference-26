"""
Test SeaweedFS-like Blob Storage Integration
============================================

Tests the blob storage, S3 gateway, and PL-GRIZZLY extensions.
"""

from seaweed_blob_store import SeaweedBlobStore
from s3_gateway import S3Gateway
from orc_storage import ORCStorage
from schema_manager import SchemaManager, Column, ColumnType
from index_storage import IndexStorage
from blob_storage import BlobStorage

fn test_blob_storage() raises:
    """Test basic blob storage operations."""
    print("Testing SeaweedBlobStore...")

    # Setup storage layers
    var base_path = "/tmp/test_seaweed"
    var blob_storage = BlobStorage(base_path + "/blobs")
    var index_storage = IndexStorage(blob_storage)
    var schema_mgr = SchemaManager(blob_storage)
    var orc_storage = ORCStorage(blob_storage, schema_mgr, index_storage)

    # Create blob store
    var blob_store = SeaweedBlobStore(base_path + "/seaweed", orc_storage)

    # Test data
    var test_data = List[UInt8]()
    for i in range(10):
        test_data.append(UInt8(i))

    # Put blob
    var fid = blob_store.put(test_data, "test.txt", "text/plain")
    print("Created blob with FID:", fid)
    assert len(fid) > 0, "FID should not be empty"

    # Get blob
    var retrieved_data = blob_store.get(fid)
    print("Retrieved", len(retrieved_data), "bytes")
    assert len(retrieved_data) == len(test_data), "Data size mismatch"

    # Check data integrity
    for i in range(len(test_data)):
        assert retrieved_data[i] == test_data[i], "Data corruption"

    # Get metadata
    var metadata_opt = blob_store.stat(fid)
    assert metadata_opt, "Metadata should exist"
    var metadata = metadata_opt.value()
    print("Blob size:", metadata.size, "Created at:", metadata.created_at)

    # Delete blob
    var deleted = blob_store.delete(fid)
    assert deleted, "Delete should succeed"

    print("✓ Blob storage tests passed")

fn test_s3_gateway() raises:
    """Test S3-compatible API."""
    print("Testing S3 Gateway...")

    # Setup
    var base_path = "/tmp/test_s3"
    var blob_storage = BlobStorage(base_path + "/blobs")
    var index_storage = IndexStorage(blob_storage)
    var schema_mgr = SchemaManager(blob_storage)
    var orc_storage = ORCStorage(blob_storage, schema_mgr, index_storage)
    var blob_store = SeaweedBlobStore(base_path + "/seaweed", orc_storage)
    var s3_gateway = S3Gateway(blob_store)

    # Test bucket operations
    var bucket_created = s3_gateway.create_bucket("test-bucket")
    assert bucket_created, "Bucket creation should succeed"

    var buckets = s3_gateway.list_buckets()
    assert len(buckets) == 1 and buckets[0] == "test-bucket", "Bucket listing failed"

    # Test object operations
    var test_data = List[UInt8]()
    test_data.append(72)  # 'H'
    test_data.append(101)  # 'e'
    test_data.append(108)  # 'l'
    test_data.append(108)  # 'l'
    test_data.append(111)  # 'o'

    var put_success = s3_gateway.put_object("test-bucket", "hello.txt", test_data, "text/plain")
    assert put_success, "Put object should succeed"

    var get_data_opt = s3_gateway.get_object("test-bucket", "hello.txt")
    assert get_data_opt, "Get object should succeed"
    var get_data = get_data_opt.value()
    assert len(get_data) == 5, "Retrieved data size incorrect"

    # Test HEAD
    var head_meta_opt = s3_gateway.head_object("test-bucket", "hello.txt")
    assert head_meta_opt, "Head object should succeed"
    var head_meta = head_meta_opt.value()
    assert head_meta.size == 5, "Metadata size incorrect"

    # Test delete
    var delete_success = s3_gateway.delete_object("test-bucket", "hello.txt")
    assert delete_success, "Delete should succeed"

    # Verify deletion
    var get_after_delete = s3_gateway.get_object("test-bucket", "hello.txt")
    assert not get_after_delete, "Object should be deleted"

    print("✓ S3 Gateway tests passed")

fn test_pl_grizzly_blob_functions() raises:
    """Test @BLOB_* functions in PL-GRIZZLY."""
    print("Testing PL-GRIZZLY blob functions...")

    # Test basic blob operations through lakehouse engine
    var base_path = "/tmp/test_blob_functions"
    var blob_storage = BlobStorage(base_path + "/blobs")
    var index_storage = IndexStorage(blob_storage)
    var schema_mgr = SchemaManager(blob_storage)
    var orc_storage = ORCStorage(blob_storage, schema_mgr, index_storage)

    var engine = LakehouseEngine(base_path)
    engine.initialize_blob_store(base_path)

    # Test @BLOB_FROM_FILE equivalent
    var test_file = "/tmp/test_blob.txt"
    var file_mod = Python.import_module("builtins")
    var fh = file_mod.open(test_file, "w")
    fh.write("Hello Blob World!")
    fh.close()

    var fid = engine.create_blob_from_file(test_file)
    print("Created blob from file, FID:", fid)
    assert len(fid) > 0, "Blob creation should return FID"

    # Test @BLOB_SIZE equivalent
    var size = engine.get_blob_size(fid)
    print("Blob size:", size)
    assert size == 17, "Blob size should be 17 bytes"

    # Test @BLOB_CONTENT equivalent
    var content = engine.get_blob_content(fid)
    print("Blob content length:", len(content))
    assert len(content) == 17, "Blob content should be 17 bytes"

    # Cleanup
    import os
    os.remove(test_file)

    print("✓ PL-GRIZZLY blob functions working through LakehouseEngine")

fn main() raises:
    """Run all blob integration tests."""
    print("Running SeaweedFS-like Blob Integration Tests")
    print("=" * 50)

    test_blob_storage()
    test_s3_gateway()
    test_pl_grizzly_blob_functions()

    print("\n✓ All blob integration tests passed!")
    print("SeaweedFS-like blob storage is ready for lakehouse integration.")