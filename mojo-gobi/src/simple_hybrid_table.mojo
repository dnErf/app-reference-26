# Simple Hybrid Table Implementation
# Demonstrates CoW and MoR strategies

from collections import List

struct SimpleRecord(Copyable, Movable):
    var id: Int
    var data: String
    
    fn __init__(out self, id: Int, data: String):
        self.id = id
        self.data = data

struct HybridTable(Copyable, Movable):
    var hot_data: List[SimpleRecord]    # CoW - recent writes
    var cold_data: List[SimpleRecord]   # MoR - older data
    var write_count: Int
    
    fn __init__(out self):
        self.hot_data = List[SimpleRecord]()
        self.cold_data = List[SimpleRecord]()
        self.write_count = 0
    
    fn write(mut self, record: SimpleRecord):
        """Adaptive write: CoW for recent data"""
        self.hot_data.append(record.copy())
        self.write_count += 1
        
        # Simulate tier promotion
        if self.write_count > 5:
            self._promote_to_cold()
    
    fn read(self) -> String:
        """Unified read: merge hot and cold data"""
        var result = String("Records: ")
        for record in self.hot_data:
            result += "H" + String(record.id) + ","
        for record in self.cold_data:
            result += "C" + String(record.id) + ","
        return result
    
    fn _promote_to_cold(mut self):
        """Move hot data to cold storage (MoR style)"""
        for record in self.hot_data:
            self.cold_data.append(record.copy())
        self.hot_data = List[SimpleRecord]()
        self.write_count = 0

fn main():
    var table = HybridTable()
    
    # Write some records
    table.write(SimpleRecord(1, "data1"))
    table.write(SimpleRecord(2, "data2"))
    table.write(SimpleRecord(3, "data3"))
    
    print("After 3 writes:", table.read())
    
    # Write more to trigger promotion
    table.write(SimpleRecord(4, "data4"))
    table.write(SimpleRecord(5, "data5"))
    table.write(SimpleRecord(6, "data6"))
    
    print("After promotion:", table.read())
