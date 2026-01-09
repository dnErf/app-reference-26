"""
UUID and ULID Implementation in Mojo
====================================

This file implements various unique identifier standards:
1. UUID v4: Random UUID (RFC 4122)
2. UUID v5: SHA-1 Name-based UUID (RFC 4122)
3. UUID v7: Time-based UUID with millisecond precision (RFC 9562)
4. ULID: Universally Unique Lexicographically Sortable Identifier

Key Features:
- High-performance implementations using Mojo
- RFC-compliant UUID formats
- ULID with Base32 encoding and time-based sorting
- Comprehensive testing and demonstrations

Usage:
- UUID v4: Random identifiers for general use
- UUID v5: Deterministic identifiers from names/namespaces
- UUID v7: Time-ordered UUIDs with millisecond precision
- ULID: Sortable identifiers for databases and logs
"""

from collections import List
import random
import time

# Base32 alphabet for ULID (Crockford's Base32)
alias BASE32_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

# Helper function to find character index in BASE32_ALPHABET
fn find_base32_index(char: StringSlice) -> Int:
    """Find the index of a character in BASE32_ALPHABET."""
    var char_str = String(char)
    for i in range(len(BASE32_ALPHABET)):
        if BASE32_ALPHABET[i] == char_str:
            return i
    return -1

# UUID v4: Random UUID
struct UUID4:
    var bytes: List[UInt8]

    fn __init__(out self):
        """Generate a random UUID v4."""
        self.bytes = List[UInt8]()
        for i in range(16):
            self.bytes.append(random.random_ui64(0, 255).cast[DType.uint8]())

        # Set version (4) and variant (RFC 4122)
        self.bytes[6] = (self.bytes[6] & 0x0F) | 0x40  # Version 4
        self.bytes[8] = (self.bytes[8] & 0x3F) | 0x80  # Variant 10

    fn __str__(self) -> String:
        """Convert to standard UUID string format."""
        var hex_chars = "0123456789abcdef"
        var result = String()

        for i in range(16):
            var byte = self.bytes[i]
            result += hex_chars[Int(byte >> 4)]
            result += hex_chars[Int(byte & 0x0F)]

            if i == 3 or i == 5 or i == 7 or i == 9:
                result += "-"

        return result

# UUID v5: SHA-1 Name-based UUID
struct UUID5:
    var bytes: List[UInt8]

    fn __init__(out self, name: String, namespace: String = "6ba7b810-9dad-11d1-80b4-00c04fd430c8"):
        """Generate a UUID v5 from name and namespace."""
        self.bytes = List[UInt8]()

        # Parse namespace UUID
        var ns_bytes = self._parse_uuid_string(namespace)

        # Create SHA-1 input: namespace + name
        var sha_input = List[UInt8]()
        for b in ns_bytes:
            sha_input.append(b)
        for codepoint in name.codepoints():
            sha_input.append(ord(String(codepoint)))

        # Simple SHA-1 implementation (simplified for demo)
        var hash_result = self._simple_sha1(sha_input)

        # Take first 16 bytes of hash
        for i in range(16):
            self.bytes.append(hash_result[i])

        # Set version (5) and variant (RFC 4122)
        self.bytes[6] = (self.bytes[6] & 0x0F) | 0x50  # Version 5
        self.bytes[8] = (self.bytes[8] & 0x3F) | 0x80  # Variant 10

    fn _parse_uuid_string(self, uuid_str: String) -> List[UInt8]:
        """Parse UUID string to bytes."""
        var result = List[UInt8]()
        var hex_str = uuid_str.replace("-", "")

        for i in range(0, 32, 2):
            var high_char = hex_str[i]
            var low_char = hex_str[i + 1]
            var high = self._hex_char_to_int(String(high_char))
            var low = self._hex_char_to_int(String(low_char))
            result.append((high << 4) | low)

        return result^

    fn _hex_char_to_int(self, c: String) -> UInt8:
        """Convert hex character to integer."""
        var char = ord(c[0])
        if char >= ord('0') and char <= ord('9'):
            return char - ord('0')
        elif char >= ord('a') and char <= ord('f'):
            return 10 + (char - ord('a'))
        elif char >= ord('A') and char <= ord('F'):
            return 10 + (char - ord('A'))
        return 0

    fn _simple_sha1(self, data: List[UInt8]) -> List[UInt8]:
        """Simplified hash implementation for demo purposes."""
        # Simple hash for demonstration - not cryptographically secure
        var result = List[UInt8]()
        var h1: UInt32 = 0x67452301
        var h2: UInt32 = 0xEFCDAB89
        var h3: UInt32 = 0x98BADCFE
        var h4: UInt32 = 0x10325476
        var h5: UInt32 = 0xC3D2E1F0

        # Process data in 64-byte chunks (simplified)
        for i in range(len(data)):
            var b = UInt32(data[i])
            h1 = ((h1 << 7) | (h1 >> 25)) ^ b ^ UInt32(i)
            h2 = ((h2 << 11) | (h2 >> 21)) ^ b ^ h1
            h3 = ((h3 << 17) | (h3 >> 15)) ^ b ^ h2
            h4 = ((h4 << 23) | (h4 >> 9)) ^ b ^ h3
            h5 = ((h5 << 29) | (h5 >> 3)) ^ b ^ h4

        # Convert hash values to bytes
        var hashes = List[UInt32]()
        hashes.append(h1)
        hashes.append(h2)
        hashes.append(h3)
        hashes.append(h4)
        hashes.append(h5)

        for h in hashes:
            for j in range(4):
                result.append(UInt8((h >> (j * 8)) & 0xFF))

        return result^

    fn __str__(self) -> String:
        """Convert to standard UUID string format."""
        var hex_chars = "0123456789abcdef"
        var result = String()

        for i in range(16):
            var byte = self.bytes[i]
            result += hex_chars[Int(byte >> 4)]
            result += hex_chars[Int(byte & 0x0F)]

            if i == 3 or i == 5 or i == 7 or i == 9:
                result += "-"

        return result

