# Advanced Storage for Mojo Arrow Database
# Indexing for fast lookups

from arrow import Int64Array

struct HashIndex:
    var index: Dict[Int64, List[Int]]

    fn __init__(inout self):
        self.index = Dict[Int64, List[Int]]()

    fn build(inout self, arr: Int64Array):
        for i in range(arr.length):
            if arr.is_valid(i):
                let val = arr[i]
                if val not in self.index:
                    self.index[val] = List[Int]()
                self.index[val].append(i)

    fn lookup(self, val: Int64) -> List[Int]:
        if val in self.index:
            return self.index[val]
        return List[Int]()