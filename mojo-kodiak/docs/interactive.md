# Mojo Kodiak Database - Interactive Documentation

This directory contains interactive examples and demonstrations for the Mojo Kodiak database.

## Quick Start Demo

Run the interactive demo to see Mojo Kodiak in action:

```bash
python3 interactive_demo.py
```

This will start an interactive session where you can:
- Create tables and insert data
- Run queries and see results
- Test performance with sample datasets
- Explore database internals

## Interactive Examples

### 1. Basic Operations Demo

```python
#!/usr/bin/env python3
"""
Interactive demo for basic Mojo Kodiak operations
"""

import subprocess
import json
import time
from pathlib import Path

def run_kodiak_command(command):
    """Run a Mojo Kodiak command and return the result"""
    try:
        result = subprocess.run(
            ['./kodiak'] + command.split(),
            capture_output=True,
            text=True,
            cwd=Path(__file__).parent
        )
        return result.stdout, result.stderr, result.returncode
    except FileNotFoundError:
        return "", "Mojo Kodiak binary not found. Please build the project first.", 1

def demo_basic_operations():
    """Demonstrate basic database operations"""

    print("=== Mojo Kodiak Interactive Demo ===\n")

    # Create a demo database
    print("1. Creating demo database...")
    stdout, stderr, code = run_kodiak_command("init demo.db")
    if code != 0:
        print(f"Error: {stderr}")
        return

    print("✓ Database created\n")

    # Create tables
    print("2. Creating tables...")
    tables = ["users", "products", "orders"]

    for table in tables:
        stdout, stderr, code = run_kodiak_command(f"create-table {table}")
        if code == 0:
            print(f"✓ Created table: {table}")
        else:
            print(f"✗ Failed to create {table}: {stderr}")

    print()

    # Insert sample data
    print("3. Inserting sample data...")

    # Users
    users_data = [
        {"name": "Alice Johnson", "email": "alice@example.com", "age": "28"},
        {"name": "Bob Smith", "email": "bob@example.com", "age": "34"},
        {"name": "Carol Williams", "email": "carol@example.com", "age": "26"}
    ]

    for user in users_data:
        data_str = ",".join([f"{k}={v}" for k, v in user.items()])
        stdout, stderr, code = run_kodiak_command(f"insert users {data_str}")
        if code == 0:
            print(f"✓ Inserted user: {user['name']}")
        else:
            print(f"✗ Failed to insert {user['name']}: {stderr}")

    # Products
    products_data = [
        {"name": "Laptop", "price": "999.99", "category": "Electronics"},
        {"name": "Book", "price": "19.99", "category": "Education"},
        {"name": "Coffee Mug", "price": "12.99", "category": "Kitchen"}
    ]

    for product in products_data:
        data_str = ",".join([f"{k}={v}" for k, v in product.items()])
        stdout, stderr, code = run_kodiak_command(f"insert products {data_str}")
        if code == 0:
            print(f"✓ Inserted product: {product['name']}")
        else:
            print(f"✗ Failed to insert {product['name']}: {stderr}")

    print()

    # Query data
    print("4. Querying data...")

    # Select all users
    print("Users:")
    stdout, stderr, code = run_kodiak_command("select users")
    if code == 0:
        print(stdout)
    else:
        print(f"Error: {stderr}")

    # Select all products
    print("Products:")
    stdout, stderr, code = run_kodiak_command("select products")
    if code == 0:
        print(stdout)
    else:
        print(f"Error: {stderr}")

    print()

    # Performance demo
    print("5. Performance demonstration...")

    # Insert many records for performance test
    print("Inserting 1000 records...")
    start_time = time.time()

    for i in range(1000):
        data_str = f"name=User{i},email=user{i}@example.com,age={20 + (i % 50)}"
        run_kodiak_command(f"insert users {data_str}")

    insert_time = time.time() - start_time
    print(".2f")

    # Query performance
    print("Querying all users...")
    start_time = time.time()

    stdout, stderr, code = run_kodiak_command("select users")

    query_time = time.time() - start_time
    if code == 0:
        lines = stdout.strip().split('\n')
        record_count = len([line for line in lines if line.strip()]) - 1  # Subtract header
        print(".2f")
    else:
        print(f"Query failed: {stderr}")

    print("\n=== Demo Complete ===")
    print("Your Mojo Kodiak database is ready for use!")

if __name__ == "__main__":
    demo_basic_operations()
```

