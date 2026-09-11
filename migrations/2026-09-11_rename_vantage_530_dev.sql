-- One-time rename for commercial_analytics.dev.bi_application_redshift
-- vantage_530 -> vantage4_530 (clearer name, ties it to the vantage4 field it's derived from).
-- Column mapping mode is already 'name' on this table (set during the earlier cid drop),
-- so no need to enable it again here.

ALTER TABLE commercial_analytics.dev.bi_application_redshift
RENAME COLUMN vantage_530 TO vantage4_530;
