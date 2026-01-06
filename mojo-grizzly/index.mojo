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