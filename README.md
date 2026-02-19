# Seller Acquisition Strategy & Channel Performance Analysis

## 📚 Table of Contents

- [🏢 Business Context](#business-context)
- [🛠 Tools](#tools)
- [🎯 Business Problem](#business-problem)
- [🏗 Data Architecture](#data-architecture)
- [📊 Dashboard](#dashboard)
- [📈 Key Insights](#key-insights)
- [🎯 Strategic Takeaways](#strategic-takeaways)

## 🏢 Business Context

**Olist** is one of Brazil’s largest marketplace integrators, connecting small businesses to major ecommerce platforms under a single contract.

Sellers:
- List products via Olist
- Ship directly to customers using Olist logistics partners
- Are evaluated via post-delivery customer satisfaction surveys

Two **datasets** from Kaggle were used for this analysis:
- The [O-List E-commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) containing ecommerce orders, seller information, customer review scores
- The [Marketing Funnel dataset](https://www.kaggle.com/datasets/olistbr/marketing-funnel-olist) containing Marketing Qualified Leads (MQLs), lead acquisition channels, closed deal timestamps

Together, the datasets and dashboard allow full lifecycle analysis:

Lead acquisition → Deal conversion → First sale → Revenue performance → Customer experience


## Business Problem

Olist invests in multiple seller acquisition channels:
	•	Organic Search
	•	Paid Search
	•	Social
	•	Direct Traffic
	•	Referral
	•	Email
	•	Display

But:
- **Which channels scale revenue?**
- **Which convert sellers efficiently?**
- **Which produce sustainable performance?**

The goal of this project was to evaluate acquisition channel effectiveness across the full seller lifecycle, not just revenue volume.



## Tools

- PostGreSQL for data modelling and analysis: [View Scripts](https://github.com/tj-jayasekera/seller-acquisition-strategy-analysis/blob/main/acquisition_stategy.sql)
- Tableau for data visualisation: [View Dashboard](https://public.tableau.com/app/profile/theekshana.jayasekera7098/viz/SellerAcquisitionStrategyDashboardOlist/AcquisitionStrategyandPerformanceDashboard)


## Data Architecture

This project follows a Bronze → Silver → Gold layered architecture:

🥉 Bronze

Raw Olist marketplace datasets imported from Kaggle.

🥈 Silver

Cleaned and transformed views:
- Standardised timestamps
- Removed nulls
- Created delivery performance flags
- Structured lifecycle fields

🥇 Gold

Aggregated analysis-ready tables:
- seller_sales_summary
- seller_experience_summary
- seller_master
- channel_scorecard

All analysis is performed on the gold.channel_scorecard table.


## Dashboard

<img width="1440" height="865" alt="Screenshot 2026-02-19 at 3 45 31 pm" src="https://github.com/user-attachments/assets/326d2ffa-d979-4b0c-ad70-16923e2d424e" />


## Key Insights

1️⃣ Paid Search = Best Overall Performer
- High revenue, high activation rate, strong seller volume

2️⃣ Organic Search = Highest Overall Revenue
- Highest total revenue, largest seller base, moderate activation

3️⃣ Referral = High-Value Sellers
- Highest avg revenue per seller, fastest lifecycle, low revenue skew

Small volume, but high-quality and consistent.

4️⃣ Direct Traffic = Highly Committed Sellers
- Highest seller activity rate, lower total revenue

5️⃣ Revenue Skew Risk
- Organic & Email heavily skewed by top sellers, referral revenue more evenly distributed


## Strategic Takeaways
- Invest further in Paid Search
- Expand Referral programs
- Improve activation for Organic sellers
- Monitor skew risk in Email & Organic

