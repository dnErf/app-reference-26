# PL-GRIZZLY Default Configuration Constants
# Simplified replacement for LakeWAL embedded storage

struct ConfigDefaults:
    """Default configuration values for PL-GRIZZLY database system."""

    # Database settings
    @staticmethod
    fn database_version() -> String:
        return "2.1.0"

    @staticmethod
    fn database_name() -> String:
        return "PL-GRIZZLY"

    @staticmethod
    fn database_engine() -> String:
        return "Lakehouse"

    # Storage settings
    @staticmethod
    fn storage_compression_default() -> String:
        return "snappy"

    @staticmethod
    fn storage_compression_level() -> String:
        return "6"

    @staticmethod
    fn storage_orc_stripe_size() -> String:
        return "67108864"  # 64MB

    @staticmethod
    fn storage_page_size() -> String:
        return "8192"

    # Query settings
    @staticmethod
    fn query_max_memory() -> String:
        return "1073741824"  # 1GB

    @staticmethod
    fn query_timeout() -> String:
        return "300000"  # 5 minutes

    @staticmethod
    fn query_max_rows() -> String:
        return "1000000"

    # JIT settings
    @staticmethod
    fn jit_enabled() -> String:
        return "true"

    @staticmethod
    fn jit_optimization_level() -> String:
        return "2"

    # Get all config as dict
    @staticmethod
    fn get_all_config() -> Dict[String, String]:
        var config = Dict[String, String]()
        config["database.version"] = Self.database_version()
        config["database.name"] = Self.database_name()
        config["database.engine"] = Self.database_engine()
        config["storage.compression.default"] = Self.storage_compression_default()
        config["storage.compression.level"] = Self.storage_compression_level()
        config["storage.orc.stripe_size"] = Self.storage_orc_stripe_size()
        config["storage.page_size"] = Self.storage_page_size()
        config["query.max_memory"] = Self.query_max_memory()
        config["query.timeout"] = Self.query_timeout()
        config["query.max_rows"] = Self.query_max_rows()
        config["jit.enabled"] = Self.jit_enabled()
        config["jit.optimization_level"] = Self.jit_optimization_level()
        return config^