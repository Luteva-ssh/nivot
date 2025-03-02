# tests/all.nim
# Main test suite for Nivot

import unittest, tables, strutils
import ../src/nivot
import ../src/nivotlib/viz
import ../src/nivotlib/transform

# Test data
proc createTestData(): DataTable =
  var dt = newDataTable()
  dt.addColumn("Region", @["North", "South", "East", "West", "North", "South", "East", "West"])
  dt.addColumn("Product", @["Apples", "Apples", "Apples", "Apples", "Bananas", "Bananas", "Bananas", "Bananas"])
  dt.addColumn("Sales", @["100", "150", "200", "120", "300", "200", "150", "250"])
  dt.addColumn("Units", @["10", "15", "20", "12", "30", "20", "15", "25"])
  return dt

suite "Core functionality":
  test "DataTable creation":
    let dt = createTestData()
    check(dt.rowCount == 8)
    check(columnsLen(dt) == 4)
    check(hasColumn(dt, "Region"))
    check(hasColumn(dt, "Product"))
    check(hasColumn(dt, "Sales"))
    check(hasColumn(dt, "Units"))
  
  test "Adding columns and rows":
    var dt = newDataTable()
    dt.addColumn("A", @["1", "2", "3"])
    dt.addColumn("B", @["a", "b", "c"])
    
    check(dt.rowCount == 3)
    check(columnsLen(dt) == 2)
    
    dt.addRow([("A", "4"), ("B", "d")])
    
    check(dt.rowCount == 4)
    check(getColumn(dt, "A").len == 4)
    check(getColumnValue(dt, "A", 3) == "4")
    check(getColumnValue(dt, "B", 3) == "d")
  
  test "Pivot table creation":
    let dt = createTestData()
    let pt = dt.pivot("Region", "Product", "Sales", sum)
    
    check(pt.rowField == "Region")
    check(pt.columnField == "Product")
    check(pt.valueField == "Sales")
    
    # Test one aggregated value
    check(getPivotValue(pt, "North", "Apples") == "100.0")

suite "Aggregation functions":
  test "Sum aggregation":
    check(sum(@["10", "20", "30"]) == "60.0")
    check(sum(@[]) == "0")
    check(sum(@["10", "invalid", "30"]) == "0") # Should handle errors
  
  test "Average aggregation":
    check(avg(@["10", "20", "30"]) == "20.0")
    check(avg(@[]) == "0")
  
  test "Count aggregation":
    check(count(@["10", "20", "30"]) == "3")
    check(count(@[]) == "0")
  
  test "Max aggregation":
    check(max(@["10", "20", "30"]) == "30.0")
    check(max(@[]) == "")
    check(max(@["a", "b", "c"]) == "c") # String comparison fallback
  
  test "Min aggregation":
    check(min(@["10", "20", "30"]) == "10.0")
    check(min(@[]) == "")
    check(min(@["a", "b", "c"]) == "a") # String comparison fallback

suite "Data transformation":
  test "Filter operation":
    let dt = createTestData()
    let filtered = dt.filter(proc(row: Table[string, string]): bool = 
      try:
        return parseFloat(row["Sales"]) > 150.0
      except CatchableError:
        return false
    )
    
    check(filtered.rowCount == 4)
  
  test "Select operation":
    let dt = createTestData()
    let selected = dt.select(["Region", "Sales"])
    
    check(selected.rowCount == 8)
    check(columnsLen(selected) == 2)
    check(hasColumn(selected, "Region"))
    check(hasColumn(selected, "Sales"))
    check(not hasColumn(selected, "Product"))
  
  test "Rename operation":
    let dt = createTestData()
    let renamed = dt.rename([("Sales", "Revenue")])
    
    check(renamed.rowCount == 8)
    check(columnsLen(renamed) == 4)
    check(hasColumn(renamed, "Revenue"))
    check(not hasColumn(renamed, "Sales"))
  
  test "Adding computed column":
    var dt = createTestData()
    dt.addComputedColumn("RevPerUnit", proc(row: Table[string, string]): string =
      try:
        let sales = parseFloat(row["Sales"])
        let units = parseFloat(row["Units"])
        return $(sales / units)
      except CatchableError:
        return "0"
    )
    
    check(columnsLen(dt) == 5)
    check(hasColumn(dt, "RevPerUnit"))
    check(getColumn(dt, "RevPerUnit").len == 8)
  
  test "Group By operation":
    let dt = createTestData()
    var aggregations: seq[(string, string, AggregationFunction)] = @[("Sales", "TotalSales", sum)]
    let grouped = dt.groupBy(["Region"], aggregations)
    
    check(columnsLen(grouped) == 2)
    check(hasColumn(grouped, "Region"))
    check(hasColumn(grouped, "TotalSales"))
    check(grouped.rowCount == 4) # 4 unique regions
  
  test "Sort By operation":
    let dt = createTestData()
    let sorted = dt.sortBy([("Sales", true)]) # descending
    
    check(sorted.rowCount == 8)
    # First row should have highest sales
    check(sorted.columns["Sales"][0] == "300")

  test "Melt operation":
    let dt = createTestData()
    let melted = dt.melt(["Region", "Product"], ["Sales", "Units"])
    
    check(columnsLen(melted) == 4)
    check(hasColumn(melted, "Region"))
    check(hasColumn(melted, "Product"))
    check(hasColumn(melted, "variable"))
    check(hasColumn(melted, "value"))
    check(melted.rowCount == 16) # 8 rows * 2 value columns

suite "Visualization":
  test "Table drawing":
    let dt = createTestData()
    let table = drawTable(dt)
    
    check(table.len > 0)
    check(table.contains("Region"))
    check(table.contains("Product"))
    check(table.contains("Sales"))
  
  test "Bar chart drawing":
    let dt = createTestData()
    let chart = drawBarChart(dt, "Region", "Sales")
    
    check(chart.len > 0)
    check(chart.contains("Sales by Region"))
    echo "Example BarChart:\n" & chart
  
  test "Line chart drawing":
    # Create a simple dataset for line chart
    var lineData = newDataTable()
    lineData.addColumn("X", @["1", "2", "3", "4", "5"])
    lineData.addColumn("Y", @["2", "5", "3", "8", "6"])
    
    # Test default line chart
    let lineChart = drawLineChart(lineData, "X", "Y")
    check(lineChart.len > 0)
    check(lineChart.contains("Y vs X"))
    check(lineChart.contains("X-axis"))
    check(lineChart.contains("Y-axis"))
    echo "Example line chart:\n" & lineChart
    
    # Test scatter chart
    let scatterChart = drawLineChart(lineData, "X", "Y", chartType = Scatter)
    check(scatterChart.len > 0)
    check(scatterChart.contains("Y vs X"))
    check(scatterChart.contains("*"))  # Should contain asterisks for data points
    
    # Test error cases
    let badColChart = drawLineChart(lineData, "NonExistent", "Y")
    check(badColChart.contains("Error"))

when isMainModule:
  echo "Running Nivot tests..."
  
  # Run all tests
  var dt = createTestData()
  
  echo "\nExample DataTable:"
  echo dt
  
  echo "\nExample PivotTable:"
  let pt = dt.pivot("Region", "Product", "Sales", sum)
  echo pt
  
  echo "\nExample Visualization:"
  echo drawTable(dt)
  
  echo "\nAll tests completed."
