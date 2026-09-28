Banking Regulatory Impact Analysis

Overview
This project simulates a regulatory impact assessment at a retail bank. A new regulation restricts customers in certain occupations from holding more than one credit card. The objective of this analysis is to quantify how many customers are affected, estimate the monthly revenue at risk, and break down that exposure by revenue tier, card tenure, and nationality to inform executive decision-making.

Dataset
The project utilizes a synthetic banking dataset consisting of two core tables:
 `monthly_view`: A 6-million-row snapshot table containing one row per card per month. It captures card status, monthly revenue, card open date, and customer nationality. The snapshot date used throughout this analysis is October 2025.
 `occupations_bank`: A card-level occupation history table with effective dates, used to derive the most recent regulated occupation per card as of the end of October 2025.

Methodology
The analytical workflow was structured across four sequential tasks to build a complete, auditable data pipeline:

 Task 1: Baseline Population Definition
   Identified the total universe of active cards as of the October 2025 snapshot.
   Filtered customers holding more than one active credit card.
   Applied inline string cleaning (normalizing whitespace and casing) to the raw occupation data, as regulatory audits require data cleaning logic to remain visible in the analysis rather than hidden in pre-processing.
   Isolated customers whose most recent occupation fell within the list of 30 restricted professions. 
 Task 2: Impact Refinement
   Applied the business assumption that each impacted customer will retain their highest-revenue card, placing all secondary cards at risk of closure.
 Task 3: Demographic Segmentation
   Built segmented breakdowns for both the overall population and the impacted cohort.
   Grouped the data by 7 revenue tiers, 6 card tenure bands, and nationality.
 Task 4: Sub-Segment Expansion
   Extended the Task 3 outputs by introducing a strict 10-profession versus 20-profession split across all prior demographic tables.

Solution Approaches
To demonstrate tool agnostic data engineering, this project was solved using two distinct, parallel workflows that yield identical results.

1. The SQL Approach (PostgreSQL)
The SQL pipeline is divided into structured files, utilizing temporary tables and common table expressions (CTEs) for readability and performance. 
 Task 1 & 2: Relied heavily on `ROW_NUMBER() OVER(PARTITION BY ...)` window functions to isolate the most recent effective occupation dates and accurately rank highest-revenue cards to determine the kept vs. impacted status. 
 Task 3: Utilized `CASE` statements to dynamically build revenue and tenure buckets directly within the aggregation queries. 
 Task 4: Employed `ALTER TABLE` combined with `UPDATE` statements to append boolean flags for the new profession groupings, using `COUNT() FILTER (WHERE ...)` clauses for rapid sub-segment aggregations. 

2. The Python Approach (Pandas)
The Python pipeline replicates the SQL logic using the `pandas` library, focusing on vectorized operations for speed.
 Task 1 & 2: Used `.sort_values()` followed by `.drop_duplicates(keep='first')` to handle the latest occupation logic, and utilized `groupby().cumcount()` as the direct equivalent of the SQL window functions.
 Task 3: Replaced SQL `CASE` statements with `pd.cut()` to efficiently bin the revenue and tenure segments.
 Task 4: Defined a dynamic lambda aggregation function within `.groupby().agg()` to calculate the 10/20 profession splits without redundant looping. 

Key Findings:
 Headline figures: 93,788 customers hold more than one active credit card in a regulated occupation. Under the assumption that each keeps their top-revenue card, 91,107 cards are at risk of closure, carrying $4.67M in monthly revenue.
 Revenue concentration: The majority of impacted cards sit in the lower revenue tiers. Cards generating under $50 per month account for roughly 66% of impacted volume. This indicates the volume of cards at risk is large, but the average revenue per impacted card is relatively low (approx. $51).
 Tenure skew: Impacted cards are distributed fairly evenly across tenure bands, with no sharp concentration in newer or older cohorts. This suggests the regulation affects an established customer base rather than a recent acquisition spike.
 Nationality spread: No single nationality dominates the impacted population. The top nationalities by impacted revenue broadly mirror their share of the overall portfolio, indicating the impact is proportional rather than concentrated in any one segment.

 Challenges and Design Decisions
 Choosing which card to keep: The assumption that each customer retains their highest revenue card is analytically clean but may not reflect actual customer behavior. Customers might prefer older cards, specific product features, or lower balances. This is a modeling assumption; sensitivity analysis would be required to explore alternative retention rules.

 Future Extensions
 Predictive Customer Modeling: The current analysis assumes all impacted cards are closed and associated revenue is lost entirely. A natural extension would be to build a retention model predicting the likelihood of a customer consolidating their spend onto their remaining product versus closing their relationship entirely.
 Longitudinal Analysis: Expanding the dataset beyond the point-in-time snapshot to analyze seasonal spending trends and revenue drift over a multi-month period.
 Sensitivity Analysis on Retention Rules: Parameterizing the SQL and Python pipelines to dynamically test alternative customer behaviors (e.g., "Keep the oldest card" or "Keep the card with the lowest balance") to provide executives with best-case and worst-case revenue scenarios.
