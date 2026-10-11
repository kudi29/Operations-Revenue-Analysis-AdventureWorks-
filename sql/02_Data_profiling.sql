-- =======================================================================================================
-- DATA PROFILING & QUALITY ASSURANCE SUITE
-- =======================================================================================================


-- =======================================================================================================
-- GROUP 1: NULL VALUE & KEY COMPLETENESS OVERVIEW
-- Purpose: Fast identification of missing foreign keys and essential attributes across sales data.
-- =======================================================================================================

-- Counts total rows and calculates null key frequencies for all primary entity keys in salesdata.
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE "SalesOrderLineKey" IS NULL) AS missing_sales_line_key,
    COUNT(*) FILTER (WHERE "ResellerKey" IS NULL) AS missing_reseller_key,
    COUNT(*) FILTER (WHERE "CustomerKey" IS NULL) AS missing_customer_key,
    COUNT(*) FILTER (WHERE "ProductKey" IS NULL) AS missing_product_key,
    COUNT(*) FILTER (WHERE "OrderDateKey" IS NULL) AS missing_order_date_key,
    COUNT(*) FILTER (WHERE "DueDateKey" IS NULL) AS missing_due_date_key,
    COUNT(*) FILTER (WHERE "ShipDateKey" IS NULL) AS missing_ship_date_key,
    COUNT(*) FILTER (WHERE "SalesTerritoryKey" IS NULL) AS missing_territory_key
FROM bronze.salesdata;


-- =======================================================================================================
-- GROUP 2: UN-SHIPPED ORDERS ANALYSIS
-- Purpose: Deep-dive investigation into records missing a Ship Date to understand 
-- root cause, date ranges, affected sales channels, and order line impact.
-- =======================================================================================================

-- Measures the total count and date bounds (Order Date, Due Date) for all un-shipped transaction rows.
SELECT
    COUNT(*) AS missing_ship_date_rows,
    MIN("OrderDateKey") AS earliest_order_date,
    MAX("OrderDateKey") AS latest_order_date,
    MIN("DueDateKey") AS earliest_due_date,
    MAX("DueDateKey") AS latest_due_date
FROM bronze.salesdata
WHERE "ShipDateKey" IS NULL;

-- Groups un-shipped order line counts by Order Date to spot time-based fulfillment bottlenecks.
SELECT
    "OrderDateKey",
    COUNT(*) AS missing_ship_date_rows
FROM bronze.salesdata
WHERE "ShipDateKey" IS NULL
GROUP BY "OrderDateKey"
ORDER BY "OrderDateKey";

-- Groups un-shipped order line counts by Due Date to track overdue delivery exposure.
SELECT
    "DueDateKey",
    COUNT(*) AS missing_ship_date_rows
FROM bronze.salesdata
WHERE "ShipDateKey" IS NULL
GROUP BY "DueDateKey"
ORDER BY "DueDateKey";

-- Aggregates un-shipped line item counts across sales channels to compare fulfillment issues per channel.
SELECT
    o."Channel",
    COUNT(*) AS missing_ship_date_rows
FROM bronze.salesdata s
LEFT JOIN bronze.sales_order_data o
    ON s."SalesOrderLineKey" = o."SalesOrderLineKey"
WHERE s."ShipDateKey" IS NULL
GROUP BY o."Channel"
ORDER BY missing_ship_date_rows DESC;

-- Retrieves a 20-row sample of un-shipped order details including order numbers, dates, and channels.
SELECT
    o."Sales Order",
    o."Channel",
    s."OrderDateKey",
    s."DueDateKey",
    s."ShipDateKey"
FROM bronze.salesdata s
LEFT JOIN bronze.sales_order_data o
    ON s."SalesOrderLineKey" = o."SalesOrderLineKey"
WHERE s."ShipDateKey" IS NULL
ORDER BY s."OrderDateKey", o."Sales Order"
LIMIT 20;

