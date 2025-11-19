# SageMaker ML Pipeline - Phase 9

## 🎯 Overview

This phase uses **Amazon SageMaker** to build a machine learning model that predicts **Customer Lifetime Value (CLV)** based on the customer segments created in Phase 8.

---

## 📊 What We Built

### **ML Problem**: Customer Lifetime Value Prediction
- **Input**: Customer features (segment, spend, purchase frequency, etc.)
- **Output**: Predicted revenue over next 12 months
- **Algorithm**: Random Forest Regression
- **Use Case**: Budget allocation, personalized marketing, retention strategies

---

## 🏗️ Architecture

```
┌─────────────────┐
│  S3 Curated     │
│  Zone           │  ← Customer segments from EMR K-Means
│  (Segments)     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  SageMaker      │
│  Notebook       │  ← Interactive ML development
│  Instance       │
└────────┬────────┘
         │
         ├── Exploratory Data Analysis (EDA)
         ├── Feature Engineering
         ├── Model Training (Random Forest)
         ├── Model Evaluation (R², RMSE, MAE)
         └── Predictions + Business Recommendations
         │
         ▼
┌─────────────────┐
│  S3 Scripts     │
│  Bucket         │  ← Saved model & predictions
└─────────────────┘
```

---

## 🚀 Setup Instructions

### **Step 1: Notebook Instance Created** ✅
- **Name**: `data-pipeline-ml-notebook`
- **Instance Type**: `ml.t3.medium` (2 vCPU, 4GB RAM)
- **Cost**: ~$0.05/hour
- **Status**: InService

### **Step 2: Access the Notebook**

1. **Open AWS Console**:
   ```
   https://console.aws.amazon.com/sagemaker/
   ```

2. **Navigate to**: `SageMaker → Notebook instances`

3. **Find**: `data-pipeline-ml-notebook`

4. **Click**: `Open JupyterLab` (or `Open Jupyter`)

### **Step 3: Upload the Notebook**

1. In JupyterLab, click the **Upload** button (📤 icon)

2. Upload this file:
   ```
   sagemaker/notebooks/customer_lifetime_value_prediction.ipynb
   ```

3. Double-click to open the notebook

### **Step 4: Run the Notebook**

1. **Select Kernel**: `Python 3` (conda_python3)

2. **Run All Cells**: Click `Run → Run All Cells` or use `Shift+Enter` for each cell

3. **Follow the Tutorial**: The notebook has detailed explanations for each step

---

## 📚 What the Notebook Does

### **1. Data Loading**
- Loads customer segments from S3 curated zone
- Reads all 4 segments (High-Value, At-Risk, New/Low-Spend, Moderate)

### **2. Exploratory Data Analysis (EDA)**
- Customer distribution by segment
- Revenue analysis by segment
- Feature correlation heatmap
- Data quality checks

### **3. Feature Engineering**
Creates predictive features:
- `avg_order_value` = total_spent / purchase_count
- `recency_score` = Normalized inverse of days_since_purchase
- `frequency_score` = Normalized purchase count
- `monetary_score` = Normalized total spend
- `engagement_score` = Weighted combination
- One-hot encoding for regions and payment methods

### **4. Target Variable Creation**
- **CLV (12-month estimate)**: `(total_spent / days_active) × 365`
- Proxy for annual revenue based on historical spending rate

### **5. Model Training**
- **Algorithm**: Random Forest Regressor
- **Parameters**: 100 trees, max depth 10
- **Train/Test Split**: 80/20

### **6. Model Evaluation**
Metrics:
- **R² Score**: Variance explained by model
- **RMSE**: Root Mean Squared Error ($ prediction error)
- **MAE**: Mean Absolute Error

### **7. Feature Importance**
- Identifies which features best predict CLV
- Visualizes top 10 most important features

### **8. Business Predictions**
For each customer:
- Predicted 12-month CLV
- Personalized recommendation:
  - 🌟 VIP Treatment (CLV > $500)
  - 💎 Premium Care (CLV > $300)
  - 📈 Growth Potential (CLV > $150)
  - ⚠️ Retention Focus (At-Risk segment)
  - 📊 Standard Care (others)

### **9. Model Persistence**
- Saves trained model to S3: `ml-models/customer_lifetime_value/`
- Saves predictions to S3: `ml-predictions/clv_predictions.csv`

---

## 💡 Business Impact

### **Before ML**:
- Treat all customers the same
- Generic marketing campaigns
- No budget prioritization

