# PL-GRIZZLY Performance Benchmark Report (1M Rows)

## Summary

| Operation | Avg Time (s) | Min Time (s) | Max Time (s) | Iterations |
|-----------|---------------|--------------|--------------|------------|
| INSERT 1M Rows | 57.57761526107788 | 57.57761526107788 | 57.57761526107788 | 1 |
| SELECT 1M Rows | 0.0027992725372314453 | 6.389617919921875e-05 | 0.013714313507080078 | 5 |
| WHERE Query on 1M Rows | 0.00023469924926757812 | 5.7220458984375e-05 | 0.0009188652038574219 | 5 |
| Aggregation on 1M Rows | 6.580352783203125e-05 | 5.507469177246094e-05 | 0.00010156631469726563 | 5 |
| SQLite INSERT 1M Rows | 4.5389039516448975 | 4.5389039516448975 | 4.5389039516448975 | 1 |
| SQLite SELECT 1M Rows | 0.7304227352142334 | 0.6923701763153076 | 0.7853035926818848 | 5 |
| SQLite WHERE on 1M Rows | 0.48592114448547363 | 0.48435425758361816 | 0.48729753494262695 | 5 |
| SQLite Aggregation on 1M Rows | 0.08372015953063965 | 0.08311009407043457 | 0.08453965187072754 | 5 |

## Performance Comparison (1M Rows)

### INSERT Performance
- PL-GRIZZLY: 57.57761526107788s
- SQLite: 4.5389039516448975s
- PL-GRIZZLY is 12.685356613508372x slower than SQLite for INSERT

### SELECT Performance
- PL-GRIZZLY: 0.0027992725372314453s
- SQLite: 0.7304227352142334s
- PL-GRIZZLY is 0.0038324006116956604x faster than SQLite for SELECT

## Detailed Results

### INSERT 1M Rows

INSERT 1M Rows:
  Iterations: 1
  Total Time: 57.57761526107788s
  Avg Time: 57.57761526107788s
  Min Time: 57.57761526107788s
  Max Time: 57.57761526107788s

### SELECT 1M Rows

SELECT 1M Rows:
  Iterations: 5
  Total Time: 0.013996362686157227s
  Avg Time: 0.0027992725372314453s
  Min Time: 6.389617919921875e-05s
  Max Time: 0.013714313507080078s

### WHERE Query on 1M Rows

WHERE Query on 1M Rows:
  Iterations: 5
  Total Time: 0.0011734962463378906s
  Avg Time: 0.00023469924926757812s
  Min Time: 5.7220458984375e-05s
  Max Time: 0.0009188652038574219s

### Aggregation on 1M Rows

Aggregation on 1M Rows:
  Iterations: 5
  Total Time: 0.00032901763916015625s
  Avg Time: 6.580352783203125e-05s
  Min Time: 5.507469177246094e-05s
  Max Time: 0.00010156631469726563s

### SQLite INSERT 1M Rows

SQLite INSERT 1M Rows:
  Iterations: 1
  Total Time: 4.5389039516448975s
  Avg Time: 4.5389039516448975s
  Min Time: 4.5389039516448975s
  Max Time: 4.5389039516448975s

### SQLite SELECT 1M Rows

SQLite SELECT 1M Rows:
  Iterations: 5
  Total Time: 3.652113676071167s
  Avg Time: 0.7304227352142334s
  Min Time: 0.6923701763153076s
  Max Time: 0.7853035926818848s

### SQLite WHERE on 1M Rows

SQLite WHERE on 1M Rows:
  Iterations: 5
  Total Time: 2.429605722427368s
  Avg Time: 0.48592114448547363s
  Min Time: 0.48435425758361816s
  Max Time: 0.48729753494262695s

### SQLite Aggregation on 1M Rows

SQLite Aggregation on 1M Rows:
  Iterations: 5
  Total Time: 0.41860079765319824s
  Avg Time: 0.08372015953063965s
  Min Time: 0.08311009407043457s
  Max Time: 0.08453965187072754s


## Recommendations

- **INSERT Optimization**: PL-GRIZZLY INSERT is significantly slower than SQLite. Consider bulk insert operations and optimize AST evaluation for INSERT statements.
- **JIT Compiler**: Current JIT benchmarks show compilation overhead. Focus on reducing compilation time for complex queries.
- **Memory Usage**: Implement detailed memory profiling to identify memory leaks in large dataset operations.
- **ORC Storage**: With 10K rows, ORC performance is acceptable, but test with larger datasets for scalability.
- **Scalability**: 1M row benchmarks reveal performance characteristics. Consider sharding or partitioning for larger datasets.
