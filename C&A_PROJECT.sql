-- ============================================================
-- URBAN RETAIL CO. — INVENTORY ANALYSIS PROJECT
-- ============================================================
-- HOW TO RUN: Execute each section one at a time (top to bottom)
-- Select the block you want → press Ctrl+Shift+Enter to run it
-- ============================================================


-- ============================================================
-- SECTION 1: CREATE DATABASE
-- ============================================================
CREATE DATABASE Urban_Retail_Co;
USE Urban_Retail_Co;


-- ============================================================
-- SECTION 2: RAW DATA TABLE (import your Excel data into this)
-- After creating this table, right-click it in the left panel
-- → Table Data Import Wizard → select your Excel/CSV file
-- ============================================================
CREATE TABLE inventory_rawdata (
    Date DATE,
    Store_ID VARCHAR(10),
    Product_ID VARCHAR(10),
    Category VARCHAR(50),
    Region VARCHAR(50),
    Inventory_Level INT,
    Units_Sold INT,
    Units_Ordered INT,
    Demand_Forecast FLOAT,
    Price FLOAT,
    Discount INT,
    Weather_Condition VARCHAR(20),
    Holiday_Promotion BOOLEAN,
    Competitor_Pricing FLOAT,
    Seasonality VARCHAR(20)
);

-- Verify data loaded correctly
SELECT * FROM inventory_rawdata LIMIT 10;


-- ============================================================
-- SECTION 3: NORMALIZE INTO CLEAN TABLES
-- We split the raw data into 4 focused tables:
-- stores, products, inventory_facts, environment
-- ============================================================

-- Table 1: Stores (unique store + region combinations)
CREATE TABLE stores (
    st_no INT AUTO_INCREMENT PRIMARY KEY,
    Store_ID VARCHAR(10),
    Region VARCHAR(50)
);

INSERT INTO stores (Store_ID, Region)
SELECT DISTINCT Store_ID, Region
FROM inventory_rawdata;

SELECT * FROM stores LIMIT 5;


-- Table 2: Products (unique product + category combinations)
CREATE TABLE products (
    Product_ID VARCHAR(10) PRIMARY KEY,
    Category VARCHAR(50)
);

INSERT INTO products (Product_ID, Category)
SELECT DISTINCT Product_ID, Category
FROM inventory_rawdata;

SELECT * FROM products LIMIT 5;


-- Table 3: Inventory Facts (daily transactional data)
CREATE TABLE inventory_facts (
    date DATE,
    st_no INT,
    Product_ID VARCHAR(10),
    Inventory_Level INT,
    Units_Sold INT,
    Units_Ordered INT,
    Demand_Forecast FLOAT,
    Discount INT,
    Competitor_Pricing FLOAT,
    FOREIGN KEY (st_no) REFERENCES stores(st_no),
    FOREIGN KEY (Product_ID) REFERENCES products(Product_ID)
);

INSERT INTO inventory_facts (
    date, st_no, Product_ID, Inventory_Level,
    Units_Sold, Units_Ordered, Demand_Forecast, Discount, Competitor_Pricing
)
SELECT
    STR_TO_DATE(ir.Date, '%Y-%m-%d'),
    s.st_no,
    p.Product_ID,
    ir.Inventory_Level,
    ir.Units_Sold,
    ir.Units_Ordered,
    ir.Demand_Forecast,
    ir.Discount,
    ir.Competitor_Pricing
FROM inventory_rawdata ir
JOIN stores s ON ir.Store_ID = s.Store_ID AND ir.Region = s.Region
JOIN products p ON ir.Product_ID = p.Product_ID;


-- Table 4: Environment (weather, holidays, seasonality)
CREATE TABLE environment (
    date DATE,
    st_no INT,
    Weather_Condition VARCHAR(50),
    Holiday_Promotion BOOLEAN,
    Seasonality VARCHAR(50),
    FOREIGN KEY (st_no) REFERENCES stores(st_no)
);

INSERT INTO environment (date, st_no, Weather_Condition, Holiday_Promotion, Seasonality)
SELECT
    STR_TO_DATE(ir.Date, '%Y-%m-%d'),
    s.st_no,
    ir.Weather_Condition,
    ir.Holiday_Promotion,
    ir.Seasonality
FROM inventory_rawdata ir
JOIN stores s ON ir.Store_ID = s.Store_ID AND ir.Region = s.Region;


-- ============================================================
-- SECTION 4: LATEST INVENTORY SNAPSHOT (using CTEs)
-- Shows the most recent stock level for every store-product pair
-- CTE 1 = all store+product combinations
-- CTE 2 = find the latest date for each pair
-- Final  = join to get the actual inventory on that date
-- ============================================================

