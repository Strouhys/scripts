param(
  [string]$InputFile = ".\sql\retention_seed_from_teradata.sql",
  [string]$OutputFile1 = ".\sql\retention_seed_from_teradata_part1.sql",
  [string]$OutputFile2 = ".\sql\retention_seed_from_teradata_part2.sql"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path $InputFile)) {
  throw "Input file not found: $InputFile"
}

$raw = Get-Content -Path $InputFile
$valuesMatch = $raw | Select-String -Pattern '^VALUES\s*$'
if (-not $valuesMatch) {
  throw "VALUES line not found in $InputFile"
}

$valuesIdx = $valuesMatch[0].LineNumber - 1
$header = $raw[0..$valuesIdx]
$tail = $raw[($valuesIdx + 1)..($raw.Count - 1)]

# Parse value blocks by real row starts: each row starts with "(" at line start.
$rows = New-Object System.Collections.Generic.List[string]
$current = ""

foreach ($lineRaw in $tail) {
  $line = $lineRaw.TrimEnd()
  if ([string]::IsNullOrWhiteSpace($line)) { continue }

  if ($line -match '^\(') {
    if ($current.Length -gt 0) {
      $rows.Add($current)
    }
    $current = $line
  } else {
    if ($current.Length -eq 0) {
      continue
    }
    $current = $current + " " + $line.TrimStart()
  }
}
if ($current.Length -gt 0) {
  $rows.Add($current)
}

# Normalize trailing delimiter from each full row block.
$normalized = New-Object System.Collections.Generic.List[string]
foreach ($r in $rows) {
  $v = $r.TrimEnd()
  if ($v.EndsWith(';')) { $v = $v.Substring(0, $v.Length - 1) }
  if ($v.EndsWith(',')) { $v = $v.Substring(0, $v.Length - 1) }
  $normalized.Add($v)
}

$total = $normalized.Count
if ($total -lt 2) {
  throw "Not enough rows to split: $total"
}

$split = [int][Math]::Ceiling($total / 2.0)
$part1 = $normalized.GetRange(0, $split)
$part2 = $normalized.GetRange($split, $total - $split)

function Write-SqlPart {
  param(
    [string]$Path,
    [string[]]$HeaderLines,
    [System.Collections.Generic.List[string]]$ValueRows
  )

  $out = New-Object System.Collections.Generic.List[string]
  foreach ($h in $HeaderLines) { $out.Add($h) }

  for ($i = 0; $i -lt $ValueRows.Count; $i++) {
    if ($i -lt $ValueRows.Count - 1) {
      $out.Add($ValueRows[$i] + ',')
    } else {
      $out.Add($ValueRows[$i] + ';')
    }
  }

  Set-Content -Path $Path -Value $out -Encoding UTF8
}

Write-SqlPart -Path $OutputFile1 -HeaderLines $header -ValueRows $part1
Write-SqlPart -Path $OutputFile2 -HeaderLines $header -ValueRows $part2

Write-Output "Parsed rows: $total"
Write-Output "Part1 rows: $($part1.Count)"
Write-Output "Part2 rows: $($part2.Count)"
Write-Output "Part1 file: $OutputFile1"
Write-Output "Part2 file: $OutputFile2"
