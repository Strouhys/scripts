param(
  [string]$InputCsv = ".\ep_opr.MAN_TABLE_RETENTION.csv",
  [string]$OutputSql = ".\sql\retention_seed_from_teradata.sql",
  [string]$ReviewCsv = ".\sql\retention_seed_manual_review.csv",
  [string]$ProjectId = "o2czed1",
  [int]$WeeklyRunDay = 6
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Escape-SqlString([string]$Value) {
  if ($null -eq $Value) { return "NULL" }
  # BigQuery string literals use backslash escapes in this script context.
  $v = $Value.Replace("\", "\\")
  $v = $v.Replace("'", "\'")
  return "'" + $v + "'"
}

function Norm([string]$Value) {
  if ($null -eq $Value) { return "" }
  return $Value.Trim()
}

function To-BoolLiteral([string]$Value) {
  $v = (Norm $Value).ToUpperInvariant()
  if ($v -eq "1" -or $v -eq "Y" -or $v -eq "TRUE") { return "TRUE" }
  return "FALSE"
}

function To-Frequency([string]$Value) {
  $v = (Norm $Value).ToUpperInvariant()
  if ($v.Length -eq 0) { return "D" }
  $f = $v.Substring(0,1)
  if ($f -in @("D","W","M")) { return $f }
  return "D"
}

function Sanitize-Id([string]$Value) {
  $v = (Norm $Value).ToUpperInvariant()
  $v = $v -replace "[^A-Z0-9_]", "_"
  return $v
}

function Convert-TeradataWhere([string]$WhereClause) {
  $w = Norm $WhereClause
  if ([string]::IsNullOrWhiteSpace($w)) {
    return [pscustomobject]@{
      Type = "CUSTOM_SQL"
      Column = $null
      RetentionValue = $null
      RetentionUnit = $null
      ColumnDataType = $null
      BoundaryMode = "CUSTOM"
      BqWhere = $null
      Reason = "empty_where"
    }
  }

  $lower = $w.ToLowerInvariant()

  # Skip explicit no-delete rules to custom/manual review.
  if ($lower.Contains("nemazat")) {
    return [pscustomobject]@{
      Type = "CUSTOM_SQL"
      Column = $null
      RetentionValue = $null
      RetentionUnit = $null
      ColumnDataType = $null
      BoundaryMode = "CUSTOM"
      BqWhere = $null
      Reason = "contains_nemazat"
    }
  }

  # Simple pattern: <column> < ... $$LOAD_DTTM ... INTERVAL 'N' (DAY|MONTH|YEAR)
  $rx = [regex]'(?is)^\s*([A-Za-z_][A-Za-z0-9_]*)\s*<.*\$\$LOAD_DTTM.*INTERVAL\s*''([0-9]+)''\s*(DAY|MONTH|YEAR).*$'
  $m = $rx.Match($w)

  $hasComplexTokens = (
    $lower.Contains(" or ") -or
    $lower.Contains("select ") -or
    $lower.Contains("add_months") -or
    $lower.Contains("current_date") -or
    $lower.Contains("format '")
  )

  if ($m.Success -and -not $hasComplexTokens) {
    $col = $m.Groups[1].Value
    $retVal = [int]$m.Groups[2].Value
    $retUnit = $m.Groups[3].Value.ToUpperInvariant()
    $bq = "$col < TIMESTAMP_SUB(TIMESTAMP(@retention_reference_dttm), INTERVAL $retVal $retUnit)"

    return [pscustomobject]@{
      Type = "COLUMN_AGE"
      Column = $col
      RetentionValue = $retVal
      RetentionUnit = $retUnit
      ColumnDataType = "TIMESTAMP"
      BoundaryMode = "LOAD_DTTM"
      BqWhere = $bq
      Reason = "auto_column_age"
    }
  }

  # Conservative fallback for custom expressions.
  $bqFallback = $w -replace '\$\$LOAD_DTTM', '@retention_reference_dttm'

  return [pscustomobject]@{
    Type = "CUSTOM_SQL"
    Column = $null
    RetentionValue = $null
    RetentionUnit = $null
    ColumnDataType = $null
    BoundaryMode = "CUSTOM"
    BqWhere = $bqFallback
    Reason = "manual_review"
  }
}

$rows = Import-Csv -Path $InputCsv -Delimiter ';'

$manualReview = New-Object System.Collections.Generic.List[object]
$sqlLines = New-Object System.Collections.Generic.List[string]

$sqlLines.Add("-- Generated from ep_opr.MAN_TABLE_RETENTION.csv")
$sqlLines.Add("-- Source row count: $($rows.Count)")
$sqlLines.Add("-- Project: $ProjectId")
$sqlLines.Add("")
$sqlLines.Add("INSERT INTO `o2czed1.opr_data.table_retention` (")
$sqlLines.Add("  retention_rule_id,")
$sqlLines.Add("  project_id,")
$sqlLines.Add("  dataset_name,")
$sqlLines.Add("  table_name,")
$sqlLines.Add("  is_active,")
$sqlLines.Add("  execution_frequency,")
$sqlLines.Add("  execution_day_of_week,")
$sqlLines.Add("  execution_day_of_month,")
$sqlLines.Add("  execution_schedule,")
$sqlLines.Add("  retention_type,")
$sqlLines.Add("  retention_column,")
$sqlLines.Add("  retention_value,")
$sqlLines.Add("  retention_unit,")
$sqlLines.Add("  column_data_type,")
$sqlLines.Add("  boundary_mode,")
$sqlLines.Add("  source_execution_where_clause,")
$sqlLines.Add("  bq_execution_where_clause,")
$sqlLines.Add("  end_column,")
$sqlLines.Add("  operation_column,")
$sqlLines.Add("  delete_operation_value,")
$sqlLines.Add("  source_time_column,")
$sqlLines.Add("  retention_comment,")
$sqlLines.Add("  created_by,")
$sqlLines.Add("  updated_by")
$sqlLines.Add(")")
$sqlLines.Add("VALUES")

$idx = 0
foreach ($r in $rows) {
  $idx++

  $dataset = Norm $r.database_name
  $table = Norm $r.table_name
  $freq = To-Frequency $r.execution_frequency
  $isActive = To-BoolLiteral $r.is_active

  $conv = Convert-TeradataWhere $r.execution_where_clause

  $ruleId = "TD_" + (Sanitize-Id $dataset) + "_" + (Sanitize-Id $table) + "_" + $idx.ToString("D5")

  $executionDayOfWeek = if ($freq -eq "W") { "$WeeklyRunDay" } else { "NULL" }
  $executionDayOfMonth = "NULL"
  $executionSchedule = "NULL"

  $retentionColumn = if ($null -eq $conv.Column) { "NULL" } else { Escape-SqlString $conv.Column }
  $retentionValue = if ($null -eq $conv.RetentionValue) { "NULL" } else { [string]$conv.RetentionValue }
  $retentionUnit = if ($null -eq $conv.RetentionUnit) { "NULL" } else { Escape-SqlString $conv.RetentionUnit }
  $columnDataType = if ($null -eq $conv.ColumnDataType) { "NULL" } else { Escape-SqlString $conv.ColumnDataType }
  $bqWhere = if ([string]::IsNullOrWhiteSpace($conv.BqWhere)) { "NULL" } else { Escape-SqlString $conv.BqWhere }

  $fields = @(
    (Escape-SqlString $ruleId),
    (Escape-SqlString $ProjectId),
    (Escape-SqlString $dataset),
    (Escape-SqlString $table),
    $isActive,
    (Escape-SqlString $freq),
    $executionDayOfWeek,
    $executionDayOfMonth,
    $executionSchedule,
    (Escape-SqlString $conv.Type),
    $retentionColumn,
    $retentionValue,
    $retentionUnit,
    $columnDataType,
    (Escape-SqlString $conv.BoundaryMode),
    (Escape-SqlString (Norm $r.execution_where_clause)),
    $bqWhere,
    "NULL",
    "NULL",
    "NULL",
    "NULL",
    (Escape-SqlString (Norm $r.retention_comment)),
    (Escape-SqlString "migration_ep_opr_man_table_retention_csv"),
    (Escape-SqlString "migration_ep_opr_man_table_retention_csv")
  )

  $line = "(" + ($fields -join ", ") + ")"

  if ($idx -lt $rows.Count) {
    $sqlLines.Add($line + ",")
  } else {
    $sqlLines.Add($line + ";")
  }

  if ($conv.Type -eq "CUSTOM_SQL") {
    $manualReview.Add([pscustomobject]@{
      retention_rule_id = $ruleId
      dataset_name = $dataset
      table_name = $table
      execution_frequency = $freq
      reason = $conv.Reason
      source_execution_where_clause = (Norm $r.execution_where_clause)
      bq_execution_where_clause = if ($null -eq $conv.BqWhere) { "" } else { $conv.BqWhere }
      retention_comment = (Norm $r.retention_comment)
    })
  }
}

Set-Content -Path $OutputSql -Value $sqlLines -Encoding UTF8
$manualReview | Export-Csv -Path $ReviewCsv -Delimiter ';' -NoTypeInformation -Encoding UTF8

Write-Output "Generated SQL: $OutputSql"
Write-Output "Generated manual review CSV: $ReviewCsv"
Write-Output "Total source rows: $($rows.Count)"
Write-Output "Rows flagged for manual review: $($manualReview.Count)"
