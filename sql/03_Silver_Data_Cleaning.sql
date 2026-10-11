SELECT
	table_name,
	column_name,
	data_type,
	is_nullable
FROM information_schema.columns
WHERE table_schema = 'bronze'
ORDER BY table_name, ordinal_position

BEGIN;

-- ================================= Customer ==================================
CREATE TABLE silver.customer (
    customer_key INT,
    customer_id TEXT,
    customer_name TEXT,
    city TEXT,
    state_province TEXT,
    country_region TEXT,
    postal_code TEXT
);

INSERT INTO silver.customer
SELECT
    NULLIF(TRIM("CustomerKey"), '')::INT AS customer_key,
    UPPER(TRIM("Customer ID")) AS customer_id,
    INITCAP(TRIM("Customer")) AS customer_name,
    INITCAP(TRIM("City")) AS city,
    INITCAP(TRIM("State-Province")) AS state_province,
    INITCAP(TRIM("Country-Region")) AS country_region,
    UPPER(TRIM("Postal-Code")) AS postal_code
FROM bronze.customer
WHERE NULLIF(TRIM("CustomerKey"), '') IS NOT NULL
  AND NULLIF(TRIM("CustomerKey"), '')::INT > 0;


-- ================================== Product ==================================
CREATE TABLE silver.product (
    product_key INT,
    sku TEXT,
    product TEXT,
    standard_cost NUMERIC(19,4),
    color TEXT,
    list_price NUMERIC(19,4),
    model TEXT,
    subcategory TEXT,
    category TEXT
);

INSERT INTO silver.product
SELECT
    NULLIF(TRIM("ProductKey"), '')::INT AS product_key,
    UPPER(TRIM("SKU")) AS sku,
    INITCAP(TRIM("Product")) AS product,
    REGEXP_REPLACE("Standard Cost", '[$,]', '', 'g')::NUMERIC(19,4) AS standard_cost,
    INITCAP(TRIM("Color")) AS color,
    REGEXP_REPLACE("List Price", '[$,]', '', 'g')::NUMERIC(19,4) AS list_price,
    INITCAP(TRIM("Model")) AS model,
    INITCAP(TRIM("Subcategory")) AS subcategory,
    INITCAP(TRIM("Category")) AS category
FROM bronze.product
WHERE NULLIF(TRIM("ProductKey"), '') IS NOT NULL
  AND NULLIF(TRIM("ProductKey"), '')::INT > 0;


-- =================================== Date ====================================
CREATE TABLE silver.date (
    date_key INT,
    date_val DATE,
    fiscal_year TEXT,
    fiscal_quarter TEXT,
    month_name TEXT,
    full_date TEXT,
    month_key INT
);

INSERT INTO silver.date
SELECT
    NULLIF(TRIM("DateKey"), '')::INT AS date_key,
    "Date"::DATE AS date_val,
    UPPER(TRIM("Fiscal Year")) AS fiscal_year,
    UPPER(TRIM("Fiscal Quarter")) AS fiscal_quarter,
    INITCAP(TRIM("Month")) AS month_name,
    TRIM("Full Date") AS full_date,
    "Monthkey"::INT AS month_key
FROM bronze.date
WHERE NULLIF(TRIM("DateKey"), '') IS NOT NULL
  AND NULLIF(TRIM("DateKey"), '')::INT > 0;


-- ================================== Reseller =================================
CREATE TABLE silver.reseller (
    reseller_key INT,
    reseller_id TEXT,
    business_type TEXT,
    reseller_name TEXT,
    city TEXT,
    state_province TEXT,
    country_region TEXT,
    postal_code TEXT
);

INSERT INTO silver.reseller
SELECT
    NULLIF(TRIM("ResellerKey"), '')::INT AS reseller_key,
    UPPER(TRIM("Reseller ID")) AS reseller_id,
    INITCAP(TRIM("Business Type")) AS business_type,
    INITCAP(TRIM("Reseller")) AS reseller_name,
    INITCAP(TRIM("City")) AS city,
    INITCAP(TRIM("State-Province")) AS state_province,
    INITCAP(TRIM("Country-Region")) AS country_region,
    UPPER(TRIM("Postal Code")) AS postal_code
