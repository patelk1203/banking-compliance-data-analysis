import pandas as pd
import re

# Load datasets
occupations = pd.read_csv("/Users/kush_patel03/Downloads/occupationsbank.csv")
monthly_view = pd.read_csv("/Users/kush_patel03/Downloads/monthlyviewbanking.csv")

RESTRICTED_OCCUPATIONS = [
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
]

# 1. Filter monthly view for Oct 1st Active cards
user_data = monthly_view[(monthly_view['snapshot_date'] == '2025-10-01') & (monthly_view['card_status'] == 'Active')]

# 2. Filter occupations up to Oct 31st and clean strings
occupations['clean_occ'] = occupations['occupation'].astype(str).str.upper().apply(lambda x: re.sub(r'\s+', ' ', x).strip())
valid_dates = occupations[occupations['occupation_effective_date'] <= '2025-10-31']
filtered_occupations = valid_dates[valid_dates['clean_occ'].isin(RESTRICTED_OCCUPATIONS)]

# 3. Rank to get latest per card
latest_occupation = filtered_occupations.sort_values('occupation_effective_date', ascending=False).drop_duplicates(subset=['card_id'])

# 4. Join on customer_id to match the SQL logic
joined = pd.merge(user_data, latest_occupation[['customer_id']], on='customer_id', how='inner')

# 5. Aggregate and filter for multi-card users
agg_data = joined.groupby('customer_id').agg(
    n_cards=('card_id', 'nunique'),
    total_revenue=('total_revenue', 'sum')
).reset_index()

final_population = agg_data[agg_data['n_cards'] > 1]

print(f"Number of affected customers: {len(final_population):,}")
print(f"Number of affected cards: {final_population['n_cards'].sum():,}")
print(f"Total monthly revenue: ${final_population['total_revenue'].sum():,.2f}")

print("\n--- TASK 2: Refined Revenue Impact ---")

# 1. Keep only regulated cards (Join on card_id instead of customer_id)
regulated_cards = pd.merge(user_data, latest_occupation[['card_id']], on='card_id', how='inner')

# 2. Identify customers with more than one regulated card
card_counts = regulated_cards.groupby('customer_id').size().reset_index(name='n_cards')
multi_card_users = card_counts[card_counts['n_cards'] > 1]

# 3. Filter the main dataset to only include these multi-card users
multi_card_data = pd.merge(regulated_cards, multi_card_users[['customer_id']], on='customer_id', how='inner')

# 4. Rank cards by revenue descending (and card_id ascending to break ties)
multi_card_data = multi_card_data.sort_values(['customer_id', 'total_revenue', 'card_id'], ascending=[True, False, True])
# Create a rank column (equivalent to ROW_NUMBER in SQL)
multi_card_data['revenue_rank'] = multi_card_data.groupby('customer_id').cumcount() + 1

# 5. Impacted cards are everything except rank 1 (the highest revenue card they keep)
impacted_cards = multi_card_data[multi_card_data['revenue_rank'] > 1]

# Final Output
print(f"Number of impacted cards: {len(impacted_cards):,}")
print(f"Total revenue impacted: ${impacted_cards['total_revenue'].sum():,.2f}")

print("\n--- TASK 3: Bucket Breakdown & Exports ---")
import numpy as np
import os

# 1. Base dataset for Overall metrics (Active cards in Oct 2025)
monthly_view['card_open_date'] = pd.to_datetime(monthly_view['card_open_date'])
overall_data = monthly_view[(monthly_view['snapshot_date'] == '2025-10-01') & (monthly_view['card_status'] == 'Active')].copy()

# 2. Assign Revenue Buckets
rev_bins = [-np.inf, 25, 50, 100, 150, 200, 250, np.inf]
rev_labels = ['<25', '25-50', '50-100', '100-150', '150-200', '200-250', '250+']
overall_data['revenue_group'] = pd.cut(overall_data['total_revenue'], bins=rev_bins, labels=rev_labels, right=False)

# 3. Assign Tenure Buckets
overall_data['tenure_months'] = (2025 - overall_data['card_open_date'].dt.year) * 12 + (10 - overall_data['card_open_date'].dt.month)
tenure_bins = [-np.inf, 3, 6, 9, 12, 24, np.inf]
tenure_labels = ['<3', '3-6', '6-9', '9-12', '12-24', '24+']
overall_data['tenure_bucket'] = pd.cut(overall_data['tenure_months'], bins=tenure_bins, labels=tenure_labels, right=False)

# 4. Create the Impacted Cards dataset by merging with the demographic data we just built
impacted_full = pd.merge(impacted_cards[['card_id']], overall_data, on='card_id', how='inner')

# 5. Helper function to aggregate data
def aggregate_data(df, group_col, prefix):
    agg = df.groupby(group_col, observed=False).agg(
        lines=('card_id', 'nunique'),
        revenue=('total_revenue', 'sum')
    ).reset_index()
    # Rename columns to match requested outputs (e.g., overall_lines, impacted_revenue)
    return agg.rename(columns={'lines': f'{prefix}_lines', 'revenue': f'{prefix}_revenue'})

# 6. Generate the 6 requested tables
tables = {
    "overall_by_revenue": aggregate_data(overall_data, 'revenue_group', 'overall'),
    "impacted_by_revenue": aggregate_data(impacted_full, 'revenue_group', 'impacted'),
    "overall_by_tenure": aggregate_data(overall_data, 'tenure_bucket', 'overall'),
    "impacted_by_tenure": aggregate_data(impacted_full, 'tenure_bucket', 'impacted'),
    "overall_by_nationality": aggregate_data(overall_data, 'nationality', 'overall').sort_values('overall_revenue', ascending=False),
    "impacted_by_nationality": aggregate_data(impacted_full, 'nationality', 'impacted').sort_values('impacted_revenue', ascending=False)
}

# 7. Export tables to CSV
export_dir = "compliance_exports"
os.makedirs(export_dir, exist_ok=True)

for name, table in tables.items():
    file_path = os.path.join(export_dir, f"{name}.csv")
    table.to_csv(file_path, index=False)
    
print(f"Success! All 6 deliverables have been exported to the '{export_dir}/' folder.")