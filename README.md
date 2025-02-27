# Nivot

Nivot is a powerful pivot library for Nim that allows you to easily transform, reshape, analyze and visualize your data.

## Features

- **Core Data Types**: `DataTable` and `PivotTable` for efficient data manipulation
- **Pivot Operations**: Easily pivot your data with various aggregation functions
- **Data Transformation**: Filter, select, sort, join, melt, cast, and more
- **Data Visualization**: Generate text-based tables, bar charts, and line charts
- **Import/Export**: Read and write data from/to CSV and JSON formats

## Installation

```bash
nimble install nivot
```

## Quick Start

```nim
import nivotpkg

# Create a data table
var dt = newDataTable()
dt.addColumn("Region", @["North", "South", "East", "West"])
dt.addColumn("Product", @["Apples", "Apples", "Bananas", "Bananas"])
dt.addColumn("Sales", @["100", "150", "300", "250"])

# Display the data
echo "Original Data:"
echo dt

# Create a pivot table
echo "\nPivot Table (Sum of Sales by Region and Product):"
let pivotSum = dt.pivot("Region", "Product", "Sales", sum)
echo pivotSum

# Filter data
let filtered = dt.filter(proc(row: Table[string, string]): bool = 
  try:
    return parseFloat(row["Sales"]) > 150.0
  except:
    return false
)
echo "\nFiltered data (Sales > 150):"
echo filtered

# Visualize data
echo "\nTabular visualization:"
echo drawTable(dt)

echo "\nBar chart of Sales by Region:"
echo drawBarChart(dt, "Region", "Sales")
```

## Core Components

Nivot is organized into several modules:

- **nivot.nim**: Core data types and pivot functionality
- **nivotlib/transform.nim**: Data transformation operations
- **nivotlib/io.nim**: Input/output operations (CSV, JSON)
- **nivotlib/viz.nim**: Visualization functions

For convenience, you can import everything using:

```nim
import nivotpkg
```

## Documentation

### DataTable Operations

```nim
# Create a new data table
var dt = newDataTable()

# Add columns
dt.addColumn("Region", @["North", "South", "East", "West"])
dt.addColumn("Sales", @["100", "150", "200", "250"])

# Add a row
dt.addRow([("Region", "Central"), ("Sales", "300")])

# Display data table
echo dt
```

### Pivot Operations

```nim
# Create a pivot table
let pt = dt.pivot(
  rowField = "Region",
  columnField = "Product", 
  valueField = "Sales",
  aggregationFn = sum  # Can also use: avg, count, max, min
)

# Convert back to a data table
let dtFromPivot = pt.toDatatable()

# Display pivot table
echo pt
```

### Data Transformation

```nim
# Filter data
let filtered = dt.filter(proc(row: Table[string, string]): bool = 
  return row["Region"] == "North"
)

# Select columns
let selected = dt.select(["Region", "Sales"])

# Rename columns
let renamed = dt.rename([("Sales", "Revenue")])

# Add computed column
dt.addComputedColumn("SalesTax", proc(row: Table[string, string]): string =
  try:
    return $(parseFloat(row["Sales"]) * 0.08)
  except:
    return "0"
)

# Group by
let grouped = dt.groupBy(
  ["Region"], 
  [("Sales", "TotalSales", sum), ("Units", "TotalUnits", sum)]
)

# Sort data
let sorted = dt.sortBy([("Sales", true)])  # true = descending

# Reshape data: wide to long
let melted = dt.melt(["Region"], ["Sales", "Units"])

# Reshape data: long to wide
let cast = melted.cast(["Region"], "variable", "value")

# Join data
let joined = left.join(right, ["Region"], "inner")  # join types: inner, left, right, full
```

### Visualization

```nim
# Draw a formatted table
echo drawTable(dt)

# Draw a bar chart
echo drawBarChart(dt, "Region", "Sales")

# Draw a line chart
echo drawLineChart(dt, "Time", "Value")

# Draw a scatter plot
echo drawLineChart(dt, "X", "Y", chartType = Scatter)
```

### Import/Export

```nim
# Import from CSV
let dtFromCsv = loadFromCsv("data.csv")

# Export to CSV
dt.saveToCsv("output.csv")

# Import from JSON
let dtFromJson = loadFromJson("data.json")

# Export to JSON
dt.saveToJson("output.json", pretty = true)
```

## Aggregation Functions

Nivot provides several built-in aggregation functions:

- **sum**: Sum of values
- **avg**: Average of values
- **count**: Count of values
- **max**: Maximum value
- **min**: Minimum value

You can also create custom aggregation functions:

```nim
proc customAggregation(values: seq[string]): string =
  # Your custom aggregation logic here
  return "result"

let pt = dt.pivot("Region", "Product", "Sales", customAggregation)
```

## License

MIT