-- Counts the total number of distinct sales orders that contain at least one un-shipped line item.
SELECT
    COUNT(DISTINCT o."Sales Order") AS affected_orders
FROM bronze.salesdata s
LEFT JOIN bronze.sales_order_data o
    ON s."SalesOrderLineKey" = o."SalesOrderLineKey"
WHERE s."ShipDateKey" IS NULL;

-- Identifies orders with un-shipped items and compares total line items versus shipped line items per order.
SELECT
    o."Sales Order",
    COUNT(*) AS total_lines,
    COUNT(s."ShipDateKey") AS lines_with_ship_date,
    COUNT(*) - COUNT(s."ShipDateKey") AS lines_missing_ship_date
FROM bronze.salesdata s
JOIN bronze.sales_order_data o
    ON s."SalesOrderLineKey" = o."SalesOrderLineKey"
GROUP BY o."Sales Order"
HAVING COUNT(*) - COUNT(s."ShipDateKey") > 0
ORDER BY lines_missing_ship_date DESC;

-- Shows affected order counts along with the first and last order numbers per sales channel for un-shipped records.
SELECT
    o."Channel",
    MIN(o."Sales Order") AS first_order,
    MAX(o."Sales Order") AS last_order,
    COUNT(DISTINCT o."Sales Order") AS affected_orders
FROM bronze.salesdata s
JOIN bronze.sales_order_data o
    ON s."SalesOrderLineKey" = o."SalesOrderLineKey"
WHERE s."ShipDateKey" IS NULL
GROUP BY o."Channel";

-- Summarizes affected order counts and order date ranges for un-shipped records grouped by sales channel.
SELECT
    o."Channel",
    MIN(s."OrderDateKey") AS earliest_order_date,
    MAX(s."OrderDateKey") AS latest_order_date,
    COUNT(DISTINCT o."Sales Order") AS affected_orders
FROM bronze.salesdata s
JOIN bronze.sales_order_data o
    ON s."SalesOrderLineKey" = o."SalesOrderLineKey"
WHERE s."ShipDateKey" IS NULL
GROUP BY o."Channel";

-- Counts the overall total number of distinct sales orders in the sales order master table for baseline comparison.
SELECT
    COUNT(DISTINCT o."Sales Order") AS total_orders
FROM bronze.sales_order_data o;

-- Groups un-shipped sales transaction rows by Sales Territory Key to identify regional fulfillment delays.
SELECT
    "SalesTerritoryKey",
    COUNT(*) AS missing_ship_date_rows
FROM bronze.salesdata
WHERE "ShipDateKey" IS NULL
GROUP BY "SalesTerritoryKey"
ORDER BY missing_ship_date_rows DESC;


-- =======================================================================================================
-- GROUP 3: PRODUCT COST OUTLIERS & DATA MATCHING
-- Purpose: Spot-checking standard cost calculations, max cost records, and alignment between sales transaction costs and core product master data.
-- =======================================================================================================

-- Selects full product dimension records for the item(s) matching the highest standard cost value.
SELECT *
FROM bronze.product
WHERE REGEXP_REPLACE("Standard Cost", '[$,]', '', 'g')::numeric = (
	SELECT 
		MAX(REGEXP_REPLACE("Standard Cost", '[$,]', '', 'g')::numeric) AS max_product_Standard_cost
	FROM bronze.product
);

-- Compares product standard costs between salesdata and product dimension for a specific high-value cost point.
SELECT
    s."ProductKey",
    s."Product Standard Cost",
    p."Standard Cost"
FROM bronze.salesdata s
LEFT JOIN bronze.product p
    ON s."ProductKey" = p."ProductKey"
WHERE REGEXP_REPLACE(s."Product Standard Cost", '[$,]', '', 'g')::numeric = 38530.39;

-- Retrieves the top 10 sales records with the highest product standard 
-- cost values after string cleaning and numeric casting.
SELECT
    "ProductKey",
    "Product Standard Cost"
