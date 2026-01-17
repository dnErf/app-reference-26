"""
SeaweedFS-inspired Blob Storage Engine
=====================================

Single-node blob storage optimized for lakehouse workloads.
Uses compact needle format with ORC metadata persistence.
"""

from collections import Dict, List, Optional
from python import Python, PythonObject
import os
from time import time, sleep
from threading import Lock
from orc_storage import ORCStorage
from schema_manager import SchemaManager, Column, ColumnType
from thread_safe_memory import AtomicInt, SpinLock

# SeaweedFS-style needle format (compact blob storage)
struct Needle(Movable):
    var cookie: UInt32      # 4 bytes - security/random cookie
    var data_size: UInt32   # 4 bytes - blob data length
    var name_size: UInt8    # 1 byte - filename length
    var name: String        # variable - filename
    var mime_size: UInt8    # 1 byte - mime type length
    var mime: String        # variable - mime type
    var ttl: UInt32         # 4 bytes - time-to-live timestamp
    var data: List[UInt8]   # variable - blob content

    fn __init__(out self):
        self.cookie = 0
        self.data_size = 0
        self.name_size = 0
        self.name = ""
        self.mime_size = 0
        self.mime = ""
        self.ttl = 0
        self.data = List[UInt8]()

    fn serialize(self) -> List[UInt8]:
        """Serialize needle to bytes (SeaweedFS format)."""
        var bytes = List[UInt8]()

        # Cookie (4 bytes, big-endian)
        bytes.append((self.cookie >> 24).to_int() & 0xFF)
        bytes.append((self.cookie >> 16).to_int() & 0xFF)
        bytes.append((self.cookie >> 8).to_int() & 0xFF)
        bytes.append(self.cookie.to_int() & 0xFF)

        # Data size (4 bytes, big-endian)
        bytes.append((self.data_size >> 24).to_int() & 0xFF)
        bytes.append((self.data_size >> 16).to_int() & 0xFF)
        bytes.append((self.data_size >> 8).to_int() & 0xFF)
        bytes.append(self.data_size.to_int() & 0xFF)

        # Name size (1 byte)
        bytes.append(self.name_size.to_int() & 0xFF)

        # Name (variable)
        for i in range(len(self.name)):
            bytes.append(ord(self.name[i]))

        # MIME size (1 byte)
        bytes.append(self.mime_size.to_int() & 0xFF)

        # MIME (variable)
        for i in range(len(self.mime)):
            bytes.append(ord(self.mime[i]))

        # TTL (4 bytes, big-endian)
        bytes.append((self.ttl >> 24).to_int() & 0xFF)
        bytes.append((self.ttl >> 16).to_int() & 0xFF)
        bytes.append((self.ttl >> 8).to_int() & 0xFF)
        bytes.append(self.ttl.to_int() & 0xFF)

        # Data (variable)
        for byte in self.data:
            bytes.append(byte)

        return bytes

    fn deserialize(data: List[UInt8]) -> Self:
        """Deserialize bytes to needle."""
        var needle = Needle()
        var pos = 0

        # Cookie
        needle.cookie = (data[pos].to_int() << 24) | (data[pos+1].to_int() << 16) | (data[pos+2].to_int() << 8) | data[pos+3].to_int()
        pos += 4

        # Data size
        needle.data_size = (data[pos].to_int() << 24) | (data[pos+1].to_int() << 16) | (data[pos+2].to_int() << 8) | data[pos+3].to_int()
        pos += 4

        # Name size
        needle.name_size = data[pos].to_int()
        pos += 1

        # Name
        for i in range(needle.name_size):
            needle.name += chr(data[pos + i])
        pos += needle.name_size

        # MIME size
        needle.mime_size = data[pos].to_int()
        pos += 1

        # MIME
        for i in range(needle.mime_size):
            needle.mime += chr(data[pos + i])
        pos += needle.mime_size

        # TTL
        needle.ttl = (data[pos].to_int() << 24) | (data[pos+1].to_int() << 16) | (data[pos+2].to_int() << 8) | data[pos+3].to_int()
        pos += 4

        # Data
        for i in range(needle.data_size):
            needle.data.append(data[pos + i])

        return needle

