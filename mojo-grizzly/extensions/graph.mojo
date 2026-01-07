# Graph Extension for Mojo Grizzly DB
# Opt-in graph database with nodes/edges.

from block import GraphStore, Node, Edge
from formats import write_orc

var graph_store: GraphStore

fn init():
    graph_store = GraphStore("")
    print("Graph extension loaded. Relations enabled.")

fn add_node(id: Int64, properties: Dict[String, String]):
    var node = Node(id, properties)
    graph_store.nodes.append(node)
    print("Node added:", id)

fn neighbors(id: Int64) -> List[Int64]:
    var neigh = List[Int64]()
    for block in graph_store.edges.blocks:
        for row in range(block[].data.num_rows()):
            var from_ = block[].data.columns[0][row]
            var to_ = block[].data.columns[1][row]
            if from_ == id:
                neigh.append(to_)
    return neigh