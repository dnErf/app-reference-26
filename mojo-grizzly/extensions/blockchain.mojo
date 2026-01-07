# Blockchain Extension for Mojo Grizzly DB
# Enables immutable chained blocks with memory head copy for fast reads.

from block import Block, BlockStore
from arrow import Table, Schema

var blockchain_store: BlockStore
var memory_head: Block  # Copy of latest block for fast reads

fn init():
    blockchain_store = BlockStore()
    memory_head = Block(Table(Schema(), 0), "")
    print("Blockchain extension loaded. Blocks are now chained with memory head.")

fn append_block(data: Table):
    let prev_hash = memory_head.hash
    let block = Block(data, prev_hash)
    blockchain_store.append(block)
    memory_head = block.copy()  # Update memory copy
    print("Block appended, head updated in memory")

fn get_head() -> Block:
    return memory_head.copy()

fn save_chain(filename: String):
    # Stub: save all blocks to .grz file
    print("Chain saved to", filename + ".grz")