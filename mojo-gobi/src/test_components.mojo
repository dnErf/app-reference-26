# Test minimal import to isolate segfault
from collections import Dict
from blob_storage import BlobStorage
from schema_manager import SchemaManager
from index_storage import IndexStorage
from orc_storage import ORCStorage
from merkle_timeline import MerkleTimeline
from incremental_processor import IncrementalProcessor
from materialization_engine import MaterializationEngine
from query_optimizer import QueryOptimizer
from profiling_manager import ProfilingManager
from root_storage import RootStorage
from job_scheduler import JobScheduler

fn main():
    print("All imports work")
    var d = Dict[String, String]()
    print("Dict created")