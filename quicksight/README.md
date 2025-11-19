# QuickSight Business Intelligence Dashboards - Phase 10

## 🎯 Overview

This phase implements **interactive business intelligence dashboards** using Amazon QuickSight to visualize insights from the complete data pipeline.

---

## 📊 Dashboard Components

### **Dashboard: Sales & Customer Analytics**

1. **Executive Summary**
   - Total Revenue KPI
   - Total Customers KPI
   - Average Order Value KPI
   - Customer Segments Donut Chart

2. **Customer Segmentation Analysis**
   - Customer Count by Segment (Bar Chart)
   - Revenue by Segment (Bar Chart)
   - Segment Distribution (Pie Chart)
   - CLV by Segment (Box Plot)

3. **Geographic Analysis**
   - Revenue by Region (Map or Bar Chart)
   - Customer Distribution by Region
   - Top Regions by Revenue

4. **Sales Trends**
   - Revenue Over Time (Line Chart)
   - Orders Over Time (Line Chart)
   - Revenue by Day of Week (Bar Chart)
   - Weekend vs Weekday Performance

5. **Product Performance**
   - Top Products by Revenue
   - Product Category Distribution
   - Average Basket Size

6. **Payment Analysis**
   - Payment Method Distribution (Pie Chart)
   - Revenue by Payment Method

---

## 🏗️ Architecture

```
┌─────────────────┐
│  Amazon         │
│  Athena         │  ← Queries Glue Data Catalog
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  QuickSight     │
│  Data Source    │  ← Connect to Athena
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  QuickSight     │
│  Datasets       │  ← Import or Direct Query
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  QuickSight     │
│  Analysis       │  ← Build visualizations
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  QuickSight     │
│  Dashboard      │  ← Publish and share
└─────────────────┘
```

---

## 🚀 Setup Guide

### **Part 1: Sign Up for QuickSight**

1. **Access QuickSight**:
   ```
   https://eu-west-2.quicksight.aws.amazon.com/
   ```

2. **Click**: "Sign up for QuickSight"

3. **Choose Edition**: Standard ($9/month, 30-day free trial)

4. **Account Name**: `data-pipeline-analytics`

5. **Region**: EU (London) - eu-west-2

6. **Grant Access**:
   - ✅ Amazon Athena
   - ✅ Amazon S3 (select our 3 buckets)

7. **Wait**: 1-2 minutes for account creation

---

### **Part 2: Connect to Athena**

Once in QuickSight:

1. **Click**: "Datasets" (left sidebar)

2. **Click**: "New dataset"

3. **Select**: "Athena"

4. **Data source name**: `athena-data-pipeline`

5. **Athena workgroup**: Select `data-pipeline-workgroup`

6. **Click**: "Create data source"

7. **Choose**: Database: `data_pipeline_catalog`

