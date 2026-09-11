-- One-time rename for commercial_analytics.dev.bi_application_redshift
-- vantage_530 -> vantage4_530 (clearer name, ties it to the vantage4 field it's derived from).
-- Column mapping mode was set to 'name' during the earlier cid drop, but the
-- CREATE OR REPLACE TABLE full backfill recreated the table and reset that
-- property, so it needs to be re-enabled here.

ALTER TABLE commercial_analytics.dev.bi_application_redshift
SET TBLPROPERTIES ('delta.columnMapping.mode' = 'name');

ALTER TABLE commercial_analytics.dev.bi_application_redshift
RENAME COLUMN vantage_530 TO vantage4_530;
