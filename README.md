# sql-datawarehouse-project
Building a modern data warehouse with SQL server or PostgreSQL, including ETL process and data analytics
🏗️ Data Architecture
<img width="1544" height="912" alt="image" src="https://github.com/user-attachments/assets/483b6cc3-6597-4a54-abda-14bdafa6eebf" />

The data architecture for this project follows Medallion Architecture Bronze, Silver, and Gold layers: Data Architecture

Bronze Layer: Stores raw data as-is from the source systems. Data is ingested from CSV Files into SQL Server Database.
Silver Layer: This layer includes data cleansing, standardization, and normalization processes to prepare data for analysis.
Gold Layer: Houses business-ready data modeled into a star schema required for reporting and analytics.
📖 Project Overview
In this project, you:

Design the architecture: a modern data warehouse with three layers, bronze, silver and gold.
Build the ETL pipelines: load the source files and move the data through the layers.
Model the data: facts and dimensions, ready for reports.
Analyze it: answer business questions with SQL.
