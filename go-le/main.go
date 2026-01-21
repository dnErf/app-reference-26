package main

import (
	"fmt"
	"log"

	"github.com/apache/arrow-go/v18/arrow"
	"github.com/apache/arrow-go/v18/arrow/array"
	"github.com/apache/arrow-go/v18/arrow/memory"
)

// Example: Merkle Tree
func exampleMerkleTree() {
	dataBlocks := []string{
		"block_0: transaction A",
		"block_1: transaction B",
		"block_2: transaction C",
		"block_3: transaction D",
		"block_4: transaction E",
	}

	fmt.Printf("\nBuilding Merkle tree with %d data blocks...\n", len(dataBlocks))
	tree, err := NewMerkleTree(dataBlocks, "sha256")
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		return
	}

	fmt.Println(tree.Display())

	// Get root hash
	fmt.Println("\n--- Root Hash ---")
	fmt.Printf("Root Hash: %s\n", tree.GetRootHash())

	// Get proofs and verify leaves
	fmt.Println("\n--- Merkle Proofs and Verification ---")
	for i := 0; i < len(dataBlocks); i++ {
		proof := tree.GetProof(i)
		originalData := dataBlocks[i]
		isValid := tree.VerifyLeaf(i, originalData, proof)

		fmt.Printf("Leaf [%d] '%s':\n", i, originalData)
		fmt.Printf("  Proof length: %d\n", len(proof))
		fmt.Printf("  Valid: %v\n", isValid)
	}

	// Verify with corrupted data
	fmt.Println("\n--- Tampering Detection ---")
	corruptedData := "corrupted data"
	proof := tree.GetProof(0)
	isValid := tree.VerifyLeaf(0, corruptedData, proof)
	fmt.Printf("Verify leaf [0] with corrupted data: %v\n", isValid)

	// Tree visualization
	fmt.Println("\n--- Tree Structure ---")
	fmt.Print(tree.VisualizeTree())
}

func demoLSMDatabase() error {
	if err := demoBasicDatabaseOperations(); err != nil {
		return err
	}
	if err := demoDatabaseConfigurations(); err != nil {
		return err
	}
	if err := demoWALRecovery(); err != nil {
		return err
	}
	return nil
}

func main() {
	fmt.Println("========== Merkle Tree Example ==========")
	exampleMerkleTree()

	// Create a memory allocator
	alloc := memory.NewGoAllocator()

	fmt.Println("\n========== Example 1: Single Column (Int64) ==========")
	example1SingleColumn(alloc)

	fmt.Println("\n========== Example 2: Multiple Columns ==========")
	example2MultipleColumns(alloc)

	fmt.Println("\n========== Example 3: Nullable Values ==========")
	example3NullableValues(alloc)

	fmt.Println("\n========== Example 4: Different Data Types ==========")
	example4MixedTypes(alloc)
}

// Example 1: Single column with int64 values
func example1SingleColumn(alloc memory.Allocator) {
	schema := arrow.NewSchema([]arrow.Field{
		{Name: "numbers", Type: arrow.PrimitiveTypes.Int64},
	}, nil)

	builder := array.NewRecordBuilder(alloc, schema)
	defer builder.Release()

	int64Builder := builder.Field(0).(*array.Int64Builder)
	int64Builder.AppendValues([]int64{1, 2, 3, 4, 5}, nil)

	record := builder.NewRecord()
	defer record.Release()

	fmt.Println("Arrow Record:")
	fmt.Printf("Schema: %v\n", record.Schema())
	fmt.Printf("NumRows: %d\n", record.NumRows())
	fmt.Printf("NumCols: %d\n", record.NumCols())

	col := record.Column(0)
	fmt.Printf("Column 0: %v\n", col)

	int64Arr := col.(*array.Int64)
	for i := 0; i < int64Arr.Len(); i++ {
		if int64Arr.IsValid(i) {
			fmt.Printf("Value[%d]: %d\n", i, int64Arr.Value(i))
		}
	}
}