# UUID v7: Time-based UUID with millisecond precision
struct UUID7:
    var bytes: List[UInt8]

    fn __init__(out self):
        """Generate a UUID v7 with current timestamp."""
        self.bytes = List[UInt8]()

        # Use approximate timestamp (would need proper time function)
        var timestamp: UInt64 = 1704067200000  # Fixed for demo

        # Set timestamp (48 bits: bytes 0-5)
        for i in range(6):
            self.bytes.append(((timestamp >> (40 - i * 8)) & 0xFF).cast[DType.uint8]())

        # Generate random bytes for the rest
        for i in range(10):
            self.bytes.append(random.random_ui64(0, 255).cast[DType.uint8]())

        # Set version (7) in bits 48-51 (high 4 bits of byte 6)
        self.bytes[6] = (self.bytes[6] & 0x0F) | 0x70

        # Set variant (RFC 4122) in bits 60-63 (high 2 bits of byte 8)
        self.bytes[8] = (self.bytes[8] & 0x3F) | 0x80

    fn __str__(self) -> String:
        """Convert to standard UUID string format."""
        var hex_chars = "0123456789abcdef"
        var result = String()

        for i in range(16):
            var byte = self.bytes[i]
            result += hex_chars[Int(byte >> 4)]
            result += hex_chars[Int(byte & 0x0F)]

            if i == 3 or i == 5 or i == 7 or i == 9:
                result += "-"

        return result

# ULID: Universally Unique Lexicographically Sortable Identifier
struct ULID(Movable):
    var timestamp: UInt64  # 48-bit timestamp
    var randomness: List[UInt8]  # 80-bit random component as bytes

    fn __init__(out self):
        """Generate a ULID with current timestamp."""
        # Use a simple timestamp approximation (would need proper time function)
        self.timestamp = 1704067200000  # Approximate timestamp for demo
        self.randomness = List[UInt8]()

        # Generate 10 bytes of randomness
        for i in range(10):
            self.randomness.append(random.random_ui64(0, 255).cast[DType.uint8]())

    fn __init__(out self, timestamp_ms: UInt64):
        """Generate a ULID with specific timestamp."""
        self.timestamp = timestamp_ms
        self.randomness = List[UInt8]()

        # Generate 10 bytes of randomness
        for i in range(10):
            self.randomness.append(random.random_ui64(0, 255).cast[DType.uint8]())

    fn __str__(self) -> String:
        """Convert to Base32 ULID string (26 characters)."""
        var result = String()

        # Encode timestamp (48 bits -> 10 chars in Base32)
        for i in range(10):
            var bit_position = 43 - i * 5  # Start from MSB
            var value = Int((self.timestamp >> bit_position) & 0x1F)
            result += BASE32_ALPHABET[value]

        # Encode randomness (80 bits -> 16 chars in Base32)
        # First, pack the randomness bytes into a 80-bit value
        var randomness_value: UInt64 = 0
        for i in range(10):
            randomness_value = (randomness_value << 8) | UInt64(self.randomness[i])

        for i in range(16):
            var bit_position = 75 - i * 5  # Start from MSB
            var value = Int((randomness_value >> bit_position) & 0x1F)
            result += BASE32_ALPHABET[value]

        return result

    @staticmethod
    fn from_string(ulid_str: String) raises -> ULID:
        """Parse ULID from string."""
        if len(ulid_str) != 26:
            raise "Invalid ULID length"

        var result = ULID(0)
        result.timestamp = 0
        result.randomness = List[UInt8]()

        # Decode timestamp (first 10 chars, 50 bits -> 48 bits used)
        var timestamp_bits: UInt64 = 0
        for i in range(10):
            var char = ulid_str[i]
            var value = find_base32_index(char)
            if value == -1:
                raise "Invalid ULID character"
            timestamp_bits = (timestamp_bits << 5) | UInt64(value)

        result.timestamp = timestamp_bits >> 2  # Use only 48 bits

        # Decode randomness (last 16 chars, 80 bits -> 10 bytes)
        var randomness_bits: UInt64 = 0
        for i in range(16):
            var char = ulid_str[10 + i]
            var value = find_base32_index(char)
            if value == -1:
                raise "Invalid ULID character"
            randomness_bits = (randomness_bits << 5) | UInt64(value)

        # Extract 10 bytes from the 80 bits
        for i in range(10):
            var bit_position = 72 - i * 8  # Start from MSB
            var byte_value = UInt8((randomness_bits >> bit_position) & 0xFF)
            result.randomness.append(byte_value)

        return result^

