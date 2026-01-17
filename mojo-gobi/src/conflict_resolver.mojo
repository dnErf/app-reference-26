"""
PL-GRIZZLY Conflict Resolver Module

Resolves conflicts using first-writer-wins policy with timestamps.
"""

from collections import Dict, List
from transaction_context import TransactionContext

# Represents a conflict between transactions
struct Conflict(Movable):
    var tx1: TransactionContext
    var tx2: TransactionContext
    var conflicting_records: List[String]
    
    fn __init__(out self, tx1: TransactionContext, tx2: TransactionContext):
        self.tx1 = tx1
        self.tx2 = tx2
        self.conflicting_records = List[String]()

# Conflict resolver using first-writer-wins
struct ConflictResolver:
    fn detect_conflicts(active_txs: List[TransactionContext]) -> List[Conflict]:
        """Detect conflicts between active transactions."""
        var conflicts = List[Conflict]()
        
        for i in range(len(active_txs)):
            for j in range(i + 1, len(active_txs)):
                var conflict = self.check_overlap(active_txs[i], active_txs[j])
                if conflict:
                    conflicts.append(conflict)
        
        return conflicts
    
    fn check_overlap(tx1: TransactionContext, tx2: TransactionContext) -> Conflict:
        """Check if two transactions have overlapping write sets."""
        var conflict_records = List[String]()
        
        for record_id in tx1.write_set.keys():
            if record_id in tx2.write_set:
                conflict_records.append(record_id)
        
        if len(conflict_records) > 0:
            var conflict = Conflict(tx1, tx2)
            conflict.conflicting_records = conflict_records
            return conflict
        
        return Conflict(TransactionContext(), TransactionContext())  # Empty conflict
    
    fn resolve_conflict(conflict: Conflict) -> TransactionContext:
        """Resolve conflict: first writer wins (earliest start timestamp)."""
        if conflict.tx1.start_ts <= conflict.tx2.start_ts:
            return conflict.tx1
        else:
            return conflict.tx2
    
    fn resolve_all_conflicts(mut self, conflicts: List[Conflict]) -> List[TransactionContext]:
        """Resolve a list of conflicts and return winning transactions."""
        var winners = List[TransactionContext]()
        
        for conflict in conflicts:
            winners.append(self.resolve_conflict(conflict))
        
        return winners