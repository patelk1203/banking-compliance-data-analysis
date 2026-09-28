-- ============================================
-- Step 0: Rebuild the permanent latest_occupation table 
-- ============================================
DROP TABLE IF EXISTS latest_occupation;

CREATE TABLE latest_occupation AS
WITH filtered_occupations AS (
    SELECT card_id, customer_id, occupation, occupation_effective_date
    FROM occupations
    WHERE occupation_effective_date <= '2025-10-31'
      AND UPPER(TRIM(REPLACE(REPLACE(occupation, '  ', ' '), '   ', ' '))) IN (
          'DRIVER','NURSE','WELDER','TECHNICIAN','ELECTRICIAN','CARETAKER','PLUMBER','MECHANIC','CONSTRUCTION WORKER',
          'MARKETING SPECIALIST','SECURITY GUARD','DELIVERY RIDER','RETAIL ASSISTANT','OFFICE ADMINISTRATOR','CUSTOMER ADVISOR',
          'WAREHOUSE OPERATOR','SALES EXECUTIVE','KITCHEN HELPER','FIELD ENGINEER','TAXI DRIVER','DATA ANALYST','STORE MANAGER',
          'SENIOR PROJECT MANAGER','ASSISTANT FINANCE OFFICER','JUNIOR SALES ASSOCIATE','MEDICAL SUPPORT STAFF','TELECOM NETWORK TECHNICIAN',
          'DIGITAL MARKETING EXECUTIVE','CUSTOMER SUPPORT REPRESENTATIVE','BUSINESS OPERATIONS COORDINATOR'
      )
),
ranked AS (
    SELECT fo.*, ROW_NUMBER() OVER(PARTITION BY fo.card_id ORDER BY fo.occupation_effective_date DESC) as rn
    FROM filtered_occupations fo
)
SELECT * FROM ranked WHERE rn = 1;


-- ============================================
-- Step 1: Add profession flags to overall dataset
-- ============================================
ALTER TABLE overall_data ADD COLUMN IF NOT EXISTS is_10_prof BOOLEAN, ADD COLUMN IF NOT EXISTS is_20_prof BOOLEAN;

UPDATE overall_data d
SET
  is_10_prof = d.card_id IN (
    SELECT lo.card_id FROM latest_occupation lo
    WHERE UPPER(TRIM(REPLACE(REPLACE(lo.occupation, '  ', ' '), '   ', ' '))) IN (
      'PLUMBER','MECHANIC','CONSTRUCTION WORKER','MARKETING SPECIALIST',
      'SECURITY GUARD','TAXI DRIVER','DATA ANALYST','NURSE','DRIVER','WELDER'
    )
  ),
  is_20_prof = d.card_id IN (
    SELECT lo.card_id FROM latest_occupation lo
    WHERE UPPER(TRIM(REPLACE(REPLACE(lo.occupation, '  ', ' '), '   ', ' '))) IN (
      'TECHNICIAN','ELECTRICIAN','CARETAKER','DELIVERY RIDER',
      'RETAIL ASSISTANT','OFFICE ADMINISTRATOR','CUSTOMER ADVISOR','WAREHOUSE OPERATOR',
      'SALES EXECUTIVE','KITCHEN HELPER','FIELD ENGINEER',
      'STORE MANAGER','SENIOR PROJECT MANAGER','ASSISTANT FINANCE OFFICER',
      'JUNIOR SALES ASSOCIATE','MEDICAL SUPPORT STAFF',
      'TELECOM NETWORK TECHNICIAN','DIGITAL MARKETING EXECUTIVE',
      'CUSTOMER SUPPORT REPRESENTATIVE','BUSINESS OPERATIONS COORDINATOR'
    )
  );


-- ============================================
-- Step 2: Add profession flags to impacted dataset
-- ============================================
ALTER TABLE impacted_cards_data ADD COLUMN IF NOT EXISTS is_10_prof BOOLEAN, ADD COLUMN IF NOT EXISTS is_20_prof BOOLEAN;