# Volume for organizing blobs (SeaweedFS-style)
struct Volume(Movable):
    var id: Int
    var file_path: String
    var index: Dict[UInt64, Tuple[Int, Int]]  # file_key -> (offset, size)
    var writable: Bool
    var file_handle: Optional[PythonObject]

    fn __init__(out self, id: Int, base_path: String):
        self.id = id
        self.file_path = base_path + "/volume_" + String(id) + ".dat"
        self.index = Dict[UInt64, Tuple[Int, Int]]()
        self.writable = True
        self.file_handle = None

        # Ensure directory exists
        var os_mod = Python.import_module("os")
        var dirname = os_mod.path.dirname(self.file_path)
        os_mod.makedirs(dirname, exist_ok=True)

    fn write_needle(mut self, file_key: UInt64, needle: Needle) -> Bool:
        """Write needle to volume file."""
        if not self.writable:
            return False

        try:
            # Open file in append mode
            var file_mod = Python.import_module("builtins")
            if not self.file_handle:
                self.file_handle = file_mod.open(self.file_path, "ab")

            # Serialize needle
            var data = needle.serialize()

            # Get current position (offset)
            var offset = self.file_handle.tell()

            # Write data
            var bytes_obj = PythonObject(data)
            self.file_handle.write(bytes_obj)

            # Update index
            self.index[file_key] = (offset, len(data))

            return True
        except:
            return False

    fn read_needle(self, file_key: UInt64) -> Optional[Needle]:
        """Read needle from volume file."""
        if file_key not in self.index:
            return None

        var offset, size = self.index[file_key]

        try:
            # Open file in read mode
            var file_mod = Python.import_module("builtins")
            var fh = file_mod.open(self.file_path, "rb")

            # Seek to offset
            fh.seek(offset)

            # Read data
            var data = fh.read(size)
            fh.close()

            # Convert to List[UInt8]
            var bytes_list = List[UInt8]()
            for i in range(len(data)):
                bytes_list.append(data[i].to_int())

            # Deserialize
            var needle = Needle.deserialize(bytes_list)
            return needle
        except:
            return None

    fn close(mut self):
        """Close volume file."""
        if self.file_handle:
            self.file_handle.close()
            self.file_handle = None

# Blob metadata for database persistence
struct BlobMetadata(Movable):
    var fid: String
    var volume_id: Int
    var file_key: UInt64
    var cookie: UInt32
    var size: Int
    var created_at: Int64
    var accessed_at: Int64
    var deleted: Bool
    var checksum: String
    var compression: String
    var ttl: Int64

    fn __init__(out self, fid: String, volume_id: Int, file_key: UInt64, cookie: UInt32, size: Int):
        self.fid = fid
        self.volume_id = volume_id
        self.file_key = file_key
        self.cookie = cookie
        self.size = size
        self.created_at = Int64(time() * 1000000)
        self.accessed_at = self.created_at
        self.deleted = False
        self.checksum = ""
        self.compression = "none"
        self.ttl = 0

