from lake_wal_embedded import get_embedded_orc_data

fn main():
    var data = get_embedded_orc_data()
    print("Decoded data length:", len(data))
    print("First 20 bytes:")
    for i in range(min(20, len(data))):
        print(" ", hex(data[i]), end="")
    print("")
    if len(data) >= 4:
        print("First 4 bytes as chars:", chr(Int(data[0])), chr(Int(data[1])), chr(Int(data[2])), chr(Int(data[3])))
