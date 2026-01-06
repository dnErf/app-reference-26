# Graph Extension for Mojo Grizzly DB
# Opt-in graph database with nodes/edges.

from block import GraphStore, Node, Edge

fn init():
    print("Graph extension loaded. Relations enabled.")

# Example usage
fn create_graph(path: String) -> GraphStore:
    return GraphStore(path)