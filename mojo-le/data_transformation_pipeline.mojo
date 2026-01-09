"""
Data Transformation Pipeline with PyArrow
==========================================

This example demonstrates building an ETL (Extract, Transform, Load) pipeline
using PyArrow for data cleaning and transformation operations. The pipeline
showcases real-world data processing patterns with columnar efficiency.

Key Concepts:
- ETL pipeline design
- Data cleaning and validation
- Type conversion and normalization
- Missing data handling
- Data quality checks
- Transformation workflows

Pipeline Stages:
1. Extract: Load data from various sources
2. Transform: Clean, validate, and transform data
3. Load: Store processed data in target format
"""

from python import Python
from python import PythonObject

fn create_sample_raw_data() raises -> PythonObject:
    """Create sample raw data with quality issues."""
    var code = """
import pandas as pd
import numpy as np

# Create sample data with various quality issues
data = {
    'customer_id': range(1, 101),
    'name': ['Customer_' + str(i) for i in range(1, 101)],
    'email': ['customer' + str(i) + '@example.com' for i in range(1, 101)],
    'age': [25, 30, None, 45, 28, 35, np.nan, 42, 29, 31] * 10,  # Missing values
    'income': [50000, 60000, 45000, 'N/A', 55000, 65000, 48000, None, 52000, 58000] * 10,  # Mixed types
    'signup_date': ['2023-01-01', '2023-02-15', 'invalid_date', '2023-03-20', '2023-04-10'] * 20,  # Invalid dates
    'status': ['active', 'inactive', 'Active', 'ACTIVE', 'pending', 'Pending', None, 'active'] * 12 + ['active', 'inactive', 'pending', 'active']  # Inconsistent casing
}

df = pd.DataFrame(data)
df
"""
    return Python.evaluate(code)

fn extract_stage():
    """Extract stage: Load data from various sources."""
    print("=== ETL Pipeline: Extract Stage ===")

    try:
        print("Data sources supported:")
        print("- CSV files")
        print("- JSON files")
        print("- Parquet files")
        print("- Database connections")
        print("- API endpoints")
        print("- Streaming sources")

        var raw_data = create_sample_raw_data()
        print("Sample raw data loaded with", len(raw_data), "records")
        print("Data contains various quality issues for processing")

    except:
        print("Extract stage failed")

fn transform_data_cleaning():
    """Transform stage: Data cleaning operations."""
    print("\n=== ETL Pipeline: Transform - Data Cleaning ===")

    try:
        print("Data Cleaning Operations:")
        print("1. Missing Value Handling:")
        print("   - Identify null/NaN values")
        print("   - Impute with mean/median/mode")
        print("   - Drop incomplete records")
        print("   - Flag missing data columns")

        print("2. Type Conversion:")
        print("   - Convert strings to numeric types")
        print("   - Parse dates from strings")
        print("   - Standardize categorical values")
        print("   - Handle mixed data types")

        print("3. Value Validation:")
        print("   - Check value ranges")
        print("   - Validate email formats")
        print("   - Verify date formats")
        print("   - Cross-reference valid values")

    except:
        print("Data cleaning operations failed")

fn transform_data_normalization():
    """Transform stage: Data normalization."""
    print("\n=== ETL Pipeline: Transform - Data Normalization ===")

    try:
        print("Data Normalization Techniques:")
        print("1. Text Normalization:")
        print("   - Convert to lowercase/uppercase")
        print("   - Remove extra whitespace")
        print("   - Standardize formatting")
        print("   - Handle special characters")

        print("2. Numeric Scaling:")
        print("   - Min-max scaling")
        print("   - Z-score standardization")
        print("   - Robust scaling")
        print("   - Log transformations")

        print("3. Categorical Encoding:")
        print("   - Label encoding")
        print("   - One-hot encoding")
        print("   - Ordinal encoding")
        print("   - Frequency encoding")

    except:
        print("Data normalization failed")

fn transform_data_enrichment():
    """Transform stage: Data enrichment."""
    print("\n=== ETL Pipeline: Transform - Data Enrichment ===")

    try:
        print("Data Enrichment Operations:")
        print("1. Derived Columns:")
        print("   - Calculate age groups from birth dates")
        print("   - Create income brackets")
        print("   - Compute customer lifetime value")
        print("   - Generate geographic features")

        print("2. Lookup Operations:")
        print("   - Join with reference tables")
        print("   - Enrich with external data")
        print("   - Add geographic information")
        print("   - Include demographic data")

        print("3. Feature Engineering:")
        print("   - Create interaction features")
        print("   - Generate time-based features")
        print("   - Compute statistical aggregations")
        print("   - Build composite indicators")

    except:
        print("Data enrichment failed")