### **After ML**:
- Identify high-value customers (VIP treatment)
- Predict churn risk (proactive retention)
- Personalize marketing spend per customer
- Data-driven budget allocation

### **Example Insights**:
```
Customer CUST002:
- Segment: High-Value Frequent
- Historical Spend: $209.97
- Predicted 12-Month CLV: $500+
- Recommendation: VIP Treatment
- Action: Personal account manager, exclusive offers

Customer CUST003:
- Segment: At-Risk
- Historical Spend: $49.95
- Predicted 12-Month CLV: $150
- Recommendation: Retention Focus
- Action: Win-back campaign with 20% discount
```

---

## 🎓 Key Learnings

### **Machine Learning Concepts**:
1. **Supervised Learning**: Learn from labeled data (historical CLV)
2. **Regression**: Predict continuous values (dollar amounts)
3. **Feature Engineering**: Transform raw data into predictive features
4. **Train/Test Split**: Evaluate on unseen data
5. **Model Evaluation**: R², RMSE, MAE metrics
6. **Feature Importance**: Understand model decisions

### **Random Forest**:
- **Ensemble Method**: Combines many decision trees
- **Advantages**: Handles non-linear relationships, resistant to overfitting
- **Interpretable**: Provides feature importance
- **Works well with small datasets**

### **SageMaker Benefits**:
- **Managed Infrastructure**: No server setup
- **Pre-installed Libraries**: Scikit-learn, pandas, boto3
- **Direct S3 Access**: Seamless data integration
- **Scalable**: Can upgrade to GPU instances for deep learning

---

## 📈 Model Performance (Expected)

With our 12-customer dataset:
- **R² Score**: ~0.80-0.95 (very good for small dataset)
- **RMSE**: ~$20-50 (prediction error in dollars)
- **MAE**: ~$15-40 (average absolute error)

**Note**: With more data, model performance improves significantly!

---

## 🔄 Next Steps

### **Phase 9 Complete** ✅
After running the notebook:
- Trained model saved to S3
- Predictions generated for all customers
- Business recommendations created

### **Production Deployment** (Optional Advanced):
1. **Deploy Model as Endpoint**:
   - Real-time predictions via REST API
   - Auto-scaling based on traffic
   - A/B testing different models

2. **Automated Retraining**:
   - Lambda function triggered monthly
   - Fetch new data from S3
   - Retrain and redeploy model

3. **Integration with CRM**:
   - Sync predictions to marketing tools
   - Automated email campaigns based on CLV
   - Dashboard for sales team

---

## 💰 Cost Management

### **Running Costs**:
- Notebook instance: **$0.05/hour**
- S3 storage: **~$0.001/month** (minimal for our data)
- No charges when stopped

### **Stop the Notebook Instance**:
```bash
# Stop instance to avoid charges
aws sagemaker stop-notebook-instance --notebook-instance-name data-pipeline-ml-notebook

# Restart when needed
aws sagemaker start-notebook-instance --notebook-instance-name data-pipeline-ml-notebook
```

### **Delete When Done** (after Phase 10):
```bash
aws sagemaker delete-notebook-instance --notebook-instance-name data-pipeline-ml-notebook
```

---

## 📁 Files Created

```
sagemaker/
├── notebooks/
│   └── customer_lifetime_value_prediction.ipynb  # Main ML notebook
└── README.md                                       # This file

S3 Outputs:
├── s3://data-lake-scripts-*/ml-models/customer_lifetime_value/
│   └── clv_rf_model.joblib                        # Trained model
└── s3://data-lake-scripts-*/ml-predictions/
    └── clv_predictions.csv                         # All customer predictions
```

---

## 🎯 Tutorial Mode Summary

### **What is SageMaker?**
AWS's fully managed ML platform for building, training, and deploying models.

### **What is CLV?**
Customer Lifetime Value = Predicted revenue a customer will generate over time.

### **What is Random Forest?**
An ensemble of decision trees that vote on predictions (wisdom of the crowd).

### **Why Feature Engineering?**
Transform raw data into meaningful patterns the model can learn from.

### **What's Next?**
Phase 10: QuickSight dashboards to visualize all our insights!

---

## 🔗 Resources

- [AWS SageMaker Documentation](https://docs.aws.amazon.com/sagemaker/)
- [Scikit-learn Random Forest](https://scikit-learn.org/stable/modules/ensemble.html#forest)
- [Customer Lifetime Value](https://en.wikipedia.org/wiki/Customer_lifetime_value)

---

**Status**: ✅ Phase 9 Setup Complete  
**Next**: Run the notebook in SageMaker JupyterLab!
