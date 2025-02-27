# nivotlib/viz.nim
# Visualization functionality for Nivot pivot library

import strutils, algorithm, math, tables, unicode
import ../nivot  # Import the main library

proc formatCell(value: string, width: int): string =
  ## Format a cell to a specified width
  let val = value.strip()
  if val.runeLen > width:
    result = val.runeSubStr(0, width - 3) & "..."
  else:
    result = val & repeat(" ", width - val.runeLen)

proc getColumnWidths(dt: DataTable, minWidth: int = 10, maxWidth: int = 30): seq[int] =
  ## Calculate appropriate column widths for a data table
  result = newSeq[int](dt.columns.len)
  var i = 0
  
  for colName, column in dt.columns:
    var maxLen = colName.runeLen
    
    for value in column:
      maxLen = max(maxLen, value.runeLen)
    
    result[i] = min(max(maxLen + 2, minWidth), maxWidth)
    i += 1

proc drawTable*(dt: DataTable): string =
  ## Draws a table with borders and formatted cells
  result = ""
  
  var headers: seq[string] = @[]
  var colWidths = getColumnWidths(dt)
  
  # Generate headers
  var i = 0
  for colName in dt.columns.keys:
    headers.add(colName)
    i += 1
  
  # Top border
  result.add("+")
  for i, width in colWidths:
    result.add(repeat("-", width))
    if i < colWidths.len - 1:
      result.add("+")
  result.add("+\n")
  
  # Headers
  result.add("|")
  for i, header in headers:
    result.add(formatCell(header, colWidths[i]))
    if i < headers.len - 1:
      result.add("|")
  result.add("|\n")
  
  # Header-data separator
  result.add("+")
  for i, width in colWidths:
    result.add(repeat("-", width))
    if i < colWidths.len - 1:
      result.add("+")
  result.add("+\n")
  
  # Data rows
  for rowIdx in 0..<dt.rowCount:
    result.add("|")
    
    for i, colName in headers:
      let value = if rowIdx < dt.columns[colName].len: dt.columns[colName][rowIdx] else: ""
      result.add(formatCell(value, colWidths[i]))
      
      if i < headers.len - 1:
        result.add("|")
    
    result.add("|\n")
  
  # Bottom border
  result.add("+")
  for i, width in colWidths:
    result.add(repeat("-", width))
    if i < colWidths.len - 1:
      result.add("+")
  result.add("+\n")

proc drawBarChart*(dt: DataTable, labelCol: string, valueCol: string, maxWidth: int = 60): string =
  ## Draw a simple horizontal bar chart
  result = ""
  
  # Check if columns exist
  if labelCol notin dt.columns or valueCol notin dt.columns:
    return "Error: Columns not found"
  
  # Find the maximum value
  var maxVal = 0.0
  for i in 0..<dt.rowCount:
    if i < dt.columns[valueCol].len:
      try:
        let val = parseFloat(dt.columns[valueCol][i])
        maxVal = max(maxVal, val)
      except:
        discard
  
  # Calculate scaling factor
  let scale = if maxVal > 0: (maxWidth - 10).float / maxVal else: 0.0
  
  # Calculate label width
  var labelWidth = labelCol.len
  for i in 0..<dt.rowCount:
    if i < dt.columns[labelCol].len:
      labelWidth = max(labelWidth, dt.columns[labelCol][i].runeLen)
  
  # Draw title
  result.add(valueCol & " by " & labelCol & "\n")
  result.add(repeat("=", valueCol.len + labelCol.len + 4) & "\n\n")
  
  # Draw bars
  for i in 0..<dt.rowCount:
    if i >= dt.columns[labelCol].len or i >= dt.columns[valueCol].len:
      continue
    
    let label = dt.columns[labelCol][i]
    let valueStr = dt.columns[valueCol][i]
    
    try:
      let value = parseFloat(valueStr)
      let barWidth = int(value * scale)
      
      result.add(formatCell(label, labelWidth))
      result.add(" | ")
      result.add(repeat("*", barWidth))
      result.add(" ")
      result.add(valueStr)
      result.add("\n")
    except:
      continue
  
  result.add("\n")

type ChartType* = enum
  Line, Scatter

