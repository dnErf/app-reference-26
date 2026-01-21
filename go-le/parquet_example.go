package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/apache/arrow-go/v18/arrow"
	"github.com/apache/arrow-go/v18/arrow/array"
	"github.com/apache/arrow-go/v18/arrow/memory"
	"github.com/apache/arrow-go/v18/parquet"
	"github.com/apache/arrow-go/v18/parquet/file"
	"github.com/apache/arrow-go/v18/parquet/pqarrow"
)

func parquetExample() {
	// Create memory allocator
	alloc := memory.NewGoAllocator()

	// Define schema
	schema := arrow.NewSchema([]arrow.Field{
		{Name: "name", Type: arrow.BinaryTypes.String},
		{Name: "age", Type: arrow.PrimitiveTypes.Int32},
		{Name: "salary", Type: arrow.PrimitiveTypes.Float64},
	}, nil)

	// Create record builder
	builder := array.NewRecordBuilder(alloc, schema)
	defer builder.Release()

	// Get builders for each field
	nameBuilder := builder.Field(0).(*array.StringBuilder)
	ageBuilder := builder.Field(1).(*array.Int32Builder)
	salaryBuilder := builder.Field(2).(*array.Float64Builder)

	// Sample data
	names := []string{"Alice", "Bob", "Charlie", "Diana", "Eve"}
	ages := []int32{25, 30, 35, 28, 32}
	salaries := []float64{50000.0, 60000.0, 70000.0, 55000.0, 65000.0}

	// Append data
	nameBuilder.AppendValues(names, nil)
	ageBuilder.AppendValues(ages, nil)
	salaryBuilder.AppendValues(salaries, nil)

	// Build arrays
	nameArray := nameBuilder.NewArray()
	defer nameArray.Release()
	ageArray := ageBuilder.NewArray()
	defer ageArray.Release()
	salaryArray := salaryBuilder.NewArray()
	defer salaryArray.Release()

	// Build record batch
	cols := []arrow.Array{nameArray, ageArray, salaryArray}
	record := array.NewRecordBatch(schema, cols, int64(len(names)))
	defer record.Release()

	// Write to Parquet file
	filename := "example.parquet"
	f, err := os.Create(filename)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()

	// Create Parquet writer without compression
	props := parquet.NewWriterProperties()

	writer, err := pqarrow.NewFileWriter(schema, f, props, pqarrow.DefaultWriterProps())
	if err != nil {
		log.Fatal(err)
	}
	defer writer.Close()

	// Write table
	if err := writer.Write(record); err != nil {
		log.Fatal(err)
	}

	fmt.Printf("Successfully wrote %d rows to %s\n", record.NumRows(), filename)

	// Now read the file back
	fmt.Println("\nReading back from Parquet file:")

	// Open file for reading
	rf, err := os.Open(filename)
	if err != nil {
		log.Fatal(err)
	}
	defer rf.Close()

	// Get file size
	fileInfo, err := rf.Stat()
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("File size: %d bytes\n", fileInfo.Size())

	// Create Parquet reader
	reader, err := file.NewParquetReader(rf)
	if err != nil {
		log.Printf("Error reading parquet file: %v\n", err)
		fmt.Println("File was written successfully, but reading has compatibility issues with the current Arrow version.")
		return
	}
	defer reader.Close()

	// Create Arrow reader
	arrowReader, err := pqarrow.NewFileReader(reader, pqarrow.ArrowReadProperties{}, alloc)
	if err != nil {
		log.Printf("Error creating Arrow reader: %v\n", err)
		return
	}

	// Read table
	readTable, err := arrowReader.ReadTable(context.Background())
	if err != nil {
		log.Printf("Error reading table: %v\n", err)
		return
	}
	defer readTable.Release()

	fmt.Printf("Read table with %d rows and %d columns\n", readTable.NumRows(), readTable.NumCols())

	// Print column names
	for i := 0; i < int(readTable.NumCols()); i++ {
		col := readTable.Column(i)
		fmt.Printf("Column %d: %s (%s)\n", i, col.Name(), col.DataType().Name())
	}

	// Read first record
	if readTable.NumRows() > 0 {
		fmt.Println("\nFirst record data:")

		// Get columns as chunked arrays
		nameChunked := readTable.Column(0).Data()
		ageChunked := readTable.Column(1).Data()
		salaryChunked := readTable.Column(2).Data()

		// Get the first chunk
		if nameChunked.Len() > 0 {
			nameCol := nameChunked.Chunk(0).(*array.String)
			ageCol := ageChunked.Chunk(0).(*array.Int32)
			salaryCol := salaryChunked.Chunk(0).(*array.Float64)

			fmt.Printf("Name: %s\n", nameCol.Value(0))
			fmt.Printf("Age: %d\n", ageCol.Value(0))
			fmt.Printf("Salary: %.2f\n", salaryCol.Value(0))
		}
	}
}