-- Preview first (before saving as table)
WITH full_combinations AS (
    SELECT s.st_no, s.Store_ID, s.Region, p.Product_ID
    FROM stores s
    CROSS JOIN products p
),
latest_inventory AS (
    SELECT st_no, Product_ID, MAX(date) AS last_inventory_date
    FROM inventory_facts
    GROUP BY st_no, Product_ID
)
SELECT
    fc.st_no, fc.Store_ID, fc.Region, fc.Product_ID,
    li.last_inventory_date,
    f.Inventory_Level
FROM full_combinations fc
LEFT JOIN latest_inventory li ON fc.st_no = li.st_no AND fc.Product_ID = li.Product_ID
LEFT JOIN inventory_facts f ON f.st_no = li.st_no AND f.Product_ID = li.Product_ID AND f.date = li.last_inventory_date
ORDER BY fc.st_no, fc.Store_ID, fc.Product_ID;

-- Table 5: Save snapshot as a table
CREATE TABLE latest_inventory_snapshot AS
WITH full_combinations AS (
    SELECT s.st_no, s.Store_ID, s.Region, p.Product_ID
    FROM stores s
    CROSS JOIN products p
),
latest_inventory AS (
    SELECT st_no, Product_ID, MAX(date) AS last_inventory_date
    FROM inventory_facts
    GROUP BY st_no, Product_ID
)
SELECT
    fc.st_no, fc.Store_ID, fc.Region, fc.Product_ID,
    li.last_inventory_date,
    f.Inventory_Level
FROM full_combinations fc
LEFT JOIN latest_inventory li ON fc.st_no = li.st_no AND fc.Product_ID = li.Product_ID
LEFT JOIN inventory_facts f ON f.st_no = li.st_no AND f.Product_ID = li.Product_ID AND f.date = li.last_inventory_date
ORDER BY fc.st_no, fc.Store_ID, fc.Product_ID;


-- ============================================================
-- SECTION 5: REORDER POINT (ROP)
-- Formula: ROP = (Avg Daily Usage × Lead Time) + Safety Stock
-- We set lead_time = 1 day, safety_stock = 30 units
-- Change these values in the parameters table if needed
-- ============================================================

-- Parameters table (easy to adjust)
CREATE TABLE parameters (
    lead_time_days INT,
    safety_stock INT
);

INSERT INTO parameters (lead_time_days, safety_stock)
VALUES (1, 30);

SELECT * FROM parameters;

-- Table 6: Reorder estimations per store per product
CREATE TABLE reorder_estimations (
    st_no INT,
    Store_ID VARCHAR(10),
    Region VARCHAR(50),
    Product_ID VARCHAR(10),
    avg_daily_usage FLOAT,
    lead_time_days INT,
    safety_stock INT,
    reorder_point INT
);

INSERT INTO reorder_estimations (
    st_no, Store_ID, Region, Product_ID,
    avg_daily_usage, lead_time_days, safety_stock, reorder_point
)
SELECT
    s.st_no, s.Store_ID, s.Region, du.Product_ID,
    ROUND(AVG(du.daily_units), 2) AS avg_daily_usage,
    p.lead_time_days,
    p.safety_stock,
    ROUND(AVG(du.daily_units) * p.lead_time_days + p.safety_stock, 0) AS reorder_point
FROM (
    SELECT f.Product_ID, f.st_no, f.date, SUM(f.Units_Sold) AS daily_units
    FROM inventory_facts f
    GROUP BY f.Product_ID, f.st_no, f.date
) AS du
JOIN stores s ON du.st_no = s.st_no
CROSS JOIN parameters p
GROUP BY s.st_no, s.Store_ID, s.Region, du.Product_ID, p.lead_time_days, p.safety_stock;

SELECT * FROM reorder_estimations;


-- ============================================================
-- SECTION 6: NEED REORDER? (Yes / No flag)
-- Compares current inventory vs reorder point
-- If stock < ROP → needs reorder
-- ============================================================
WITH full_combinations AS (
    SELECT s.st_no, s.Store_ID, s.Region, p.Product_ID
    FROM stores s
    CROSS JOIN products p
)
SELECT
    fc.st_no, fc.Store_ID, fc.Region, fc.Product_ID,
    COALESCE(s.Inventory_Level, 0) AS Inventory_Level,
    r.reorder_point,
    CASE
        WHEN COALESCE(s.Inventory_Level, 0) < r.reorder_point THEN 'Yes'
        ELSE 'No'
    END AS need_reorder
