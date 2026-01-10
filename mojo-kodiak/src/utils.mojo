"""
Mojo Kodiak DB - Utility Functions

Contains utility functions for ID generation, hashing, and other common operations.
"""

import time
from python import Python

struct ULID:
    """
    ULID (Universally Unique Lexicographically Sortable Identifier) implementation.
    128-bit identifier that's sortable by creation time.
    Format: TTTTTTTTTTRRRRRRRRRRRRRRRR (10 bytes timestamp + 16 bytes random)
    """

    var timestamp: UInt64  # 48 bits used (Unix timestamp in milliseconds)
    var randomness: UInt64  # 80 bits of randomness

    fn __init__(out self) raises:
        """
        Generate a new ULID with current timestamp and random bytes.
        """
        var py_time = Python.import_module("time")
        var current_time = py_time.time()
        self.timestamp = UInt64(current_time * 1000)  # Convert to milliseconds

        # Generate randomness using Python's secrets module
        var secrets = Python.import_module("secrets")
        var random_bytes = secrets.token_bytes(10)  # 80 bits = 10 bytes
        self.randomness = 0
        for i in range(10):
            self.randomness = self.randomness << 8
            self.randomness |= UInt64(random_bytes[i])

    fn __str__(self) -> String:
        """
        Convert ULID to Crockford base32 string representation.
        """
        # Combine timestamp and randomness into 128-bit value
        var value = UInt128(self.timestamp) << 80 | UInt128(self.randomness)

        # Crockford base32 alphabet (no I, L, O, U)
        var alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
        var result = String("")

        # Encode 128 bits as 26 base32 characters
        for i in range(26):
            var char_index = Int((value >> (125 - i * 5)) & 0x1F)
            result += alphabet[char_index]

        return result

    fn to_bytes(self) -> List[UInt8]:
        """
        Convert ULID to 16 bytes (big-endian).
        """
        var bytes = List[UInt8]()
        var value = UInt128(self.timestamp) << 80 | UInt128(self.randomness)

        for i in range(16):
            bytes.append(UInt8((value >> (120 - i * 8)) & 0xFF))

        return bytes

    @staticmethod
    fn from_string(ulid_str: String) raises -> ULID:
        """
        Parse ULID from Crockford base32 string.
        """
        if len(ulid_str) != 26:
            raise Error("ULID string must be 26 characters")

        # Crockford base32 decoding
        var alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
        var value: UInt128 = 0

        for char in ulid_str:
            var char_upper = String(char).upper()
            var index = alphabet.find(char_upper)
            if index == -1:
                raise Error("Invalid character in ULID: " + char_upper)
            value = (value << 5) | UInt128(index)

        var ulid = ULID.__init_zeroed()
        ulid.timestamp = UInt64(value >> 80)
        ulid.randomness = UInt64(value & 0xFFFFFFFFFFFFFFFFFF)  # 80 bits

        return ulid

