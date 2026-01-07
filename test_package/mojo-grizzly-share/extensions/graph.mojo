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

fn shortest_path(start: Int64, end: Int64) -> List[Int64]:
    # BFS for shortest path
    var visited = Dict[Int64, Bool]()
    var queue = List[Tuple[Int64, List[Int64]]]()
    queue.append((start, List[Int64](start)))
    visited[start] = True
    while len(queue) > 0:
        var current, path = queue[0]
        queue.remove(0)
        if current == end:
            return path
        for neigh in neighbors(current):
            if neigh not in visited:
                visited[neigh] = True
                var new_path = path.copy()
                new_path.append(neigh)
                queue.append((neigh, new_path))
    return List[Int64]()  # No path

fn recommend_friends(user: Int64) -> List[Int64]:
    # Simple friend recommendation: mutual friends
    var friends = neighbors(user)
    var recommendations = Dict[Int64, Int]()
    for friend in friends:
        for friend_of_friend in neighbors(friend):
            if friend_of_friend != user and friend_of_friend not in friends:
                if friend_of_friend in recommendations:
                    recommendations[friend_of_friend] += 1
                else:
                    recommendations[friend_of_friend] = 1
    # Sort by count
    var sorted_rec = List[Tuple[Int, Int64]]()
    for key in recommendations.keys():
        sorted_rec.append((recommendations[key], key))
    sorted_rec.sort(reverse=True)
    var result = List[Int64]()
    for rec in sorted_rec:
        result.append(rec[1])
    return result