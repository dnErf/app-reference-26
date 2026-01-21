use arrow::array::{Int32Builder, Int64Builder, Float64Builder, StringBuilder, BooleanBuilder, RecordBatch, Array};
use arrow::datatypes::{DataType, Field, Schema};
use std::sync::Arc;

mod bplus_tree;
use bplus_tree::BPlusTree;

fn main() {
    println!("========== Example 1: Single Column (Int64) ==========");
    example1_single_column();

    println!("\n========== Example 2: Multiple Columns ==========");
    example2_multiple_columns();

    println!("\n========== Example 3: Nullable Values ==========");
    example3_nullable_values();

    println!("\n========== Example 4: Different Data Types ==========");
    example4_mixed_types();

    println!("\n========== Example 5: B+ Tree Operations ==========");
    example5_bplus_tree();
}

/// Example 1: Single column with Int64 values
fn example1_single_column() {
    let mut builder = Int64Builder::new();
    builder.append_values(&[1, 2, 3, 4, 5], &[true, true, true, true, true]);
    let array = builder.finish();

    println!("Int64 Array: {:?}", array);
    println!("Length: {}", array.len());

    for i in 0..array.len() {
        if array.is_valid(i) {
            println!("Value[{}]: {}", i, array.value(i));
        }
    }
}

/// Example 2: Multiple columns with different types
fn example2_multiple_columns() {
    let schema = Arc::new(Schema::new(vec![
        Field::new("id", DataType::Int32, false),
        Field::new("name", DataType::Utf8, false),
        Field::new("score", DataType::Float64, false),
    ]));

    let mut id_builder = Int32Builder::new();
    let mut name_builder = StringBuilder::new();
    let mut score_builder = Float64Builder::new();

    // Append data
    id_builder.append_values(&[1, 2, 3], &[true, true, true]);
    name_builder.append_value("Alice");
    name_builder.append_value("Bob");
    name_builder.append_value("Charlie");
    score_builder.append_values(&[95.5, 87.3, 92.1], &[true, true, true]);

    let id_array = id_builder.finish();
    let name_array = name_builder.finish();
    let score_array = score_builder.finish();

    let batch = RecordBatch::try_new(
        schema.clone(),
        vec![Arc::new(id_array), Arc::new(name_array), Arc::new(score_array)],
    ).expect("Failed to create RecordBatch");

    println!("Schema: {}", schema);
    println!("NumRows: {}", batch.num_rows());
    println!("NumCols: {}", batch.num_columns());

    // Print data
    for i in 0..batch.num_rows() {
        let id = batch.column(0)
            .as_any()
            .downcast_ref::<arrow::array::Int32Array>()
            .unwrap()
            .value(i);
        let name = batch.column(1)
            .as_any()
            .downcast_ref::<arrow::array::StringArray>()
            .unwrap()
            .value(i);
        let score = batch.column(2)
            .as_any()
            .downcast_ref::<arrow::array::Float64Array>()
            .unwrap()
            .value(i);

        println!("Row {}: ID={}, Name={}, Score={:.2}", i, id, name, score);
    }
}

/// Example 3: Working with nullable values
fn example3_nullable_values() {
    let mut builder = Int64Builder::new();
    // Append values with some nulls
    builder.append_values(&[10, 20, 30, 40, 50], &[true, false, true, false, true]);
    let array = builder.finish();

    println!("Record with nullable values:");
    for i in 0..array.len() {
        if array.is_valid(i) {
            println!("Value[{}]: {}", i, array.value(i));
        } else {
            println!("Value[{}]: NULL", i);
        }
    }
    println!("Null count: {}", array.null_count());
}

/// Example 4: Mixed data types
fn example4_mixed_types() {
    let schema = Arc::new(Schema::new(vec![
        Field::new("int_col", DataType::Int32, false),
        Field::new("float_col", DataType::Float64, false),
        Field::new("string_col", DataType::Utf8, false),
        Field::new("bool_col", DataType::Boolean, false),
    ]));

    let mut int_builder = Int32Builder::new();
    let mut float_builder = Float64Builder::new();
    let mut string_builder = StringBuilder::new();
    let mut bool_builder = BooleanBuilder::new();

    // Append data
    int_builder.append_values(&[100, 200, 300], &[true, true, true]);
    float_builder.append_values(&[1.5, 2.5, 3.5], &[true, true, true]);
    string_builder.append_value("first");
    string_builder.append_value("second");
    string_builder.append_value("third");
    bool_builder.append_values(&[true, false, true], &[true, true, true]).unwrap();

    let int_array = int_builder.finish();
    let float_array = float_builder.finish();
    let string_array = string_builder.finish();
    let bool_array = bool_builder.finish();

    let batch = RecordBatch::try_new(
        schema.clone(),
        vec![
            Arc::new(int_array),
            Arc::new(float_array),
            Arc::new(string_array),
            Arc::new(bool_array),
        ],
    ).expect("Failed to create RecordBatch");

    println!("Schema: {}", schema);
    println!("NumRows: {}", batch.num_rows());

    // Print all rows
    for i in 0..batch.num_rows() {
        let int_val = batch.column(0)
            .as_any()
            .downcast_ref::<arrow::array::Int32Array>()
            .unwrap()
            .value(i);
        let float_val = batch.column(1)
            .as_any()
            .downcast_ref::<arrow::array::Float64Array>()
            .unwrap()
            .value(i);
        let string_val = batch.column(2)
            .as_any()
            .downcast_ref::<arrow::array::StringArray>()
            .unwrap()
            .value(i);
        let bool_val = batch.column(3)
            .as_any()
            .downcast_ref::<arrow::array::BooleanArray>()
            .unwrap()
            .value(i);

        println!("Row {}: int={}, float={:.2}, string={}, bool={}", i, int_val, float_val, string_val, bool_val);
    }
}

/// Example 5: B+ Tree operations
fn example5_bplus_tree() {
    let mut tree = BPlusTree::new();

    println!("Creating B+ Tree with multiple insertions...");
    
    // Insert key-value pairs
    let data = vec![
        (50, "apple"),
        (30, "cat"),
        (70, "dog"),
        (10, "elephant"),
        (40, "fox"),
        (60, "giraffe"),
        (80, "horse"),
        (5, "igloo"),
        (15, "jazz"),
        (35, "kite"),
    ];

    for (key, value) in data.iter() {
        tree.insert(*key, value.to_string());
        println!("Inserted: {} -> {}", key, value);
    }

    println!("\n{}", tree);
    
    println!("\nTree Structure:");
    tree.print_tree();

    println!("\n--- Search Operations ---");
    let search_keys = vec![50, 30, 100, 5];
    for key in search_keys {
        match tree.search(key) {
            Some(value) => println!("Found: {} -> {}", key, value),
            None => println!("Not found: {}", key),
        }
    }

    println!("\n--- Range Queries ---");
    let ranges = vec![(10, 40), (30, 70), (1, 100)];
    for (start, end) in ranges {
        let result = tree.range_query(start, end);
        println!("Range [{}, {}]:", start, end);
        for (k, v) in result {
            println!("  {} -> {}", k, v);
        }
    }

    println!("\n--- All Keys (Sorted) ---");
    let all_keys = tree.all_keys();
    println!("Keys: {:?}", all_keys);

    println!("\n--- Update Value ---");
    tree.insert(50, "APPLE (updated)".to_string());
    match tree.search(50) {
        Some(value) => println!("Updated value: 50 -> {}", value),
        None => println!("Key not found"),
    }
}