### 2. Query Performance Analyzer

```python
#!/usr/bin/env python3
"""
Interactive query performance analyzer for Mojo Kodiak
"""

import time
import subprocess
import matplotlib.pyplot as plt
import pandas as pd
from pathlib import Path

class QueryAnalyzer:
    def __init__(self, db_path="demo.db"):
        self.db_path = db_path

    def run_query(self, query):
        """Run a query and measure execution time"""
        start_time = time.time()
        result = subprocess.run(
            ['./kodiak', 'query', query],
            capture_output=True,
            text=True,
            cwd=Path(__file__).parent
        )
        end_time = time.time()

        return {
            'query': query,
            'time': end_time - start_time,
            'success': result.returncode == 0,
            'output': result.stdout,
            'error': result.stderr
        }

    def benchmark_queries(self, queries, iterations=5):
        """Benchmark multiple queries"""
        results = []

        print(f"Benchmarking {len(queries)} queries, {iterations} iterations each...")

        for query in queries:
            query_results = []

            print(f"\nTesting: {query[:50]}...")

            for i in range(iterations):
                result = self.run_query(query)
                query_results.append(result['time'])
                print(".3f")

            avg_time = sum(query_results) / len(query_results)
            min_time = min(query_results)
            max_time = max(query_results)

            results.append({
                'query': query,
                'avg_time': avg_time,
                'min_time': min_time,
                'max_time': max_time,
                'iterations': iterations
            })

        return results

    def generate_report(self, results):
        """Generate a performance report"""
        print("\n" + "="*60)
        print("MOJO KODIAK QUERY PERFORMANCE REPORT")
        print("="*60)

        # Create DataFrame for analysis
        df = pd.DataFrame(results)

        # Sort by average time
        df = df.sort_values('avg_time', ascending=False)

        print(f"{'Query':<50} {'Avg Time':<10} {'Min':<8} {'Max':<8}")
        print("-" * 76)

        for _, row in df.iterrows():
            query_short = row['query'][:47] + "..." if len(row['query']) > 47 else row['query']
            print("<50")

        # Performance insights
        print("\nPERFORMANCE INSIGHTS:")
        print("-" * 30)

        fastest = df.loc[df['avg_time'].idxmin()]
        slowest = df.loc[df['avg_time'].idxmax()]

        print(".3f")
        print(".3f")

        if len(df) > 1:
            ratio = slowest['avg_time'] / fastest['avg_time']
            print(".1f")

        # Recommendations
        print("\nRECOMMENDATIONS:")
        print("-" * 20)

        slow_queries = df[df['avg_time'] > df['avg_time'].median()]
        if len(slow_queries) > 0:
            print(f"• {len(slow_queries)} queries are slower than median performance")
            print("  Consider optimizing these queries or adding indexes")

        if df['avg_time'].max() > 1.0:
            print("• Some queries take over 1 second - review for optimization")

        print("• For best performance, consider data locality and query patterns")

def main():
    analyzer = QueryAnalyzer()

    # Sample queries to benchmark
    queries = [
        "SELECT COUNT(*) FROM users",
        "SELECT * FROM users WHERE age > 25",
        "SELECT * FROM users LIMIT 10",
        "SELECT name, email FROM users WHERE age BETWEEN 20 AND 30",
        "SELECT * FROM users ORDER BY age DESC LIMIT 5"
    ]

    # Run benchmarks
    results = analyzer.benchmark_queries(queries)

    # Generate report
    analyzer.generate_report(results)

    # Optional: Create performance chart
    try:
        df = pd.DataFrame(results)
        plt.figure(figsize=(12, 6))
        plt.bar(range(len(df)), df['avg_time'])
        plt.xticks(range(len(df)), [q[:30] + "..." for q in df['query']], rotation=45, ha='right')
        plt.ylabel('Average Time (seconds)')
        plt.title('Mojo Kodiak Query Performance')
        plt.tight_layout()
        plt.savefig('performance_chart.png', dpi=150, bbox_inches='tight')
        print("\nPerformance chart saved as 'performance_chart.png'")
    except ImportError:
        print("\nInstall matplotlib to generate performance charts:")
        print("pip install matplotlib")

if __name__ == "__main__":
    main()
```

