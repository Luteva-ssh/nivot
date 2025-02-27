# nivotlib/transform.nim
# Data transformation functionality for Nivot pivot library

import strutils, sequtils, tables, algorithm, math, sets
import ../nivot  # Import the main library

proc filter*(dt: DataTable, predicate: proc(row: Table[string, string]): bool): DataTable =
  ## Filter rows based on a predicate function
  result = newDataTable()
  
  # Initialize columns
  for colName in dt.columns.keys:
    result.addColumn(colName)
  
  # Apply filter
  for i in 0..<dt.rowCount:
    var row = initTable[string, string]()
    
    # Build row data
    for colName, column in dt.columns:
      row[colName] = if i < column.len: column[i] else: ""
    
    # Apply predicate
    if predicate(row):
      var rowTuple: seq[(string, string)] = @[]
      for colName, value in row:
        rowTuple.add((colName, value))
      
      result.addRow(rowTuple)

proc select*(dt: DataTable, columns: openArray[string]): DataTable =
  ## Select specific columns from the data table
  result = newDataTable()
  
  # Add selected columns
  for colName in columns:
    if colName in dt.columns:
      result.addColumn(colName, dt.columns[colName])
  
  result.rowCount = dt.rowCount

proc rename*(dt: DataTable, mapping: openArray[(string, string)]): DataTable =
  ## Rename columns based on a mapping
  result = newDataTable()
  
  # Add columns with new names
  for (oldName, newName) in mapping:
    if oldName in dt.columns:
      result.addColumn(newName, dt.columns[oldName])
  
  # Add remaining columns
  for colName, column in dt.columns:
    var found = false
    for (oldName, _) in mapping:
      if colName == oldName:
        found = true
        break
    
    if not found:
      result.addColumn(colName, column)
  
  result.rowCount = dt.rowCount

proc transform*(dt: DataTable, columns: openArray[string], transformation: proc(values: seq[string]): seq[string]): DataTable =
  ## Apply a transformation to specific columns
  result = dt
  
  # Apply transformation to each specified column
  for colName in columns:
    if colName in dt.columns:
      result.columns[colName] = transformation(dt.columns[colName])

proc addComputedColumn*(dt: var DataTable, newColumn: string, computation: proc(row: Table[string, string]): string) =
  ## Add a new column based on a computation of existing columns
  var newColumnData = newSeq[string](dt.rowCount)
  
  # Compute values for each row
  for i in 0..<dt.rowCount:
    var row = initTable[string, string]()
    
    # Build row data
    for colName, column in dt.columns:
      row[colName] = if i < column.len: column[i] else: ""
    
    # Apply computation
    newColumnData[i] = computation(row)
  
  # Add the new column
  dt.addColumn(newColumn, newColumnData)

proc groupBy*(dt: DataTable, groupColumns: openArray[string], aggregations: openArray[(string, string, AggregationFunction)]): DataTable =
  ## Group data by specified columns and apply aggregations
  # Each aggregation is a tuple of (column name, new column name, aggregation function)
  result = newDataTable()
  
  # Add group columns to result
  for colName in groupColumns:
    result.addColumn(colName)
  
  # Add aggregation result columns to result
  for (_, newName, _) in aggregations:
    result.addColumn(newName)
  
  # Group data
  var groups = initTable[string, seq[int]]()
  
  for i in 0..<dt.rowCount:
    var key = ""
    for colName in groupColumns:
      if colName in dt.columns and i < dt.columns[colName].len:
        key &= dt.columns[colName][i] & "||"
      else:
        key &= "||"
    
    if key notin groups:
      groups[key] = @[]
    
    groups[key].add(i)
  
  # Process each group
  for key, indices in groups:
    var groupValues = key.split("||")[0..<groupColumns.len]
    var row: seq[(string, string)] = @[]
    
    # Add group column values
    for i, colName in groupColumns:
      row.add((colName, groupValues[i]))
    
    # Apply aggregations
    for (colName, newName, aggFn) in aggregations:
      if colName in dt.columns:
        var values = newSeq[string]()
        for idx in indices:
          if idx < dt.columns[colName].len:
            values.add(dt.columns[colName][idx])
        
        row.add((newName, aggFn(values)))
      else:
        row.add((newName, ""))
    
    result.addRow(row)

