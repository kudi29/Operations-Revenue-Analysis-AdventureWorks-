-- =============================================================================
-- Description : Inspect column names and data types for Silver tables
-- =============================================================================
SELECT 
	table_name, 
	column_name, 
	data_type,
	is_nullable
FROM information_schema.columns
WHERE table_schema = 'silver'
ORDER BY table_name, ordinal_position;


-- =============================================================================
-- Description : Primary key uniqueness audits (Silver)
-- Expected    : 0 rows returned for each
-- =============================================================================
SELECT 
	customer_key, 
	COUNT(*) AS row_count
FROM silver.customer
GROUP BY customer_key
HAVING COUNT(*) > 1;

SELECT 
	product_key, 
	COUNT(*) AS row_count
FROM silver.product
GROUP BY product_key
HAVING COUNT(*) > 1;

SELECT 
	reseller_key, 
	COUNT(*) AS row_count
FROM silver.reseller
GROUP BY reseller_key
HAVING COUNT(*) > 1;

SELECT 
	sales_territory_key, 
	COUNT(*) AS row_count
FROM silver.sales_territory
GROUP BY sales_territory_key
HAVING COUNT(*) > 1;

SELECT 
	date_key, 
	COUNT(*) AS row_count
FROM silver.date
GROUP BY date_key
HAVING COUNT(*) > 1;


-- =============================================================================
-- Description : Verify fact grain and line-item key uniqueness in Silver
-- Expected    : total_rows = unique_line_keys
-- =============================================================================
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT sales_order_line_key) AS unique_line_keys
FROM silver.sales;


-- =============================================================================
-- Description : Verify the order-data join source is unique on the line key
-- Purpose     : A duplicate here would fan out the fact load join and inflate sales
-- Expected    : total_rows = unique_line_keys
-- =============================================================================
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT sales_order_line_key) AS unique_line_keys
FROM silver.sales_order_data;



-- ======================DDL ===================================================


CREATE SCHEMA IF NOT EXISTS gold;


-- =============================================================================
-- Description : Dimension tables
-- =============================================================================
CREATE TABLE IF NOT EXISTS gold.dim_customer (
    customer_key INT PRIMARY KEY,
    customer_id TEXT,
    customer_name TEXT,
    city TEXT,
    state_province TEXT,
    country_region TEXT,
    postal_code TEXT
);

CREATE TABLE IF NOT EXISTS gold.dim_product (
    product_key INT PRIMARY KEY,
    sku TEXT,
    product TEXT,
    standard_cost NUMERIC(19,4),
    color TEXT,
    list_price NUMERIC(19,4),
    model TEXT,
    subcategory TEXT,
    category TEXT
);

CREATE TABLE IF NOT EXISTS gold.dim_reseller (
    reseller_key INT PRIMARY KEY,
    reseller_id TEXT,
    business_type TEXT,
    reseller_name TEXT,
    city TEXT,
    state_province TEXT,
    country_region TEXT,
    postal_code TEXT
);

CREATE TABLE IF NOT EXISTS gold.dim_sales_territory (
    sales_territory_key INT PRIMARY KEY,
    region TEXT,
    country TEXT,
    territory_group TEXT
);

CREATE TABLE IF NOT EXISTS gold.dim_date (
    date_key INT PRIMARY KEY,
    date_val DATE,
    fiscal_year TEXT,
    fiscal_quarter TEXT,
    month_name TEXT,
    month_key INT
);


-- =============================================================================
-- Description : Fact table (one record per sales order line item)
-- =============================================================================
CREATE TABLE IF NOT EXISTS gold.fact_sales (
    sales_order_line_key INT PRIMARY KEY,
    sales_order TEXT,
    sales_order_line TEXT,
    channel TEXT,
    reseller_key INT,
    customer_key INT,
    product_key INT,
    order_date_key INT,
    due_date_key INT,
    ship_date_key INT,
    sales_territory_key INT,
    order_quantity INT,
    unit_price NUMERIC(19,4),
    extended_amount  NUMERIC(19,4),
    unit_price_discount_pct NUMERIC(7,4),
    product_standard_cost NUMERIC(19,4),
    total_product_cost NUMERIC(19,4),
    sales_amount NUMERIC(19,4)
);