### 3. Data Import/Export Demo

```python
#!/usr/bin/env python3
"""
Interactive data import/export demonstration
"""

import pandas as pd
import json
from pathlib import Path
import subprocess

def create_sample_data():
    """Create sample datasets for demonstration"""

    # E-commerce data
    users = pd.DataFrame({
        'user_id': range(1, 101),
        'name': [f'User{i}' for i in range(1, 101)],
        'email': [f'user{i}@example.com' for i in range(1, 101)],
        'age': [20 + (i % 50) for i in range(1, 101)],
        'signup_date': pd.date_range('2023-01-01', periods=100, freq='D')
    })

    products = pd.DataFrame({
        'product_id': range(1, 51),
        'name': [f'Product{i}' for i in range(1, 51)],
        'price': [10.99 + i * 5.5 for i in range(1, 51)],
        'category': ['Electronics', 'Books', 'Clothing', 'Home', 'Sports'] * 10,
        'stock': [100 + i * 10 for i in range(1, 51)]
    })

    orders = pd.DataFrame({
        'order_id': range(1, 201),
        'user_id': [1 + (i % 100) for i in range(1, 201)],
        'product_id': [1 + (i % 50) for i in range(1, 201)],
        'quantity': [1 + (i % 5) for i in range(1, 201)],
        'order_date': pd.date_range('2023-06-01', periods=200, freq='H')
    })

    return users, products, orders

def export_to_formats(dataframes, base_name):
    """Export DataFrames to multiple formats"""

    formats = {
        'csv': lambda df, name: df.to_csv(f'{name}.csv', index=False),
        'json': lambda df, name: df.to_json(f'{name}.json', orient='records', indent=2),
        'feather': lambda df, name: df.to_feather(f'{name}.feather'),
        'parquet': lambda df, name: df.to_parquet(f'{name}.parquet', index=False)
    }

    print(f"Exporting {base_name} to multiple formats...")

    for fmt, exporter in formats.items():
        try:
            exporter(dataframes, base_name)
            print(f"✓ Exported to {base_name}.{fmt}")
        except Exception as e:
            print(f"✗ Failed to export {base_name}.{fmt}: {e}")

def import_from_csv(csv_file, table_name):
    """Import CSV data into Mojo Kodiak"""

    print(f"Importing {csv_file} into table '{table_name}'...")

    # Read CSV
    df = pd.read_csv(csv_file)

    # Convert all columns to string (Mojo Kodiak requirement)
    df = df.astype(str)

    # Save as temporary Feather file
    temp_feather = f"temp_{table_name}.feather"
    df.to_feather(temp_feather)

    # Import into Mojo Kodiak
    result = subprocess.run(
        ['./kodiak', 'import-table', table_name, temp_feather],
        capture_output=True,
        text=True,
        cwd=Path(__file__).parent
    )

    if result.returncode == 0:
        print(f"✓ Successfully imported {len(df)} rows into {table_name}")
    else:
        print(f"✗ Import failed: {result.stderr}")

    # Clean up
    Path(temp_feather).unlink(missing_ok=True)

def demonstrate_data_flow():
    """Demonstrate complete data import/export workflow"""

    print("=== Mojo Kodiak Data Import/Export Demo ===\n")

    # Create sample data
    print("1. Creating sample datasets...")
    users, products, orders = create_sample_data()
    print("✓ Created sample data:"
    print(f"  - Users: {len(users)} records")
    print(f"  - Products: {len(products)} records")
    print(f"  - Orders: {len(orders)} records\n")

    # Export to multiple formats
    print("2. Exporting data to multiple formats...")
    export_to_formats(users, 'sample_users')
    export_to_formats(products, 'sample_products')
    export_to_formats(orders, 'sample_orders')
    print()

    # Initialize Mojo Kodiak database
    print("3. Initializing Mojo Kodiak database...")
    result = subprocess.run(
        ['./kodiak', 'init', 'import_demo.db'],
        capture_output=True,
        text=True,
        cwd=Path(__file__).parent
    )

    if result.returncode != 0:
        print(f"✗ Database initialization failed: {result.stderr}")
        return

    print("✓ Database initialized\n")

    # Create tables
    print("4. Creating tables in Mojo Kodiak...")
    tables = ['users', 'products', 'orders']

    for table in tables:
        result = subprocess.run(
            ['./kodiak', 'create-table', table],
            capture_output=True,
            text=True,
            cwd=Path(__file__).parent
        )

        if result.returncode == 0:
            print(f"✓ Created table: {table}")
        else:
            print(f"✗ Failed to create {table}: {result.stderr}")

    print()

    # Import data
    print("5. Importing data into Mojo Kodiak...")
    import_from_csv('sample_users.csv', 'users')
    import_from_csv('sample_products.csv', 'products')
    import_from_csv('sample_orders.csv', 'orders')
    print()

    # Verify import
    print("6. Verifying data import...")
    for table in tables:
        result = subprocess.run(
            ['./kodiak', 'query', f'SELECT COUNT(*) FROM {table}'],
            capture_output=True,
            text=True,
            cwd=Path(__file__).parent
        )

        if result.returncode == 0:
            count = result.stdout.strip()
            print(f"✓ {table}: {count} records")
        else:
            print(f"✗ Failed to query {table}: {result.stderr}")

    print("\n=== Data Import/Export Demo Complete ===")
    print("Your data has been successfully imported into Mojo Kodiak!")

def cleanup_demo_files():
    """Clean up demo files"""

    files_to_clean = [
        'sample_users.csv', 'sample_users.json', 'sample_users.feather', 'sample_users.parquet',
        'sample_products.csv', 'sample_products.json', 'sample_products.feather', 'sample_products.parquet',
        'sample_orders.csv', 'sample_orders.json', 'sample_orders.feather', 'sample_orders.parquet',
        'import_demo.db'
    ]

    for file in files_to_clean:
        Path(file).unlink(missing_ok=True)

    print("Demo files cleaned up.")

if __name__ == "__main__":
    try:
        demonstrate_data_flow()
    except KeyboardInterrupt:
        print("\nDemo interrupted by user.")
    except Exception as e:
        print(f"\nDemo failed with error: {e}")
    finally:
        cleanup = input("\nClean up demo files? (y/N): ").lower().strip()
        if cleanup == 'y':
            cleanup_demo_files()
```

