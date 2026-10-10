# Project Documentation

**Operations and Revenue Analysis** | PostgreSQL · Power BI · DAX

Technical reference for the data pipeline behind the report: architecture and lineage, a data dictionary for the Silver and Gold layers, transformation and modelling rules, validation checks, and a rebuild runbook. For the business context and findings, see the project [README](../README.md).

---

## Contents

1. [Architecture](#1-architecture)
2. [Lineage: Bronze to Silver to Gold](#2-lineage-bronze-to-silver-to-gold)
3. [Data dictionary: Gold layer](#3-data-dictionary-gold-layer)
4. [Silver layer rules](#4-silver-layer-rules)
5. [Modelling conventions](#5-modelling-conventions)
6. [Validation and expected results](#6-validation-and-expected-results)
7. [Rebuild runbook](#7-rebuild-runbook)
8. [Analysis queries](#8-analysis-queries)
9. [Known issues and open items](#9-known-issues-and-open-items)

---

## 1. Architecture

```mermaid
flowchart LR
    CSV[Source CSV files] --> B[Bronze\nraw text, untransformed]
    B --> S[Silver\ntyped, cleaned, constrained]
    S --> G[Gold\nstar schema]
    G --> PBI[Power BI semantic model]
```

| Layer | Schema | Purpose | Scripts |
|---|---|---|---|
| Bronze | `bronze` | Raw copy of the source files, all values as text | Loaded from CSV |
| Silver | `silver` | Typed, standardized, validated data with integrity constraints | `silver_layer_full.sql` |
| Gold | `gold` | Business-ready star schema used by Power BI | `gold_layer_full.sql` |

Only the six Gold tables are loaded into Power BI. Bronze and Silver exist for preparation and validation.

## 2. Lineage: Bronze to Silver to Gold

| Silver table | Bronze source | Gold table | Notes |
|---|---|---|---|
| `silver.customer` | `bronze.customer` | `gold.dim_customer` | Loaded as is |
| `silver.product` | `bronze.product` | `gold.dim_product` | Loaded as is |
| `silver.reseller` | `bronze.reseller` | `gold.dim_reseller` | Loaded as is |
| `silver.sales_territory` | `bronze.SalesTerritory` | `gold.dim_sales_territory` | Loaded as is |
| `silver.date` | `bronze.date` | `gold.dim_date` | `full_date` dropped; `month_name` re-derived with `TO_CHAR(date_val, 'Mon')` |
| `silver.sales` + `silver.sales_order_data` | `bronze.salesdata` + `bronze.sales_order_data` | `gold.fact_sales` | Inner join on `sales_order_line_key`; order metadata (`sales_order`, `sales_order_line`, `channel`) merged into the fact table |

`silver.sales_order_data` has no separate Gold table. It shares the grain of `silver.sales` (one row per sales order line), so it is folded into `gold.fact_sales`.

## 3. Data dictionary: Gold layer

### `gold.fact_sales`

**Grain:** one row per sales order line. **Primary key:** `sales_order_line_key`.

| Column | Type | Description |
|---|---|---|
| `sales_order_line_key` | INT | Unique key for the order line (primary key) |
| `sales_order` | TEXT | Sales order identifier (from sales order data) |
| `sales_order_line` | TEXT | Line identifier within the order (from sales order data) |
| `channel` | TEXT | Sales channel: Reseller or Internet (from sales order data) |
| `reseller_key` | INT | Foreign key to `dim_reseller`; `-1` for sales with no reseller |
| `customer_key` | INT | Foreign key to `dim_customer`; `-1` for sales with no individual customer |
| `product_key` | INT | Foreign key to `dim_product` |
| `order_date_key` | INT | Foreign key to `dim_date` (order date) |
| `due_date_key` | INT | Foreign key to `dim_date` (due date) |
| `ship_date_key` | INT | Foreign key to `dim_date` (ship date); `NULL` where the order had not shipped |
| `sales_territory_key` | INT | Foreign key to `dim_sales_territory` |
| `order_quantity` | INT | Units on the line |
| `unit_price` | NUMERIC(19,4) | Unit price at list |
| `extended_amount` | NUMERIC(19,4) | Line amount before price reductions (quantity × unit price); compared with `sales_amount` to derive effective discount |
| `unit_price_discount_pct` | NUMERIC(7,4) | Recorded discount fraction. **Zero on every source row; do not use** (see [Known issues](#9-known-issues-and-open-items)) |
| `product_standard_cost` | NUMERIC(19,4) | Standard cost per unit |
| `total_product_cost` | NUMERIC(19,4) | Line cost (quantity × standard cost, within rounding) |
| `sales_amount` | NUMERIC(19,4) | Realized revenue for the line. **Source of truth for sales** |

Derived business measures: **Gross profit** = `sales_amount - total_product_cost`. **Profit margin %** = gross profit ÷ `sales_amount`.

### `gold.dim_customer`

**Grain:** one row per customer. **Primary key:** `customer_key`.

| Column | Type | Description |
|---|---|---|
| `customer_key` | INT | Surrogate key; `-1` is the 'Reseller / Non-Customer' sentinel |
| `customer_id` | TEXT | Customer code (upper case) |
| `customer_name` | TEXT | Customer name (title case) |
| `city` | TEXT | City |
| `state_province` | TEXT | State or province |
| `country_region` | TEXT | Country or region |
| `postal_code` | TEXT | Postal code (upper case) |

### `gold.dim_product`

**Grain:** one row per product SKU. **Primary key:** `product_key`.

| Column | Type | Description |
|---|---|---|
| `product_key` | INT | Surrogate key; `-1` is the 'Not Applicable' sentinel |
| `sku` | TEXT | Stock-keeping unit (upper case) |
| `product` | TEXT | Product name |
| `standard_cost` | NUMERIC(19,4) | Standard unit cost |
| `color` | TEXT | Colour |
| `list_price` | NUMERIC(19,4) | List price |
| `model` | TEXT | Product model |
| `subcategory` | TEXT | Product subcategory |
| `category` | TEXT | Product category (Bikes, Components, Clothing, Accessories) |

### `gold.dim_reseller`

**Grain:** one row per reseller account. **Primary key:** `reseller_key`.

| Column | Type | Description |
|---|---|---|
| `reseller_key` | INT | Surrogate key; `-1` is the 'Direct / Non-Reseller' sentinel |
| `reseller_id` | TEXT | Reseller code (upper case) |
| `business_type` | TEXT | Reseller business type |
| `reseller_name` | TEXT | Reseller name |
| `city` | TEXT | City |
| `state_province` | TEXT | State or province |
| `country_region` | TEXT | Country or region |
| `postal_code` | TEXT | Postal code (upper case) |

### `gold.dim_sales_territory`

**Grain:** one row per sales territory. **Primary key:** `sales_territory_key`.

| Column | Type | Description |
|---|---|---|
| `sales_territory_key` | INT | Surrogate key; `-1` is the 'Not Applicable' sentinel |
| `region` | TEXT | Sales region |
| `country` | TEXT | Country |
| `territory_group` | TEXT | Territory group |

### `gold.dim_date`

**Grain:** one row per calendar day. **Primary key:** `date_key`. Used as a role-playing dimension for order, due, and ship dates.

| Column | Type | Description |
|---|---|---|
| `date_key` | INT | Surrogate key; `-1` is the placeholder row dated `1900-01-01` |
| `date_val` | DATE | Calendar date |
| `fiscal_year` | TEXT | Fiscal year (July–June), for example FY2018 |
| `fiscal_quarter` | TEXT | Fiscal quarter within the fiscal year |
| `month_name` | TEXT | Abbreviated month name, derived from `date_val` |
| `month_key` | INT | Sort key so months display in fiscal-calendar order |

### Foreign keys and indexes

All seven foreign keys sit on `gold.fact_sales`: `fk_product`, `fk_reseller`, `fk_customer`, `fk_territory`, `fk_date` (order date), `fk_due_date`, and `fk_ship_date`. Indexes cover the product, reseller, customer, territory, and order-date keys.

## 4. Silver layer rules

Applied when loading each Silver table from Bronze.

| Rule | Detail |
|---|---|
| Key cleaning | `NULLIF(TRIM(key), '')::INT`, so a blank key becomes `NULL` and can never break the cast |
| Key filtering | Rows with a missing or non-positive key are excluded from the load |
| Text standardization | `TRIM()` everywhere; `INITCAP()` for names, places, categories, and channel; `UPPER()` for codes, SKUs, postal codes, and sales order identifiers |
| Numeric cleaning | `REGEXP_REPLACE()` removes `$` and `,` from money columns and `%` and `,` from the discount column before casting to `NUMERIC` |
| Missing ship date | A blank `ShipDateKey` becomes `NULL`; it is never fabricated |
| Primary keys | One on every Silver table |
| Not-null columns | Keys plus essential descriptive columns (for example `customer_name`, `product`, `reseller_name`, `region`, `country`, `date_val`, `sales_order`) |
| Check constraints | Costs and prices ≥ 0; `order_quantity` > 0; sales and extended amounts ≥ 0; discount fraction between 0 and 1 |
| Foreign keys | `silver.sales` references customer, reseller, product, order, due and ship dates, territory, and sales order data |

## 5. Modelling conventions

**Sentinel keys.** Not every sale has a reseller or an individual customer, so the data uses `-1` for "not applicable":

| Table | `-1` row | Used when |
|---|---|---|
| `reseller` | 'Direct / Non-Reseller' | Internet-channel sales have no reseller |
| `customer` | 'Reseller / Non-Customer' | Reseller-channel sales have no individual customer |
| `product` | 'Not Applicable' | Reserved for unknown products |
| `sales_territory` | 'Not Applicable' | Reserved for unknown territories |
| `date` | placeholder dated `1900-01-01` | Reserved for unknown dates |

The `1900-01-01` row is a technical placeholder, not a real transaction date. In reports, exclude `-1` rows from customer and reseller counts. The sentinel usage audit in the Silver script shows which sentinels the sales table actually references.

**Build order matters.** The sentinel rows must be inserted after the dimension primary keys exist (the inserts use `ON CONFLICT`) and before the foreign keys on `silver.sales` are created. The Silver script follows this order.

**Sales Amount is the source of truth.** Revenue always comes from `sales_amount`. Effective discount, where needed, is derived from `extended_amount` and `sales_amount`, never from `unit_price_discount_pct`.

**Fiscal calendar.** The fiscal year runs July to June. Missing ship dates are left as `NULL`.

## 6. Validation and expected results

### Silver (`silver_layer_full.sql`, Section 5)

| Check | Expected result |
|---|---|
| Bronze vs Silver row counts, all seven tables | `bronze_count = silver_count` for every row (sentinels excluded) |
| Bronze vs Silver total sales | Variance = 0 |
| Orphan foreign key audit | All zero (a sanity check, since the constraints already enforce this) |
| Sentinel usage audit | `reseller_key = -1` equals the Internet-channel row count; `customer_key = -1` equals the Reseller-channel row count |
| Channel key pattern | Internet rows use the reseller sentinel; Reseller rows use the customer sentinel |

### Gold (`gold_layer_full.sql`, Sections 2 and 5)

| Check | Expected result |
|---|---|
| Primary key uniqueness on each Silver dimension | 0 rows returned |
| Silver `sales` and `sales_order_data` grain | `total_rows = unique_line_keys` |
| Gold `fact_sales` grain | `total_rows = unique_line_keys` |
| Control totals, Silver vs Gold (rows, quantity, sales, cost) | Both rows identical; a difference means the inner join dropped rows |
| Orphan checks for all seven fact keys | 0 for every check (NULL keys are skipped, then profiled below) |
| Key profile by channel | Internet → `reseller_sentinel = row_count`; Reseller → `customer_sentinel = row_count`; no NULLs in `reseller_key`, `customer_key`, `product_key`, `sales_territory_key`, or `order_date_key` |
| KPI query | Totals agree with the Power BI report |

## 7. Rebuild runbook

**Prerequisite:** the Bronze tables are loaded in PostgreSQL from the source CSV files.

**Step 1: Silver.** Run `silver_layer_full.sql`.

- Sections 1–4 run together as one transaction (`BEGIN` … `COMMIT`): drop, create, load, dimension constraints, sentinel rows, fact constraints.
- If the block errors, run `ROLLBACK;` before retrying. The previous Silver layer is left untouched.
- Then run Section 5 and compare the results with the expected values above.

**Step 2: Gold.** Run `gold_layer_full.sql` section by section.

| Section | Action |
|---|---|
| 1 Reset | Truncates the six Gold tables (tables must already exist) |
| 2 Silver audits | Read-only checks on Silver |
| 3 DDL | Creates the schema, tables, foreign keys, and indexes if absent; safe to rerun |
| 4 Load | One transaction loading all six tables, followed by `ANALYZE` |
| 5 Validation | Grain, control totals, orphan checks, key profile, KPIs |
| 6 Analysis | Business queries |

The reset in Section 1 requires the Gold tables to exist. On a brand-new database, run Section 3 first.

**Step 3: Power BI.** Connect to the six Gold tables and refresh.

## 8. Analysis queries

Section 6 of `gold_layer_full.sql`:

| Query | Purpose |
|---|---|
| Category fiscal-year performance | Sales, gross profit, margin %, year-over-year growth, and margin change by product category and fiscal year |
| Touring Bikes cost vs list price | Unit margin at list price for each Touring Bikes product |
| Touring Bikes realized price vs list price | Realized price, volume, profit, and margin per product (unweighted and volume-weighted price) |
| Loss-making Touring Bikes by reseller and territory | Groups that sell below cost |
| Loss-making Touring Bikes line transactions | Line-level price and loss detail for unprofitable rows |
| Loss-making Touring Bikes drill-down | Line counts, pricing metrics, and net loss per reseller and model |
| Touring Bikes channel and model metrics | Volume, profit, margin, and price by channel and model |
| Touring Bikes channel variance | Realized vs extended amount by channel and model |
| Touring Bikes channel summary | Internet vs Reseller profitability |

**Reading note:** the category year-over-year query excludes June 16–30 of every year so periods stay like-for-like (the extract ends around mid-June 2020). Its totals therefore differ slightly from report totals that include all dates. The Internet-channel rows appear under 'Direct / Non-Reseller' in the reseller-based loss queries; add `f.channel = 'Reseller'` to restrict to real resellers.

## 9. Known issues and open items

| Item | Detail |
|---|---|
| Discount column is unusable | `unit_price_discount_pct` is `0.00%` on all 121,253 rows. The loss-making line-transaction query computes `expected_selling_price` from it, and the drill-down reports `avg_discount_pct` from it, so both currently show no discount. Replace them with an effective discount: `1 - sales_amount / extended_amount`. |
| Reseller sales below cost | 15,684 reseller rows differ from the expected calculation; 3,282 have Sales Amount below Extended Amount. The cause of the reseller pricing is not established and needs input from the pricing owner. |
| Missing ship dates | 2,113 orders dated 9–15 June 2020 have no ship date. They are left as `NULL`. |
| Partial final fiscal year | FY2020 covers about 11.5 months. |
| Unused sentinels | The product, territory, and date sentinels may have no fact rows. Check the sentinel usage audit; unused rows still appear as "N/A" members in report slicers. |
| Gold reset on a new database | The Section 1 truncate fails if the Gold tables do not exist yet; run the DDL first. |