-- =============================================================================
-- Description : Foreign keys (dropped and re-added so reruns never error)
-- =============================================================================
ALTER TABLE gold.fact_sales DROP CONSTRAINT IF EXISTS fk_product;
ALTER TABLE gold.fact_sales ADD CONSTRAINT fk_product
    FOREIGN KEY (product_key) REFERENCES gold.dim_product(product_key);

ALTER TABLE gold.fact_sales DROP CONSTRAINT IF EXISTS fk_reseller;
ALTER TABLE gold.fact_sales ADD CONSTRAINT fk_reseller
    FOREIGN KEY (reseller_key) REFERENCES gold.dim_reseller(reseller_key);

ALTER TABLE gold.fact_sales DROP CONSTRAINT IF EXISTS fk_customer;
ALTER TABLE gold.fact_sales ADD CONSTRAINT fk_customer
    FOREIGN KEY (customer_key) REFERENCES gold.dim_customer(customer_key);

ALTER TABLE gold.fact_sales DROP CONSTRAINT IF EXISTS fk_territory;
ALTER TABLE gold.fact_sales ADD CONSTRAINT fk_territory
    FOREIGN KEY (sales_territory_key) REFERENCES gold.dim_sales_territory(sales_territory_key);

ALTER TABLE gold.fact_sales DROP CONSTRAINT IF EXISTS fk_date;
ALTER TABLE gold.fact_sales ADD CONSTRAINT fk_date
    FOREIGN KEY (order_date_key) REFERENCES gold.dim_date(date_key);

ALTER TABLE gold.fact_sales DROP CONSTRAINT IF EXISTS fk_due_date;
ALTER TABLE gold.fact_sales ADD CONSTRAINT fk_due_date
    FOREIGN KEY (due_date_key) REFERENCES gold.dim_date(date_key);

ALTER TABLE gold.fact_sales DROP CONSTRAINT IF EXISTS fk_ship_date;
ALTER TABLE gold.fact_sales ADD CONSTRAINT fk_ship_date
    FOREIGN KEY (ship_date_key) REFERENCES gold.dim_date(date_key);


-- =============================================================================
-- Description : Indexes on fact foreign keys (speeds up joins and Power BI)
-- =============================================================================
CREATE INDEX IF NOT EXISTS ix_fact_sales_product   ON gold.fact_sales (product_key);
CREATE INDEX IF NOT EXISTS ix_fact_sales_reseller  ON gold.fact_sales (reseller_key);
CREATE INDEX IF NOT EXISTS ix_fact_sales_customer  ON gold.fact_sales (customer_key);
CREATE INDEX IF NOT EXISTS ix_fact_sales_territory ON gold.fact_sales (sales_territory_key);
CREATE INDEX IF NOT EXISTS ix_fact_sales_order_dt  ON gold.fact_sales (order_date_key);


-- #############################################################################
-- LOAD
-- Run this whole block together. It is one transaction, so a failure leaves
-- gold empty instead of half-loaded. If it errors, run ROLLBACK; then retry.
-- #############################################################################

BEGIN;

-- Customer dimension
INSERT INTO gold.dim_customer
SELECT
    customer_key,
	customer_id, 
	customer_name, 
	city, 
	state_province, 
	country_region, 
	postal_code
FROM silver.customer;

-- Product dimension
INSERT INTO gold.dim_product
SELECT
    product_key, 
	sku, 
	product, 
	standard_cost, 
	color, 
	list_price, 
	model, 
	subcategory, 
	category
FROM silver.product;

-- Reseller dimension
INSERT INTO gold.dim_reseller
SELECT
    reseller_key, 
	reseller_id, 
	business_type, 
	reseller_name, 
	city, 
	state_province, 
	country_region, 
	postal_code
FROM silver.reseller;

-- Sales territory dimension
INSERT INTO gold.dim_sales_territory
SELECT
    sales_territory_key, 
	region, 
	country, 
	territory_group
FROM silver.sales_territory;

-- Date dimension (month_name derived from date_val)
INSERT INTO gold.dim_date
SELECT
    date_key,
    date_val,
    fiscal_year,
    fiscal_quarter,
    TO_CHAR(date_val, 'Mon') AS month_name,
    month_key
FROM silver.date;