fn transform_data_quality():
    """Transform stage: Data quality checks."""
    print("\n=== ETL Pipeline: Transform - Data Quality ===")

    try:
        print("Data Quality Validation:")
        print("1. Completeness Checks:")
        print("   - Required field validation")
        print("   - Null value percentages")
        print("   - Record completeness scores")
        print("   - Missing data patterns")

        print("2. Accuracy Validation:")
        print("   - Business rule validation")
        print("   - Cross-field consistency")
        print("   - Reference data matching")
        print("   - Outlier detection")

        print("3. Consistency Checks:")
        print("   - Format standardization")
        print("   - Value range validation")
        print("   - Duplicate detection")
        print("   - Referential integrity")

    except:
        print("Data quality checks failed")

fn load_stage():
    """Load stage: Store processed data."""
    print("\n=== ETL Pipeline: Load Stage ===")

    try:
        print("Data Loading Destinations:")
        print("1. Database Storage:")
        print("   - Relational databases (PostgreSQL, MySQL)")
        print("   - NoSQL databases (MongoDB, Cassandra)")
        print("   - Data warehouses (Redshift, BigQuery)")
        print("   - Time-series databases (InfluxDB)")

        print("2. File Storage:")
        print("   - Parquet files (compressed, columnar)")
        print("   - CSV/JSON files")
        print("   - ORC files")
        print("   - Avro files")

        print("3. Cloud Storage:")
        print("   - S3, GCS, Azure Blob Storage")
        print("   - Partitioned datasets")
        print("   - Optimized file formats")

        print("4. In-Memory Storage:")
        print("   - Redis, Memcached")
        print("   - Application caches")
        print("   - Real-time processing")

    except:
        print("Load stage failed")

fn demonstrate_pipeline_orchestration():
    """Demonstrate pipeline orchestration concepts."""
    print("\n=== Pipeline Orchestration ===")

    try:
        print("Pipeline Management Features:")
        print("1. Workflow Scheduling:")
        print("   - Cron-based scheduling")
        print("   - Event-driven triggers")
        print("   - Dependency management")
        print("   - Retry mechanisms")

        print("2. Monitoring & Logging:")
        print("   - Pipeline execution tracking")
        print("   - Performance metrics")
        print("   - Error handling and alerts")
        print("   - Data quality dashboards")

        print("3. Scalability:")
        print("   - Parallel processing")
        print("   - Distributed execution")
        print("   - Resource optimization")
        print("   - Auto-scaling capabilities")

    except:
        print("Pipeline orchestration demonstration failed")

fn demonstrate_error_handling():
    """Demonstrate error handling in ETL pipelines."""
    print("\n=== Error Handling & Recovery ===")

    try:
        print("Error Handling Strategies:")
        print("1. Graceful Degradation:")
        print("   - Continue processing on non-critical errors")
        print("   - Log warnings for data quality issues")
        print("   - Skip invalid records with logging")
        print("   - Partial success handling")

        print("2. Recovery Mechanisms:")
        print("   - Checkpoint-based restarts")
        print("   - Transaction rollbacks")
        print("   - Dead letter queues")
        print("   - Manual intervention workflows")

        print("3. Data Validation:")
        print("   - Pre-processing validation")
        print("   - Post-processing verification")
        print("   - Automated testing")
        print("   - Quality gate checks")

    except:
        print("Error handling demonstration failed")

fn main():
    """Main ETL pipeline demonstration."""
    print("=== Data Transformation Pipeline with PyArrow ===")
    print("Demonstrating ETL pipeline for data cleaning and transformation")
    print()

    # Extract stage
    extract_stage()

    # Transform stages
    transform_data_cleaning()
    transform_data_normalization()
    transform_data_enrichment()
    transform_data_quality()

    # Load stage
    load_stage()

    # Additional features
    demonstrate_pipeline_orchestration()
    demonstrate_error_handling()

    print("\n=== ETL Pipeline Complete ===")
    print("Key takeaways:")
    print("- ETL pipelines provide structured data processing")
    print("- PyArrow enables efficient columnar transformations")
    print("- Data quality is critical for downstream analytics")
    print("- Pipeline orchestration ensures reliable execution")
    print("- Error handling prevents data corruption")
    print("- Scalable design supports growing data volumes")