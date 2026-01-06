# BLOCK Store for Mojo Grizzly DB
# Persistent storage using ORC under the hood, extensible to blockchain/graph.

from arrow import Table, Schema
from formats import write_orc, read_orc
import hashlib  # Assume Mojo has hashlib or implement simple hash

struct Block(Copyable, Movable):
    var data: Table
    var hash: String
    var prev_hash: String  # For blockchain

    fn __init__(out self, var data: Table, prev_hash: String = ""):
        self.data = data^
        self.prev_hash = prev_hash
        self.hash = self.compute_hash()

    fn __copyinit__(out self, existing: Block):
        self.data = existing.data
        self.hash = existing.hash
        self.prev_hash = existing.prev_hash

    fn __copyinit__(out self, existing: Block):
        self.data = existing.data
        self.hash = existing.hash
        self.prev_hash = existing.prev_hash

    fn __moveinit__(out self, deinit existing: Block):
        self.data = existing.data^
        self.hash = existing.hash
        self.prev_hash = existing.prev_hash

    fn compute_hash(self) -> String:
        # Include prev_hash
        var h = 0
        for col in self.data.columns:
            for val in col.data:
                h = (h * 31 + val) % 1000000
        h = (h * 31 + hash_string(self.prev_hash)) % 1000000
        return String(h)

    fn verify_chain(blocks: List[Block]) -> Bool:
        for i in range(1, len(blocks)):
            if blocks[i].prev_hash != blocks[i-1].hash or not blocks[i].verify():
                return False
        return True

fn hash_string(s: String) -> Int:
    var h = 0
    for c in s.codepoints():
        h = (h * 31 + c) % 1000000
    return h

struct Node:
    var id: Int64
    var properties: Dict[String, String]

struct Edge:
    var from_id: Int64
    var to_id: Int64
    var label: String
    var properties: Dict[String, String]

struct GraphStore:
    var nodes: BlockStore
    var edges: BlockStore

    fn __init__(inout self, path: String):
        self.nodes = BlockStore()
        self.edges = BlockStore()

    fn add_node(inout self, node: Node):
        # Convert to table
        var schema = Schema()
        schema.add_field("id", "int64")
        var table = Table(schema, 0)
        table.columns[0].append(node.id)
        self.nodes.append(Block(table^))

    fn add_edge(inout self, edge: Edge):
        var schema = Schema()
        schema.add_field("from_id", "int64")
        schema.add_field("to_id", "int64")
        var table = Table(schema, 0)
        table.columns[0].append(edge.from_id)
        table.columns[1].append(edge.to_id)
        self.edges.append(Block(table^))

struct BlockStore(Copyable, Movable):
    var blocks: Dict[String, Block]

    fn __init__(out self):
        self.blocks = Dict[String, Block]()

    fn __copyinit__(out self, existing: BlockStore):
        self.blocks = Dict[String, Block]()
        for k in existing.blocks.keys():
            self.blocks[k] = existing.blocks[k]

    fn __moveinit__(out self, deinit existing: BlockStore):
        self.blocks = existing.blocks

    fn append(inout self, var block: Block):
        self.blocks[block.hash] = block^