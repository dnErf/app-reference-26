"""
ULID and UUID Generation Utilities for Mojo Kodiak

This module provides unique identifier generation capabilities including:
- ULID (Universally Unique Lexicographically Sortable Identifier)
- UUID v5 (Name-based UUID generation)

These identifiers are essential for the SCM system, BLOB storage, and package management.
"""

from python import Python
from time import time
import random

# ULID Implementation
struct ULID:
    """
    Universally Unique Lexicographically Sortable Identifier.

    ULID is a 26-character string that is URL-safe and can be sorted lexicographically.
    Format: TTTTTTTTTTRRRRRRRRRRRRRRRR
    - T: 10-character timestamp (48 bits)
    - R: 16-character randomness (80 bits)
    """
    var timestamp: UInt64
    var randomness: UInt64
    var encoded: String

    fn __init__(out self) raises:
        """Create a new ULID with current timestamp and random bytes."""
        var time_module = Python.import_module("time")
        var time_val = time_module.time()
        # Convert to milliseconds, but keep as reasonable size for ULID
        var time_ms = time_val * 1000
        var time_int = Int(time_ms)
        self.timestamp = UInt64(time_int % 281474976710655)  # Max ULID timestamp (2^48 - 1)
        self.randomness = 0  # Initialize first
        self.encoded = ""  # Initialize first
        self.randomness = self._generate_randomness()
        self.encoded = self._encode()

    fn __init__(out self, timestamp: UInt64, randomness: UInt64):
        """Create ULID from existing timestamp and randomness values."""
        self.timestamp = timestamp
        self.randomness = randomness
        self.encoded = self._encode()

    fn __init__(out self, ulid_string: String):
        """Parse ULID from string representation."""
        if len(ulid_string) != 26:
            self.timestamp = 0
            self.randomness = 0
            self.encoded = ""
            return

        # Decode timestamp (first 10 characters)
        var timestamp_part = ulid_string[0:10]
        self.timestamp = self._decode_crockford(timestamp_part)

        # Decode randomness (last 16 characters)
        var randomness_part = ulid_string[10:26]
        self.randomness = self._decode_crockford(randomness_part)

        self.encoded = ulid_string

    fn _generate_randomness(self) raises -> UInt64:
        """Generate 64 bits of randomness."""
        # Use Python's random module for better randomness
        var py_random = Python.import_module("random")
        # Generate two 32-bit random values and combine
        var rand1 = py_random.getrandbits(32)
        var rand2 = py_random.getrandbits(32)
        # Combine into 64-bit value
        var result = UInt64(Int(rand1)) | (UInt64(Int(rand2)) << 32)
        return result

    fn _encode(self) -> String:
        """Encode timestamp and randomness into ULID string."""
        var timestamp_encoded = self._encode_crockford(self.timestamp, 10)
        var randomness_encoded = self._encode_crockford(self.randomness, 16)
        return timestamp_encoded + randomness_encoded

    fn _encode_crockford(self, value: UInt64, length: Int) -> String:
        """Encode a number using Crockford Base32 encoding."""
        var chars = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
        var result = String("")

        var current_value = value
        for i in range(length):
            var char_index = Int(current_value % 32)
            result = chars[char_index] + result
            current_value = current_value // 32

        return result

    fn _decode_crockford(self, encoded: String) -> UInt64:
        """Decode a Crockford Base32 encoded string."""
        var chars = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
        var result: UInt64 = 0

        for char in encoded.codepoints():
            var char_str = String(char)
            var char_index = chars.find(char_str)
            if char_index == -1:
                # Handle case-insensitive decoding
                char_str = char_str.upper()
                char_index = chars.find(char_str)
                if char_index == -1:
                    continue

            result = result * 32 + UInt64(char_index)

        return result

    fn to_string(self) -> String:
        """Return the ULID as a string."""
        return self.encoded

    fn __str__(self) -> String:
        """String representation of ULID."""
        return self.encoded