FROM bronze.reseller
WHERE NULLIF(TRIM("ResellerKey"), '') IS NOT NULL
  AND NULLIF(TRIM("ResellerKey"), '')::INT > 0;


-- ============================== Sales Territory ==============================
CREATE TABLE silver.sales_territory (
    sales_territory_key INT,
    region TEXT,
    country TEXT,
    territory_group TEXT
);

INSERT INTO silver.sales_territory
    (sales_territory_key, region, country, territory_group)
SELECT
    NULLIF(TRIM("SalesTerritoryKey"), '')::INT AS sales_territory_key,
    INITCAP(TRIM("Region")) AS region,
    INITCAP(TRIM("Country")) AS country,
    INITCAP(TRIM("Group")) AS territory_group
FROM bronze.SalesTerritory
WHERE NULLIF(TRIM("SalesTerritoryKey"), '') IS NOT NULL
  AND NULLIF(TRIM("SalesTerritoryKey"), '')::INT > 0;


-- =============================== Sales Order Data ============================
CREATE TABLE silver.sales_order_data (
    sales_order_line_key INT,
    channel TEXT,
    sales_order TEXT,
    sales_order_line TEXT
);

INSERT INTO silver.sales_order_data
SELECT
    NULLIF(TRIM("SalesOrderLineKey"), '')::INT AS sales_order_line_key,
    INITCAP(TRIM("Channel")) AS channel,
    UPPER(TRIM("Sales Order")) AS sales_order,
    TRIM("Sales Order Line") AS sales_order_line
FROM bronze.sales_order_data
WHERE NULLIF(TRIM("SalesOrderLineKey"), '') IS NOT NULL
  AND NULLIF(TRIM("SalesOrderLineKey"), '')::INT > 0;


-- ============================ Sales (fact) ===================================
CREATE TABLE silver.sales (
    sales_order_line_key    INT,
    reseller_key            INT,
    customer_key            INT,
    product_key             INT,
    order_date_key          INT,
    due_date_key            INT,
    ship_date_key           INT,
    sales_territory_key     INT,
    order_quantity          INT,
    unit_price              NUMERIC(19,4),
    extended_amount         NUMERIC(19,4),
    unit_price_discount_pct NUMERIC(7,4),
    product_standard_cost   NUMERIC(19,4),
    total_product_cost      NUMERIC(19,4),
    sales_amount            NUMERIC(19,4)
);

-- Money columns arrive as text such as '$1,234.50'; strip symbols, then cast.
INSERT INTO silver.sales
SELECT
    NULLIF(TRIM("SalesOrderLineKey"), '')::INT AS sales_order_line_key,
    NULLIF(TRIM("ResellerKey"), '')::INT AS reseller_key,
    NULLIF(TRIM("CustomerKey"), '')::INT AS customer_key,
    NULLIF(TRIM("ProductKey"), '')::INT AS product_key,
    NULLIF(TRIM("OrderDateKey"), '')::INT AS order_date_key,
    NULLIF(TRIM("DueDateKey"), '')::INT AS due_date_key,
    NULLIF(TRIM("ShipDateKey"), '')::INT AS ship_date_key,
    NULLIF(TRIM("SalesTerritoryKey"), '')::INT AS sales_territory_key,
    NULLIF(TRIM("Order Quantity"), '')::INT AS order_quantity,
    REGEXP_REPLACE("Unit Price", '[$,]', '', 'g')::NUMERIC(19,4) AS unit_price,
    REGEXP_REPLACE("Extended Amount", '[$,]', '', 'g')::NUMERIC(19,4) AS extended_amount,
    REGEXP_REPLACE("Unit Price Discount Pct", '[%,]', '', 'g')::NUMERIC(7,4) AS unit_price_discount_pct,
    REGEXP_REPLACE("Product Standard Cost", '[$,]', '', 'g')::NUMERIC(19,4) AS product_standard_cost,
    REGEXP_REPLACE("Total Product Cost", '[$,]', '', 'g')::NUMERIC(19,4) AS total_product_cost,
    REGEXP_REPLACE("Sales Amount", '[$,]', '', 'g')::NUMERIC(19,4) AS sales_amount