## Web-Based Interactive Documentation

For a more interactive experience, you can run the web documentation server:

```bash
python3 web_docs.py
```

This starts a local web server with:
- Live code examples you can modify and run
- Interactive query builder
- Performance comparison charts
- Data visualization tools

## Advanced Examples

### Custom Extension Demo

```mojo
# demo_extensions.mojo
from extensions import Extension, ExtensionRegistry
from database import Database

struct AnalyticsExtension(Extension):
    var name: String

    fn __init__(inout self):
        self.name = "analytics"

    fn execute(inout self, db: Database, command: String) -> String:
        if command == "stats":
            return self.generate_stats(db)
        elif command == "analyze":
            return self.analyze_data(db)
        else:
            return "Unknown analytics command"

    fn generate_stats(self, db: Database) -> String:
        # Generate database statistics
        var stats = String("Database Statistics:\n")

        # Count tables
        var table_count = 0
        # Implementation would count actual tables

        stats += "Tables: " + String(table_count) + "\n"
        stats += "Total Records: " + String(self.get_total_records(db)) + "\n"

        return stats

    fn analyze_data(self, db: Database) -> String:
        return "Data analysis not yet implemented"

    fn get_total_records(self, db: Database) -> Int:
        # Implementation would sum records across all tables
        return 0

# Usage example
fn demo_extensions():
    var db = Database()
    var registry = ExtensionRegistry()

    # Register custom extension
    var analytics = AnalyticsExtension()
    registry.register_extension(analytics)

    # Use extension
    var result = registry.execute_extension("analytics", "stats")
    print(result)
```