proc drawLineChart*(
  dt: DataTable, 
  xCol: string, 
  yCol: string, 
  width: int = 60, 
  height: int = 20,
  chartType: ChartType = Line
): string =
  ## Draw a simple ASCII line or scatter chart
  result = ""
  
  # Check if columns exist
  if xCol notin dt.columns or yCol notin dt.columns:
    return "Error: Columns not found"
  
  # Parse data
  var points: seq[(float, float)] = @[]
  for i in 0..<dt.rowCount:
    if i < dt.columns[xCol].len and i < dt.columns[yCol].len:
      try:
        let x = parseFloat(dt.columns[xCol][i])
        let y = parseFloat(dt.columns[yCol][i])
        points.add((x, y))
      except:
        discard
  
  if points.len == 0:
    return "Error: No valid data points"
  
  # Find min/max values
  var minX, maxX, minY, maxY: float
  minX = points[0][0]
  maxX = points[0][0]
  minY = points[0][1]
  maxY = points[0][1]
  
  for (x, y) in points:
    minX = min(minX, x)
    maxX = max(maxX, x)
    minY = min(minY, y)
    maxY = max(maxY, y)
  
  # Add some padding
  let rangeX = maxX - minX
  let rangeY = maxY - minY
  minX -= rangeX * 0.05
  maxX += rangeX * 0.05
  minY -= rangeY * 0.05
  maxY += rangeY * 0.05
  
  # Scale factors
  let scaleX = if maxX > minX: (width - 1).float / (maxX - minX) else: 1.0
  let scaleY = if maxY > minY: (height - 1).float / (maxY - minY) else: 1.0
  
  # Create grid
  var grid = newSeq[seq[char]](height)
  for y in 0..<height:
    grid[y] = newSeq[char](width)
    for x in 0..<width:
      grid[y][x] = ' '
  
  # Draw axes
  let originX = clamp(int((0 - minX) * scaleX), 0, width - 1)
  let originY = height - 1 - clamp(int((0 - minY) * scaleY), 0, height - 1)
  
  for y in 0..<height:
    grid[y][originX] = '|'
  
  for x in 0..<width:
    grid[originY][x] = '-'
  
  if originX >= 0 and originX < width and originY >= 0 and originY < height:
    grid[originY][originX] = '+'
  
  # Plot points or line
  if chartType == Scatter:
    # Scatter plot
    for (x, y) in points:
      let plotX = int((x - minX) * scaleX)
      let plotY = height - 1 - int((y - minY) * scaleY)
      
      if plotX >= 0 and plotX < width and plotY >= 0 and plotY < height:
        grid[plotY][plotX] = '*'
  else:
    # Line chart
    # Sort points by x value
    points.sort(proc (a, b: (float, float)): int = 
      if a[0] < b[0]: -1 
      elif a[0] > b[0]: 1 
      else: 0
    )
    
    for i in 1..<points.len:
      let x1 = int((points[i-1][0] - minX) * scaleX)
      let y1 = height - 1 - int((points[i-1][1] - minY) * scaleY)
      let x2 = int((points[i][0] - minX) * scaleX)
      let y2 = height - 1 - int((points[i][1] - minY) * scaleY)
      
      # Simple line drawing
      if x1 == x2:
        let startY = min(y1, y2)
        let endY = max(y1, y2)
        for y in startY..endY:
          if y >= 0 and y < height and x1 >= 0 and x1 < width:
            grid[y][x1] = '|'
      elif y1 == y2:
        let startX = min(x1, x2)
        let endX = max(x1, x2)
        for x in startX..endX:
          if x >= 0 and x < width and y1 >= 0 and y1 < height:
            grid[y1][x] = '-'
      else:
        # Bresenham's line algorithm
        let dx = abs(x2 - x1)
        let dy = abs(y2 - y1)
        let sx = if x1 < x2: 1 else: -1
        let sy = if y1 < y2: 1 else: -1
        var err = (if dx > dy: dx else: -dy) div 2
        var x = x1
        var y = y1
        
        while true:
          if x >= 0 and x < width and y >= 0 and y < height:
            grid[y][x] = if dx > dy: '-' else: '|'
          
          if x == x2 and y == y2:
            break
          
          let e2 = err
          if e2 > -dx:
            err -= dy
            x += sx
          if e2 < dy:
            err += dx
            y += sy
  
  # Draw the grid
  result.add(yCol & " vs " & xCol & "\n")
  result.add(repeat("=", yCol.len + xCol.len + 4) & "\n\n")
  
  for y in 0..<height:
    var row = ""
    for x in 0..<width:
      row.add(grid[y][x])
    result.add(row & "\n")
  
  # Add legend
  result.add("\n")
  result.add("X-axis: " & xCol & " (" & $minX & " to " & $maxX & ")\n")
  result.add("Y-axis: " & yCol & " (" & $minY & " to " & $maxY & ")\n")

when isMainModule:
  import random
  
  # Example usage
  var dt = newDataTable()
  dt.addColumn("Category", @["A", "B", "C", "D", "E"])
  dt.addColumn("Value", @["10", "25", "15", "30", "20"])
  
  # Create time series data
  var tsData = newDataTable()
  tsData.addColumn("Time", newSeq[string](20))
  tsData.addColumn("Value", newSeq[string](20))
  
  for i in 0..<20:
    tsData.columns["Time"][i] = $i
    tsData.columns["Value"][i] = $(rand(100))
  
  echo "Table visualization:"
  echo drawTable(dt)
  
  echo "\nBar chart:"
  echo drawBarChart(dt, "Category", "Value")
  
  echo "\nLine chart:"
  echo drawLineChart(tsData, "Time", "Value")
