WITH user_data AS (
    SELECT
        customer_id,
        card_id,
        total_revenue
    FROM monthly_view
    WHERE snapshot_date = '2025-10-01'
      AND card_status = 'Active'
),
filtered_occupations AS (
    SELECT
        card_id,
        customer_id,
        occupation,
        occupation_effective_date
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
    SELECT
        card_id,
        customer_id,
        occupation,
        occupation_effective_date
    FROM (
        SELECT
            card_id,
            customer_id,
            occupation,
            occupation_effective_date,
            ROW_NUMBER() OVER (
                PARTITION BY card_id
                ORDER BY occupation_effective_date DESC
            ) AS rn
        FROM filtered_occupations
    ) ranked
    WHERE rn = 1
),
joined AS (
    SELECT
        u.customer_id,
        COUNT(DISTINCT u.card_id) AS n_cards,
        SUM(u.total_revenue)      AS total_revenue
    FROM user_data u
    INNER JOIN latest_occupation lo
        ON u.customer_id = lo.customer_id
    GROUP BY u.customer_id
)
SELECT
    COUNT(DISTINCT customer_id) AS affected_customers,
    SUM(n_cards) AS affected_cards,
    ROUND(SUM(total_revenue)::numeric, 2) AS total_monthly_revenue
FROM joined
WHERE n_cards > 1;