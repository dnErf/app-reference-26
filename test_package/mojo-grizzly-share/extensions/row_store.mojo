# Row Store Extension for Mojo Grizzly DB
# Makes AVRO row persistence the default upon installation.

struct RowStoreConfig:
    @staticmethod
    var is_default: Bool = False

fn init():
    RowStoreConfig.is_default = True
    print("Row store installed: AVRO row persistence is now default")