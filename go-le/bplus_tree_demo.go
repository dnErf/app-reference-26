package main

import "fmt"

func bplusTreeDemo() {
	fmt.Println("\n========== B+ Tree Demonstration ==========\n")

	tree := NewBPlusTree()

	// Sample data
	data := []struct {
		key   int
		value string
	}{
		{50, "apple"},
		{30, "cat"},
		{70, "dog"},
		{10, "elephant"},
		{40, "fox"},
		{60, "giraffe"},
		{80, "horse"},
		{5, "igloo"},
		{15, "jazz"},
		{35, "kite"},
	}

	fmt.Println("Creating B+ Tree with multiple insertions...")
	for _, item := range data {
		tree.Insert(item.key, item.value)
		fmt.Printf("Inserted: %d -> %s\n", item.key, item.value)
	}

	fmt.Printf("\n%s\n", tree)

	fmt.Println("\nTree Structure:")
	tree.PrintTree()

	fmt.Println("\n--- Search Operations ---")
	searchKeys := []int{50, 30, 100, 5}
	for _, key := range searchKeys {
		if value, found := tree.Search(key); found {
			fmt.Printf("Found: %d -> %s\n", key, value)
		} else {
			fmt.Printf("Not found: %d\n", key)
		}
	}

	fmt.Println("\n--- Range Queries ---")
	ranges := []struct {
		start int
		end   int
	}{
		{10, 40},
		{30, 70},
		{1, 100},
	}

	for _, r := range ranges {
		results := tree.RangeQuery(r.start, r.end)
		fmt.Printf("Range [%d, %d]:\n", r.start, r.end)
		for _, entry := range results {
			fmt.Printf("  %d -> %s\n", entry.Key, entry.Value)
		}
	}

	fmt.Println("\n--- All Keys (Sorted) ---")
	keys := tree.AllKeys()
	fmt.Printf("Keys: %v\n", keys)

	fmt.Println("\n--- Update Value ---")
	tree.Insert(50, "APPLE (updated)")
	if value, found := tree.Search(50); found {
		fmt.Printf("Updated value: 50 -> %s\n", value)
	}
}