proc sortBy*(dt: DataTable, columns: openArray[(string, bool)]): DataTable =
  ## Sort data by specified columns (column name, descending flag)
  result = dt
  
  # Create indices array and sort it
  var indices = toSeq(0..<dt.rowCount)
  
  # Convert columns to a sequence to avoid iterator capture issues
  let colsSeq = @columns
  
  indices.sort(proc(a, b: int): int =
    for (colName, descending) in colsSeq:
      if hasColumn(dt, colName):
        var aVal = getColumnValue(dt, colName, a)
        var bVal = getColumnValue(dt, colName, b)
        
        # Try numeric comparison first
        try:
          let aNum = parseFloat(aVal)
          let bNum = parseFloat(bVal)
          
          let cmp = cmp(aNum, bNum)
          if cmp != 0:
            return if descending: -cmp else: cmp
        except CatchableError:
          # Fall back to string comparison
          let cmp = cmp(aVal, bVal)
          if cmp != 0:
            return if descending: -cmp else: cmp
    
    return 0
  )
  
  # Create new data table with sorted data
  result = newDataTable()
  
  # Add columns
  for colName, column in dt.columns:
    var sortedColumn = newSeq[string](dt.rowCount)
    
    for i, idx in indices:
      sortedColumn[i] = if idx < column.len: column[idx] else: ""
    
    result.addColumn(colName, sortedColumn)
  
  result.rowCount = dt.rowCount

proc melt*(dt: DataTable, idVars: openArray[string], valueVars: openArray[string], varName: string = "variable", valueName: string = "value"): DataTable =
  ## Melt data from wide to long format
  result = newDataTable()
  
  # Add id columns
  for colName in idVars:
    result.addColumn(colName)
  
  # Add variable and value columns
  result.addColumn(varName)
  result.addColumn(valueName)
  
  # Melt the data
  for i in 0..<dt.rowCount:
    # For each row in the original data
    for valueVar in valueVars:
      if valueVar in dt.columns:
        var row: seq[(string, string)] = @[]
        
        # Add id values
        for idVar in idVars:
          if idVar in dt.columns:
            row.add((idVar, if i < dt.columns[idVar].len: dt.columns[idVar][i] else: ""))
        
        # Add variable and value
        row.add((varName, valueVar))
        row.add((valueName, if i < dt.columns[valueVar].len: dt.columns[valueVar][i] else: ""))
        
        result.addRow(row)

proc castData*(dt: DataTable, idVars: openArray[string], varColumn: string, valueColumn: string): DataTable =
  ## Cast data from long to wide format
  result = newDataTable()
  
  # Add id columns
  for colName in idVars:
    if colName in dt.columns:
      result.addColumn(colName)
  
  # Find unique values in the variable column to create new columns
  var uniqueVars: seq[string] = @[]
  if varColumn in dt.columns:
    for i in 0..<dt.rowCount:
      if i < dt.columns[varColumn].len:
        let val = dt.columns[varColumn][i]
        if val notin uniqueVars:
          uniqueVars.add(val)
          result.addColumn(val)
  
  # Group data by id variables
  var groups = initTable[string, seq[int]]()
  
  for i in 0..<dt.rowCount:
    var key = ""
    for colName in idVars:
      if colName in dt.columns and i < dt.columns[colName].len:
        key &= dt.columns[colName][i] & "||"
      else:
        key &= "||"
    
    if key notin groups:
      groups[key] = @[]
    
    groups[key].add(i)
  
  # Process each group
  for key, indices in groups:
    var idValues = key.split("||")[0..<idVars.len]
    var row: seq[(string, string)] = @[]
    
    # Add id values
    for i, colName in idVars:
      row.add((colName, idValues[i]))
    
    # Initialize value columns with empty strings
    for varName in uniqueVars:
      row.add((varName, ""))
    
    # Fill in values
    for idx in indices:
      if idx < dt.columns[varColumn].len and idx < dt.columns[valueColumn].len:
        let varName = dt.columns[varColumn][idx]
        let value = dt.columns[valueColumn][idx]
        
        # Update the value in the row
        for i in idVars.len..<row.len:
          if row[i][0] == varName:
            row[i] = (varName, value)
            break
    
    result.addRow(row)