// Example 2: Multiple columns with different types
func example2MultipleColumns(alloc memory.Allocator) {
	schema := arrow.NewSchema([]arrow.Field{
		{Name: "id", Type: arrow.PrimitiveTypes.Int32},
		{Name: "name", Type: arrow.BinaryTypes.String},
		{Name: "score", Type: arrow.PrimitiveTypes.Float64},
	}, nil)

	builder := array.NewRecordBuilder(alloc, schema)
	defer builder.Release()

	// Get builders for each field
	idBuilder := builder.Field(0).(*array.Int32Builder)
	nameBuilder := builder.Field(1).(*array.StringBuilder)
	scoreBuilder := builder.Field(2).(*array.Float64Builder)

	// Append data
	idBuilder.AppendValues([]int32{1, 2, 3}, nil)
	nameBuilder.AppendValues([]string{"Alice", "Bob", "Charlie"}, nil)
	scoreBuilder.AppendValues([]float64{95.5, 87.3, 92.1}, nil)

	record := builder.NewRecord()
	defer record.Release()

	fmt.Printf("Schema: %v\n", record.Schema())
	fmt.Printf("NumRows: %d, NumCols: %d\n", record.NumRows(), record.NumCols())

	// Print all data
	for i := 0; i < int(record.NumRows()); i++ {
		idArr := record.Column(0).(*array.Int32)
		nameArr := record.Column(1).(*array.String)
		scoreArr := record.Column(2).(*array.Float64)

		fmt.Printf("Row %d: ID=%d, Name=%s, Score=%.2f\n",
			i,
			idArr.Value(i),
			nameArr.Value(i),
			scoreArr.Value(i),
		)
	}
}

// Example 3: Working with nullable values
func example3NullableValues(alloc memory.Allocator) {
	schema := arrow.NewSchema([]arrow.Field{
		{Name: "values", Type: arrow.PrimitiveTypes.Int64},
	}, nil)

	builder := array.NewRecordBuilder(alloc, schema)
	defer builder.Release()

	valueBuilder := builder.Field(0).(*array.Int64Builder)

	// Add values with some nulls (nil in the valid array means null)
	valueBuilder.AppendValues([]int64{10, 20, 30, 40, 50}, []bool{true, false, true, false, true})

	record := builder.NewRecord()
	defer record.Release()

	fmt.Printf("Record with nullable values:\n")
	arr := record.Column(0).(*array.Int64)

	for i := 0; i < arr.Len(); i++ {
		if arr.IsValid(i) {
			fmt.Printf("Value[%d]: %d\n", i, arr.Value(i))
		} else {
			fmt.Printf("Value[%d]: NULL\n", i)
		}
	}
	fmt.Printf("Null count: %d\n", arr.NullN())
}

// Example 4: Mixed data types
func example4MixedTypes(alloc memory.Allocator) {
	schema := arrow.NewSchema([]arrow.Field{
		{Name: "int_col", Type: arrow.PrimitiveTypes.Int32},
		{Name: "float_col", Type: arrow.PrimitiveTypes.Float32},
		{Name: "string_col", Type: arrow.BinaryTypes.String},
		{Name: "bool_col", Type: arrow.FixedWidthTypes.Boolean},
	}, nil)

	builder := array.NewRecordBuilder(alloc, schema)
	defer builder.Release()

	intBuilder := builder.Field(0).(*array.Int32Builder)
	floatBuilder := builder.Field(1).(*array.Float32Builder)
	stringBuilder := builder.Field(2).(*array.StringBuilder)
	boolBuilder := builder.Field(3).(*array.BooleanBuilder)

	// Append data
	intBuilder.AppendValues([]int32{100, 200, 300}, nil)
	floatBuilder.AppendValues([]float32{1.5, 2.5, 3.5}, nil)
	stringBuilder.AppendValues([]string{"first", "second", "third"}, nil)
	boolBuilder.AppendValues([]bool{true, false, true}, nil)

	record := builder.NewRecord()
	defer record.Release()

	fmt.Printf("Mixed Types Record:\n")
	fmt.Printf("Schema: %v\n", record.Schema())
	fmt.Printf("NumRows: %d\n", record.NumRows())

	// Print all rows
	for i := 0; i < int(record.NumRows()); i++ {
		intArr := record.Column(0).(*array.Int32)
		floatArr := record.Column(1).(*array.Float32)
		stringArr := record.Column(2).(*array.String)
		boolArr := record.Column(3).(*array.Boolean)

		fmt.Printf("Row %d: int=%d, float=%.2f, string=%s, bool=%v\n",
			i,
			intArr.Value(i),
			floatArr.Value(i),
			stringArr.Value(i),
			boolArr.Value(i),
		)
	}

	fmt.Println("\n========== Arrow Parquet Example ==========")
	parquetExample()

	// Database Simulation Demo
	fmt.Println("\n========== Comprehensive Database Simulation ==========")
	demoComprehensiveDatabase()

	// LSM Database Demo
	fmt.Println("\n========== LSM Database System ==========")
	if err := demoLSMDatabase(); err != nil {
		log.Printf("LSM Database demo failed: %v", err)
	}

	// B+ Tree Demo
	bplusTreeDemo()
}