UPDATE impacted_cards_data i
SET
  is_10_prof = i.card_id IN (
    SELECT lo.card_id FROM latest_occupation lo
    WHERE UPPER(TRIM(REPLACE(REPLACE(lo.occupation, '  ', ' '), '   ', ' '))) IN (
      'PLUMBER','MECHANIC','CONSTRUCTION WORKER','MARKETING SPECIALIST',
      'SECURITY GUARD','TAXI DRIVER','DATA ANALYST','NURSE','DRIVER','WELDER'
    )
  ),
  is_20_prof = i.card_id IN (
    SELECT lo.card_id FROM latest_occupation lo
    WHERE UPPER(TRIM(REPLACE(REPLACE(lo.occupation, '  ', ' '), '   ', ' '))) IN (
      'TECHNICIAN','ELECTRICIAN','CARETAKER','DELIVERY RIDER',
      'RETAIL ASSISTANT','OFFICE ADMINISTRATOR','CUSTOMER ADVISOR','WAREHOUSE OPERATOR',
      'SALES EXECUTIVE','KITCHEN HELPER','FIELD ENGINEER',
      'STORE MANAGER','SENIOR PROJECT MANAGER','ASSISTANT FINANCE OFFICER',
      'JUNIOR SALES ASSOCIATE','MEDICAL SUPPORT STAFF',
      'TELECOM NETWORK TECHNICIAN','DIGITAL MARKETING EXECUTIVE',
      'CUSTOMER SUPPORT REPRESENTATIVE','BUSINESS OPERATIONS COORDINATOR'
    )
  );


-- ============================================
-- Step 3: Overall outputs (Tenure & Nationality)
-- ============================================
SELECT
  tenure_bucket, COUNT(DISTINCT card_id) AS overall_cards, SUM(total_revenue) AS overall_revenue,
  COUNT(DISTINCT card_id) FILTER (WHERE is_10_prof) AS prof10_cards, COALESCE(SUM(total_revenue) FILTER (WHERE is_10_prof), 0) AS prof10_revenue,
  COUNT(DISTINCT card_id) FILTER (WHERE is_20_prof) AS prof20_cards, COALESCE(SUM(total_revenue) FILTER (WHERE is_20_prof), 0) AS prof20_revenue
FROM overall_data GROUP BY tenure_bucket ORDER BY CASE tenure_bucket WHEN '<3' THEN 1 WHEN '3-6' THEN 2 WHEN '6-9' THEN 3 WHEN '9-12' THEN 4 WHEN '12-24' THEN 5 WHEN '24+' THEN 6 ELSE 99 END;

SELECT
  nationality, COUNT(DISTINCT card_id) AS overall_cards, SUM(total_revenue) AS overall_revenue,
  COUNT(DISTINCT card_id) FILTER (WHERE is_10_prof) AS prof10_cards, COALESCE(SUM(total_revenue) FILTER (WHERE is_10_prof), 0) AS prof10_revenue,
  COUNT(DISTINCT card_id) FILTER (WHERE is_20_prof) AS prof20_cards, COALESCE(SUM(total_revenue) FILTER (WHERE is_20_prof), 0) AS prof20_revenue
FROM overall_data GROUP BY nationality ORDER BY overall_revenue DESC LIMIT 10;


-- ============================================
-- Step 4: Impacted outputs (Revenue & Tenure)
-- ============================================
SELECT
  revenue_group, COUNT(DISTINCT card_id) AS impacted_cards, SUM(total_revenue) AS impacted_revenue,
  COUNT(DISTINCT CASE WHEN is_10_prof THEN card_id END) AS impacted_prof10_cards, COALESCE(SUM(CASE WHEN is_10_prof THEN total_revenue END), 0) AS impacted_prof10_revenue,
  COUNT(DISTINCT CASE WHEN is_20_prof THEN card_id END) AS impacted_prof20_cards, COALESCE(SUM(CASE WHEN is_20_prof THEN total_revenue END), 0) AS impacted_prof20_revenue
FROM impacted_cards_data GROUP BY revenue_group ORDER BY CASE revenue_group WHEN '<25' THEN 1 WHEN '25-50' THEN 2 WHEN '50-100' THEN 3 WHEN '100-150' THEN 4 WHEN '150-200' THEN 5 WHEN '200-250' THEN 6 WHEN '250+' THEN 7 ELSE 99 END;

SELECT
  tenure_bucket, COUNT(DISTINCT card_id) AS impacted_cards, SUM(total_revenue) AS impacted_revenue,
  COUNT(DISTINCT CASE WHEN is_10_prof THEN card_id END) AS impacted_prof10_cards, COALESCE(SUM(CASE WHEN is_10_prof THEN total_revenue END), 0) AS impacted_prof10_revenue,
  COUNT(DISTINCT CASE WHEN is_20_prof THEN card_id END) AS impacted_prof20_cards, COALESCE(SUM(CASE WHEN is_20_prof THEN total_revenue END), 0) AS impacted_prof20_revenue
FROM impacted_cards_data GROUP BY tenure_bucket ORDER BY CASE tenure_bucket WHEN '<3' THEN 1 WHEN '3-6' THEN 2 WHEN '6-9' THEN 3 WHEN '9-12' THEN 4 WHEN '12-24' THEN 5 WHEN '24+' THEN 6 ELSE 99 END;