-- Sales fact (silver.sales facts and keys joined to silver.sales_order_data)
INSERT INTO gold.fact_sales
SELECT
    s.sales_order_line_key,
    o.sales_order,
    o.sales_order_line,
    o.channel,
    s.reseller_key,
    s.customer_key,
    s.product_key,
    s.order_date_key,
    s.due_date_key,
    s.ship_date_key,
    s.sales_territory_key,
    s.order_quantity,
    s.unit_price,
    s.extended_amount,
    s.unit_price_discount_pct,
    s.product_standard_cost,
    s.total_product_cost,
    s.sales_amount
FROM silver.sales s
INNER JOIN silver.sales_order_data o
    ON s.sales_order_line_key = o.sales_order_line_key;

COMMIT;

-- Refresh planner statistics after the bulk load
ANALYZE gold.dim_customer;
ANALYZE gold.dim_product;
ANALYZE gold.dim_reseller;
ANALYZE gold.dim_sales_territory;
ANALYZE gold.dim_date;
ANALYZE gold.fact_sales;


-- #############################################################################
-- VALIDATION
-- #############################################################################

-- =============================================================================
-- Description : Grain audit (Gold fact)
-- Expected    : total_rows = unique_line_keys
-- =============================================================================
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT sales_order_line_key) AS unique_line_keys
FROM gold.fact_sales;


-- =============================================================================
-- Description : Control totals, Silver vs Gold
-- Expected    : both result sets identical (an inner-join row loss shows here)
-- =============================================================================
SELECT 'silver' AS layer,
       COUNT(*) AS rows,
       SUM(order_quantity) AS total_quantity,
       SUM(sales_amount) AS total_sales,
       SUM(total_product_cost) AS total_cost
FROM silver.sales
UNION ALL
SELECT 'gold',
       COUNT(*),
       SUM(order_quantity),
       SUM(sales_amount),
       SUM(total_product_cost)
FROM gold.fact_sales;


-- =============================================================================
-- ORPHAN CHECKS (gold.fact_sales)
-- Pattern     : NOT EXISTS against the dimension; NULL keys are skipped here and
--               profiled separately in the null profile below.
-- Expected    : 0 for every check
-- =============================================================================
SELECT COUNT(*) AS missing_customer_keys
FROM gold.fact_sales f
WHERE f.customer_key IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM gold.dim_customer c WHERE c.customer_key = f.customer_key);

SELECT COUNT(*) AS missing_reseller_keys
FROM gold.fact_sales f
WHERE f.reseller_key IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM gold.dim_reseller r WHERE r.reseller_key = f.reseller_key);

SELECT COUNT(*) AS missing_product_keys
FROM gold.fact_sales f
WHERE f.product_key IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM gold.dim_product p WHERE p.product_key = f.product_key);

SELECT COUNT(*) AS missing_territory_keys
FROM gold.fact_sales f
WHERE f.sales_territory_key IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM gold.dim_sales_territory t WHERE t.sales_territory_key = f.sales_territory_key);

SELECT COUNT(*) AS missing_order_dates
FROM gold.fact_sales f
WHERE f.order_date_key IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM gold.dim_date d WHERE d.date_key = f.order_date_key);

SELECT COUNT(*) AS missing_due_dates
FROM gold.fact_sales f
WHERE f.due_date_key IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM gold.dim_date d WHERE d.date_key = f.due_date_key);

SELECT COUNT(*) AS missing_ship_dates
FROM gold.fact_sales f
WHERE f.ship_date_key IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM gold.dim_date d WHERE d.date_key = f.ship_date_key);


-- =============================================================================
-- Description : Key profile by channel (NULLs and -1 sentinels)
-- Purpose     : Confirms how each channel represents "no reseller" / "no
--               customer", and that always-required keys are fully populated.
-- Expected    : Internet -> reseller_sentinel = row_count, customer_sentinel = 0
--               Reseller -> customer_sentinel = row_count, reseller_sentinel = 0
--               All rows -> null_reseller = null_customer = 0
--                           null_product = null_territory = null_order_date = 0
--               (silver maps "no reseller" and "no customer" to key -1)
-- =============================================================================
SELECT
    channel,
    COUNT(*) AS row_count,
    COUNT(*) FILTER (WHERE reseller_key = -1) AS reseller_sentinel,
    COUNT(*) FILTER (WHERE customer_key = -1) AS customer_sentinel,
    COUNT(*) FILTER (WHERE reseller_key IS NULL) AS null_reseller,
    COUNT(*) FILTER (WHERE customer_key IS NULL) AS null_customer,
    COUNT(*) FILTER (WHERE product_key IS NULL) AS null_product,
    COUNT(*) FILTER (WHERE sales_territory_key IS NULL) AS null_territory,
    COUNT(*) FILTER (WHERE order_date_key IS NULL) AS null_order_date