FROM bronze.salesdata
WHERE NULLIF(TRIM("SalesOrderLineKey"), '') IS NOT NULL
  AND NULLIF(TRIM("SalesOrderLineKey"), '')::INT > 0;


-- #############################################################################
-- DIMENSION CONSTRAINTS
-- #############################################################################

ALTER TABLE silver.customer
    ADD CONSTRAINT pk_silver_customer PRIMARY KEY (customer_key),
    ALTER COLUMN customer_key SET NOT NULL,
    ALTER COLUMN customer_id SET NOT NULL,
    ALTER COLUMN customer_name SET NOT NULL;

ALTER TABLE silver.product
    ADD CONSTRAINT pk_silver_product PRIMARY KEY (product_key),
    ALTER COLUMN product_key SET NOT NULL,
    ALTER COLUMN product SET NOT NULL,
    ADD CONSTRAINT chk_product_standard_cost CHECK (standard_cost >= 0),
    ADD CONSTRAINT chk_product_list_price CHECK (list_price >= 0);

ALTER TABLE silver.reseller
    ADD CONSTRAINT pk_silver_reseller PRIMARY KEY (reseller_key),
    ALTER COLUMN reseller_key  SET NOT NULL,
    ALTER COLUMN reseller_name SET NOT NULL;

ALTER TABLE silver.date
    ADD CONSTRAINT pk_silver_date PRIMARY KEY (date_key),
    ALTER COLUMN date_key SET NOT NULL,
    ALTER COLUMN date_val SET NOT NULL;

ALTER TABLE silver.sales_territory
    ADD CONSTRAINT pk_silver_sales_territory PRIMARY KEY (sales_territory_key),
    ALTER COLUMN sales_territory_key SET NOT NULL,
    ALTER COLUMN region SET NOT NULL,
    ALTER COLUMN country SET NOT NULL;

ALTER TABLE silver.sales_order_data
    ADD CONSTRAINT pk_silver_sales_order_data PRIMARY KEY (sales_order_line_key),
    ALTER COLUMN sales_order_line_key SET NOT NULL,
    ALTER COLUMN sales_order SET NOT NULL;


-- #############################################################################
-- SENTINEL ROWS (key = -1)
-- Must run after the primary keys above and before the fact foreign keys below.
-- #############################################################################

-- Customer: Reseller-channel sales have no individual customer
-- (the source stores these rows with customer_key = -1)
INSERT INTO silver.customer
    (customer_key, customer_id, customer_name, city, state_province, country_region, postal_code)
VALUES
    (-1, 'N/A', 'Reseller / Non-Customer', 'N/A', 'N/A', 'N/A', 'N/A')
ON CONFLICT (customer_key) DO NOTHING;

-- Reseller: Internet-channel sales have no reseller
INSERT INTO silver.reseller
    (reseller_key, reseller_id, business_type, reseller_name, city, state_province, country_region, postal_code)
VALUES
    (-1, 'N/A', 'N/A', 'Direct / Non-Reseller', 'N/A', 'N/A', 'N/A', 'N/A')
ON CONFLICT (reseller_key) DO NOTHING;

-- Product
INSERT INTO silver.product
    (product_key, sku, product, standard_cost, list_price)
VALUES
    (-1, 'N/A', 'Not Applicable', 0, 0)
ON CONFLICT (product_key) DO NOTHING;

-- Sales territory
INSERT INTO silver.sales_territory
    (sales_territory_key, region, country, territory_group)
VALUES
    (-1, 'Not Applicable', 'Not Applicable', 'Not Applicable')
ON CONFLICT (sales_territory_key) DO NOTHING;

-- Date
INSERT INTO silver.date
    (date_key, date_val, fiscal_year, fiscal_quarter, month_name, full_date, month_key)
VALUES
    (-1, '1900-01-01', 'N/A', 'N/A', 'Not Applicable', '1900-01-01', -1)
ON CONFLICT (date_key) DO NOTHING;


-- #############################################################################
-- FACT TABLE CONSTRAINTS (silver.sales)
-- #############################################################################