FROM full_combinations fc
LEFT JOIN latest_inventory_snapshot s ON fc.st_no = s.st_no AND fc.Product_ID = s.Product_ID
LEFT JOIN reorder_estimations r ON fc.st_no = r.st_no AND fc.Product_ID = r.Product_ID
ORDER BY fc.st_no, fc.Store_ID, fc.Product_ID;


-- ============================================================
-- SECTION 7: SEASONAL SALES & INVENTORY TABLES
-- ============================================================

-- Table 7: Sales broken down by season per product
CREATE TABLE seasonal_product_sales AS
SELECT
    Product_ID,
    ROUND(SUM(CASE WHEN Seasonality = 'Winter' THEN Units_Sold * Price ELSE 0 END), 0) AS Winter_Sales,
    ROUND(SUM(CASE WHEN Seasonality = 'Summer' THEN Units_Sold * Price ELSE 0 END), 0) AS Summer_Sales,
    ROUND(SUM(CASE WHEN Seasonality = 'Autumn' THEN Units_Sold * Price ELSE 0 END), 0) AS Autumn_Sales,
    ROUND(SUM(CASE WHEN Seasonality = 'Spring' THEN Units_Sold * Price ELSE 0 END), 0) AS Spring_Sales,
    ROUND(SUM(Units_Sold * Price), 0) AS Total_Sales,
    ROUND(SUM(Units_Sold * Price) / 4, 0) AS Avg_Seasonal_Sales
FROM inventory_rawdata
GROUP BY Product_ID;

SELECT * FROM seasonal_product_sales;


-- Table 8: Inventory levels broken down by season per product
CREATE TABLE seasonal_product_inventory AS
SELECT
    Product_ID,
    SUM(CASE WHEN Seasonality = 'Winter' THEN Inventory_Level ELSE 0 END) AS Winter_Inventory,
    SUM(CASE WHEN Seasonality = 'Summer' THEN Inventory_Level ELSE 0 END) AS Summer_Inventory,
    SUM(CASE WHEN Seasonality = 'Autumn' THEN Inventory_Level ELSE 0 END) AS Autumn_Inventory,
    SUM(CASE WHEN Seasonality = 'Spring' THEN Inventory_Level ELSE 0 END) AS Spring_Inventory,
    SUM(Inventory_Level) AS Total_Inventory,
    ROUND(SUM(Inventory_Level) / 4, 2) AS Avg_Seasonal_Inventory
FROM inventory_rawdata
GROUP BY Product_ID;

SELECT * FROM seasonal_product_inventory;


-- ============================================================
-- SECTION 8: SEASONAL KPI REPORT
-- Turnover, Days Inventory Outstanding, Health Status
-- 🟥 Slow = overstock risk | 🟨 Moderate = healthy | 🟩 Fast = stockout risk
-- ============================================================
SELECT
    s.Product_ID,
    season.Seasonality,
    ROUND(CASE season.Seasonality
        WHEN 'Winter' THEN s.Winter_Sales
        WHEN 'Summer' THEN s.Summer_Sales
        WHEN 'Autumn' THEN s.Autumn_Sales
        WHEN 'Spring' THEN s.Spring_Sales
    END, 2) AS Cost_of_Goods_Sold,
    ROUND(CASE season.Seasonality
        WHEN 'Winter' THEN i.Winter_Inventory
        WHEN 'Summer' THEN i.Summer_Inventory
        WHEN 'Autumn' THEN i.Autumn_Inventory
        WHEN 'Spring' THEN i.Spring_Inventory
    END, 2) AS Inventory_Level,
    ROUND(i.Avg_Seasonal_Inventory, 2) AS Avg_Seasonal_Inventory,
    ROUND(CASE season.Seasonality
        WHEN 'Winter' THEN s.Winter_Sales
        WHEN 'Summer' THEN s.Summer_Sales
        WHEN 'Autumn' THEN s.Autumn_Sales
        WHEN 'Spring' THEN s.Spring_Sales
    END / NULLIF(i.Avg_Seasonal_Inventory, 0), 2) AS Inventory_Turnover,
    CASE
        WHEN ROUND(CASE season.Seasonality
            WHEN 'Winter' THEN s.Winter_Sales WHEN 'Summer' THEN s.Summer_Sales
            WHEN 'Autumn' THEN s.Autumn_Sales WHEN 'Spring' THEN s.Spring_Sales
        END / NULLIF(i.Avg_Seasonal_Inventory, 0), 2) < 25 THEN '🟥 Slow – Overstock Risk'
        WHEN ROUND(CASE season.Seasonality
            WHEN 'Winter' THEN s.Winter_Sales WHEN 'Summer' THEN s.Summer_Sales
            WHEN 'Autumn' THEN s.Autumn_Sales WHEN 'Spring' THEN s.Spring_Sales
        END / NULLIF(i.Avg_Seasonal_Inventory, 0), 2) BETWEEN 25 AND 50 THEN '🟨 Moderate – Efficient and No Risk'
        ELSE '🟩 Fast – Risk of Stock out'
    END AS Inventory_Health,
    ROUND(90 / NULLIF(CASE season.Seasonality
        WHEN 'Winter' THEN s.Winter_Sales WHEN 'Summer' THEN s.Summer_Sales
        WHEN 'Autumn' THEN s.Autumn_Sales WHEN 'Spring' THEN s.Spring_Sales
    END / NULLIF(i.Avg_Seasonal_Inventory, 0), 0)) AS Days_Inventory_Outstanding