FROM bronze.salesdata
ORDER BY REGEXP_REPLACE("Product Standard Cost", '[$,]', '', 'g')::numeric DESC
LIMIT 10;


-- =======================================================================================================
-- GROUP 4: ENTITY INTEGRITY & DUPLICATE CHECKS
-- Purpose: Detecting unexpected primary key duplicates in primary dimension lookup tables.
-- =======================================================================================================

-- Checks for duplicate primary keys in the salesterritory dimension table.
SELECT
    "SalesTerritoryKey",
    COUNT(*) AS row_count
FROM bronze.salesterritory
GROUP BY "SalesTerritoryKey"
HAVING COUNT(*) > 1;


-- =======================================================================================================
-- GROUP 5: REFERENTIAL INTEGRITY (ORPHAN FOREIGN KEYS)
-- Purpose: Finding transaction records in sales data that point to non-existent dimension records (products, customers, resellers, territories).
-- =======================================================================================================

-- Returns distinct Product Keys in salesdata that do not exist in the product dimension table.
SELECT DISTINCT s."ProductKey"
FROM bronze.salesdata s
LEFT JOIN bronze.product p
    ON s."ProductKey" = p."ProductKey"
WHERE p."ProductKey" IS NULL;

-- Returns distinct Customer Keys in salesdata that do not exist in the customer dimension table.
SELECT DISTINCT s."CustomerKey"
FROM bronze.salesdata s
LEFT JOIN bronze.customer c
    ON s."CustomerKey" = c."CustomerKey"
WHERE c."CustomerKey" IS NULL;

-- Returns distinct Reseller Keys in salesdata that do not exist in the reseller dimension table.
SELECT DISTINCT s."ResellerKey"
FROM bronze.salesdata s
LEFT JOIN bronze.reseller r
    ON s."ResellerKey" = r."ResellerKey"
WHERE r."ResellerKey" IS NULL;

-- Returns distinct Sales Territory Keys in salesdata that do not exist in the salesterritory dimension table.
SELECT DISTINCT s."SalesTerritoryKey"
FROM bronze.salesdata s
LEFT JOIN bronze.salesterritory t
    ON s."SalesTerritoryKey" = t."SalesTerritoryKey"
WHERE t."SalesTerritoryKey" IS NULL;


-- =======================================================================================================
-- GROUP 6: DATE DIMENSION INTEGRITY
-- Purpose: Ensuring date keys in sales transactions map to valid dates in the central date dimension table.
-- =======================================================================================================

-- Counts sales records with populated Order Date keys that fail to match any entry in the date dimension table.
SELECT
    COUNT(*) AS orphan_order_date_rows
FROM bronze.salesdata s
LEFT JOIN bronze.date d
    ON s."OrderDateKey" = d."DateKey"
WHERE s."OrderDateKey" IS NOT NULL
  AND d."DateKey" IS NULL;

-- Counts sales records with populated Due Date keys that fail to match any entry in the date dimension table.
SELECT
    COUNT(*) AS orphan_due_date_rows
FROM bronze.salesdata s
LEFT JOIN bronze.date d
    ON s."DueDateKey" = d."DateKey"
WHERE s."DueDateKey" IS NOT NULL
  AND d."DateKey" IS NULL;

-- Counts sales records with populated Ship Date keys that fail to match any entry in the date dimension table.
SELECT
    COUNT(*) AS orphan_ship_date_rows
FROM bronze.salesdata s
LEFT JOIN bronze.date d
    ON s."ShipDateKey" = d."DateKey"
WHERE s."ShipDateKey" IS NOT NULL
  AND d."DateKey" IS NULL;


-- =======================================================================================================
-- GROUP 7: NUMERIC DATA QUALITY & BOUNDARY CHECKS
-- Purpose: Identifying invalid numeric entries (<= 0) and measuring minimum/maximum distribution bounds across metrics.
-- =======================================================================================================

