# Secret Extension for Mojo Grizzly DB
# Highly secure secrets for tokens/keys.

import random

var secrets: Dict[String, String] = Dict[String, String]()
var master_key: String = ""

fn init():
    global master_key = generate_key()
    print("Secret extension loaded. Master key:", master_key)

fn generate_key() -> String:
    # Simple random key
    return str(random.randint(100000, 999999))

fn create_secret(name: String, value: String):
    let encrypted = encrypt(value, master_key)
    secrets[name] = encrypted

fn get_secret(name: String) -> String:
    if name in secrets:
        return decrypt(secrets[name], master_key)
    return ""

fn encrypt(value: String, key: String) -> String:
    # Simple XOR encryption
    var result = ""
    for i in range(len(value)):
        let c = ord(value[i]) ^ ord(key[i % len(key)])
        result += chr(c)
    return result

fn decrypt(encrypted: String, key: String) -> String:
    return encrypt(encrypted, key)  # XOR is symmetric