### Performance Benchmark Suite

```python
#!/usr/bin/env python3
"""
Comprehensive performance benchmark suite for Mojo Kodiak
"""

import time
import subprocess
import statistics
import json
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

class BenchmarkSuite:
    def __init__(self, db_path="benchmark.db"):
        self.db_path = db_path
        self.results = {}

    def setup_database(self, record_count=10000):
        """Set up database with test data"""

        print(f"Setting up database with {record_count} records...")

        # Initialize database
        self.run_command("init", self.db_path)
        self.run_command("create-table", "benchmark")

        # Insert test data
        start_time = time.time()

        for i in range(record_count):
            data = f"id={i},name=Record{i},value={i*10},category=Type{i%10}"
            self.run_command("insert", "benchmark", data)

        setup_time = time.time() - start_time
        print(".2f")

        return setup_time

    def run_command(self, *args):
        """Run a Mojo Kodiak command"""
        cmd = ['./kodiak'] + list(args)
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=Path(__file__).parent
        )
        return result

    def benchmark_query(self, query, iterations=10):
        """Benchmark a single query"""

        times = []

        for _ in range(iterations):
            start_time = time.time()
            result = self.run_command("query", query)
            end_time = time.time()

            if result.returncode == 0:
                times.append(end_time - start_time)
            else:
                print(f"Query failed: {result.stderr}")
                return None

        return {
            'query': query,
            'iterations': iterations,
            'avg_time': statistics.mean(times),
            'min_time': min(times),
            'max_time': max(times),
            'std_dev': statistics.stdev(times) if len(times) > 1 else 0
        }

    def run_comprehensive_benchmarks(self):
        """Run comprehensive benchmark suite"""

        print("Running comprehensive benchmark suite...\n")

        # Setup
        self.setup_database(5000)

        # Define benchmark queries
        queries = [
            ("Simple Count", "SELECT COUNT(*) FROM benchmark"),
            ("Simple Select All", "SELECT * FROM benchmark LIMIT 100"),
            ("Filtered Query", "SELECT * FROM benchmark WHERE value > 25000"),
            ("Range Query", "SELECT * FROM benchmark WHERE id BETWEEN 1000 AND 2000"),
            ("Category Filter", "SELECT * FROM benchmark WHERE category = 'Type5'"),
            ("Ordered Query", "SELECT * FROM benchmark ORDER BY value DESC LIMIT 50"),
            ("Complex Filter", "SELECT * FROM benchmark WHERE value > 10000 AND category IN ('Type1', 'Type2', 'Type3')")
        ]

        results = []

        for name, query in queries:
            print(f"Benchmarking: {name}")
            result = self.benchmark_query(query)

            if result:
                results.append({
                    'name': name,
                    **result
                })
                print(".4f")

        # Save results
        with open('benchmark_results.json', 'w') as f:
            json.dump(results, f, indent=2)

        print("\nBenchmark results saved to 'benchmark_results.json'")

        return results

    def compare_with_sqlite(self, record_count=5000):
        """Compare performance with SQLite"""

        print("Comparing with SQLite...")

        # Setup SQLite database
        import sqlite3

        sqlite_db = sqlite3.connect('sqlite_benchmark.db')
        sqlite_db.execute('''
            CREATE TABLE benchmark (
                id INTEGER PRIMARY KEY,
                name TEXT,
                value INTEGER,
                category TEXT
            )
        ''')

        # Insert data
        for i in range(record_count):
            sqlite_db.execute(
                "INSERT INTO benchmark (name, value, category) VALUES (?, ?, ?)",
                (f'Record{i}', i*10, f'Type{i%10}')
            )
        sqlite_db.commit()

        # Benchmark queries
        queries = [
            ("COUNT(*)", "SELECT COUNT(*) FROM benchmark"),
            ("SELECT LIMIT", "SELECT * FROM benchmark LIMIT 100"),
            ("WHERE clause", "SELECT * FROM benchmark WHERE value > 25000"),
            ("BETWEEN", "SELECT * FROM benchmark WHERE id BETWEEN 1000 AND 2000")
        ]

        sqlite_results = []
        mojo_results = []

        for name, query in queries:
            # SQLite benchmark
            times = []
            for _ in range(5):
                start = time.time()
                sqlite_db.execute(query).fetchall()
                times.append(time.time() - start)

            sqlite_results.append({
                'query': name,
                'avg_time': statistics.mean(times)
            })

            # Mojo Kodiak benchmark
            result = self.benchmark_query(query)
            if result:
                mojo_results.append({
                    'query': name,
                    'avg_time': result['avg_time']
                })

        sqlite_db.close()

        # Print comparison
        print("\nPerformance Comparison (SQLite vs Mojo Kodiak):")
        print("-" * 60)
        print(f"{'Query':<20} {'SQLite':<10} {'Mojo':<10} {'Ratio':<10}")
        print("-" * 60)

        for sqlite_r, mojo_r in zip(sqlite_results, mojo_results):
            ratio = sqlite_r['avg_time'] / mojo_r['avg_time'] if mojo_r['avg_time'] > 0 else float('inf')
            print("<20")

        return sqlite_results, mojo_results

def main():
    suite = BenchmarkSuite()

    # Run comprehensive benchmarks
    results = suite.run_comprehensive_benchmarks()

    # Compare with SQLite
    sqlite_results, mojo_results = suite.compare_with_sqlite()

    # Generate summary report
    print("\n" + "="*60)
    print("BENCHMARK SUMMARY REPORT")
    print("="*60)

    if results:
        fastest = min(results, key=lambda x: x['avg_time'])
        slowest = max(results, key=lambda x: x['avg_time'])

        print(".4f")
        print(".4f")

        avg_overall = sum(r['avg_time'] for r in results) / len(results)
        print(".4f")

    print("\nBenchmark suite completed successfully!")

if __name__ == "__main__":
    main()
```

## Running the Examples

1. **Basic Demo**: `python3 interactive_demo.py`
2. **Performance Analyzer**: `python3 query_analyzer.py`
3. **Data Import/Export**: `python3 data_import_demo.py`
4. **Benchmark Suite**: `python3 benchmark_suite.py`

## Requirements

- Python 3.8+
- Mojo Kodiak binary (built from source)
- pandas (for data manipulation)
- matplotlib (for charts, optional)

Install dependencies:
```bash
pip install pandas matplotlib
```

## Next Steps

- Explore the [API documentation](api.md) for detailed reference
- Check out [performance optimization](performance.md) tips
- Learn about [migration strategies](migration.md) from other databases
- Join our community for support and contributions

Happy exploring with Mojo Kodiak! 🚀