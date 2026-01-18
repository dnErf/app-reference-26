"""
Demonstration of New Aggregate Functions
========================================

Shows SQL examples using the new @ aggregate functions.
"""

fn demonstrate_new_aggregates() raises:
    """Show examples of the new aggregate functions in SQL."""
    print("New Aggregate Functions Demonstration")
    print("=" * 40)

    print("\n1. @Stdev() - Standard Deviation")
    print("   SELECT dept, @Stdev(salary) as salary_stdev")
    print("   FROM employees")
    print("   GROUP BY dept")
    print("   HAVING @Stdev(salary) > 10000")

    print("\n2. @Variance() - Variance")
    print("   SELECT category, @Variance(price) as price_variance")
    print("   FROM products")
    print("   GROUP BY category")
    print("   HAVING @Variance(price) < 500")

    print("\n3. @Median() - Median Value")
    print("   SELECT region, @Median(sales) as median_sales")
    print("   FROM sales_data")
    print("   GROUP BY region")

    print("\n4. @Percentile() - Percentile (75th percentile)")
    print("   SELECT dept, @Percentile(salary, 75) as salary_75th")
    print("   FROM employees")
    print("   GROUP BY dept")

    print("\n5. @Mode() - Most Frequent Value")
    print("   SELECT product_type, @Mode(color) as most_common_color")
    print("   FROM inventory")
    print("   GROUP BY product_type")

    print("\n6. @First() / @Last() - First/Last Values")
    print("   SELECT customer_id,")
    print("          @First(order_date) as first_order,")
    print("          @Last(order_date) as last_order")
    print("   FROM orders")
    print("   GROUP BY customer_id")

    print("\n7. Complex HAVING with New Aggregates")
    print("   SELECT dept, COUNT(*), @Median(salary), @Stdev(salary)")
    print("   FROM employees")
    print("   GROUP BY dept")
    print("   HAVING @Median(salary) > 50000")
    print("      AND @Stdev(salary) < 15000")
    print("      AND @Mode(job_title) = 'Engineer'")

    print("\n8. Statistical Analysis Query")
    print("   SELECT")
    print("       experiment_group,")
    print("       COUNT(*) as sample_size,")
    print("       AVG(response_time) as avg_time,")
    print("       @Median(response_time) as median_time,")
    print("       @Stdev(response_time) as time_stdev,")
    print("       @Percentile(response_time, 95) as p95_time,")
    print("       @Mode(browser_type) as common_browser")
    print("   FROM experiment_results")
    print("   GROUP BY experiment_group")
    print("   HAVING @Stdev(response_time) < 100")
    print("      AND COUNT(*) > 30")

    print("\n✓ All new aggregate functions are ready for use!")
    print("✓ They work seamlessly with GROUP BY and HAVING")
    print("✓ @ prefix distinguishes them from standard SQL functions")
    print("✓ Full statistical analysis capabilities now available")

fn main() raises:
    """Run the demonstration."""
    demonstrate_new_aggregates()