8. **Select tables** (one at a time, we'll create multiple datasets):
   - `sales_enriched_transactions`
   - `customers`
   - `products`
   - `customer_segments` (if you created Athena table in Phase 8)

---

### **Part 3: Create Dataset from Enriched Transactions**

1. **Select table**: `sales_enriched_transactions`

2. **Import mode**:
   - **SPICE** (recommended) - Fast, in-memory, max 25GB free
   - **Direct Query** - Real-time, slower queries

   **Recommendation**: Use SPICE for optimal dashboard performance

3. **Click**: "Edit/Preview data"

4. **Data Preparation** (optional enhancements):
   
   **Add Calculated Fields**:
   - Revenue Category Label:
     ```
     ifelse(
       {revenue_category} = 'high', 'High Revenue ($200+)',
       {revenue_category} = 'medium', 'Medium Revenue ($50-200)',
       'Low Revenue (<$50)'
     )
     ```
   
   - Month-Year:
     ```
     formatDate({transaction_date}, 'yyyy-MM')
     ```
   
   - Order Size Label:
     ```
     ifelse(
       {order_size} = 'large', 'Large Order (10+ items)',
       {order_size} = 'medium', 'Medium Order (5-9 items)',
       'Small Order (<5 items)'
     )
     ```

5. **Filters** (optional):
   - Remove any test/invalid data if needed

6. **Click**: "Save & visualize"

---

## 📊 Building Dashboards

### **Dashboard 1: Executive Summary**

#### **Visual 1: Total Revenue KPI**
1. **Visual Type**: KPI
2. **Value**: Sum of `total_amount`
3. **Format**: Currency ($)
4. **Title**: "Total Revenue"

#### **Visual 2: Total Customers KPI**
1. **Visual Type**: KPI
2. **Value**: Count Distinct of `customer_id`
3. **Title**: "Total Customers"

#### **Visual 3: Average Order Value KPI**
1. **Visual Type**: KPI
2. **Value**: Average of `total_amount`
3. **Format**: Currency ($)
4. **Title**: "Avg Order Value"

#### **Visual 4: Customer Segments**
1. **Visual Type**: Donut Chart
2. **Group by**: `segment` (or join with customer_segments)
3. **Value**: Count of `transaction_id`
4. **Title**: "Customer Distribution by Segment"

---

### **Dashboard 2: Revenue Analysis**

#### **Visual 1: Revenue by Region**
1. **Visual Type**: Horizontal Bar Chart
2. **Y-axis**: `region`
3. **Value**: Sum of `total_amount`
4. **Sort**: Descending by value
5. **Title**: "Revenue by Region"

#### **Visual 2: Revenue Over Time**
1. **Visual Type**: Line Chart
2. **X-axis**: `transaction_date` (by Day or Month)
3. **Value**: Sum of `total_amount`
4. **Title**: "Daily Revenue Trend"

#### **Visual 3: Revenue by Day of Week**
1. **Visual Type**: Vertical Bar Chart
2. **X-axis**: `day_of_week`
3. **Value**: Sum of `total_amount`
4. **Title**: "Revenue by Day of Week"

#### **Visual 4: Weekend vs Weekday**
1. **Visual Type**: Pie Chart
2. **Group by**: `is_weekend`
3. **Value**: Sum of `total_amount`
4. **Title**: "Weekend vs Weekday Revenue"

---

### **Dashboard 3: Product & Payment Analysis**

#### **Visual 1: Top Products**
1. **Visual Type**: Horizontal Bar Chart (Top 10)
2. **Y-axis**: `product_id`
3. **Value**: Sum of `total_amount`
4. **Filter**: Top 10 by revenue
5. **Title**: "Top 10 Products by Revenue"

#### **Visual 2: Payment Method Distribution**
1. **Visual Type**: Pie Chart
2. **Group by**: `payment_method`
3. **Value**: Count of `transaction_id`
4. **Title**: "Payment Method Preferences"

#### **Visual 3: Revenue Category Distribution**
1. **Visual Type**: Donut Chart
2. **Group by**: `revenue_category`
3. **Value**: Count of `transaction_id`
4. **Title**: "Order Size Distribution"

#### **Visual 4: Discount Analysis**
1. **Visual Type**: Combo Chart (Bar + Line)
2. **X-axis**: `discount_tier`
3. **Bars**: Count of orders
4. **Line**: Average `total_discount`
5. **Title**: "Discount Tier Analysis"

---

## 🎨 Dashboard Best Practices

### **Layout Tips**:
1. **Top Row**: KPIs (most important metrics)
2. **Second Row**: Key charts (revenue, customers)
3. **Bottom Rows**: Detailed analysis
4. **Consistent Colors**: Use theme colors
5. **Clear Titles**: Descriptive, action-oriented

### **Visual Selection Guide**:
- **KPI**: Single metric cards
- **Bar Chart**: Compare categories (regions, products)
- **Line Chart**: Trends over time
- **Pie/Donut**: Part-to-whole (segments, payment methods)
- **Scatter**: Correlation between two metrics
- **Heat Map**: Patterns across two dimensions
- **Table**: Detailed data with filters

### **Interactivity**:
- **Filters**: Add date range, region, segment filters
- **Drill-downs**: Click bar to see details
- **Parameters**: Let users change thresholds
- **Actions**: Navigate between dashboards

---

## 🔧 Advanced Features

### **1. Add Customer Segment Dataset**

If you created customer segments in Phase 8:

1. **Create New Dataset**: Athena → `customer_segments`
2. **Join with Transactions**:
   - In Analysis, add both datasets
   - Join on: `customer_id`
   - Type: Left join (keep all transactions)

3. **New Visuals Available**:
   - Revenue by Segment
   - CLV Predictions
   - Segment Migration Analysis

### **2. Calculated Fields**

Useful calculations:

```
// Customer Lifetime Value per Customer
{predicted_clv}

// Revenue per Customer
{total_spent} / {purchase_count}

// Profit Margin
({total_amount} - {total_discount}) / {total_amount} * 100

// Days Since Last Purchase
dateDiff({transaction_date}, now())

// Is Repeat Customer
ifelse({purchase_count} > 1, 'Repeat', 'New')
```

### **3. Filters & Parameters**

**Date Range Filter**:
- Add filter on `transaction_date`
- Type: Relative dates
- Options: Last 7 days, Last 30 days, Last quarter

**Region Parameter**:
- Create parameter: `selected_region`
- Add control: Dropdown (US-EAST, US-WEST, EU-WEST, AP-SOUTH)
- Filter visuals by parameter value

### **4. Themes & Formatting**

1. **Click**: Analysis settings → Themes
2. **Choose**: Pre-built theme or create custom
3. **Colors**: Match your brand
4. **Fonts**: Consistent typography

---

## 📤 Sharing Dashboards

### **Publish Dashboard**:
1. **Click**: "Share" (top-right)
2. **Click**: "Publish dashboard"
3. **Name**: "Sales & Customer Analytics Dashboard"
4. **Click**: "Publish"

### **Share with Users**:
1. **Click**: "Share" → "Share dashboard"
2. **Add users**: Enter email addresses
3. **Permissions**:
   - **Viewer**: Can view, no edits
   - **Co-owner**: Can edit
4. **Click**: "Share"

### **Embed in Website** (Advanced):
- Requires Enterprise edition
- Generate embed URL
- Use QuickSight API for SSO

---

## 🎯 Dashboard Reference

### **Sales Performance Dashboard**

**Top Row (KPIs)**:
```
┌─────────────┬─────────────┬─────────────┬─────────────┐
│  $1,271.66  │     12      │   $105.97   │     15      │
│ Total Sales │  Customers  │  Avg Order  │   Orders    │
└─────────────┴─────────────┴─────────────┴─────────────┘
```

**Middle Row (Charts)**:
```
┌──────────────────────────┬──────────────────────────┐
│   Revenue by Region      │  Customer Segments       │
│                          │                          │
│  US-EAST    ██████ $350  │   [Pie Chart]            │
│  US-WEST    ████   $250  │   - High-Value  17%      │
│  EU-WEST    ████   $240  │   - Moderate    42%      │
│  AP-SOUTH   ███    $180  │   - New/Low     25%      │
│                          │   - At-Risk     17%      │
└──────────────────────────┴──────────────────────────┘
```

**Bottom Row (Trends)**:
```
┌──────────────────────────────────────────────────────┐
│   Revenue Trend Over Time                            │
│                                                      │
│   [Line chart showing daily revenue trends]          │
│                                                      │
└──────────────────────────────────────────────────────┘
```

---

## 💡 Business Use Cases

### **Use Case 1: Executive Meeting**
Dashboard shows:
- Monthly revenue vs target
- Top performing regions
- Customer growth rate
- → Quick overview for leadership

### **Use Case 2: Marketing Campaign**
Dashboard shows:
- Customer segments
- At-risk customers count
- CLV predictions
- → Target campaigns to right segments

### **Use Case 3: Sales Team**
Dashboard shows:
- Revenue by product
- Regional performance
- Conversion rates
- → Focus efforts on high-potential areas

### **Use Case 4: Operations**
Dashboard shows:
- Order size distribution
- Payment method trends
- Processing times
- → Optimize fulfillment processes

---

## 🎓 Technical Concepts

### **SPICE vs Direct Query**

**SPICE (Super-fast, Parallel, In-memory Calculation Engine)**:
- ✅ Fast query performance (in-memory)
- ✅ 25GB free per user
- ✅ Cached data, refreshed on schedule
- ❌ Not real-time (scheduled refresh)
- **Use for**: Most dashboards

**Direct Query**:
- ✅ Always real-time data
- ✅ No storage limits
- ❌ Slower query performance
- ❌ Depends on source database speed
- **Use for**: Real-time monitoring

### **Data Refresh**

For SPICE datasets:
1. **Manual**: Click "Refresh now"
2. **Scheduled**: Set up automatic refresh
   - Daily at specific time
   - Hourly (Enterprise only)
   - After data pipeline completes

### **Performance Optimization**

1. **Pre-aggregate** data in Athena views
2. **Limit rows** to necessary data (date filters)
3. **Use SPICE** for faster dashboards
4. **Optimize Athena** queries (partitions, compression)

---

## 💰 Cost Optimization

### **QuickSight Costs**:
- **Standard**: $9/month per author (first 30 days free)
- **Enterprise**: $18/month per author + $0.30/session for readers
- **SPICE**: First 25GB free, then $0.25/GB/month

### **Associated Costs**:
- **Athena**: $5 per TB scanned
  - Use partitioning to reduce scans
  - Use SPICE to cache results
- **S3**: Storage costs (minimal for our data)

### **Savings Tips**:
1. Use SPICE to reduce Athena query costs
2. Schedule refreshes during off-peak hours
3. Delete unused datasets
4. Share dashboards instead of creating duplicates

---

## 🔍 Troubleshooting

### **Issue: Can't see Athena workgroup**
**Solution**: 
- Verify QuickSight has Athena access
- Check region matches (eu-west-2)
- Ensure workgroup exists

### **Issue: No data in visuals**
**Solution**:
- Run MSCK REPAIR TABLE in Athena first
- Check dataset preview shows data
- Verify date filters aren't excluding all data

### **Issue: Slow dashboard loading**
**Solution**:
- Switch from Direct Query to SPICE
- Reduce data volume with filters
- Pre-aggregate in Athena views

### **Issue: Can't create calculated field**
**Solution**:
- Check syntax carefully (case-sensitive)
- Use correct function names
- Test with simple calculation first

---

## 📚 Next Steps After Phase 10

### **Production Enhancements**:

1. **Scheduled Refreshes**:
   - Set SPICE refresh after Glue ETL completes
   - Use EventBridge to trigger refreshes

2. **Alerts & Notifications**:
   - Set up threshold alerts (revenue drops)
   - Email notifications for key metrics

3. **Advanced Analytics**:
   - ML Insights (anomaly detection)
   - Forecasting (future revenue predictions)
   - What-if analysis

4. **Multi-dashboard Strategy**:
   - Executive dashboard (high-level KPIs)
   - Operational dashboard (detailed metrics)
   - Team-specific dashboards

5. **Data Governance**:
   - Row-level security (restrict data by user)
   - Column-level security
   - Audit logging

---

## ✅ Completion Checklist

- [ ] QuickSight account created
- [ ] Athena data source connected
- [ ] Dataset created from sales_enriched_transactions
- [ ] SPICE import completed
- [ ] At least 5 visualizations created
- [ ] Dashboard published
- [ ] Dashboard title and description added
- [ ] Dashboard shared (optional)

---

## 🎉 Implementation Complete!

The **10-phase AWS Data Science Pipeline** is now operational:

1. ✅ S3 Data Lake
2. ✅ Sample Data
3. ✅ Lambda Ingestion
4. ✅ EventBridge Automation
5. ✅ Glue Data Catalog
6. ✅ Glue ETL
7. ✅ Athena Queries
8. ✅ EMR Spark (K-Means Segmentation)
9. ✅ SageMaker ML (CLV Prediction)
10. ✅ QuickSight Dashboards

**Pipeline Capabilities**:
- End-to-end data pipeline
- Automated data ingestion
- Data quality & transformation
- Customer segmentation (ML)
- Predictive analytics (ML)
- Interactive business dashboards

This is a **production-ready architecture** for enterprise data solutions! 🚀
