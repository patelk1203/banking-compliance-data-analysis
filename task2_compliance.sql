WITH user_data AS (
    SELECT customer_id, card_id, total_revenue
    FROM monthly_view
    WHERE snapshot_date = '2025-10-01' 
      AND card_status = 'Active'
),
filtered_occupations AS (
    SELECT card_id, customer_id, occupation, occupation_effective_date
    FROM occupations
    WHERE occupation_effective_date <= '2025-10-31'
      AND UPPER(TRIM(REGEXP_REPLACE(occupation, '\s+', ' ', 'g'))) IN (
          'DRIVER', 'NURSE', 'WELDER', 'TECHNICIAN', 'ELECTRICIAN',
          'CARETAKER', 'PLUMBER', 'MECHANIC', 'CONSTRUCTION WORKER',
          'MARKETING SPECIALIST', 'SECURITY GUARD', 'DELIVERY RIDER',
          'RETAIL ASSISTANT', 'OFFICE ADMINISTRATOR', 'CUSTOMER ADVISOR',
          'WAREHOUSE OPERATOR', 'SALES EXECUTIVE', 'KITCHEN HELPER',
          'FIELD ENGINEER', 'TAXI DRIVER', 'DATA ANALYST', 'STORE MANAGER',
          'SENIOR PROJECT MANAGER', 'ASSISTANT FINANCE OFFICER',
          'JUNIOR SALES ASSOCIATE', 'MEDICAL SUPPORT STAFF',
          'TELECOM NETWORK TECHNICIAN', 'DIGITAL MARKETING EXECUTIVE',
          'CUSTOMER SUPPORT REPRESENTATIVE', 'BUSINESS OPERATIONS COORDINATOR'
      )
),
latest_occupation AS (
    SELECT card_id, customer_id, occupation, occupation_effective_date
    FROM (
        SELECT card_id, customer_id, occupation, occupation_effective_date,
            ROW_NUMBER() OVER (
                PARTITION BY card_id
                ORDER BY occupation_effective_date DESC
            ) AS rn
        FROM filtered_occupations
    ) ranked
    WHERE rn = 1
),
regulated_cards AS (
    -- Step 1: Keep only regulated cards (Joining on card_id this time)
    SELECT u.*
    FROM user_data u
    INNER JOIN (SELECT DISTINCT card_id FROM latest_occupation) lo
        ON u.card_id = lo.card_id
),
users_multi_card AS (
    -- Step 2: Identify customers with > 1 regulated card
    SELECT customer_id
    FROM regulated_cards
    GROUP BY customer_id
    HAVING COUNT(DISTINCT card_id) > 1
),
cards_ranked AS (
    -- Step 3: Rank cards by revenue for those multi-card users
    SELECT r.*,
           ROW_NUMBER() OVER (
               PARTITION BY r.customer_id 
               ORDER BY r.total_revenue DESC, r.card_id ASC
           ) AS rn_revenue
    FROM regulated_cards r
    INNER JOIN users_multi_card u 
        ON r.customer_id = u.customer_id
)
-- Step 4: Sum everything except the #1 highest revenue card
SELECT 
    COUNT(*) AS number_of_impacted_cards,
    ROUND(SUM(total_revenue)::numeric, 2) AS total_revenue_impacted
FROM cards_ranked
WHERE rn_revenue > 1;