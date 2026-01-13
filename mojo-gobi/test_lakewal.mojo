"""
LakeWAL Test Program
===================

Test the embedded LakeWAL functionality.
"""

from lake_wal import LakeWAL

fn main():
    """Test LakeWAL embedded configuration."""
    print("Testing LakeWAL Embedded Configuration")
    print("=====================================")

    var lakewal = LakeWAL()

    print("LakeWAL Info:")
    print(lakewal.get_storage_info())

    print("\nAvailable Configuration Keys:")
    var keys = lakewal.list_configs()
    for key in keys:
        var value = lakewal.get_config(key)
        print("  ", key, "=", value)

    print("\nTesting specific configurations:")
    print("Database version:", lakewal.get_config_with_default("database.version", "unknown"))
    print("Compression:", lakewal.get_config_with_default("storage.compression", "unknown"))
    print("Cache enabled:", lakewal.get_config_with_default("query.cache.enabled", "unknown"))
    print("Non-existent key:", lakewal.get_config_with_default("non.existent", "default_value"))

    print("\nEmbedded status:", "Yes" if lakewal.is_embedded() else "No")