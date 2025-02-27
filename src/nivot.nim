# Nivot - A pivot library for Nim
#
# This library provides functionality for pivoting, reshaping, and aggregating
# data in various formats.

import tables, strutils, sequtils, math

type
  DataColumn* = seq[string]
  DataTable* = object
    columns*: OrderedTable[string, DataColumn]
    rowCount*: int

  AggregationFunction* = proc(values: seq[string]): string

  PivotTable* = object
    rowValues*: Table[string, seq[string]]
    columnValues*: Table[string, seq[string]]
    values*: Table[string, Table[string, string]]
    rowField*: string
    columnField*: string
    valueField*: string
    aggregationFn*: AggregationFunction

proc newDataTable*(): DataTable =
  ## Creates a new empty data table
  result.columns = initOrderedTable[string, DataColumn]()
  result.rowCount = 0

proc columnsLen*(dt: DataTable): int =
  ## Returns the number of columns in the data table
  result = dt.columns.len

proc hasColumn*(dt: DataTable, columnName: string): bool =
  ## Checks if the data table has a column with the given name
  result = dt.columns.hasKey(columnName)

proc getColumn*(dt: DataTable, columnName: string): DataColumn =
  ## Gets a column from the data table
  result = dt.columns[columnName]

proc getColumnValue*(dt: DataTable, columnName: string, rowIndex: int): string =
  ## Gets a value from a column at the specified row index
  if dt.columns.hasKey(columnName) and rowIndex < dt.columns[columnName].len:
    result = dt.columns[columnName][rowIndex]
  else:
    result = ""

proc getPivotValue*(pt: PivotTable, rowValue: string, colValue: string): string =
  ## Gets a value from a pivot table
  if pt.values.hasKey(rowValue) and pt.values[rowValue].hasKey(colValue):
    result = pt.values[rowValue][colValue]
  else:
    result = ""

proc addColumn*(dt: var DataTable, name: string, values: seq[string] = @[]) =
  ## Adds a column to the data table
  var column = values
  # Ensure the column has enough rows
  if dt.rowCount > column.len:
    column.add(newSeq[string](dt.rowCount - column.len))
  dt.columns[name] = column
  
  # Update row count if this column is longer
  if column.len > dt.rowCount:
    dt.rowCount = column.len

proc addRow*(dt: var DataTable, row: openArray[(string, string)]) =
  ## Adds a row to the data table
  for (colName, value) in row:
    if colName notin dt.columns:
      dt.addColumn(colName)
    
    if dt.columns[colName].len < dt.rowCount + 1:
      dt.columns[colName].add(newSeq[string](dt.rowCount + 1 - dt.columns[colName].len))
    
    dt.columns[colName][dt.rowCount] = value
  
  dt.rowCount += 1

proc `$`*(dt: DataTable): string =
  ## Returns a string representation of the data table
  var header: seq[string] = @[]
  var rows: seq[seq[string]] = @[]
  
  # Initialize rows
  for i in 0..<dt.rowCount:
    rows.add(@[])
  
  # Add column data
  for colName, colValues in dt.columns:
    header.add(colName)
    
    for i in 0..<dt.rowCount:
      if i < colValues.len:
        if rows[i].len < header.len:
          rows[i].add(colValues[i])
        else:
          rows[i][header.len - 1] = colValues[i]
      else:
        if rows[i].len < header.len:
          rows[i].add("")
        else:
          rows[i][header.len - 1] = ""
  
  # Format the table
  result = header.join("\t") & "\n"
  for row in rows:
    result.add(row.join("\t") & "\n")

# Aggregation functions
proc sum*(values: seq[string]): string =
  ## Sum aggregation function
  if values.len == 0:
    return "0"
    
  try:
    var total = 0.0
    for v in values:
      total += parseFloat(v)
    result = $total
  except CatchableError:
    result = "0"

proc avg*(values: seq[string]): string =
  ## Average aggregation function
  if values.len == 0:
    return "0"
  
  try:
    var total = 0.0
    var count = 0
    for v in values:
      total += parseFloat(v)
      count += 1
    
    if count > 0:
      result = $(total / count.float)
    else:
      result = "0"
  except:
    result = "0"

proc count*(values: seq[string]): string =
  ## Count aggregation function
  $values.len

proc max*(values: seq[string]): string =
  ## Max aggregation function
  if values.len == 0:
    return ""
  
  try:
    var maxVal = parseFloat(values[0])
    for v in values[1..^1]:
      let val = parseFloat(v)
      if val > maxVal:
        maxVal = val
    result = $maxVal
  except:
    result = values.foldl(if a > b: a else: b, values[0])

proc min*(values: seq[string]): string =
  ## Min aggregation function
  if values.len == 0:
    return ""
  
  try:
    var minVal = parseFloat(values[0])
    for v in values[1..^1]:
      let val = parseFloat(v)
      if val < minVal:
        minVal = val
    result = $minVal
  except:
    result = values.foldl(if a < b: a else: b, values[0])

