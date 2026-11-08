---------------------- CREATING STORED PROCEDURE FOR THE SILVER LAYER BY WRAPPING ALL THE CODE -------
CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN 

    -- we Define custom Variables with @ outside of Try Block which makes it Global Variable
    --and it can be accessed in both TRY, CATCH
    DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
    BEGIN TRY

        SET @batch_start_time = GETDATE();
        PRINT '>> LOADING THE SILVER LAYER';
        PRINT '===========================';

        PRINT '>> LOADING CRM TABLES';
        PRINT '----------------------';

        ----------------INSERTING IN TO THE TABLE 1 "silver.crm_cust_info" OF THE SILVER LAYER--------------------
        -----------------------------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table 1 :silver.crm_cust_info';
        TRUNCATE TABLE silver.crm_cust_info;
        PRINT '>> Inserting Data in to Table 1 :silver.crm_cust_info';

        INSERT INTO silver.crm_cust_info (
            cst_id,
            cst_key,
            cst_firstname,
            cst_lastname,
            cst_marital_status,
            cst_gndr,
            cst_create_date
        )
        SELECT
            cst_id, 
            cst_key,
            TRIM(cst_firstname) AS cst_firstname,
            TRIM(cst_lastname) AS cst_lastname,

            -- Standardized casing to Title Case and 'n/a'
            CASE WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
                 WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
                 ELSE 'n/a'
            END AS cst_marital_status,

            CASE WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
                 WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
                 ELSE 'n/a'
            END AS cst_gndr,

            cst_create_date
        FROM (
            SELECT 
                *,
                ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last 
            FROM bronze.crm_cust_info
            WHERE cst_id IS NOT NULL
        ) t 
        WHERE flag_last = 1;
        SET @end_time = GETDATE();
        PRINT '>> LOAD Dutation of Table 1 : ' + CAST(DATEDIFF(SECOND,@start_time,@end_time)AS NVARCHAR) + 'Seconds' ;
        PRINT '------------';


        ----------------INSERTING IN TO THE TABLE 2 "silver.crm_prd_info" OF THE SILVER LAYER --------------------
        
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table 2 :silver.crm_prd_info';
        TRUNCATE TABLE silver.crm_prd_info;
        PRINT '>> Inserting Data in to Table 2 :silver.crm_prd_info';

        INSERT INTO silver.crm_prd_info (
            prd_id,
            cat_id,
            prd_key,
            prd_nm,
            prd_cost,
            prd_line,
            prd_start_dt,
            prd_end_dt
        )
        SELECT
            prd_id,
            REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
            SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key, -- Fixed alias from prd_id to prd_key
            TRIM(prd_nm) AS prd_nm,
            ISNULL(prd_cost, 0) AS prd_cost,

            CASE UPPER(TRIM(prd_line)) 
                WHEN 'M' THEN 'Mountain'
                WHEN 'R' THEN 'Road'
                WHEN 'S' THEN 'Other Sales'
                WHEN 'T' THEN 'Tour'
                ELSE 'n/a'
            END AS prd_line,

            CAST(prd_start_dt AS DATE) AS prd_start_dt,
            CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - 1 AS DATE) AS prd_end_dt
        FROM bronze.crm_prd_info;
         SET @end_time = GETDATE();
        PRINT '>> LOAD Dutation of Table 2 : ' + CAST(DATEDIFF(SECOND,@start_time,@end_time)AS NVARCHAR) + 'Seconds' ;
        PRINT '------------';


        ----------------INSERTING IN TO THE TABLE 3 "silver.crm_sales_details" OF THE SILVER LAYER --------------------
        ------------------------------------------------------------------------------------------------------------
        
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table 3:silver.crm_sales_details';
        TRUNCATE TABLE silver.crm_sales_details;
        PRINT '>> Inserting Data in to Table 3 :silver.crm_sales_details';

        INSERT INTO silver.crm_sales_details (
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        )
        SELECT 
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,

            -- Removed spaces inside != operators
            CASE WHEN sls_order_dt <= 0 OR LEN(sls_order_dt) != 8 THEN NULL
                 ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE) 
            END AS sls_order_dt,

            CASE WHEN sls_ship_dt <= 0 OR LEN(sls_ship_dt) != 8 THEN NULL
                 ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE) 
            END AS sls_ship_dt,

            CASE WHEN sls_due_dt <= 0 OR LEN(sls_due_dt) != 8 THEN NULL
                 ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
            END AS sls_due_dt,

            -- 1. CLEANING SALES: Fixes nulls, zeros, and mismatched totals
            CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price) 
                 THEN sls_quantity * ABS(sls_price)
                 ELSE sls_sales
            END AS sls_sales,

            -- 2. sls_quantity has no issues - Hence No need to clean it
            sls_quantity, 

            -- 3. CLEANING PRICE: Derives clean price from sales if null, zero, or negative
            CASE WHEN sls_price IS NULL OR sls_price <= 0
                 THEN sls_sales / NULLIF(sls_quantity, 0)
                 ELSE sls_price
            END AS sls_price
        FROM bronze.crm_sales_details;
         SET @end_time = GETDATE();
        PRINT '>> LOAD Dutation of Table 3 : ' + CAST(DATEDIFF(SECOND,@start_time,@end_time)AS NVARCHAR) + 'Seconds' ;
        PRINT '------------';


        
        PRINT '>> LOADING ERP TABLES';
        PRINT '----------------------';


        --------------- INSERTING INTO TABLE 4 "silver.erp_cust_az12" OF THE SILVER LAYER ----------
        --------------------------------------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table 4 :silver.erp_cust_az12';
        TRUNCATE TABLE silver.erp_cust_az12;
        PRINT '>> Inserting Data in to Table 4 :silver.erp_cust_az12';

        INSERT INTO silver.erp_cust_az12 (
            cid,
            bdate,
            gen
        )
        SELECT 
            CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
                 ELSE cid
            END AS cid,

            CASE WHEN bdate > GETDATE() THEN NULL
                 ELSE bdate
            END AS bdate,

            CASE WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male' 
                 WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
                 ELSE 'n/a'
            END AS gen
        FROM bronze.erp_cust_az12;
        SET @end_time = GETDATE();
        PRINT '>>LOAD Dutation of Table 4 : ' + CAST(DATEDIFF(SECOND,@start_time,@end_time)AS NVARCHAR) + 'Seconds' ;
        PRINT '------------';


        ------------------- INSERT IN TO THE TABLE 5 "silver.erp_loc_a101" OF SILVER LAYER-------------------------------
        -----------------------------------------------------------------------------------------------------------------
        SET @start_time = GETDATE();

        PRINT '>> Truncating Table 5 :silver.erp_loc_a101';
        TRUNCATE TABLE silver.erp_loc_a101;
        PRINT '>> Inserting Data in to Table 5 :silver.erp_loc_a101';

        INSERT INTO silver.erp_loc_a101 (
            cid, 
            cntry
        )
        SELECT  
            REPLACE(cid, '-', '') AS cid,
            CASE WHEN UPPER(TRIM(cntry)) = 'DE' THEN 'Germany'
                 WHEN UPPER(TRIM(cntry)) IN ('US', 'USA') THEN 'United States'
                 WHEN TRIM(cntry) IS NULL OR TRIM(cntry) = '' THEN 'n/a' -- Standardized to 'n/a'
                 ELSE TRIM(cntry) -- Added TRIM to clean whitespace
            END AS cntry
        FROM bronze.erp_loc_a101;
         SET @end_time = GETDATE();
        PRINT '>>LOAD Dutation of Table 5 : ' + CAST(DATEDIFF(SECOND,@start_time,@end_time)AS NVARCHAR) + 'Seconds' ;
        PRINT '------------';


        ---------------- INSERT IN TO THE TABLE 6 "silver.erp_px_cat_g1v2" OF SILVER LAYER---------------
        --------------------------------------------------------------------
        SET @start_time = GETDATE();

        PRINT '>> Truncating Table 6 :silver.erp_px_cat_g1v2';
        TRUNCATE TABLE silver.erp_px_cat_g1v2;
        PRINT '>> Inserting Data in to Table 6 :silver.erp_px_cat_g1v2';

        INSERT INTO silver.erp_px_cat_g1v2 (
            id, 
            cat, 
            subcat, 
            maintenance
        )
        SELECT 
            id, 
            cat, 
            subcat, 
            maintenance 
        FROM bronze.erp_px_cat_g1v2;
         SET @end_time = GETDATE();
        PRINT '>> LOAD Dutation of Table 6 : ' + CAST(DATEDIFF(SECOND,@start_time,@end_time)AS NVARCHAR) + 'Seconds' ;
        PRINT '------------';


        SET @batch_end_time = GETDATE();
        PRINT '===================================='
        PRINT 'LOADING SILVER LAYER IS COMPLETED'
        PRINT '>> LOAD Dutation for Batch Loading : ' + CAST(DATEDIFF(SECOND,@batch_start_time,@batch_end_time)AS NVARCHAR) + 'Seconds' ;
        PRINT '===================================';

    END TRY

    BEGIN CATCH
        PRINT '=======================================================';
        PRINT 'ERROR OCCURED DURING THE DATA LOADING INTO SILVER LAYER';
        PRINT 'ERROR MESSAGE' + ERROR_MESSAGE();
        PRINT 'ERROR MESSAGE' + CAST(ERROR_NUMBER() AS VARCHAR);
        PRINT 'ERROR MESSAGE' + CAST(ERROR_STATE() AS VARCHAR);
        PRINT '=======================================================';


    END CATCH

END;
GO

-- Execute the stored procedure after creation
EXEC silver.load_silver;
GO