FROM gold.fact_sales
GROUP BY channel
ORDER BY channel;


-- =============================================================================
-- Description : High-level KPIs (compare against Power BI)
-- =============================================================================
SELECT
    SUM(sales_amount) AS total_sales,
    SUM(total_product_cost) AS total_cost,
    SUM(sales_amount - total_product_cost) AS gross_profit,
    SUM(order_quantity) AS total_units
FROM gold.fact_sales;


-- #############################################################################
-- ANALYSIS
-- #############################################################################

-- =============================================================================
-- Description : Product Category Fiscal Year Performance & YoY Growth Analysis
-- Metrics     : Sales, Gross Profit, Profit Margin %, YoY Growth %, Margin Points Change
-- Granularity : Product Category x Fiscal Year
-- Note        : The WHERE clause excludes June 16-30 of every year. The source
--               data ends partway through June of the final fiscal year, so that
--               year is incomplete. Dropping the same late-June window from every
--               fiscal year keeps the periods like-for-like and prevents the
--               partial final year from showing a misleading YoY decline.
--               If the data load is extended past June 15, revisit this filter.
-- =============================================================================
WITH fy AS (
  SELECT p.category, 
  		 d.fiscal_year,
         SUM(f.sales_amount) AS sales,
         SUM(f.sales_amount - f.total_product_cost) AS gross_profit
  FROM gold.fact_sales f
  JOIN gold.dim_product p ON f.product_key = p.product_key
  JOIN gold.dim_date d ON f.order_date_key = d.date_key
  WHERE NOT (EXTRACT(MONTH FROM d.date_val) = 6 AND EXTRACT(DAY FROM d.date_val) > 15)
  GROUP BY p.category, d.fiscal_year
), m AS (
  SELECT *, gross_profit / NULLIF(sales,0) * 100 AS margin_pct FROM fy
)
SELECT category, fiscal_year,
       ROUND(sales) AS sales,
       ROUND(gross_profit) AS gross_profit,
       ROUND(margin_pct,2) AS margin_pct,
       ROUND((sales / NULLIF(LAG(sales) OVER w,0) - 1) * 100, 1) AS sales_yoy_pct,
       ROUND((gross_profit / NULLIF(LAG(gross_profit) OVER w,0) - 1) * 100, 1) AS profit_yoy_pct,
       ROUND(margin_pct - LAG(margin_pct) OVER w, 2) AS margin_change_pts
FROM m
WINDOW w AS (PARTITION BY category ORDER BY fiscal_year)
ORDER BY category, fiscal_year;


-- =============================================================================
-- Description : Audit Touring Bikes Cost vs. List Price Variances
-- Filters     : Subcategory = 'touring bikes'
-- =============================================================================
SELECT
    product_key,
    product,
    subcategory,
    standard_cost,
    list_price,
    (list_price - standard_cost) AS unit_margin_amount,
    ROUND(((list_price - standard_cost) / NULLIF(list_price, 0)) * 100, 2) AS list_margin_pct
FROM gold.dim_product
WHERE LOWER(subcategory) = 'touring bikes'
ORDER BY list_margin_pct ASC, unit_margin_amount ASC;


-- =============================================================================
-- Description : Audit Realized Sales Price vs. List Price Variance (Touring Bikes)
-- Purpose     : Quantifies line-item discounting and margin leakage per SKU
-- Note        : avg_effective_unit_price and avg_unit_cost are unweighted
--               line-level averages. Use SUM(sales_amount) / SUM(order_quantity)
--               for the volume-weighted price.
-- =============================================================================
SELECT
    p.product_key,
    p.product,
    p.standard_cost,
    p.list_price,
    ROUND(AVG(f.sales_amount / NULLIF(f.order_quantity, 0)), 2) AS avg_effective_unit_price,
    ROUND(SUM(f.sales_amount) / NULLIF(SUM(f.order_quantity), 0), 2) AS weighted_unit_price,
    ROUND(AVG(f.total_product_cost / NULLIF(f.order_quantity, 0)), 2) AS avg_unit_cost,
    SUM(f.order_quantity) AS total_units_sold,
    SUM(f.sales_amount) AS total_realized_sales,
    SUM(f.sales_amount - f.total_product_cost) AS total_realized_profit,
    ROUND((SUM(f.sales_amount - f.total_product_cost) / NULLIF(SUM(f.sales_amount), 0)) * 100, 2) AS realized_margin_pct