-- Counts sales records containing non-positive (zero or negative) order quantities.
SELECT
    COUNT(*) AS invalid_quantity_rows
FROM bronze.salesdata
WHERE "Order Quantity"::numeric <= 0;

-- Computes minimum and maximum numeric values across all financial metrics and order quantity in salesdata.
SELECT
    MIN("Order Quantity") AS min_quantity,
    MAX("Order Quantity") AS max_quantity,
    MAX(REGEXP_REPLACE("Unit Price", '[$,]', '', 'g')::numeric) AS max_unit_price,
    MIN(REGEXP_REPLACE("Unit Price", '[$,]', '', 'g')::numeric) AS min_unit_price,
    MIN(REGEXP_REPLACE("Sales Amount", '[$,]', '', 'g')::numeric) AS min_sales_amount,
    MAX(REGEXP_REPLACE("Sales Amount", '[$,]', '', 'g')::numeric) AS max_sales_amount,
    MIN(REGEXP_REPLACE("Total Product Cost", '[$,]', '', 'g')::numeric) AS min_product_cost,
    MAX(REGEXP_REPLACE("Total Product Cost", '[$,]', '', 'g')::numeric) AS max_product_cost
FROM bronze.salesdata;

-- Counts sales records containing non-positive (zero or negative) unit prices after currency string cleaning.
SELECT
    COUNT(*) AS invalid_unit_price_rows
FROM bronze.salesdata
WHERE REGEXP_REPLACE("Unit Price", '[$,]', '', 'g')::numeric <= 0;

-- Counts sales records containing non-positive (zero or negative) sales amounts after currency string cleaning.
SELECT
    COUNT(*) AS invalid_sales_amount_rows
FROM bronze.salesdata
WHERE REGEXP_REPLACE("Sales Amount", '[$,]', '', 'g')::numeric <= 0;

-- Calculates the minimum and maximum sales amounts after currency string cleaning and numeric casting.
SELECT
    MIN(REGEXP_REPLACE("Sales Amount", '[$,]', '', 'g')::numeric) AS min_sales_amount,
    MAX(REGEXP_REPLACE("Sales Amount", '[$,]', '', 'g')::numeric) AS max_sales_amount
FROM bronze.salesdata;

-- Check to see if product standard cost is negitive
SELECT
    COUNT(*) AS invalid_product_cost_rows
FROM bronze.salesdata
WHERE REGEXP_REPLACE("Product Standard Cost", '[$,]', '', 'g')::numeric <= 0


---- Retrieves top 10 sales records ordered by total product cost in descending order.
SELECT
    "SalesOrderLineKey",
    "ProductKey",
    "Order Quantity",
    "Product Standard Cost",
    "Total Product Cost",
    "Sales Amount"
FROM bronze.salesdata
ORDER BY REGEXP_REPLACE("Total Product Cost", '[$,]', '', 'g')::numeric DESC
LIMIT 10;


-- Counts sales records where total product cost differs from quantity multiplied by standard cost by more than one cent.
SELECT
    COUNT(*) AS cost_mismatch_rows
FROM bronze.salesdata
WHERE ABS(
    ("Order Quantity"::numeric * 
		REGEXP_REPLACE("Product Standard Cost", '[$,]', '', 'g')::numeric)
    	- REGEXP_REPLACE("Total Product Cost", '[$,]', '', 'g')::numeric
) > 0.01;


-- Calculates the maximum and average absolute cost variances across all sales records.
SELECT
    MAX(
        ABS(
            ("Order Quantity"::numeric * 
				REGEXP_REPLACE(
					"Product Standard Cost", '[$,]', '', 'g')::numeric)
            	- REGEXP_REPLACE("Total Product Cost", '[$,]', '', 'g')::numeric
        )
    ) AS max_cost_difference,
    AVG(
        ABS(
            ("Order Quantity"::numeric * 
				REGEXP_REPLACE("Product Standard Cost", '[$,]', '', 'g')::numeric)
            	- REGEXP_REPLACE("Total Product Cost", '[$,]', '', 'g')::numeric
        )
    ) AS avg_cost_difference
