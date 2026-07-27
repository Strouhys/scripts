-- Retence BigQuery - Czech descriptions for retention_status_model
-- Purpose: Translate status descriptions to Czech for existing rows and keep values consistent.

MERGE `o2czed1.opr_data.retention_status_model` T
USING (
  SELECT 'RUN' AS entity_type, 'CREATED' AS status_code, FALSE AS is_terminal, FALSE AS is_success, 10 AS status_order, 'Zaznam behu byl vytvoren' AS description UNION ALL
  SELECT 'RUN', 'RUNNING', FALSE, FALSE, 20, 'Beh je prave zpracovavan' UNION ALL
  SELECT 'RUN', 'SUCCESS', TRUE, TRUE, 30, 'Vsechny tasky probehly uspesne nebo byly korektne preskoceny' UNION ALL
  SELECT 'RUN', 'PARTIAL_SUCCESS', TRUE, FALSE, 40, 'Alespon jeden task selhal a alespon jeden uspel nebo byl preskocen' UNION ALL
  SELECT 'RUN', 'FAILED', TRUE, FALSE, 50, 'Systemove selhani, beh nebyl dokoncen' UNION ALL

  SELECT 'TASK', 'RUNNING', FALSE, FALSE, 10, 'Task se prave vykonava' UNION ALL
  SELECT 'TASK', 'SUCCESS', TRUE, TRUE, 20, 'Mazani bylo uspesne provedeno' UNION ALL
  SELECT 'TASK', 'FAILED', TRUE, FALSE, 30, 'Mazani selhalo' UNION ALL
  SELECT 'TASK', 'SKIPPED_FREQUENCY', TRUE, TRUE, 40, 'Neni naplanovano pro aktualni datum' UNION ALL
  SELECT 'TASK', 'SKIPPED_ALREADY_SUCCESS', TRUE, TRUE, 50, 'Pravidlo uz bylo pro tento den uspesne dokonceno' UNION ALL
  SELECT 'TASK', 'SKIPPED_TABLE_NOT_FOUND', TRUE, TRUE, 60, 'Cilova tabulka zatim neexistuje' UNION ALL
  SELECT 'TASK', 'SKIPPED_COLUMN_NOT_FOUND', TRUE, TRUE, 70, 'Pozadovany retencni sloupec neexistuje' UNION ALL
  SELECT 'TASK', 'SKIPPED_NOT_ACTIVE', TRUE, TRUE, 80, 'Pravidlo je neaktivni' UNION ALL
  SELECT 'TASK', 'SKIPPED_NOT_IMPLEMENTED', TRUE, TRUE, 90, 'Typ retence neni v aktualni verzi implementovan' UNION ALL
  SELECT 'TASK', 'SKIPPED_VALIDATION', TRUE, TRUE, 100, 'Pravidlo neproslo statickou validaci'
) S
ON T.entity_type = S.entity_type
AND T.status_code = S.status_code
WHEN MATCHED THEN
  UPDATE SET
    T.is_terminal = S.is_terminal,
    T.is_success = S.is_success,
    T.status_order = S.status_order,
    T.description = S.description
WHEN NOT MATCHED THEN
  INSERT (entity_type, status_code, is_terminal, is_success, status_order, description)
  VALUES (S.entity_type, S.status_code, S.is_terminal, S.is_success, S.status_order, S.description);