FROM gold.fact_sales f
JOIN gold.dim_product p
    ON f.product_key = p.product_key
WHERE LOWER(p.subcategory) = 'touring bikes'
GROUP BY p.product_key, p.product, p.standard_cost, p.list_price
ORDER BY realized_margin_pct ASC;


-- =============================================================================
-- Description : Isolate Loss-Making Touring Bike Sales by Reseller / Territory
-- Purpose     : Identifies specific resellers/regions approving below-cost sales
-- Note        : Internet-channel rows carry the -1 reseller sentinel, so they
--               appear under reseller_name 'Direct / Non-Reseller'. This query
--               and the drill-down below therefore cover both channels. Add
--               WHERE f.channel = 'Reseller' to restrict to resellers only.
-- =============================================================================
SELECT
    r.reseller_name,
    t.region,
    p.product,
    SUM(f.order_quantity) AS units_sold,
    ROUND(AVG(f.sales_amount / NULLIF(f.order_quantity, 0)), 2) AS avg_selling_price,
    p.standard_cost,
    SUM(f.sales_amount - f.total_product_cost) AS total_realized_profit
FROM gold.fact_sales f
JOIN gold.dim_product p
    ON f.product_key = p.product_key
LEFT JOIN gold.dim_reseller r
    ON f.reseller_key = r.reseller_key
LEFT JOIN gold.dim_sales_territory t
    ON f.sales_territory_key = t.sales_territory_key
WHERE LOWER(p.subcategory) = 'touring bikes'
GROUP BY r.reseller_name, t.region, p.product, p.standard_cost
HAVING SUM(f.sales_amount - f.total_product_cost) < 0
ORDER BY total_realized_profit ASC;


-- =============================================================================
-- Description : Isolate Loss-Making Touring Bike Line Transactions
-- Purpose     : Details price variances and per-unit loss for unprofitable rows
-- =============================================================================
SELECT
    p.product,
    f.order_quantity,
    f.unit_price,
    f.unit_price_discount_pct,
    ROUND(f.unit_price * (1 - f.unit_price_discount_pct), 2) AS expected_selling_price,
    ROUND(f.sales_amount / NULLIF(f.order_quantity, 0), 2) AS realized_selling_price,
    p.standard_cost,
    ROUND((f.sales_amount / NULLIF(f.order_quantity, 0)) - p.standard_cost, 2) AS profit_per_unit,
    ROUND(f.sales_amount - f.total_product_cost, 2) AS total_profit
FROM gold.fact_sales f
JOIN gold.dim_product p
    ON f.product_key = p.product_key
WHERE LOWER(p.subcategory) = 'touring bikes'
  AND f.sales_amount - f.total_product_cost < 0
ORDER BY total_profit ASC;


-- =============================================================================
-- Description : Loss-Making Touring Bikes Drilled Down by Reseller & Model
-- Purpose     : Shows line counts, pricing metrics, and total net loss per reseller
-- Note        : Internet rows join to the -1 sentinel and appear under
--               'Direct / Non-Reseller'. Add f.channel = 'Reseller' to the
--               WHERE clause to restrict to real resellers.
-- =============================================================================
SELECT
    r.reseller_name,
    t.region AS territory,
    p.product AS touring_bike_model,
    COUNT(*) AS loss_transaction_count,
    SUM(f.order_quantity) AS total_units_sold_below_cost,

    -- Pricing & cost metrics per unit
    ROUND(AVG(f.unit_price), 2) AS avg_unit_list_price,
    ROUND(AVG(f.sales_amount / NULLIF(f.order_quantity, 0)), 2) AS avg_realized_unit_price,
    ROUND(AVG(p.standard_cost), 2) AS avg_unit_standard_cost,
    ROUND(AVG(f.unit_price_discount_pct) * 100, 2) AS avg_discount_pct,

    -- Financial loss totals
    ROUND(SUM(f.sales_amount), 2) AS total_sales_amount,
    ROUND(SUM(f.total_product_cost), 2) AS total_product_cost,
    ROUND(SUM(f.sales_amount - f.total_product_cost), 2) AS total_net_loss
