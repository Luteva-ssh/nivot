# nivotlib/io.nim
# Input/Output functionality for Nivot pivot library

import strutils, tables, parsecsv, streams, json
import ../nivot  # Import the main library

proc loadFromCsv*(filename: string, separator: char = ','): DataTable =
  ## Loads data from a CSV file into a DataTable
  var dt = newDataTable()
  var p: CsvParser
  var file = newFileStream(filename, fmRead)
  
  if file == nil:
    raise newException(IOError, "Cannot open file: " & filename)
  
  p.open(file, filename, separator=separator)
  defer: p.close()
  
  # Read header
  if p.readRow():
    var headers: seq[string] = @[]
    for i in 0..<p.row.len:
      headers.add(p.row[i])
      dt.addColumn(p.row[i])
    
    # Read rows
    while p.readRow():
      var row: seq[(string, string)] = @[]
      for i in 0..<min(p.row.len, headers.len):
        row.add((headers[i], p.row[i]))
      
      dt.addRow(row)
  
  return dt

proc saveToCsv*(dt: DataTable, filename: string, separator: char = ',') =
  ## Saves a DataTable to a CSV file
  var file = open(filename, fmWrite)
  defer: file.close()
  
  # Write header
  var headers: seq[string] = @[]
  for colName in dt.columns.keys:
    headers.add(colName)
  
  file.writeLine(headers.join($separator))
  
  # Write rows
  for i in 0..<dt.rowCount:
    var row: seq[string] = @[]
    for colName in headers:
      if colName in dt.columns and i < dt.columns[colName].len:
        row.add(dt.columns[colName][i])
      else:
        row.add("")
    
    file.writeLine(row.join($separator))

proc loadFromJson*(filename: string): DataTable =
  ## Loads data from a JSON file into a DataTable
  var dt = newDataTable()
  
  let jsonStr = readFile(filename)
  let jsonNode = parseJson(jsonStr)
  
  # Expect an array of objects
  if jsonNode.kind != JArray:
    raise newException(ValueError, "JSON must be an array of objects")
  
  # First, collect all possible keys
  var keys: seq[string] = @[]
  for item in jsonNode:
    if item.kind == JObject:
      for key in item.keys:
        if key notin keys:
          keys.add(key)
  
  # Initialize columns
  for key in keys:
    dt.addColumn(key)
  
  # Add data
  for item in jsonNode:
    if item.kind == JObject:
      var row: seq[(string, string)] = @[]
      for key in keys:
        if key in item:
          var value = ""
          case item[key].kind
          of JString:
            value = item[key].getStr()
          of JInt:
            value = $item[key].getInt()
          of JFloat:
            value = $item[key].getFloat()
          of JBool:
            value = $item[key].getBool()
          of JNull:
            value = ""
          else:
            value = $item[key]
          
          row.add((key, value))
        else:
          row.add((key, ""))
      
      dt.addRow(row)
  
  return dt

proc saveToJson*(dt: DataTable, filename: string, pretty: bool = true) =
  ## Saves a DataTable to a JSON file
  var jsonArray = newJArray()
  
  # Convert to array of objects
  for i in 0..<dt.rowCount:
    var obj = newJObject()
    
    for colName, column in dt.columns:
      if i < column.len:
        let value = column[i]
        # Try to convert to appropriate JSON types
        try:
          let floatVal = parseFloat(value)
          obj[colName] = %floatVal
        except:
          try:
            let intVal = parseInt(value)
            obj[colName] = %intVal
          except:
            if value.toLowerAscii() == "true":
              obj[colName] = %true
            elif value.toLowerAscii() == "false":
              obj[colName] = %false
            else:
              obj[colName] = %value
      else:
        obj[colName] = newJNull()
    
    jsonArray.add(obj)
  
  # Write to file
  let jsonStr = if pretty: pretty(jsonArray) else: $jsonArray
  writeFile(filename, jsonStr)

when isMainModule:
  # Example usage
  var dt = newDataTable()
  dt.addColumn("Region", @["North", "South", "East", "West", "North", "South", "East", "West"])
  dt.addColumn("Product", @["Apples", "Apples", "Apples", "Apples", "Bananas", "Bananas", "Bananas", "Bananas"])
  dt.addColumn("Sales", @["100", "150", "200", "120", "300", "200", "150", "250"])
  
  # Save to CSV and JSON
  dt.saveToCsv("example.csv")
  dt.saveToJson("example.json")
  
  # Load from CSV and JSON
  let dtFromCsv = loadFromCsv("example.csv")
  let dtFromJson = loadFromJson("example.json")
  
  echo "Original Data:"
  echo dt
  
  echo "\nData loaded from CSV:"
  echo dtFromCsv
  
  echo "\nData loaded from JSON:"
  echo dtFromJson
