-- One-time rename for commercial_analytics.public.bi_application
-- vantage_530 -> vantage4_530 (clearer name, ties it to the vantage4 field it's derived from).
-- The earlier ADD COLUMN didn't require column mapping (only RENAME/DROP do), so this
-- table is still on default mapping mode -- enable 'name' mode first.

ALTER TABLE commercial_analytics.public.bi_application
SET TBLPROPERTIES ('delta.columnMapping.mode' = 'name');

ALTER TABLE commercial_analytics.public.bi_application
RENAME COLUMN vantage_530 TO vantage4_530;
