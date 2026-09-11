-- One-time rename for commercial_analytics.commercial_analytics.bi_application_redshift
-- vantage_530 -> vantage4_530 (clearer name, ties it to the vantage4 field it's derived from).
-- This table hasn't had column mapping enabled yet (the prod backfill used
-- CREATE OR REPLACE TABLE, which doesn't need it), so enable it first --
-- this is a one-way change that upgrades the table's Delta protocol version.

ALTER TABLE commercial_analytics.commercial_analytics.bi_application_redshift
SET TBLPROPERTIES ('delta.columnMapping.mode' = 'name');

ALTER TABLE commercial_analytics.commercial_analytics.bi_application_redshift
RENAME COLUMN vantage_530 TO vantage4_530;
