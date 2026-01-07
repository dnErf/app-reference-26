# Graph Extension for Mojo Grizzly DB
# Opt-in graph database with nodes/edges.

from block import GraphStore, Node, Edge

var graph_store: GraphStore

fn init():
    graph_store = GraphStore("")
    print("Graph extension loaded. Relations enabled.")

fn add_node(id: Int64, properties: Dict[String, String]):
    var node = Node(id, properties)
    graph_store.nodes.append(node)
    print("Node added:", id)

fn add_edge(from_id: Int64, to_id: Int64, label: String, properties: Dict[String, String]):
    var edge = Edge(from_id, to_id, label, properties)
    graph_store.edges.append(edge)
    print("Edge added:", from_id, "->", to_id)