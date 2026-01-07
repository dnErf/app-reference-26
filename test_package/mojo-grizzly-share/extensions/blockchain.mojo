# Blockchain Extension for Mojo Grizzly DB
# Enables immutable chained blocks with memory head copy for fast reads.

from block import Block, BlockStore
from arrow import Table, Schema
from formats import write_orc

var blockchain_store: BlockStore
var memory_head: Block  # Copy of latest block for fast reads

struct NFT:
    var id: String
    var metadata: String
    var owner: String

struct SmartContract:
    var id: String
    var code: String

var nfts = List[NFT]()
var contracts = List[SmartContract]()

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
    # Save all blocks to .grz file
    var i = 0
    for block in blockchain_store.blocks:
        var block_filename = filename + "_" + str(i) + ".orc"
        write_orc(block[].data, block_filename)
        i += 1
    print("Chain saved to", filename + ".grz")

fn mint_nft(metadata: String) -> String:
    let id = "nft_" + str(len(nfts))
    nfts.append(NFT(id, metadata, "owner_default"))
    print("NFT minted:", id)
    return id

fn deploy_contract(code: String) -> String:
    let id = "contract_" + str(len(contracts))
    contracts.append(SmartContract(id, code))
    print("Contract deployed:", id)
    return id