FROM bronze.salesdata;


-- Counts sales records where the calculated sales amount 
-- (quantity * unit price * net discount) differs from the recorded sales amount by more than one cent.
SELECT
    COUNT(*) AS sales_amount_mismatch_rows
FROM bronze.salesdata
WHERE ABS(
    (
        "Order Quantity"::numeric
        * REGEXP_REPLACE("Unit Price", '[$,]', '', 'g')::numeric
        * (1 - REGEXP_REPLACE("Unit Price Discount Pct", '[%,]', '', 'g')::numeric)
    )
    - REGEXP_REPLACE("Sales Amount", '[$,]', '', 'g')::numeric
) > 0.01;



-- Calculates the maximum and average absolute variances between calculated net sales amount and recorded sales amount.
SELECT
    MAX(
        ABS(
            (
                "Order Quantity"::numeric
                * REGEXP_REPLACE("Unit Price", '[$,]', '', 'g')::numeric
                * (1 - REGEXP_REPLACE("Unit Price Discount Pct", '[%,]', '', 'g')::numeric)
            )
            - REGEXP_REPLACE("Sales Amount", '[$,]', '', 'g')::numeric
        )
    ) AS max_sales_difference,
    AVG(
        ABS(
            (
                "Order Quantity"::numeric
                * REGEXP_REPLACE("Unit Price", '[$,]', '', 'g')::numeric
                * (1 - REGEXP_REPLACE("Unit Price Discount Pct", '[%,]', '', 'g')::numeric)
            )
            - REGEXP_REPLACE("Sales Amount", '[$,]', '', 'g')::numeric
        )
    ) AS avg_sales_difference
FROM bronze.salesdata;



-- Counts transaction frequencies for negative ResellerKeys to identify specific sentinel/placeholder reseller values in sales data.
SELECT
    "ResellerKey",
    COUNT(*) AS row_count
FROM bronze.salesdata
WHERE "ResellerKey"::numeric < 0
GROUP BY "ResellerKey"
ORDER BY "ResellerKey";

-- Counts transaction frequencies for negative CustomerKeys to identify specific sentinel/placeholder customer values in sales data.
SELECT
    "CustomerKey",
    COUNT(*) AS row_count
FROM bronze.salesdata
WHERE "CustomerKey"::numeric < 0
GROUP BY "CustomerKey"
ORDER BY "CustomerKey";

-- Verifies if negative ResellerKeys in sales data map to valid dimension records or act as unmapped placeholder keys.
SELECT
    s."ResellerKey",
    COUNT(*) AS sales_rows,
    COUNT(r."ResellerKey") AS matching_reseller_rows
FROM bronze.salesdata s
LEFT JOIN bronze.reseller r
    ON s."ResellerKey" = r."ResellerKey"
WHERE s."ResellerKey"::numeric < 0
GROUP BY s."ResellerKey"
ORDER BY s."ResellerKey";

-- Verifies if negative CustomerKeys in sales data map to valid dimension records or act as unmapped placeholder keys.
SELECT
    s."CustomerKey",
    COUNT(*) AS sales_rows,
    COUNT(c."CustomerKey") AS matching_customer_rows
FROM bronze.salesdata s
LEFT JOIN bronze.customer c
    ON s."CustomerKey" = c."CustomerKey"
WHERE s."CustomerKey"::numeric < 0
GROUP BY s."CustomerKey"
ORDER BY s."CustomerKey";


SELECT *
FROM bronze.reseller
WHERE "ResellerKey" = '-1';

SELECT *
FROM bronze.customer
WHERE "CustomerKey" = '-1';


SELECT
    "Unit Price Discount Pct",
    COUNT(*) AS row_count
FROM bronze.salesdata
GROUP BY "Unit Price Discount Pct"
ORDER BY "Unit Price Discount Pct";
