# UUID Implementation
struct UUID:
    """
    Universally Unique Identifier.

    Supports UUID v5 (name-based) generation using SHA-1 hashing.
    """
    var bytes: List[UInt8]  # 16 bytes
    var string_repr: String

    fn __init__(out self):
        """Create a nil UUID (all zeros)."""
        self.bytes = List[UInt8]()
        for i in range(16):
            self.bytes.append(0)
        self.string_repr = self._bytes_to_string()

    fn __init__(out self, uuid_string: String) raises:
        """Parse UUID from string representation."""
        self.bytes = List[UInt8]()
        self.string_repr = uuid_string

        # Parse UUID string format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
        if len(uuid_string) != 36:
            # Invalid format, create nil UUID
            for i in range(16):
                self.bytes.append(0)
            return

        # Remove hyphens and parse hex
        var hex_string = uuid_string.replace("-", "")
        if len(hex_string) != 32:
            # Invalid format, create nil UUID
            for i in range(16):
                self.bytes.append(0)
            return

        for i in range(16):
            var byte_str = hex_string[i*2:i*2+2]
            var byte_value = self._hex_to_byte(byte_str)
            self.bytes.append(byte_value)

    fn _hex_to_byte(self, hex_str: String) raises -> UInt8:
        """Convert hex string to byte."""
        var py_builtin = Python.import_module("builtins")
        return UInt8(py_builtin.int(hex_str, 16))

    fn _bytes_to_string(self) raises -> String:
        """Convert bytes to UUID string format."""
        if len(self.bytes) != 16:
            return "00000000-0000-0000-0000-000000000000"

        var hex_parts = List[String]()
        for i in range(16):
            var hex_byte = String.format("{:02x}", self.bytes[i])
            hex_parts.append(hex_byte)

        return hex_parts[0] + hex_parts[1] + hex_parts[2] + hex_parts[3] + "-" +
               hex_parts[4] + hex_parts[5] + "-" +
               hex_parts[6] + hex_parts[7] + "-" +
               hex_parts[8] + hex_parts[9] + "-" +
               hex_parts[10] + hex_parts[11] + hex_parts[12] + hex_parts[13] + hex_parts[14] + hex_parts[15]

    fn to_string(self) -> String:
        """Return the UUID as a string."""
        return self.string_repr

    fn __str__(self) -> String:
        """String representation of UUID."""
        return self.string_repr

    @staticmethod
    fn generate_v5(name: String, namespace: UUID) raises -> UUID:
        """
        Generate UUID v5 (name-based) using SHA-1 hashing.

        Args:
            name: The name to hash
            namespace: The namespace UUID

        Returns:
            A new UUID v5
        """
        var hashlib = Python.import_module("hashlib")

        # Combine namespace bytes with name
        var namespace_bytes = namespace.bytes.copy()
        var name_bytes = name.as_bytes()

        # Create SHA-1 hash
        var sha1 = hashlib.sha1()
        sha1.update(bytes(namespace_bytes))
        sha1.update(name_bytes)
        var hash_bytes = sha1.digest()

        # Create UUID from first 16 bytes of hash
        var uuid_bytes = List[UInt8]()
        for i in range(16):
            uuid_bytes.append(UInt8(hash_bytes[i]))

        # Set version (5) and variant (RFC 4122)
        uuid_bytes[6] = (uuid_bytes[6] & 0x0F) | 0x50  # Version 5
        uuid_bytes[8] = (uuid_bytes[8] & 0x3F) | 0x80  # Variant 10

        var result = UUID()
        result.bytes = uuid_bytes^
        result.string_repr = result._bytes_to_string()
        return result^

# Namespace UUIDs for UUID v5 generation
fn get_namespace_dns() -> UUID:
    """Get the DNS namespace UUID."""
    return UUID("6ba7b810-9dad-11d1-80b4-00c04fd430c8")

fn get_namespace_url() -> UUID:
    """Get the URL namespace UUID."""
    return UUID("6ba7b811-9dad-11d1-80b4-00c04fd430c8")

fn get_namespace_oid() -> UUID:
    """Get the OID namespace UUID."""
    return UUID("6ba7b812-9dad-11d1-80b4-00c04fd430c8")

fn get_namespace_x500() -> UUID:
    """Get the X.500 namespace UUID."""
    return UUID("6ba7b814-9dad-11d1-80b4-00c04fd430c8")

# Utility functions
fn generate_ulid() raises -> ULID:
    """Generate a new ULID."""
    return ULID()

fn generate_uuid_v5(name: String, namespace: UUID) raises -> UUID:
    """Generate a UUID v5 from name and namespace."""
    return UUID.generate_v5(name, namespace)

fn ulid_from_string(ulid_string: String) -> ULID:
    """Parse ULID from string."""
    return ULID(ulid_string)

fn uuid_from_string(uuid_string: String) raises -> UUID:
    """Parse UUID from string."""
    return UUID(uuid_string)

# Test functions
fn test_ulid_generation() raises:
    """Test ULID generation and parsing."""
    print("Testing ULID generation...")

    var ulid1 = generate_ulid()
    var ulid2 = generate_ulid()

    print("ULID 1:", ulid1.to_string())
    print("ULID 2:", ulid2.to_string())

    # Test parsing
    var parsed = ulid_from_string(ulid1.to_string())
    print("Parsed ULID:", parsed.to_string())
    print("Parse successful:", ulid1.to_string() == parsed.to_string())

fn test_uuid_v5_generation() raises:
    """Test UUID v5 generation."""
    print("Testing UUID v5 generation...")

    var name1 = "example.com"
    var name2 = "example.com"
    var name3 = "different.com"

    var namespace_url = get_namespace_url()
    var uuid1 = generate_uuid_v5(name1, namespace_url)
    var uuid2 = generate_uuid_v5(name2, namespace_url)
    var uuid3 = generate_uuid_v5(name3, namespace_url)

    print("UUID 1 (example.com):", uuid1.to_string())
    print("UUID 2 (example.com):", uuid2.to_string())
    print("UUID 3 (different.com):", uuid3.to_string())
    print("UUID 1 == UUID 2:", uuid1.to_string() == uuid2.to_string())
    print("UUID 1 != UUID 3:", uuid1.to_string() != uuid3.to_string())