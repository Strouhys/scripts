# Runbook - migrace retention pravidel z Teradata CSV

## 1) Vygenerovane soubory

- `sql/retention_seed_from_teradata.sql`
- `sql/retention_seed_manual_review.csv`
- `sql/retention_custom_auto_updates.sql`
- `sql/retention_custom_remaining_after_updates.sql`

## 2) Doporuceny postup v BigQuery

1. Nahrat seed:
   - spustit `retention_seed_from_teradata.sql`
2. Spustit hromadne update vzoru:
   - spustit `retention_custom_auto_updates.sql`
3. Vypsat zbyvajici manualni pravidla:
   - spustit `retention_custom_remaining_after_updates.sql`

## 3) Kontrolni dotazy

```sql
SELECT retention_type, COUNT(*) cnt
FROM `o2czed1.opr_data.table_retention`
GROUP BY retention_type
ORDER BY cnt DESC;
```

```sql
SELECT COUNT(*) AS custom_total,
       COUNTIF(bq_execution_where_clause IS NULL) AS custom_without_bq
FROM `o2czed1.opr_data.table_retention`
WHERE retention_type = 'CUSTOM_SQL';
```

```sql
SELECT is_active, COUNT(*) cnt
FROM `o2czed1.opr_data.table_retention`
GROUP BY is_active;
```

## 4) Poznamky

- Update skript je konzervativni a snazi se nemenit semantiku mimo jasne opakovane vzory.
- Pravidla s `nemazat` jsou automaticky deaktivovana (`is_active = FALSE`).
- Pravidla se slozitymi selecty nebo nestandardnimi funkcemi zustavaji v manual review.
