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