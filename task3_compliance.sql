DROP TABLE IF EXISTS overall_data, impacted_cards_data;

-- 1. Create a base table to calculate tenure, buckets, and overall stats
CREATE TABLE overall_data AS
SELECT 
    customer_id, card_id, total_revenue, nationality, card_open_date,
    CASE
      WHEN total_revenue < 25  THEN '<25'
      WHEN total_revenue < 50  THEN '25-50'
      WHEN total_revenue < 100 THEN '50-100'
      WHEN total_revenue < 150 THEN '100-150'
      WHEN total_revenue < 200 THEN '150-200'
      WHEN total_revenue < 250 THEN '200-250'
      ELSE '250+'
    END AS revenue_group,
    CASE
      WHEN ((EXTRACT(YEAR FROM DATE '2025-10-01') - EXTRACT(YEAR FROM card_open_date)) * 12 
           + (EXTRACT(MONTH FROM DATE '2025-10-01') - EXTRACT(MONTH FROM card_open_date))) < 3 THEN '<3'
      WHEN ((EXTRACT(YEAR FROM DATE '2025-10-01') - EXTRACT(YEAR FROM card_open_date)) * 12 
           + (EXTRACT(MONTH FROM DATE '2025-10-01') - EXTRACT(MONTH FROM card_open_date))) < 6 THEN '3-6'
      WHEN ((EXTRACT(YEAR FROM DATE '2025-10-01') - EXTRACT(YEAR FROM card_open_date)) * 12 
           + (EXTRACT(MONTH FROM DATE '2025-10-01') - EXTRACT(MONTH FROM card_open_date))) < 9 THEN '6-9'
      WHEN ((EXTRACT(YEAR FROM DATE '2025-10-01') - EXTRACT(YEAR FROM card_open_date)) * 12 
           + (EXTRACT(MONTH FROM DATE '2025-10-01') - EXTRACT(MONTH FROM card_open_date))) < 12 THEN '9-12'
      WHEN ((EXTRACT(YEAR FROM DATE '2025-10-01') - EXTRACT(YEAR FROM card_open_date)) * 12 
           + (EXTRACT(MONTH FROM DATE '2025-10-01') - EXTRACT(MONTH FROM card_open_date))) < 24 THEN '12-24'
      ELSE '24+'
    END AS tenure_bucket
FROM monthly_view
WHERE snapshot_date = '2025-10-01' AND card_status = 'Active';

-- 2. Create a table for impacted cards using Task 2 logic, inheriting the buckets
CREATE TABLE impacted_cards_data AS
WITH filtered_occupations AS (
    SELECT card_id, customer_id, occupation_effective_date FROM occupations
    WHERE occupation_effective_date <= '2025-10-31'
      AND UPPER(TRIM(REGEXP_REPLACE(occupation, '\s+', ' ', 'g'))) IN (
          'DRIVER', 'NURSE', 'WELDER', 'TECHNICIAN', 'ELECTRICIAN', 'CARETAKER', 'PLUMBER', 'MECHANIC', 
          'CONSTRUCTION WORKER', 'MARKETING SPECIALIST', 'SECURITY GUARD', 'DELIVERY RIDER', 'RETAIL ASSISTANT', 
          'OFFICE ADMINISTRATOR', 'CUSTOMER ADVISOR', 'WAREHOUSE OPERATOR', 'SALES EXECUTIVE', 'KITCHEN HELPER', 
          'FIELD ENGINEER', 'TAXI DRIVER', 'DATA ANALYST', 'STORE MANAGER', 'SENIOR PROJECT MANAGER', 
          'ASSISTANT FINANCE OFFICER', 'JUNIOR SALES ASSOCIATE', 'MEDICAL SUPPORT STAFF', 'TELECOM NETWORK TECHNICIAN', 
          'DIGITAL MARKETING EXECUTIVE', 'CUSTOMER SUPPORT REPRESENTATIVE', 'BUSINESS OPERATIONS COORDINATOR'
      )
),
latest_occupation AS (
    SELECT card_id FROM (
        SELECT card_id, ROW_NUMBER() OVER(PARTITION BY card_id ORDER BY occupation_effective_date DESC) as rn
        FROM filtered_occupations
    ) ranked WHERE rn = 1
),
regulated_cards AS (
    SELECT o.* FROM overall_data o
    INNER JOIN (SELECT DISTINCT card_id FROM latest_occupation) lo ON o.card_id = lo.card_id
),
users_multi_card AS (
    SELECT customer_id FROM regulated_cards GROUP BY customer_id HAVING COUNT(DISTINCT card_id) > 1
),
cards_ranked AS (
    SELECT r.*, ROW_NUMBER() OVER(PARTITION BY r.customer_id ORDER BY r.total_revenue DESC, r.card_id ASC) AS rn_revenue
    FROM regulated_cards r
    INNER JOIN users_multi_card u ON r.customer_id = u.customer_id
)
SELECT * FROM cards_ranked WHERE rn_revenue > 1;

-- Output 1: Overall by Revenue
SELECT revenue_group, COUNT(DISTINCT card_id) AS overall_lines, ROUND(SUM(total_revenue)::numeric, 2) AS overall_revenue 
FROM overall_data GROUP BY revenue_group ORDER BY CASE revenue_group WHEN '<25' THEN 1 WHEN '25-50' THEN 2 WHEN '50-100' THEN 3 WHEN '100-150' THEN 4 WHEN '150-200' THEN 5 WHEN '200-250' THEN 6 ELSE 7 END;

-- Output 2: Impacted by Revenue
SELECT revenue_group, COUNT(DISTINCT card_id) AS impacted_lines, ROUND(SUM(total_revenue)::numeric, 2) AS impacted_revenue 
FROM impacted_cards_data GROUP BY revenue_group ORDER BY CASE revenue_group WHEN '<25' THEN 1 WHEN '25-50' THEN 2 WHEN '50-100' THEN 3 WHEN '100-150' THEN 4 WHEN '150-200' THEN 5 WHEN '200-250' THEN 6 ELSE 7 END;

-- Output 3: Overall by Tenure
SELECT tenure_bucket, COUNT(DISTINCT card_id) AS overall_lines, ROUND(SUM(total_revenue)::numeric, 2) AS overall_revenue 
FROM overall_data GROUP BY tenure_bucket ORDER BY CASE tenure_bucket WHEN '<3' THEN 1 WHEN '3-6' THEN 2 WHEN '6-9' THEN 3 WHEN '9-12' THEN 4 WHEN '12-24' THEN 5 ELSE 6 END;

-- Output 4: Impacted by Tenure
SELECT tenure_bucket, COUNT(DISTINCT card_id) AS impacted_lines, ROUND(SUM(total_revenue)::numeric, 2) AS impacted_revenue 
FROM impacted_cards_data GROUP BY tenure_bucket ORDER BY CASE tenure_bucket WHEN '<3' THEN 1 WHEN '3-6' THEN 2 WHEN '6-9' THEN 3 WHEN '9-12' THEN 4 WHEN '12-24' THEN 5 ELSE 6 END;

-- Output 5: Overall by Nationality
SELECT nationality, COUNT(DISTINCT card_id) AS overall_lines, ROUND(SUM(total_revenue)::numeric, 2) AS overall_revenue 
FROM overall_data GROUP BY nationality ORDER BY overall_revenue DESC;

-- Output 6: Impacted by Nationality
SELECT nationality, COUNT(DISTINCT card_id) AS impacted_lines, ROUND(SUM(total_revenue)::numeric, 2) AS impacted_revenue 
FROM impacted_cards_data GROUP BY nationality ORDER BY impacted_revenue DESC;