-- Primary key and not-null columns
ALTER TABLE silver.sales
    ADD CONSTRAINT pk_silver_sales PRIMARY KEY (sales_order_line_key),
    ALTER COLUMN sales_order_line_key SET NOT NULL,
    ALTER COLUMN product_key SET NOT NULL,
    ALTER COLUMN order_date_key SET NOT NULL,
    ALTER COLUMN sales_territory_key SET NOT NULL;

-- Foreign keys (referential integrity)
ALTER TABLE silver.sales
    ADD CONSTRAINT fk_sales_customer
        FOREIGN KEY (customer_key) REFERENCES silver.customer(customer_key),
    ADD CONSTRAINT fk_sales_reseller
        FOREIGN KEY (reseller_key) REFERENCES silver.reseller(reseller_key),
    ADD CONSTRAINT fk_sales_product
        FOREIGN KEY (product_key) REFERENCES silver.product(product_key),
    ADD CONSTRAINT fk_sales_order_date
        FOREIGN KEY (order_date_key) REFERENCES silver.date(date_key),
    ADD CONSTRAINT fk_sales_due_date
        FOREIGN KEY (due_date_key) REFERENCES silver.date(date_key),
    ADD CONSTRAINT fk_sales_ship_date
        FOREIGN KEY (ship_date_key) REFERENCES silver.date(date_key),
    ADD CONSTRAINT fk_sales_territory
        FOREIGN KEY (sales_territory_key) REFERENCES silver.sales_territory(sales_territory_key),
    ADD CONSTRAINT fk_sales_order_data
        FOREIGN KEY (sales_order_line_key) REFERENCES silver.sales_order_data(sales_order_line_key);

-- Mathematical integrity and domain checks
ALTER TABLE silver.sales
    ADD CONSTRAINT chk_sales_order_quantity CHECK (order_quantity > 0),
    ADD CONSTRAINT chk_sales_unit_price CHECK (unit_price >= 0),
    ADD CONSTRAINT chk_sales_extended_amount CHECK (extended_amount >= 0),
    ADD CONSTRAINT chk_sales_discount_pct CHECK (unit_price_discount_pct >= 0 AND unit_price_discount_pct <= 1),
    ADD CONSTRAINT chk_sales_amount CHECK (sales_amount >= 0);

COMMIT;


-- #############################################################################
-- POST-LOAD QA AND AUDIT SUITE
-- #############################################################################

-- =============================================================================
-- 1. Row count reconciliation, Bronze vs Silver (all tables)
-- Expected : bronze_count = silver_count for every row
--            (silver counts exclude the -1 sentinel rows)
-- =============================================================================
SELECT 'sales' AS entity,
       (SELECT COUNT(*) FROM bronze.salesdata) AS bronze_count,
       (SELECT COUNT(*) FROM silver.sales) AS silver_count
UNION ALL
SELECT 'sales_order_data',
       (SELECT COUNT(*) FROM bronze.sales_order_data),
       (SELECT COUNT(*) FROM silver.sales_order_data)
UNION ALL
SELECT 'customer',
       (SELECT COUNT(*) FROM bronze.customer),
       (SELECT COUNT(*) FROM silver.customer WHERE customer_key > 0)
UNION ALL
SELECT 'product',
       (SELECT COUNT(*) FROM bronze.product),
       (SELECT COUNT(*) FROM silver.product WHERE product_key > 0)
UNION ALL
SELECT 'reseller',
       (SELECT COUNT(*) FROM bronze.reseller),
       (SELECT COUNT(*) FROM silver.reseller WHERE reseller_key > 0)
UNION ALL
SELECT 'sales_territory',
       (SELECT COUNT(*) FROM bronze.SalesTerritory),
       (SELECT COUNT(*) FROM silver.sales_territory WHERE sales_territory_key > 0)
UNION ALL
SELECT 'date',
       (SELECT COUNT(*) FROM bronze.date),
       (SELECT COUNT(*) FROM silver.date WHERE date_key > 0);