proc join*(left: DataTable, right: DataTable, by: openArray[string], joinType: string = "inner"): DataTable =
  ## Join two data tables based on common columns
  ## joinType can be "inner", "left", "right", or "full"
  result = newDataTable()
  
  # Add all columns from left table
  for colName in left.columns.keys:
    result.addColumn(colName)
  
  # Add columns from right table (except join columns)
  for colName in right.columns.keys:
    if colName notin by:
      result.addColumn(colName)
  
  # Create indices for joining
  var rightIndices = initTable[string, seq[int]]()
  
  for i in 0..<right.rowCount:
    var key = ""
    for colName in by:
      if colName in right.columns and i < right.columns[colName].len:
        key &= right.columns[colName][i] & "||"
      else:
        key &= "||"
    
    if key notin rightIndices:
      rightIndices[key] = @[]
    
    rightIndices[key].add(i)
  
  # Process each row in left table
  for i in 0..<left.rowCount:
    var key = ""
    for colName in by:
      if colName in left.columns and i < left.columns[colName].len:
        key &= left.columns[colName][i] & "||"
      else:
        key &= "||"
    
    # Find matching rows in right table
    if key in rightIndices:
      for rightIdx in rightIndices[key]:
        var row: seq[(string, string)] = @[]
        
        # Add left values
        for colName in left.columns.keys:
          row.add((colName, if i < left.columns[colName].len: left.columns[colName][i] else: ""))
        
        # Add right values (except join columns)
        for colName in right.columns.keys:
          if colName notin by:
            row.add((colName, if rightIdx < right.columns[colName].len: right.columns[colName][rightIdx] else: ""))
        
        result.addRow(row)
    elif joinType in ["left", "full"]:
      # Left join - include left row with NULL right values
      var row: seq[(string, string)] = @[]
      
      # Add left values
      for colName in left.columns.keys:
        row.add((colName, if i < left.columns[colName].len: left.columns[colName][i] else: ""))
      
      # Add empty right values
      for colName in right.columns.keys:
        if colName notin by:
          row.add((colName, ""))
      
      result.addRow(row)
  
  # For right and full joins, add right rows that didn't match
  if joinType in ["right", "full"]:
    var processedKeys = initHashSet[string]()
    
    # Process left keys first to avoid duplicates
    for i in 0..<left.rowCount:
      var key = ""
      for colName in by:
        if colName in left.columns and i < left.columns[colName].len:
          key &= left.columns[colName][i] & "||"
        else:
          key &= "||"
      
      processedKeys.incl(key)
    
    # Add right rows with no match
    for key, indices in rightIndices:
      if key notin processedKeys:
        for rightIdx in indices:
          var row: seq[(string, string)] = @[]
          
          # Add empty left values (except join columns)
          for colName in left.columns.keys:
            if colName in by:
              # Extract join column value from key
              let keyParts = key.split("||")
              let byIndex = by.find(colName)
              if byIndex >= 0 and byIndex < keyParts.len:
                row.add((colName, keyParts[byIndex]))
            else:
              row.add((colName, ""))
          
          # Add right values
          for colName in right.columns.keys:
            if colName notin by:
              row.add((colName, if rightIdx < right.columns[colName].len: right.columns[colName][rightIdx] else: ""))
          
          result.addRow(row)

when isMainModule:
  # Example usage
  var dt = newDataTable()
  dt.addColumn("Region", @["North", "South", "East", "West", "North", "South", "East", "West"])
  dt.addColumn("Product", @["Apples", "Apples", "Apples", "Apples", "Bananas", "Bananas", "Bananas", "Bananas"])
  dt.addColumn("Sales", @["100", "150", "200", "120", "300", "200", "150", "250"])
  dt.addColumn("Units", @["10", "15", "20", "12", "30", "20", "15", "25"])
  
  echo "Original data:"
  echo dt
  
  echo "\nFiltered data (Sales > 150):"
  let filtered = dt.filter(proc(row: Table[string, string]): bool = 
    try:
      return parseFloat(row["Sales"]) > 150.0
    except:
      return false
  )
  echo filtered
  
  echo "\nSelected columns (Region, Sales):"
  let selected = dt.select(["Region", "Sales"])
  echo selected
  
  echo "\nRenamed columns (Sales -> Revenue):"
  let renamed = dt.rename([("Sales", "Revenue")])
  echo renamed
  
  echo "\nData with computed column (Revenue per Unit):"
  var dtWithComputed = dt
  dtWithComputed.addComputedColumn("RevPerUnit", proc(row: Table[string, string]): string =
    try:
      let sales = parseFloat(row["Sales"])
      let units = parseFloat(row["Units"])
      return $(sales / units)
    except:
      return "0"
  )
  echo dtWithComputed
  
  echo "\nGrouped data (by Region):"
  let grouped = dt.groupBy(["Region"], [("Sales", "TotalSales", sum), ("Units", "TotalUnits", sum)])
  echo grouped
  
  echo "\nSorted data (by Sales, descending):"
  let sorted = dt.sortBy([("Sales", true)])
  echo sorted
  
  echo "\nMelted data:"
  let melted = dt.melt(["Region", "Product"], ["Sales", "Units"])
  echo melted
  
  echo "\nCast data:"
  let casted = melted.castData(["Region", "Product"], "variable", "value")
  echo casted
