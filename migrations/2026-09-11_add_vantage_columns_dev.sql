-- One-time schema change for commercial_analytics.dev.bi_application_redshift
-- Adds columns required by bi_application_redshift_dev
-- Run once in Databricks before running bi_application_redshift_dev; do not add to the recurring job.

ALTER TABLE commercial_analytics.dev.bi_application_redshift
ADD COLUMNS (
  vantage4 STRING,
  vantage_530 BOOLEAN
);