FROM gold.fact_sales f
JOIN gold.dim_reseller r
    ON f.reseller_key = r.reseller_key
JOIN gold.dim_sales_territory t
    ON f.sales_territory_key = t.sales_territory_key
JOIN gold.dim_product p
    ON f.product_key = p.product_key
WHERE LOWER(p.subcategory) = 'touring bikes'
  AND f.sales_amount - f.total_product_cost < 0
GROUP BY r.reseller_name, t.region, p.product
ORDER BY total_net_loss ASC;


-- =============================================================================
-- Description : Aggregate Touring Bikes Channel & Model Metrics
-- Purpose     : Compares volume, gross profit, margin %, and pricing by channel
-- =============================================================================
SELECT
    f.channel,
    p.product,
    SUM(f.order_quantity) AS units_sold,
    ROUND(SUM(f.sales_amount), 2) AS total_sales,
    ROUND(SUM(f.total_product_cost), 2) AS total_cost,
    ROUND(SUM(f.sales_amount - f.total_product_cost), 2) AS gross_profit,
    ROUND(SUM(f.sales_amount - f.total_product_cost) / NULLIF(SUM(f.sales_amount), 0) * 100, 2) AS profit_margin_pct,
    ROUND(SUM(f.sales_amount) / NULLIF(SUM(f.order_quantity), 0), 2) AS realized_price_per_unit,
    ROUND(AVG(p.standard_cost), 2) AS standard_cost
FROM gold.fact_sales f
JOIN gold.dim_product p
    ON f.product_key = p.product_key
WHERE LOWER(p.subcategory) = 'touring bikes'
GROUP BY f.channel, p.product
ORDER BY p.product, f.channel;


-- =============================================================================
-- Description : Touring Bikes Channel Variance Analysis
-- Purpose     : Measures realized vs extended amount variances per model/channel
-- =============================================================================
SELECT
    f.channel,
    p.product,
    COUNT(*) AS sales_lines,
    SUM(f.order_quantity) AS units_sold,
    ROUND(SUM(f.sales_amount), 2) AS total_sales,
    ROUND(SUM(f.extended_amount), 2) AS total_extended_amount,
    ROUND(SUM(f.total_product_cost), 2) AS total_cost,
    ROUND(SUM(f.sales_amount - f.total_product_cost), 2) AS gross_profit,
    ROUND(AVG(f.unit_price), 2) AS avg_unit_price,
    ROUND(SUM(f.sales_amount) / NULLIF(SUM(f.order_quantity), 0), 2) AS realized_price_per_unit,
    ROUND(SUM(f.extended_amount) / NULLIF(SUM(f.order_quantity), 0), 2) AS extended_price_per_unit,
    ROUND(AVG(p.standard_cost), 2) AS standard_cost,
    ROUND(SUM(f.sales_amount - f.extended_amount), 2) AS sales_vs_extended_variance
FROM gold.fact_sales f
JOIN gold.dim_product p
    ON f.product_key = p.product_key
WHERE LOWER(p.subcategory) = 'touring bikes'
GROUP BY f.channel, p.product
ORDER BY p.product, f.channel;


-- =============================================================================
-- Description : Touring Bikes High-Level Channel Summary Profitability
-- Purpose     : Internet (E-Commerce) vs Reseller channel comparison
-- =============================================================================
SELECT
    f.channel,
    SUM(f.order_quantity) AS units_sold,
    ROUND(SUM(f.sales_amount), 2) AS total_sales,
    ROUND(SUM(f.total_product_cost), 2) AS total_cost,
    ROUND(SUM(f.sales_amount - f.total_product_cost), 2) AS gross_profit,
    ROUND(SUM(f.sales_amount - f.total_product_cost) / NULLIF(SUM(f.sales_amount), 0) * 100, 2) AS profit_margin_pct,
    ROUND(SUM(f.sales_amount) / NULLIF(SUM(f.order_quantity), 0), 2) AS realized_price_per_unit,
    ROUND(SUM(f.extended_amount) / NULLIF(SUM(f.order_quantity), 0), 2) AS extended_price_per_unit
FROM gold.fact_sales f
JOIN gold.dim_product p
    ON f.product_key = p.product_key
WHERE LOWER(p.subcategory) = 'touring bikes'
GROUP BY f.channel
ORDER BY gross_profit;