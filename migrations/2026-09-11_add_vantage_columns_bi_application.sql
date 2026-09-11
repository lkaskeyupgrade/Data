-- One-time schema change for commercial_analytics.public.bi_application
-- Adds columns required by the updated bi_application script (vantage4/vantage4_530
-- now flow through from bi_application_redshift). Positioned AFTER fico_550 to match
-- where the script places them via SELECT * pass-through -- run once before running
-- the updated bi_application script; do not add to the recurring job.

ALTER TABLE commercial_analytics.public.bi_application
ADD COLUMN vantage4 STRING AFTER fico_550;

ALTER TABLE commercial_analytics.public.bi_application
ADD COLUMN vantage4_530 BOOLEAN AFTER vantage4;