FROM seasonal_product_sales s
JOIN seasonal_product_inventory i ON s.Product_ID = i.Product_ID
JOIN (
    SELECT 'Winter' AS Seasonality UNION SELECT 'Summer'
    UNION SELECT 'Autumn' UNION SELECT 'Spring'
) AS season
ORDER BY s.Product_ID, season.Seasonality;


-- ============================================================
-- SECTION 9: KPI SUMMARY TABLE (per store per product)
-- Turnover, Inventory Age, Stockout Rate
-- ============================================================
CREATE TABLE KPI_Summary (
    Store_ID VARCHAR(10),
    Product_ID VARCHAR(10),
    Avg_Inventory_Level FLOAT,
    Total_Units_Sold INT,
    Inventory_Turnover FLOAT,
    Inventory_Age FLOAT,
    Stockout_Days INT,
    Total_Days INT,
    Stockout_Rate_Pct FLOAT,
    PRIMARY KEY (Store_ID, Product_ID)
);

INSERT INTO KPI_Summary
SELECT
    s.Store_ID,
    f.Product_ID,
    AVG(f.Inventory_Level) AS Avg_Inventory_Level,
    SUM(f.Units_Sold) AS Total_Units_Sold,
    SUM(f.Units_Sold) / NULLIF(AVG(f.Inventory_Level), 0) AS Inventory_Turnover,
    90 / NULLIF(SUM(f.Units_Sold) / NULLIF(AVG(f.Inventory_Level), 0), 0) AS Inventory_Age,
    SUM(CASE WHEN f.Inventory_Level = 0 THEN 1 ELSE 0 END) AS Stockout_Days,
    COUNT(*) AS Total_Days,
    100.0 * SUM(CASE WHEN f.Inventory_Level = 0 THEN 1 ELSE 0 END) / COUNT(*) AS Stockout_Rate_Pct
FROM inventory_facts f
JOIN stores s ON f.st_no = s.st_no
GROUP BY s.Store_ID, f.Product_ID;

SELECT * FROM KPI_Summary;


-- ============================================================
-- SECTION 10: BUSINESS ANALYTICS QUERIES
-- These are the "insight" queries — great to show in interviews
-- ============================================================

-- Q1: Does higher discount = more demand?
SELECT
    Discount,
    ROUND(AVG(Demand_Forecast), 2) AS avg_demand_forecast,
    ROUND(AVG(Units_Ordered), 2) AS avg_units_ordered
FROM inventory_rawdata
GROUP BY Discount
ORDER BY Discount DESC;


-- Q2: How does our price compare to competitors per category?
SELECT
    Category,
    ROUND(AVG(Price - Competitor_Pricing), 2) AS avg_price_difference,
    ROUND(AVG(Units_Ordered), 2) AS avg_units_ordered
FROM inventory_rawdata
GROUP BY Category
ORDER BY avg_price_difference;


-- Q3: Is each product making profit or loss vs competitors?
SELECT
    Product_ID, Category,
    ROUND(AVG(Price), 2) AS avg_price,
    ROUND(AVG(Competitor_Pricing), 2) AS avg_competitor_price,
    ROUND(AVG(Demand_Forecast), 2) AS avg_demand_forecast,
    CASE
        WHEN AVG(Price) > AVG(Competitor_Pricing) AND AVG(Demand_Forecast) > 100 THEN 'Profit'
        WHEN AVG(Price) > AVG(Competitor_Pricing) AND AVG(Demand_Forecast) < 60  THEN 'Loss – very low demand'
        WHEN AVG(Price) < AVG(Competitor_Pricing) AND AVG(Demand_Forecast) > 100 THEN 'Loss – price too low'
        WHEN AVG(Price) < AVG(Competitor_Pricing) AND AVG(Demand_Forecast) < 60  THEN 'Stop selling this product'
        ELSE 'Stable or inconclusive'
    END AS Business_Status
