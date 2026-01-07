# Column Store Extension for Mojo Grizzly DB
# Makes Parquet columnar persistence the default upon installation.

struct ColumnStoreConfig:
    @staticmethod
    var is_default: Bool = False

fn init():
    ColumnStoreConfig.is_default = True
    print("Column store installed: Parquet columnar persistence is now default")