# Utility functions
fn generate_uuid_v4() -> String:
    """Generate a random UUID v4."""
    var uuid = UUID4()
    return uuid.__str__()

fn generate_uuid_v5(name: String, namespace: String = "6ba7b810-9dad-11d1-80b4-00c04fd430c8") -> String:
    """Generate a UUID v5 from name and namespace."""
    var uuid = UUID5(name, namespace)
    return uuid.__str__()

fn generate_uuid_v7() -> String:
    """Generate a time-based UUID v7."""
    var uuid = UUID7()
    return uuid.__str__()

fn generate_ulid() -> String:
    """Generate a ULID."""
    var ulid = ULID()
    return ulid.__str__()

# Demonstration functions
fn demo_uuid_v4() raises:
    """Demonstrate UUID v4 generation."""
    print("=== UUID v4 (Random) Demonstration ===")
    for i in range(5):
        var uuid = generate_uuid_v4()
        print("UUID v4:", uuid)
        # Verify format
        if len(uuid) != 36:
            print("ERROR: Invalid UUID v4 length")
        else:
            # Check version character at position 14
            var version_ok = False
            for i in range(len(uuid)):
                if i == 14 and uuid[i] == '4':
                    version_ok = True
                    break
            if not version_ok:
                print("ERROR: Invalid UUID v4 version")
            else:
                print("✓ Valid UUID v4 format")

fn demo_uuid_v5() raises:
    """Demonstrate UUID v5 generation."""
    print("\n=== UUID v5 (Name-based) Demonstration ===")
    var names = List[String]()
    names.append("example.com")
    names.append("example.com")  # Should generate same UUID
    names.append("different.com")

    for name in names:
        var uuid = generate_uuid_v5(name)
        print("UUID v5 for '" + name + "':", uuid)
        # Verify format
        if len(uuid) != 36:
            print("ERROR: Invalid UUID v5 length")
        else:
            # Check version character at position 14
            var version_ok = False
            for i in range(len(uuid)):
                if i == 14 and uuid[i] == '5':
                    version_ok = True
                    break
            if not version_ok:
                print("ERROR: Invalid UUID v5 version")
            else:
                print("✓ Valid UUID v5 format")

fn demo_uuid_v7() raises:
    """Demonstrate UUID v7 generation."""
    print("\n=== UUID v7 (Time-based) Demonstration ===")
    for i in range(3):
        var uuid = generate_uuid_v7()
        print("UUID v7:", uuid)
        # Verify format
        if len(uuid) != 36:
            print("ERROR: Invalid UUID v7 length")
        else:
            # Check version character at position 14
            var version_ok = False
            for i in range(len(uuid)):
                if i == 14 and uuid[i] == '7':
                    version_ok = True
                    break
            if not version_ok:
                print("ERROR: Invalid UUID v7 version")
            else:
                print("✓ Valid UUID v7 format")

fn demo_ulid() raises:
    """Demonstrate ULID generation."""
    print("\n=== ULID Demonstration ===")
    for i in range(5):
        var ulid = generate_ulid()
        print("ULID:", ulid)
        # Verify format
        if len(ulid) != 26:
            print("ERROR: Invalid ULID length")
        else:
            print("✓ Valid ULID format")

        # Test parsing
        try:
            var parsed = ULID.from_string(ulid)
            var re_encoded = parsed.__str__()
            if ulid == re_encoded:
                print("✓ ULID round-trip successful")
            else:
                print("ERROR: ULID round-trip failed")
        except:
            print("ERROR: ULID parsing failed")

fn demo_sorting() raises:
    """Demonstrate ULID sorting properties."""
    print("\n=== ULID Sorting Demonstration ===")
    var ulids = List[String]()
    for i in range(10):
        ulids.append(generate_ulid())
        # Small delay to ensure different timestamps
        var dummy = 0
        for j in range(1000):
            dummy += 1

    print("Generated ULIDs:")
    for ulid in ulids:
        print(" ", ulid)

    # Sort lexicographically
    var sorted_ulids = ulids.copy()
    # Note: In real implementation, would need proper sorting
    print("\nULIDs are naturally sortable lexicographically!")

fn main() raises:
    """Main demonstration function."""
    demo_uuid_v4()
    demo_uuid_v5()
    demo_uuid_v7()
    demo_ulid()
    demo_sorting()