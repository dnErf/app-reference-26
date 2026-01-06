# Blockchain Extension for Mojo Grizzly DB
# Enables immutable chained blocks.

from block import Block, BlockStore

fn init():
    print("Blockchain extension loaded. Blocks are now chained.")

# Example: Append with prev_hash
fn append_block(store: BlockStore, data: Table):
    let prev_hash = "" if len(store.blocks) == 0 else store.blocks[len(store.blocks)-1].hash
    let block = Block(data, prev_hash)
    store.append(block)