-- =============================================================================
-- 2. Financial totals reconciliation (two independent sums, no join)
-- Expected : variance = 0
-- =============================================================================
SELECT
    b.bronze_total_sales,
    s.silver_total_sales,
    b.bronze_total_sales - s.silver_total_sales AS variance
FROM (
    SELECT SUM(REGEXP_REPLACE("Sales Amount", '[$,]', '', 'g')::NUMERIC(19,4)) AS bronze_total_sales
    FROM bronze.salesdata
) b
CROSS JOIN (
    SELECT SUM(sales_amount) AS silver_total_sales
    FROM silver.sales
) s;


-- =============================================================================
-- 3. Orphan foreign key audit on silver.sales
-- Expected : all 0 (the foreign keys already enforce this, so this is a
--            sanity check that the constraints were created)
-- =============================================================================
SELECT
    COUNT(*) FILTER (WHERE c.customer_key IS NULL AND s.customer_key IS NOT NULL) AS orphan_customer_keys,
    COUNT(*) FILTER (WHERE r.reseller_key IS NULL AND s.reseller_key IS NOT NULL)  AS orphan_reseller_keys,
    COUNT(*) FILTER (WHERE p.product_key IS NULL AND s.product_key IS NOT NULL) AS orphan_product_keys,
    COUNT(*) FILTER (WHERE t.sales_territory_key IS NULL AND s.sales_territory_key IS NOT NULL) AS orphan_territory_keys
FROM silver.sales s
LEFT JOIN silver.customer c ON s.customer_key = c.customer_key
LEFT JOIN silver.reseller r ON s.reseller_key = r.reseller_key
LEFT JOIN silver.product p ON s.product_key = p.product_key
LEFT JOIN silver.sales_territory t ON s.sales_territory_key = t.sales_territory_key;


-- =============================================================================
-- 4. Sentinel usage audit
-- Purpose  : Shows which -1 sentinel rows are actually referenced by sales.
--            Sentinels with 0 references still flow into gold and appear as
--            "N/A" values in Power BI slicers; delete them if unused.
-- Expected : reseller_key = -1 should equal the Internet-channel row count,
--            and customer_key = -1 the Reseller-channel row count.
-- =============================================================================
SELECT 'reseller_key = -1' AS sentinel, COUNT(*) AS fact_rows FROM silver.sales WHERE reseller_key = -1
UNION ALL
SELECT 'customer_key = -1', COUNT(*) FROM silver.sales WHERE customer_key = -1
UNION ALL
SELECT 'product_key = -1', COUNT(*) FROM silver.sales WHERE product_key = -1
UNION ALL
SELECT 'sales_territory_key = -1', COUNT(*) FROM silver.sales WHERE sales_territory_key = -1
UNION ALL
SELECT 'order_date_key = -1', COUNT(*) FROM silver.sales WHERE order_date_key = -1
UNION ALL
SELECT 'due_date_key = -1', COUNT(*) FROM silver.sales WHERE due_date_key = -1
UNION ALL
SELECT 'ship_date_key = -1', COUNT(*) FROM silver.sales WHERE ship_date_key = -1
UNION ALL
SELECT 'ship_date_key IS NULL (unshipped)', COUNT(*) FROM silver.sales WHERE ship_date_key IS NULL
UNION ALL
SELECT 'customer_key IS NULL', COUNT(*) FROM silver.sales WHERE customer_key IS NULL;


-- =============================================================================
-- 5. Channel vs reseller / customer key pattern
-- Purpose  : Confirms how each channel represents "no reseller" / "no customer"
-- =============================================================================
SELECT
    o.channel,
    COUNT(*) AS row_count,
    COUNT(*) FILTER (WHERE s.reseller_key = -1) AS reseller_sentinel,
    COUNT(*) FILTER (WHERE s.reseller_key IS NULL) AS reseller_null,
    COUNT(*) FILTER (WHERE s.customer_key = -1) AS customer_sentinel,
    COUNT(*) FILTER (WHERE s.customer_key IS NULL) AS customer_null
FROM silver.sales s
JOIN silver.sales_order_data o
    ON s.sales_order_line_key = o.sales_order_line_key
GROUP BY o.channel
ORDER BY o.channel;