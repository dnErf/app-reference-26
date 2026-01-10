from collections import List
from types import Row

struct FractalTree(Copyable, Movable):
    var buffers: List[List[Row]]
    var max_level: Int

    fn __init__(out self, max_level: Int = 5):
        self.buffers = List[List[Row]]()
        self.max_level = max_level
        # Initialize levels
        for i in range(max_level):
            self.buffers.append(List[Row]())

    fn insert(mut self, row: Row):
        # Insert into level 0
        self.buffers[0].append(row.copy())
        # Check if need merge
        self._merge_if_needed()

    fn _merge_if_needed(mut self):
        var level = 0
        while level < self.max_level - 1 and len(self.buffers[level]) > 10:  # arbitrary threshold
            # Merge to next level
            for r in self.buffers[level]:
                self.buffers[level + 1].append(r.copy())
            self.buffers[level].clear()
            level += 1

    fn get_all_rows(self) -> List[Row]:
        var all_rows = List[Row]()
        for level in self.buffers:
            for r in level:
                all_rows.append(r.copy())
        return all_rows ^