FROM inventory_rawdata
GROUP BY Product_ID, Category
ORDER BY Product_ID;


-- Q4: Do holiday promotions actually boost orders?
SELECT
    Product_ID, Category,
    ROUND(AVG(CASE WHEN Holiday_Promotion = 1 THEN Units_Ordered ELSE NULL END), 2) AS holiday_orders,
    ROUND(AVG(CASE WHEN Holiday_Promotion = 0 THEN Units_Ordered ELSE NULL END), 2) AS non_holiday_orders,
    ROUND(
        AVG(CASE WHEN Holiday_Promotion = 1 THEN Units_Ordered ELSE NULL END) -
        AVG(CASE WHEN Holiday_Promotion = 0 THEN Units_Ordered ELSE NULL END), 2
    ) AS promo_uplift,
    CASE
        WHEN ROUND(AVG(CASE WHEN Holiday_Promotion = 1 THEN Units_Ordered ELSE NULL END) -
             AVG(CASE WHEN Holiday_Promotion = 0 THEN Units_Ordered ELSE NULL END), 2) >= 25
             THEN 'Promotion drives very high demand – scale up'
        WHEN ROUND(AVG(CASE WHEN Holiday_Promotion = 1 THEN Units_Ordered ELSE NULL END) -
             AVG(CASE WHEN Holiday_Promotion = 0 THEN Units_Ordered ELSE NULL END), 2) BETWEEN 20 AND 24.99
             THEN 'Strong impact – continue promoting'
        WHEN ROUND(AVG(CASE WHEN Holiday_Promotion = 1 THEN Units_Ordered ELSE NULL END) -
             AVG(CASE WHEN Holiday_Promotion = 0 THEN Units_Ordered ELSE NULL END), 2) BETWEEN 15 AND 19.99
             THEN 'Some impact – test if discount is necessary'
        ELSE 'Unclear effect – reevaluate'
    END AS Conclusion
FROM inventory_rawdata
GROUP BY Product_ID, Category
HAVING promo_uplift IS NOT NULL
ORDER BY promo_uplift DESC;


-- Q5: Which weather condition drives the most orders per product?
SELECT
    Product_ID, Category, Weather_Condition,
    ROUND(AVG(Units_Ordered), 2) AS avg_units_ordered,
    RANK() OVER (PARTITION BY Product_ID ORDER BY AVG(Units_Ordered) DESC) AS weather_rank
FROM inventory_rawdata
GROUP BY Product_ID, Category, Weather_Condition
ORDER BY Product_ID, weather_rank;


-- Q6: Seasonal performance — pricing, forecast accuracy, profitability
SELECT
    Product_ID, Category, Seasonality,
    ROUND(AVG(Units_Ordered), 2) AS avg_units_ordered,
    ROUND(AVG(Demand_Forecast), 2) AS avg_demand_forecast,
    ROUND(AVG(Price), 2) AS avg_price,
    ROUND(AVG(Competitor_Pricing), 2) AS avg_competitor_price,
    ROUND(AVG(Discount), 2) AS avg_discount,
    ROUND(AVG(Price - Competitor_Pricing), 2) AS price_gap,
    ROUND(AVG(Units_Ordered) - AVG(Demand_Forecast), 2) AS forecast_accuracy_gap,
    CASE
        WHEN AVG(Units_Ordered) > AVG(Demand_Forecast) AND AVG(Price) > AVG(Competitor_Pricing)
            THEN 'High demand despite higher price – profitable'
        WHEN AVG(Units_Ordered) < AVG(Demand_Forecast) AND AVG(Price) > AVG(Competitor_Pricing)
            THEN 'Overpriced – consider lowering price'
        WHEN AVG(Units_Ordered) < AVG(Demand_Forecast) AND AVG(Price) < AVG(Competitor_Pricing)
            THEN 'Uncompetitive product – likely should delist'
        ELSE 'Stable or needs review'
    END AS seasonal_conclusion
FROM inventory_rawdata
GROUP BY Product_ID, Category, Seasonality
ORDER BY Product_ID, Seasonality;

-- ============================================================
-- END OF PROJECT
-- ============================================================
