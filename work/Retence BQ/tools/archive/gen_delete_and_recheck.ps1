$base='c:\Users\x0577063\scripts\work\Retence BQ'
$xlsx=(Get-ChildItem -Path $base -Filter '*.xlsx' | Select-Object -First 1).FullName
$csv=Join-Path $base 'o2czed1.opr_data.table_retention_16.7.2026.csv'
$outDelete=Join-Path $base 'sql\retention_delete_nonexisting_tables.sql'
$outFix=Join-Path $base 'sql\retention_syntax_fix_candidates_after_delete.sql'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=[System.IO.Compression.ZipFile]::OpenRead($xlsx)
$shared=@()
$ss=$zip.Entries | Where-Object FullName -eq 'xl/sharedStrings.xml'
$sr=[IO.StreamReader]::new($ss.Open())
$ssx=[xml]$sr.ReadToEnd()
$sr.Close()
foreach($si in $ssx.sst.si){
  if($si.t){
    $shared += [string]$si.t
  } elseif($si.r){
    $parts=@()
    foreach($r in $si.r){ $parts += [string]$r.t }
    $shared += ($parts -join '')
  } else {
    $shared += ''
  }
}

$s1=$zip.Entries | Where-Object FullName -eq 'xl/worksheets/sheet1.xml'
$sr2=[IO.StreamReader]::new($s1.Open())
$sx=[xml]$sr2.ReadToEnd()
$sr2.Close()
$zip.Dispose()

$ns=[System.Xml.XmlNamespaceManager]::new($sx.NameTable)
$ns.AddNamespace('x','http://schemas.openxmlformats.org/spreadsheetml/2006/main')
$rows=$sx.SelectNodes('//x:sheetData/x:row',$ns)