# Main SeaweedFS-inspired blob store
struct SeaweedBlobStore(Movable):
    var base_path: String
    var volumes: Dict[Int, Volume]
    var current_volume_id: AtomicInt
    var next_file_key: AtomicInt
    var metadata_table: String
    var orc_storage: ORCStorage

    fn __init__(out self, base_path: String, orc_storage: ORCStorage):
        self.base_path = base_path
        self.volumes = Dict[Int, Volume]()
        self.current_volume_id = AtomicInt(1)
        self.next_file_key = AtomicInt(1)
        self.metadata_table = "seaweed_metadata"
        self.orc_storage = orc_storage

        # Initialize metadata table
        self._ensure_metadata_table()

        # Load existing volumes
        self._load_existing_volumes()

    fn put(mut self, data: List[UInt8], name: String = "", mime: String = "") -> String:
        """Store blob and return FID."""
        # Select or create volume
        var volume_id = self.current_volume_id.load()
        if volume_id not in self.volumes:
            self.volumes[volume_id] = Volume(volume_id, self.base_path)

        # Generate FID components
        var file_key = UInt64(self.next_file_key.fetch_add(1))
        var cookie = self._generate_cookie()

        # Create needle
        var needle = Needle()
        needle.cookie = cookie
        needle.data_size = len(data)
        needle.name_size = len(name)
        needle.name = name
        needle.mime_size = len(mime)
        needle.mime = mime
        needle.ttl = 0  # No TTL for now
        needle.data = data

        # Write to volume
        var volume = self.volumes[volume_id]
        if not volume.write_needle(file_key, needle):
            return ""  # Write failed

        # Create FID
        var fid = String(volume_id) + "," + String(file_key) + "," + String(cookie)

        # Persist metadata
        var metadata = BlobMetadata(fid, volume_id, file_key, cookie, len(data))
        self._persist_metadata(metadata)

        return fid

    fn get(self, fid: String) -> List[UInt8]:
        """Retrieve blob by FID."""
        var parts = fid.split(",")
        if len(parts) != 3:
            return List[UInt8]()

        var volume_id = Int(parts[0])
        var file_key = UInt64(parts[1])
        var cookie = UInt32(parts[2])

        if volume_id not in self.volumes:
            return List[UInt8]()

        var needle_opt = self.volumes[volume_id].read_needle(file_key)
        if not needle_opt:
            return List[UInt8]()

        var needle = needle_opt.value()
        if needle.cookie != cookie:
            return List[UInt8]()  # Cookie mismatch (security)

        # Update access time
        self._update_access_time(fid)

        return needle.data

    fn delete(mut self, fid: String) -> Bool:
        """Mark blob as deleted."""
        return self._mark_deleted(fid)

    fn stat(self, fid: String) -> Optional[BlobMetadata]:
        """Get blob metadata."""
        # Query metadata table
        var query = "SELECT * FROM " + self.metadata_table + " WHERE fid = '" + fid + "'"
        var results = self.orc_storage.query_table(query)

        if len(results) == 0:
            return None

        # Parse first result into BlobMetadata
        var row = results[0]
        var metadata = BlobMetadata(
            row["fid"], Int(row["volume_id"]), UInt64(row["file_key"]),
            UInt32(row["cookie"]), Int(row["size"])
        )
        metadata.created_at = Int64(row["created_at"])
        metadata.accessed_at = Int64(row["accessed_at"])
        metadata.deleted = Bool(row["deleted"])
        metadata.checksum = row["checksum"]
        metadata.compression = row["compression"]
        metadata.ttl = Int64(row["ttl"])

        return metadata

    fn _generate_cookie(self) -> UInt32:
        """Generate random cookie for security."""
        # Simple random cookie (in production, use better randomness)
        return UInt32(time() * 1000000 % 0xFFFFFFFF)

    fn _ensure_metadata_table(mut self):
        """Create metadata table if it doesn't exist."""
        var columns = List[Column]()
        columns.append(Column("fid", ColumnType.STRING))
        columns.append(Column("volume_id", ColumnType.INT))
        columns.append(Column("file_key", ColumnType.INT))  # BIGINT equivalent
        columns.append(Column("cookie", ColumnType.INT))
        columns.append(Column("size", ColumnType.INT))
        columns.append(Column("created_at", ColumnType.INT))
        columns.append(Column("accessed_at", ColumnType.INT))
        columns.append(Column("deleted", ColumnType.BOOL))
        columns.append(Column("checksum", ColumnType.STRING))
        columns.append(Column("compression", ColumnType.STRING))
        columns.append(Column("ttl", ColumnType.INT))

        # Try to create (ignore if exists)
        _ = self.orc_storage.create_table(self.metadata_table, columns)

    fn _persist_metadata(mut self, metadata: BlobMetadata):
        """Persist metadata to ORC table."""
        var record = Dict[String, String]()
        record["fid"] = metadata.fid
        record["volume_id"] = String(metadata.volume_id)
        record["file_key"] = String(metadata.file_key)
        record["cookie"] = String(metadata.cookie)
        record["size"] = String(metadata.size)
        record["created_at"] = String(metadata.created_at)
        record["accessed_at"] = String(metadata.accessed_at)
        record["deleted"] = metadata.deleted ? "true" : "false"
        record["checksum"] = metadata.checksum
        record["compression"] = metadata.compression
        record["ttl"] = String(metadata.ttl)

        var records = List[Dict[String, String]]()
        records.append(record)
        _ = self.orc_storage.write_table(self.metadata_table, records)

    fn _load_existing_volumes(mut self):
        """Load existing volumes from filesystem."""
        var os_mod = Python.import_module("os")
        var glob_mod = Python.import_module("glob")

        var pattern = self.base_path + "/volume_*.dat"
        var files = glob_mod.glob(pattern)

        for file_path in files:
            var filename = os_mod.path.basename(file_path)
            var volume_id_str = filename[7:-4]  # Remove "volume_" and ".dat"
            var volume_id = Int(volume_id_str)
            self.volumes[volume_id] = Volume(volume_id, self.base_path)

            # Update current volume ID
            if volume_id >= self.current_volume_id.load():
                self.current_volume_id = AtomicInt(volume_id + 1)

    fn _update_access_time(mut self, fid: String):
        """Update last accessed timestamp."""
        var now = Int64(time() * 1000000)
        # Update in metadata table
        var update_sql = "UPDATE " + self.metadata_table + " SET accessed_at = " + String(now) + " WHERE fid = '" + fid + "'"
        # Note: ORC storage may not support UPDATE, so this is a placeholder
        # In practice, we'd need to implement update operations or use append-only approach

    fn _mark_deleted(mut self, fid: String) -> Bool:
        """Mark blob as deleted."""
        var update_sql = "UPDATE " + self.metadata_table + " SET deleted = true WHERE fid = '" + fid + "'"
        # Placeholder - implement actual update
        return True

    fn cleanup(mut self):
        """Close all volumes."""
        for volume in self.volumes.values():
            volume.close()