proc pivot*(
  dt: DataTable, 
  rowField: string, 
  columnField: string, 
  valueField: string,
  aggregationFn: AggregationFunction = sum
): PivotTable =
  ## Creates a pivot table from the data table
  var pt = PivotTable(
    rowField: rowField,
    columnField: columnField,
    valueField: valueField,
    aggregationFn: aggregationFn
  )
  
  # Initialize tables
  pt.rowValues = initTable[string, seq[string]]()
  pt.columnValues = initTable[string, seq[string]]()
  pt.values = initTable[string, Table[string, string]]()
  
  # Ensure fields exist
  if rowField notin dt.columns or columnField notin dt.columns or valueField notin dt.columns:
    return pt
  
  # Collect unique row and column values
  var uniqueRowValues: seq[string] = @[]
  var uniqueColumnValues: seq[string] = @[]
  
  for i in 0..<dt.rowCount:
    let rowValue = if i < dt.columns[rowField].len: dt.columns[rowField][i] else: ""
    let colValue = if i < dt.columns[columnField].len: dt.columns[columnField][i] else: ""
    
    if rowValue notin uniqueRowValues:
      uniqueRowValues.add(rowValue)
    
    if colValue notin uniqueColumnValues:
      uniqueColumnValues.add(colValue)
  
  # Group values by row and column
  for i in 0..<dt.rowCount:
    let rowValue = if i < dt.columns[rowField].len: dt.columns[rowField][i] else: ""
    let colValue = if i < dt.columns[columnField].len: dt.columns[columnField][i] else: ""
    let value = if i < dt.columns[valueField].len: dt.columns[valueField][i] else: ""
    
    if rowValue notin pt.rowValues:
      pt.rowValues[rowValue] = @[]
    
    if colValue notin pt.columnValues:
      pt.columnValues[colValue] = @[]
    
    if rowValue notin pt.values:
      pt.values[rowValue] = initTable[string, string]()
    
    if colValue notin pt.values[rowValue]:
      pt.values[rowValue][colValue] = ""
      pt.rowValues[rowValue].add(value)
      pt.columnValues[colValue].add(value)
    else:
      pt.rowValues[rowValue].add(value)
      pt.columnValues[colValue].add(value)
  
  # Apply aggregation
  for rowValue in uniqueRowValues:
    for colValue in uniqueColumnValues:
      if rowValue in pt.values and colValue in pt.values[rowValue]:
        # Find all values for this row-column combination
        var valuesToAggregate: seq[string] = @[]
        for i in 0..<dt.rowCount:
          let rValue = if i < dt.columns[rowField].len: dt.columns[rowField][i] else: ""
          let cValue = if i < dt.columns[columnField].len: dt.columns[columnField][i] else: ""
          let vValue = if i < dt.columns[valueField].len: dt.columns[valueField][i] else: ""
          
          if rValue == rowValue and cValue == colValue:
            valuesToAggregate.add(vValue)
        
        # Apply aggregation function
        pt.values[rowValue][colValue] = aggregationFn(valuesToAggregate)
  
  return pt

proc toDatatable*(pt: PivotTable): DataTable =
  ## Converts a pivot table back to a data table
  var dt = newDataTable()
  
  # Create column names
  var columnNames = @[pt.rowField]
  var uniqueColumnValues: seq[string] = @[]
  
  for colValue in pt.columnValues.keys:
    if colValue notin uniqueColumnValues:
      uniqueColumnValues.add(colValue)
  
  for colValue in uniqueColumnValues:
    columnNames.add(colValue)
  
  # Add columns to the data table
  for colName in columnNames:
    dt.addColumn(colName)
  
  # Add rows
  var uniqueRowValues: seq[string] = @[]
  for rowValue in pt.rowValues.keys:
    if rowValue notin uniqueRowValues:
      uniqueRowValues.add(rowValue)
  
  for rowValue in uniqueRowValues:
    var row = @[(pt.rowField, rowValue)]
    
    for colValue in uniqueColumnValues:
      if rowValue in pt.values and colValue in pt.values[rowValue]:
        row.add((colValue, pt.values[rowValue][colValue]))
      else:
        row.add((colValue, ""))
    
    dt.addRow(row)
  
  return dt

proc `$`*(pt: PivotTable): string =
  ## Returns a string representation of the pivot table
  let dt = pt.toDatatable()
  return $dt

when isMainModule:
  # Example usage
  var dt = newDataTable()
  dt.addColumn("Region", @["North", "South", "East", "West", "North", "South", "East", "West"])
  dt.addColumn("Product", @["Apples", "Apples", "Apples", "Apples", "Bananas", "Bananas", "Bananas", "Bananas"])
  dt.addColumn("Sales", @["100", "150", "200", "120", "300", "200", "150", "250"])
  
  echo "Original Data:"
  echo dt
  
  echo "\nPivot Table (Sum of Sales by Region and Product):"
  let pivotSum = dt.pivot("Region", "Product", "Sales", sum)
  echo pivotSum
  
  echo "\nPivot Table (Average of Sales by Region and Product):"
  let pivotAvg = dt.pivot("Region", "Product", "Sales", avg)
  echo pivotAvg
