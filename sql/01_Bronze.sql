CREATE SCHEMA bronze;
CREATE SCHEMA silver;
CREATE SCHEMA gold;

-- Customers table

DROP TABLE IF EXISTS bronze.customer;
CREATE TABLE bronze.customer (
	"CustomerKey" TEXT,
	"Customer ID" TEXT,
	"Customer" TEXT,
	"City" TEXT,
	"State-Province" TEXT,
	"Country-Region" TEXT,
	"Postal-Code" TEXT
);

COPY bronze.customer
FROM 'C:/Users/ThinkPad/OneDrive/Desktop/Operations_and_Revenue_Analytics/Customer_data.csv'
WITH (
	FORMAT csv,
	HEADER true,
	DELIMITER ',',
	ENCODING 'LATIN1'
);

-- Product table

DROP TABLE IF EXISTS bronze.product;
CREATE TABLE bronze.product (
	"ProductKey" TEXT,
	"SKU" TEXT,
	"Product" TEXT,
	"Standard Cost" TEXT,
	"Color" TEXT,
	"List Price" TEXT,
	"Model" TEXT,
	"Subcategory" TEXT,
	"Category" TEXT
);

COPY bronze.product
FROM 'C:/Users/ThinkPad/OneDrive/Desktop/Operations_and_Revenue_Analytics/Product_data.csv'
WITH(
	FORMAT csv,
	HEADER true,
	DELIMITER ',',
	ENCODING 'LATIN1'
);


-- Date Table

DROP TABLE IF EXISTS bronze.date;
CREATE TABLE bronze.date (
	"DateKey" TEXT,
	"Date" TEXT,
	"Fiscal Year" TEXT,
	"Fiscal Quarter" TEXT,
	"Month" TEXT,
	"Full Date" TEXT,
	"Monthkey" TEXT
);

COPY bronze.date
FROM 'C:/Users/ThinkPad\OneDrive/Desktop/Operations_and_Revenue_Analytics/Date_data.csv'
WITH (
	FORMAT csv,
	HEADER true,
	DELIMITER ',',
	ENCODING 'LATIN1'
);


-- Reseller Table

DROP TABLE IF EXISTS bronze.reseller;
CREATE TABLE bronze.reseller(
	"ResellerKey" TEXT,
	"Reseller ID" TEXT,
	"Business Type"	TEXT,
	"Reseller" TEXT,
	"City"	TEXT,
	"State-Province" TEXT,	
	"Country-Region" TEXT,	
	"Postal Code" TEXT
);

COPY bronze.reseller
FROM 'C:/Users/ThinkPad/OneDrive/Desktop/Operations_and_Revenue_Analytics/Reseller_data.csv'
WITH (
	FORMAT csv,
	HEADER true,
	DELIMITER ',',
	ENCODING 'LATIN1'
);


-- Sales Territory 

DROP TABLE IF EXISTS bronze.SalesTerritory;
CREATE TABLE bronze.SalesTerritory(
	"SalesTerritoryKey"	TEXT,
	"Region" TEXT,
	"Country" TEXT,
	"Group" TEXT
);

COPY bronze.SalesTerritory
FROM 'C:/Users/ThinkPad\OneDrive/Desktop/Operations_and_Revenue_Analytics/Sales Territory_data.csv'
WITH (
	FORMAT csv,
	HEADER true,
	DELIMITER ',',
	ENCODING 'LATIN1'
);


-- Sales Data
DROP TABLE IF EXISTS bronze.SalesData;
CREATE TABLE bronze.SalesData(
	"SalesOrderLineKey" TEXT,	
	"ResellerKey" TEXT,	
	"CustomerKey" TEXT,
	"ProductKey" TEXT,	
	"OrderDateKey" TEXT,	
	"DueDateKey" TEXT,	
	"ShipDateKey" TEXT,	
	"SalesTerritoryKey" TEXT,	
	"Order Quantity" TEXT,	
	"Unit Price" TEXT,	
	"Extended Amount" TEXT,
	"Unit Price Discount Pct" TEXT,	
	"Product Standard Cost"	 TEXT,
	"Total Product Cost" TEXT,	
	"Sales Amount" TEXT
);


COPY bronze.SalesData
FROM 'C:/Users/ThinkPad/OneDrive/Desktop/Operations_and_Revenue_Analytics/Sales_data.csv'
WITH (
	FORMAT csv,
	HEADER true,
	DELIMITER ',',
	ENCODING 'LATIN1'
);


-- Sales order data

DROP TABLE IF EXISTS bronze.sales_order_data;
CREATE TABLE bronze.sales_order_data(
	"Channel" TEXT,
	"SalesOrderLineKey" TEXT,	
	"Sales Order" TEXT,	
	"Sales Order Line" TEXT
);

COPY bronze.sales_order_data
FROM 'C:/Users/ThinkPad/OneDrive/Desktop/Operations_and_Revenue_Analytics/Sales_order_data.csv'
WITH (
	FORMAT csv,
	HEADER true,
	DELIMITER ',',
	ENCODING 'LATIN1'
);


