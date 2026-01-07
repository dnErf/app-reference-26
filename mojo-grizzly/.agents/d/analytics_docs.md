# Advanced Analytics Documentation

## Overview
Batch 7 implements advanced analytics features for Mojo-Grizzly, including time-series aggregations, geospatial queries, complex aggregations, statistical functions, and data quality checks.

## Features Implemented

### Time-Series Aggregations
- Moving average calculation with window size
- Function: `moving_average(values, window)`

### Geospatial Queries
- Haversine distance between coordinates
- Function: `haversine_distance(lat1, lon1, lat2, lon2)`

### Complex Aggregations
- Percentile calculation (e.g., median)
- SQL: `SELECT PERCENTILE(column, 0.5)`

### Statistical Functions
- Mean and standard deviation
- SQL: `SELECT STATS(column)` returns mean and std_dev

### Data Quality Checks
- Basic null count and row count
- SQL: `SELECT DATA_QUALITY`

## Usage Examples

```sql
LOAD EXTENSION 'analytics';
SELECT PERCENTILE(price, 0.5) FROM sales;
SELECT STATS(revenue) FROM transactions;
SELECT DATA_QUALITY FROM table;
```

## Files Modified
- `extensions/analytics.mojo`: Core analytics functions
- `query.mojo`: Parsing and execution of new aggregates
- `cli.mojo`: Extension loading

## Testing
- New SQL functions parse and execute
- Analytics functions compute correctly
- Compilation successful