struct UUID:
    """
    UUID (Universally Unique Identifier) implementation.
    """

    var data: List[UInt8]  # 16 bytes

    fn __init__(out self) raises:
        """
        Generate a new UUID v4 (random).
        """
        var secrets = Python.import_module("secrets")
        var random_bytes = secrets.token_bytes(16)
        self.data = List[UInt8]()
        for i in range(16):
            self.data.append(random_bytes[i])

        # Set version (4) and variant (RFC 4122)
        self.data[6] = (self.data[6] & 0x0F) | 0x40  # Version 4
        self.data[8] = (self.data[8] & 0x3F) | 0x80  # Variant 10

    fn __str__(self) -> String:
        """
        Convert UUID to standard string format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
        """
        var result = String("")
        var hex_chars = "0123456789abcdef"

        for i in range(16):
            var byte = self.data[i]
            result += hex_chars[Int(byte >> 4)]
            result += hex_chars[Int(byte & 0x0F)]

            if i == 3 or i == 5 or i == 7 or i == 9:
                result += "-"

        return result

    @staticmethod
    fn v5(namespace: UUID, name: String) raises -> UUID:
        """
        Generate UUID v5 (name-based) using SHA-1 hash.
        """
        var hashlib = Python.import_module("hashlib")
        var sha1 = hashlib.sha1()

        # Add namespace bytes
        for byte in namespace.data:
            sha1.update(bytes([byte]))

        # Add name bytes
        sha1.update(name.as_bytes())

        var hash_bytes = sha1.digest()
        var uuid = UUID.__init_zeroed()
        uuid.data = List[UInt8]()

        # Take first 16 bytes of SHA-1 hash
        for i in range(16):
            uuid.data.append(hash_bytes[i])

        # Set version (5) and variant (RFC 4122)
        uuid.data[6] = (uuid.data[6] & 0x0F) | 0x50  # Version 5
        uuid.data[8] = (uuid.data[8] & 0x3F) | 0x80  # Variant 10

        return uuid

    @staticmethod
    fn namespace_dns() raises -> UUID:
        """
        DNS namespace UUID: 6ba7b810-9dad-11d1-80b4-00c04fd430c8
        """
        var uuid = UUID.__init_zeroed()
        uuid.data = List[UInt8]([0x6b, 0xa7, 0xb8, 0x10, 0x9d, 0xad, 0x11, 0xd1,
                                0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8])
        return uuid

    @staticmethod
    fn namespace_url() raises -> UUID:
        """
        URL namespace UUID: 6ba7b811-9dad-11d1-80b4-00c04fd430c8
        """
        var uuid = UUID.__init_zeroed()
        uuid.data = List[UInt8]([0x6b, 0xa7, 0xb8, 0x11, 0x9d, 0xad, 0x11, 0xd1,
                                0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8])
        return uuid

    @staticmethod
    fn namespace_oid() raises -> UUID:
        """
        OID namespace UUID: 6ba7b812-9dad-11d1-80b4-00c04fd430c8
        """
        var uuid = UUID.__init_zeroed()
        uuid.data = List[UInt8]([0x6b, 0xa7, 0xb8, 0x12, 0x9d, 0xad, 0x11, 0xd1,
                                0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8])
        return uuid

    @staticmethod
    fn namespace_x500() raises -> UUID:
        """
        X.500 namespace UUID: 6ba7b814-9dad-11d1-80b4-00c04fd430c8
        """
        var uuid = UUID.__init_zeroed()
        uuid.data = List[UInt8]([0x6b, 0xa7, 0xb8, 0x14, 0x9d, 0xad, 0x11, 0xd1,
                                0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8])
        return uuid

fn generate_ulid() raises -> String:
    """
    Convenience function to generate a new ULID string.
    """
    var ulid = ULID()
    return ulid.__str__()

fn generate_uuid_v4() raises -> String:
    """
    Convenience function to generate a new UUID v4 string.
    """
    var uuid = UUID()
    return uuid.__str__()

fn generate_uuid_v5(namespace: String, name: String) raises -> String:
    """
    Convenience function to generate a UUID v5 string.
    namespace should be one of: 'dns', 'url', 'oid', 'x500'
    """
    var ns_uuid: UUID
    if namespace == "dns":
        ns_uuid = UUID.namespace_dns()
    elif namespace == "url":
        ns_uuid = UUID.namespace_url()
    elif namespace == "oid":
        ns_uuid = UUID.namespace_oid()
    elif namespace == "x500":
        ns_uuid = UUID.namespace_x500()
    else:
        raise Error("Unknown namespace: " + namespace)

    var uuid = UUID.v5(ns_uuid, name)
    return uuid.__str__()

fn atof(s: String) raises -> Float64:
    """
    Convert string to float64. Simple implementation for basic cases.
    """
    if s == "":
        return 0.0

    var result: Float64 = 0.0
    var decimal_place = 0
    var is_negative = False
    var i = 0

    # Handle negative sign
    if s[i] == '-':
        is_negative = True
        i += 1

    # Parse integer part
    while i < len(s) and s[i] != '.':
        if s[i] >= '0' and s[i] <= '9':
            result = result * 10.0 + Float64(ord(s[i]) - ord('0'))
        elif s[i] == ' ' or s[i] == '\t':
            pass  # Skip whitespace
        else:
            break
        i += 1

    # Parse decimal part
    if i < len(s) and s[i] == '.':
        i += 1
        var divisor: Float64 = 10.0
        while i < len(s):
            if s[i] >= '0' and s[i] <= '9':
                result += Float64(ord(s[i]) - ord('0')) / divisor
                divisor *= 10.0
            elif s[i] == ' ' or s[i] == '\t':
                pass  # Skip whitespace
            else:
                break
            i += 1

    return result if not is_negative else -result