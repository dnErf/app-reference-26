"""
Minimal test for SeaweedFS-like blob storage
===========================================

Demonstrates core blob functionality.
"""

from seaweed_blob_store import Needle
from collections import List

fn test_needle_format() raises:
    """Test needle serialization/deserialization."""
    print("Testing Needle format...")

    # Create test needle
    var needle = Needle()
    needle.cookie = 12345
    needle.data_size = 5
    needle.name_size = 8
    needle.name = "test.txt"
    needle.mime_size = 10
    needle.mime = "text/plain"
    needle.ttl = 0
    needle.data = List[UInt8]()
    needle.data.append(72)  # 'H'
    needle.data.append(101) # 'e'
    needle.data.append(108) # 'l'
    needle.data.append(108) # 'l'
    needle.data.append(111) # 'o'

    # Serialize
    var serialized = needle.serialize()
    print("Serialized size:", len(serialized), "bytes")

    # Deserialize
    var deserialized = Needle.deserialize(serialized)
    print("Deserialized cookie:", deserialized.cookie)
    print("Deserialized name:", deserialized.name)
    print("Deserialized data size:", len(deserialized.data))

    # Verify
    assert deserialized.cookie == needle.cookie
    assert deserialized.name == needle.name
    assert len(deserialized.data) == len(needle.data)

    print("✓ Needle format test passed")

fn main() raises:
    """Run minimal blob tests."""
    print("Running SeaweedFS-like Blob Storage Tests")
    print("=" * 45)

    test_needle_format()

    print("\n✓ Core blob storage components working!")
    print("Note: Full integration requires ORC storage setup.")