$missingPairs=[System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach($row in $rows){
  $cells=$row.SelectNodes('x:c',$ns)
  if($cells.Count -lt 3){ continue }
  $vals=@()
  foreach($c in $cells){
    $t=$c.GetAttribute('t')
    $v=$c.SelectSingleNode('x:v',$ns)
    if($null -eq $v){ $vals += ''; continue }
    $raw=$v.InnerText
    if($t -eq 's'){
      $vals += $shared[[int]$raw]
    } else {
      $vals += $raw
    }
  }

  $ds=([string]$vals[0]).Trim()
  $tb=([string]$vals[1]).Trim()
  $st=([string]$vals[2]).Trim()

  if($ds -and $tb -and $ds -ne 'database_name' -and $st -match '(?i)NEEXISTUJE'){
    [void]$missingPairs.Add(($ds.ToUpper() + '|' + $tb.ToUpper()))
  }
}

$ret=Import-Csv $csv
$toDelete=@($ret | Where-Object { $missingPairs.Contains(($_.source_dataset_name.ToUpper() + '|' + $_.table_name.ToUpper())) })
$rem=@($ret | Where-Object { -not $missingPairs.Contains(($_.source_dataset_name.ToUpper() + '|' + $_.table_name.ToUpper())) })

# delete script
$deleteLines=@()
$deleteLines += '-- Delete retention rules for tables marked as NEEXISTUJE in neexistuji.xlsx'
$deleteLines += '-- Generated: 2026-07-16'
$deleteLines += ''
$deleteLines += 'CREATE TEMP TABLE to_delete AS'
$deleteLines += 'SELECT DISTINCT source_dataset_name, table_name FROM UNNEST(['
$pairs=@($toDelete | Select-Object source_dataset_name,table_name -Unique | Sort-Object source_dataset_name,table_name)
for($i=0; $i -lt $pairs.Count; $i++){
  $ds=$pairs[$i].source_dataset_name.Replace("'","''")
  $tb=$pairs[$i].table_name.Replace("'","''")
  $comma = if($i -lt ($pairs.Count-1)){','} else {''}
  $deleteLines += "  STRUCT('$ds' AS source_dataset_name, '$tb' AS table_name)$comma"
}
$deleteLines += ']);'
$deleteLines += ''
$deleteLines += 'SELECT COUNT(*) AS candidate_rows_to_delete'
$deleteLines += 'FROM `o2czed1.opr_data.table_retention` r'
$deleteLines += 'JOIN to_delete d'
$deleteLines += '  ON UPPER(r.source_dataset_name) = UPPER(d.source_dataset_name)'
$deleteLines += ' AND UPPER(r.table_name) = UPPER(d.table_name);'
$deleteLines += ''
$deleteLines += 'DELETE FROM `o2czed1.opr_data.table_retention` r'
$deleteLines += 'WHERE EXISTS ('
$deleteLines += '  SELECT 1'
$deleteLines += '  FROM to_delete d'
$deleteLines += '  WHERE UPPER(r.source_dataset_name) = UPPER(d.source_dataset_name)'
$deleteLines += '    AND UPPER(r.table_name) = UPPER(d.table_name)'
$deleteLines += ');'
$deleteLines += ''
$deleteLines += 'SELECT COUNT(*) AS remaining_rows FROM `o2czed1.opr_data.table_retention`;'
Set-Content -Path $outDelete -Value ($deleteLines -join "`r`n") -Encoding UTF8

# issue buckets on remaining set
function Ids($filter){ @($rem | Where-Object $filter | Select-Object -ExpandProperty retention_rule_id | Sort-Object -Unique) }
$empty = Ids { $_.retention_type -eq 'CUSTOM_SQL' -and [string]::IsNullOrWhiteSpace($_.bq_execution_where_clause) }
$retence = Ids { $_.retention_type -eq 'CUSTOM_SQL' -and $_.bq_execution_where_clause -match '(?i)retence\s+se' }
$thisRun = Ids { $_.retention_type -eq 'CUSTOM_SQL' -and $_.bq_execution_where_clause -match '%this\.run_dttm%' }
$brokenDate = Ids { $_.retention_type -eq 'CUSTOM_SQL' -and $_.bq_execution_where_clause -match 'DATE\(@retention_reference_dttm\)\(\)' }
$quoted = Ids { $_.retention_type -eq 'CUSTOM_SQL' -and $_.bq_execution_where_clause -match "'@retention_reference_dttm'" }
$semi = Ids { $_.retention_type -eq 'CUSTOM_SQL' -and $_.bq_execution_where_clause -like '*;*' }

function SqlInList([string[]]$ids){
  if($ids.Count -eq 0){ return "'__NONE__'" }
  return ($ids | ForEach-Object { "'$_'" }) -join ",`r`n  "
}

$fix=@()
$fix += '-- Syntax fix candidates after deleting non-existing tables'
$fix += '-- Generated: 2026-07-16'
$fix += ('-- Remaining rows in snapshot: ' + $rem.Count)
$fix += ('-- Remaining CUSTOM_SQL: ' + (@($rem | Where-Object retention_type -eq 'CUSTOM_SQL').Count))
$fix += ('-- Buckets: empty_bq=' + $empty.Count + ', retence_text=' + $retence.Count + ', this_run_dttm=' + $thisRun.Count + ', broken_date=' + $brokenDate.Count + ', quoted_param=' + $quoted.Count + ', semicolon=' + $semi.Count)
$fix += ''
$fix += '-- 1) Deactivate invalid/no-op clauses'
$fix += 'UPDATE `o2czed1.opr_data.table_retention`'
$fix += 'SET is_active = FALSE, updated_dttm = CURRENT_TIMESTAMP(), updated_by = ''syntax_review_after_delete_2026_07_16'''
$fix += 'WHERE retention_rule_id IN ('
$fix += ('  ' + (SqlInList ($empty + $retence | Sort-Object -Unique)))
$fix += ');'
$fix += ''
$fix += '-- 2) Replace %this.run_dttm% placeholder'
$fix += 'UPDATE `o2czed1.opr_data.table_retention`'
$fix += 'SET bq_execution_where_clause = REPLACE(bq_execution_where_clause, ''%this.run_dttm%'', ''@retention_reference_dttm''),'
$fix += '    updated_dttm = CURRENT_TIMESTAMP(), updated_by = ''syntax_review_after_delete_2026_07_16'''
$fix += 'WHERE retention_rule_id IN ('
$fix += ('  ' + (SqlInList $thisRun))
$fix += ');'
$fix += ''
$fix += '-- 3) Fix malformed DATE(@retention_reference_dttm)()'
$fix += 'UPDATE `o2czed1.opr_data.table_retention`'
$fix += 'SET bq_execution_where_clause = REPLACE(bq_execution_where_clause, ''DATE(@retention_reference_dttm)()'', ''DATE(@retention_reference_dttm)''),'
$fix += '    updated_dttm = CURRENT_TIMESTAMP(), updated_by = ''syntax_review_after_delete_2026_07_16'''
$fix += 'WHERE retention_rule_id IN ('
$fix += ('  ' + (SqlInList $brokenDate))
$fix += ');'
$fix += ''
$fix += '-- 4) Fix quoted runtime parameter'
$fix += 'UPDATE `o2czed1.opr_data.table_retention`'
$fix += 'SET bq_execution_where_clause = REPLACE(bq_execution_where_clause, ''''@retention_reference_dttm'''', ''@retention_reference_dttm''),'
$fix += '    updated_dttm = CURRENT_TIMESTAMP(), updated_by = ''syntax_review_after_delete_2026_07_16'''
$fix += 'WHERE retention_rule_id IN ('
$fix += ('  ' + (SqlInList $quoted))
$fix += ');'
$fix += ''
$fix += '-- 5) Remove trailing semicolon'
$fix += 'UPDATE `o2czed1.opr_data.table_retention`'
$fix += 'SET bq_execution_where_clause = REGEXP_REPLACE(bq_execution_where_clause, r'';\s*$'', ''''),'
$fix += '    updated_dttm = CURRENT_TIMESTAMP(), updated_by = ''syntax_review_after_delete_2026_07_16'''
$fix += 'WHERE retention_rule_id IN ('
$fix += ('  ' + (SqlInList $semi))
$fix += ');'
$fix += ''
$fix += '-- 6) Post-check'
$fix += 'SELECT'
$fix += '  COUNTIF(retention_type = ''CUSTOM_SQL'') AS custom_total,'
$fix += '  COUNTIF(retention_type = ''CUSTOM_SQL'' AND (bq_execution_where_clause IS NULL OR TRIM(bq_execution_where_clause) = '''')) AS empty_bq,'
$fix += '  COUNTIF(retention_type = ''CUSTOM_SQL'' AND REGEXP_CONTAINS(bq_execution_where_clause, r''(?i)retence\s+se'')) AS retence_text,'
$fix += '  COUNTIF(retention_type = ''CUSTOM_SQL'' AND REGEXP_CONTAINS(bq_execution_where_clause, r''%this\.run_dttm%'')) AS this_run_dttm_placeholder,'
$fix += '  COUNTIF(retention_type = ''CUSTOM_SQL'' AND REGEXP_CONTAINS(bq_execution_where_clause, r''DATE\(@retention_reference_dttm\)\(\)'')) AS broken_date_call,'
$fix += '  COUNTIF(retention_type = ''CUSTOM_SQL'' AND REGEXP_CONTAINS(bq_execution_where_clause, r''''''@retention_reference_dttm'''''')) AS quoted_retention_param,'
$fix += '  COUNTIF(retention_type = ''CUSTOM_SQL'' AND REGEXP_CONTAINS(bq_execution_where_clause, r'';\s*$'')) AS trailing_semicolon'
$fix += 'FROM `o2czed1.opr_data.table_retention`;'
Set-Content -Path $outFix -Value ($fix -join "`r`n") -Encoding UTF8

Write-Output ('GENERATED_DELETE_FILE=' + $outDelete)
Write-Output ('GENERATED_FIX_FILE=' + $outFix)
Write-Output ('DELETE_PAIRS=' + $pairs.Count)
Write-Output ('DELETE_ROWS=' + $toDelete.Count)
Write-Output ('REMAINING_ROWS=' + $rem.Count)
Write-Output ('FIX_COUNTS empty=' + $empty.Count + ' retence=' + $retence.Count + ' this_run=' + $thisRun.Count + ' broken=' + $brokenDate.Count + ' quoted=' + $quoted.Count + ' semicolon=' + $semi.Count)
