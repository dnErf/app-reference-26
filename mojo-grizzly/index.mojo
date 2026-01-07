# Advanced Storage for Mojo Arrow Database
# Indexing for fast lookups

from arrow import Int64Array

struct HashIndex(Copyable, Movable):
    var index: Dict[Int64, List[Int]]

    fn __init__(out self):
        self.index = Dict[Int64, List[Int]]()

    fn __copyinit__(out self, existing: HashIndex):
        self.index = existing.index.copy()

    fn __moveinit__(out self, deinit existing: HashIndex):
        self.index = existing.index^

    fn build(inout self, arr: Int64Array):
        for i in range(len(arr.data)):
            let val = arr[i]
            self.insert(val, i)

    fn lookup(self, val: Int64) raises -> List[Int]:
        if val in self.index:
            return self.index[val].copy()
        return List[Int]()

struct BTreeIndex(Copyable, Movable):
    var root: BTreeNode

    fn __init__(out self):
        self.root = BTreeNode()

    fn __copyinit__(out self, existing: BTreeIndex):
        self.root = existing.root.copy()

    fn __moveinit__(out self, deinit existing: BTreeIndex):
        self.root = existing.root^

    fn build(inout self, arr: Int64Array):
        for i in range(len(arr.data)):
            self.insert(arr[i], i)

    fn insert(inout self, val: Int64, row: Int):
        self.root.insert(val, row)

    fn lookup(self, val: Int64) raises -> List[Int]:
        return self.root.search(val)

    fn lookup_range(self, min_val: Int64, max_val: Int64) raises -> List[Int]:
        return self.root.search_range(min_val, max_val)

struct BTreeNode(Copyable, Movable):
    var keys: List[Int64]
    var values: List[Int]  # Row indices
    var children: List[BTreeNode]
    var is_leaf: Bool
    var t: Int  # Minimum degree

    fn __init__(out self, t: Int = 2):
        self.keys = List[Int64]()
        self.values = List[Int]()
        self.children = List[BTreeNode]()
        self.is_leaf = True
        self.t = t

    fn __copyinit__(out self, existing: BTreeNode):
        self.keys = existing.keys.copy()
        self.values = existing.values.copy()
        self.children = existing.children.copy()
        self.is_leaf = existing.is_leaf
        self.t = existing.t

    fn __moveinit__(out self, deinit existing: BTreeNode):
        self.keys = existing.keys^
        self.values = existing.values^
        self.children = existing.children^
        self.is_leaf = existing.is_leaf
        self.t = existing.t

    fn insert(inout self, val: Int64, row: Int):
        # Full B-tree insert with split
        if self.is_leaf:
            var i = 0
            while i < len(self.keys) and self.keys[i] < val:
                i += 1
            self.keys.insert(i, val)
            self.values.insert(i, row)
            if len(self.keys) == 2 * self.t - 1:
                # Split
                self.split()
        else:
            var i = 0
            while i < len(self.keys) and val > self.keys[i]:
                i += 1
            self.children[i].insert(val, row)
            if len(self.children[i].keys) == 2 * self.t - 1:
                self.split_child(i)

    fn split(inout self):
        # Split leaf node
        let mid = self.t - 1
        let mid_key = self.keys[mid]
        let mid_val = self.values[mid]
        var new_node = BTreeNode(self.t)
        new_node.is_leaf = True
        for i in range(mid + 1, len(self.keys)):
            new_node.keys.append(self.keys[i])
            new_node.values.append(self.values[i])
        self.keys.resize(mid)
        self.values.resize(mid)
        # For root split, but simplified
        self.children.append(new_node)

    fn split_child(inout self, i: Int):
        # Split child
        let child = self.children[i]
        let mid = self.t - 1
        let mid_key = child.keys[mid]
        let mid_val = child.values[mid]
        var new_node = BTreeNode(self.t)
        new_node.is_leaf = child.is_leaf
        for j in range(mid + 1, len(child.keys)):
            new_node.keys.append(child.keys[j])
            new_node.values.append(child.values[j])
        if not child.is_leaf:
            for j in range(self.t, len(child.children)):
                new_node.children.append(child.children[j])
        self.keys.insert(i, mid_key)
        self.values.insert(i, mid_val)
        self.children.insert(i + 1, new_node)
        child.keys.resize(mid)
        child.values.resize(mid)
        if not child.is_leaf:
            child.children.resize(self.t)

    fn search(self, val: Int64) -> List[Int]:
        var i = 0
        while i < len(self.keys) and val > self.keys[i]:
            i += 1
        if i < len(self.keys) and self.keys[i] == val:
            return List[Int](self.values[i])
        if self.is_leaf:
            return List[Int]()
        return self.children[i].search(val)

    fn search_range(self, min_val: Int64, max_val: Int64) -> List[Int]:
        var results = List[Int]()
        self.traverse_range(min_val, max_val, results)
        return results

    fn traverse_range(self, min_val: Int64, max_val: Int64, inout results: List[Int]):
        var local_results = List[Int]()
        var i = 0
        while i < len(self.keys):
            if not self.is_leaf:
                self.children[i].traverse_range(min_val, max_val, results)
            if self.keys[i] >= min_val and self.keys[i] <= max_val:
                local_results.append(self.values[i])
            i += 1
        if not self.is_leaf:
            self.children[i].traverse_range(min_val, max_val, results)
        # Batch append to reduce overhead
        for val in local_results:
            results.append(val)

struct CompositeIndex(Copyable, Movable):
    var indexes: List[HashIndex]  # For multiple columns

    fn __init__(out self, num_cols: Int):
        self.indexes = List[HashIndex]()
        for _ in range(num_cols):
            self.indexes.append(HashIndex())

    fn build(inout self, table: Table, cols: List[Int]):
        for row in range(table.num_rows()):
            for i in range(len(cols)):
                let col_idx = cols[i]
                let val = table.columns[col_idx][row]
                self.indexes[i].insert(val, row)

    fn lookup(self, values: List[Int64]) -> List[Int]:
        # Intersect lookups from each index
        if len(values) == 0:
            return List[Int]()
        var result = self.indexes[0].lookup(values[0])
        for i in range(1, len(values)):
            let next = self.indexes[i].lookup(values[i])
            result = intersect_lists(result, next)
        return result

fn intersect_lists(a: List[Int], b: List[Int]) -> List[Int]:
    var result = List[Int]()
    var i = 0
    var j = 0
    while i < len(a) and j < len(b):
        if a[i] == b[j]:
            result.append(a[i])
            i += 1
            j += 1
        elif a[i] < b[j]:
            i += 1
        else:
            j += 1
    return result