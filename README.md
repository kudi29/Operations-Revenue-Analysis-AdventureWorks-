# Operations and Revenue Analysis

### End-to-End Data Analytics Project | PostgreSQL · Power BI · DAX

An end-to-end sales and profitability analysis built to help a Sales Manager and management team understand what changed in performance, where revenue and profit are being generated, and where the business may need to take action.

| | |
|---|---|
| **Analysis period** | July 2017 – mid-June 2020 (FY2020 is a partial year) |
| **Fiscal years** | FY2018–FY2020 (July–June) |
| **Dataset** | AdventureWorks sales data |
| **Sales order lines** | 121,253 |
| **Tools** | PostgreSQL, Power BI, DAX |

---

## Table of Contents

- [Project Overview](#project-overview)
- [Business Problem](#business-problem)
- [Business Objectives](#business-objectives)
- [Executive Summary](#executive-summary)
- [Tools and Technologies](#tools-and-technologies)
- [Dataset and Data Model](#dataset-and-data-model)
- [End-to-End Workflow](#end-to-end-workflow)
- [Data Quality and Preparation](#data-quality-and-preparation)
- [Rebuilding the Database](#rebuilding-the-database)
- [Power BI Semantic Model](#power-bi-semantic-model)
- [Key Business Findings](#key-business-findings)
- [Recommendations](#recommendations)
- [Limitations and Considerations](#limitations-and-considerations)
- [Skills Demonstrated](#skills-demonstrated)
- [Repository Structure](#repository-structure)
- [How to Explore the Project](#how-to-explore-the-project)

---

## Project Overview

This project investigates sales performance and profitability across products, customers, sales territories, and sales channels. The work follows an end-to-end analytical process: translating a stakeholder request into clear business questions, profiling and preparing source data in PostgreSQL, building a business-ready star schema, defining measures in Power BI, and communicating findings through an executive report.

The analysis deliberately evaluates **revenue and profitability together**. High sales do not automatically mean strong business performance: product categories and territories can contribute substantial revenue while producing relatively low margins or losses.

### Project at a glance

| Item | Description |
|---|---|
| Role | Data Analyst, end-to-end analysis |
| Business audience | Sales Manager and management team |
| Source | AdventureWorks sales data |
| Analysis period | July 2017 – mid-June 2020 |
| Fact-table grain | One row per sales order line |
| Database | PostgreSQL (Bronze / Silver / Gold) |
| Reporting and semantic model | Power BI |
| Calculations | DAX |
| Main deliverable | Executive sales and profitability report |

## Business Problem

Management observed changes in sales performance and needed to understand what was driving those changes. The business requested a report that could explore performance across products, customers, territories, and sales channels, while tracking revenue and profitability over time.

The analysis was designed to answer a practical management question:

> Are sales growth and business profitability moving together, and where should management investigate performance?

The report supports exploration of sales trends, category and product performance, territory results, and differences between the Reseller and Internet channels.

## Business Objectives

The analysis was scoped around five objectives:

1. **Understand overall performance** using sales, gross profit, and profit margin.
2. **Track performance over time** and compare fiscal years with the prior year.
3. **Identify product performance differences**, including the strongest and weakest contributors to gross profit.
4. **Compare sales territories** to identify regions that drive results and regions that may need attention.
5. **Investigate profitability drivers**, including product mix, sales channel, and the relationship between sales amount and product cost.

### Core business measures

- **Total Sales:** revenue recorded in the source sales data.
- **Gross Profit:** Total Sales minus Total Cost.
- **Profit Margin %:** Gross Profit divided by Total Sales.

Units, orders, average order value, average selling price, profit per unit, and year-over-year measures provide additional context.

## Executive Summary

Revenue grew strongly over the analysis period, but margins did not keep pace. Profitability also varied substantially by product category, territory, and sales channel.

| Measure / finding | Result |
|---|---:|
| Overall sales | **\$109.8M** |
| Overall gross profit | **\$12.6M** |
| Overall profit margin | **11.4%** |
| FY2018 sales | \$23.9M |
| FY2020 sales (partial year) | \$51.9M |
| FY2018 margin | 12.7% |
| FY2020 margin | 11.2% |
| Bikes share of sales | 86% |
| Accessories margin | 49.9% |
| Australia margin | Approximately 34% |
| Touring Bikes reseller margin | -11.84% |
| Touring Bikes Internet margin | 37.84% |

### Main takeaways

- **Sales more than doubled, while margin declined.** Annual sales rose from \$23.9M in FY2018 to \$51.9M in FY2020 (which covers only about 11.5 months), while margin fell from 12.7% to 11.2%.
- **Revenue and profit were concentrated differently.** Bikes generated approximately 86% of sales at an 11.1% margin, while Accessories generated a 49.9% margin on a much smaller revenue base.
- **Territory results differed sharply.** Australia contributed about 10% of sales but 29% of gross profit, with a margin of approximately 34%. Central, Southeast, and Northeast together represented around 21% of sales but earned margins of roughly 2%.
- **Some products performed very differently by channel.** Touring Bikes lost money through Resellers at a -11.84% margin but were profitable through the Internet channel at a 37.84% margin.
- **The recorded discount field was unreliable.** The source discount percentage was zero on every row, even though some reseller sales amounts were below their extended amounts. Effective discounts were therefore derived for investigation, while Sales Amount remained the source of truth.

## Tools and Technologies

| Tool / technique | How it was used |
|---|---|
| **PostgreSQL** | Source-data profiling, validation, cleaning, transformation, reconciliation, and creation of analytical tables |
| **SQL** | Aggregations, `FILTER`-based checks, key and duplicate checks, regular-expression cleaning, window functions for year-over-year analysis, and financial reconciliation |
| **Bronze / Silver / Gold architecture** | Separated raw ingestion, cleaned data, and business-ready analytical tables |
| **Dimensional modelling** | Created a star schema with a sales fact table and descriptive dimensions |
| **Power BI** | Built the semantic model and management-facing report |
| **DAX** | Created core business measures and fiscal time-intelligence calculations |
| **Business analysis** | Interpreted differences between revenue, gross profit, margin, product category, territory, and channel |

## Dataset and Data Model

The source data consists of seven AdventureWorks tables, with 121,253 sales order lines in the sales data.

### Source data inventory

| Table | Contents | Rows | Grain |
|---|---|---:|---|
| Sales Data | Detailed sales transactions | 121,253 | One row per sales order line |
| Sales Order Data | Order-level attributes, including channel | 121,253 | One row per sales order line in the supplied extract |
| Date Data | Calendar and fiscal attributes | 1,461 | One row per calendar date |
| Product Data | Products, categories, subcategories, models, and prices | 397 | One row per product |
| Reseller Data | Reseller details, business type, and location | 702 | One row per reseller |
| Customer Data | Customer details and location | 18,485 | One row per customer |
| Territory Data | Territory, region, and group attributes | 11 | One row per territory |

The Gold layer contains six tables: `fact_sales`, `dim_customer`, `dim_product`, `dim_reseller`, `dim_sales_territory`, and `dim_date`. Sales order metadata (order number, order line, channel) was merged into the fact table because it shares the same grain and has a one-to-one relationship through the sales order line key.

### Star schema

```mermaid
erDiagram
    dim_customer        ||--o{ fact_sales : customer_key
    dim_product         ||--o{ fact_sales : product_key
    dim_reseller        ||--o{ fact_sales : reseller_key
    dim_sales_territory ||--o{ fact_sales : sales_territory_key
    dim_date            ||--o{ fact_sales : "order / due / ship date key"
```

| Fact-table key | Dimension |
|---|---|
| `sales_territory_key` | `dim_sales_territory` |
| `reseller_key` | `dim_reseller` |
| `customer_key` | `dim_customer` |
| `product_key` | `dim_product` |
| `order_date_key`, `due_date_key`, `ship_date_key` | `dim_date` (role-playing) |

The model uses one-to-many relationships from dimensions to the sales fact table, with single-direction filtering. This structure supports consistent calculations and allows users to slice results by product, customer, reseller, territory, and date.

### Sentinel keys

Not every sale has a reseller or an individual customer, so the data uses `-1` keys for "not applicable" members. Internet-channel sales have no reseller (`reseller_key = -1`), and Reseller-channel sales have no individual customer (`customer_key = -1`). Matching dimension rows ('Direct / Non-Reseller' and 'Reseller / Non-Customer') exist so that every foreign key resolves. Product, territory, and date sentinels follow the same convention; the date sentinel uses the placeholder `1900-01-01`, which is not a real transaction date.

## End-to-End Workflow

1. **Understand the business request:** define the management problem and the decisions the analysis should support.
2. **Gather requirements:** confirm the reporting period, metrics, channels, and territories in scope.
3. **Inventory and profile the data:** inspect row counts, grain, key completeness, duplicates, date validity, foreign keys, and financial calculations.
4. **Build the Bronze layer:** load source CSV data in its raw form.
5. **Create the Silver layer:** standardize text, assign appropriate data types, validate records, and apply integrity rules.
6. **Create the Gold layer:** build a validated, business-ready star schema.
7. **Develop the Power BI semantic model:** configure relationships, date roles, measures, and model organization.
8. **Analyze results:** compare fiscal-year trends, product profitability, territories, and sales channels.
9. **Communicate findings:** present the results and actionable recommendations in an executive report.

## Data Quality and Preparation

Data profiling was used to establish whether the source could reliably answer the business questions before reporting began.

### Bronze, Silver, and Gold layers

| Layer | Purpose | Main work |
|---|---|---|
| **Bronze** | Preserve source data | Load raw CSV data without transformation |
| **Silver** | Prepare reliable data | Assign data types, trim and standardize text, remove unwanted numeric symbols, validate keys, add sentinel rows, and apply constraints |
| **Gold** | Support analytics | Create the sales fact table and descriptive dimensions in a star schema |

### Silver-layer transformations

- Applied appropriate data types to columns.
- Used `TRIM()` to remove surrounding whitespace, and converted blank key values to `NULL` before casting so a blank can never break a load.
- Used `INITCAP()` for standardized title case and `UPPER()` for codes and SKUs where appropriate.
- Used `REGEXP_REPLACE()` to remove currency symbols and thousands separators before numeric conversion.
- Applied primary keys, foreign keys, nullability, and non-negative and range checks on the dimensions and the sales table.
- Added `-1` sentinel rows to the customer, reseller, product, territory, and date tables, after the primary keys exist and before the fact foreign keys are created.

### Validation checks

The build scripts include checks that run after each layer is loaded:

- **Row counts:** Bronze versus Silver for every table (sentinel rows excluded).
- **Financial totals:** Bronze versus Silver total sales, with the variance expected to be zero.
- **Grain and key uniqueness:** primary-key duplicate checks on every Silver dimension, plus line-item key uniqueness on the sales table and on the sales order data that is joined into the fact table.
- **Control totals:** row count, quantity, sales, and cost compared between Silver and Gold.
- **Referential integrity:** null-safe orphan checks for every fact-table key (product, customer, reseller, territory, and the order, due, and ship dates). No orphan keys were found.
- **Key profile by channel:** confirms that each channel uses the sentinel keys as expected and that always-required keys (product, territory, order date) are fully populated.
- **Sentinel usage:** shows which `-1` rows the sales table actually references.

### Important reconciliation findings

**1. The discount percentage field was zero on every row.**

The source column `unit_price_discount_pct` contained `0.00%` across all 121,253 rows, including the freshly downloaded source file. It therefore could not be used to measure the actual discount behaviour in the affected transactions.

**2. Sales Amount was retained as the source of truth.**

A total of 15,684 rows (12.9%), all in the Reseller channel, differed from the expected calculation using quantity, unit price, and the recorded discount field. Of these, 12,402 were small unit-price precision differences where Sales Amount equalled Extended Amount. The remaining 3,282 rows had Sales Amount below Extended Amount, indicating price reductions not represented in the discount percentage column.

Recalculating sales using the formula and the zeroed discount field would have overstated sales by approximately **\$527K (0.5%)** and margin by about **0.4 percentage points**. For this reason, the analysis retained Sales Amount and derived an effective discount from Extended Amount and Sales Amount where needed for investigation.

**3. Missing ship dates were preserved rather than fabricated.**

There were 2,113 missing `ShipDateKey` values, concentrated in orders placed from 9–15 June 2020. The pattern was consistent with orders near the end of the extract that had not yet shipped. These values were left null. The same pattern indicates the extract ends around mid-June 2020, which is why FY2020 is treated as a partial year.

**4. Product cost reconciliation was close.**

Total Product Cost closely matched Quantity multiplied by Product Standard Cost, with a maximum difference of \$0.15 and an average absolute difference of approximately \$0.004, consistent with rounding.

## Rebuilding the Database

Both layers can be rebuilt from scratch and rerun safely.

**Prerequisite:** the Bronze tables are loaded in PostgreSQL from the source CSV files.

1. **Silver layer:** run `silver_layer_full.sql`. Sections 1–4 (drop, create, load, constraints, and sentinel rows) run together as one transaction, so a failure leaves the previous Silver layer untouched. Run `ROLLBACK;` if the block errors, then retry. Section 5 holds the QA checks.
2. **Gold layer:** run `gold_layer_full.sql` section by section. It empties the Gold tables, audits Silver, creates the schema, tables, foreign keys, and indexes if they do not exist, then loads all six tables in one transaction and runs validation. Section 6 holds the analysis queries.
3. **Power BI:** connect to the six Gold tables and refresh.

## Power BI Semantic Model

The Gold tables were loaded into Power BI to create a semantic model designed for reliable business analysis rather than visual presentation alone.

### Model design

- Loaded only the six Gold tables into Power BI; Bronze and Silver remained preparation and validation layers.
- Connected each dimension to `fact_sales` using one-to-many relationships and single-direction filtering.
- Used `dim_date` as the date dimension for the July–June fiscal calendar.
- Set the order date relationship as active, with due date and ship date relationships inactive so the different date roles could be used through DAX when required.
- Hid technical foreign-key columns from report users.
- Stored measures in a dedicated measure table.

### Fiscal calendar

The analysis covers FY2018–FY2020, with the fiscal year running from July through June. For example, FY2018 contains:

- Q1: July–September 2017
- Q2: October–December 2017
- Q3: January–March 2018
- Q4: April–June 2018

The existing date dimension was used rather than relying on Power BI's automatic date table. Month labels were sorted by a month key so they appear in fiscal-calendar order rather than alphabetically.

### DAX measures

| Measure group | Measures |
|---|---|
| Core business measures | Total Sales, Total Cost, Gross Profit, Profit Margin %, Total Units, Total Orders, Average Order Value |
| Time intelligence | Sales YTD, Sales PY, Sales YoY Change, Sales YoY %, Profit PY, Profit YoY % |
| Driver analysis | Average Selling Price, Profit per Unit, Discount Amount, Discounted Sales Lines, Discount Rate |

These measures support comparisons across time, territory, product, and channel using consistent definitions.

### Executive Overview

The Executive Overview uses three main filters: Date Range, Territory, and Channel. It focuses on three questions:

1. How are sales changing over time? Monthly Total Sales compared with Sales PY.
2. How are revenue and profit changing by fiscal year? Revenue and profit by fiscal year.
3. Which territories perform well or poorly? Territory performance.

The wider report also investigates product categories, top and bottom products, subcategory performance, and reseller-versus-Internet profitability.

## Key Business Findings

### 1. Revenue growth came with margin pressure

Sales increased from **\$23.9M in FY2018 to \$51.9M in FY2020**, while profit margin decreased from **12.7% to 11.2%**. FY2020 covers only about 11.5 months, so the sales growth is, if anything, understated. Revenue growth alone gives an incomplete view of business performance: margin needs to be monitored alongside sales.

### 2. Bikes dominate revenue, but other categories deliver higher margins

| Category | Total sales | Gross profit | Margin |
|---|---:|---:|---:|
| Bikes | \$94.6M | \$10.5M | 11.1% |
| Components | \$11.8M | \$1.0M | 8.8% |
| Clothing | \$2.1M | \$0.4M | 17.4% |
| Accessories | \$1.3M | \$0.6M | 49.9% |

Bikes are the main revenue driver, accounting for approximately 86% of sales, but their margin is relatively thin. Accessories and Clothing generate less revenue but higher margins. Components have a comparatively low margin of 8.8%.

The top 10 products by gross profit were all Bikes, specifically Mountain-200 and Road-150 variants. Together, they generated approximately \$6.71M gross profit at a 23.24% margin. The bottom 10 products generated approximately **-\$518K gross profit**, at an aggregate margin of about **-8.85%**.

### 3. Touring Bike losses are concentrated in the Reseller channel

| Touring Bikes channel | Revenue | Product cost | Gross profit | Margin |
|---|---:|---:|---:|---:|
| Reseller | \$10.45M | \$11.69M | -\$1.24M | -11.84% |
| Internet | \$3.84M | \$2.39M | \$1.45M | 37.84% |

Seven of the ten products in the bottom 10 were Touring Bikes. Looking only at product-level performance could suggest that Touring Bikes are inherently unprofitable. Comparing channels changes the interpretation: Touring Bikes were profitable online but sold below standard product cost through Resellers.

This points to a channel-specific pricing or cost issue that needs further investigation, rather than a product-wide problem.

### 4. Discount depth does not explain reseller margin differences

| Reseller subcategory | Average effective discount | Gross margin |
|---|---:|---:|
| Touring Bikes | 2.33% | -11.84% |
| Road Bikes | 0.23% | -3.99% |
| Mountain Bikes | 0.66% | 5.36% |
| Jerseys | 0.75% | -22.91% |
| Caps | 0.89% | -18.17% |
| Touring Frames | 0.16% | -0.34% |
| Helmets | 1.38% | 32.99% |
| Wheels | 0.09% | 25.82% |

The observed reseller losses do not track closely with effective discount depth. For example, reseller Helmets had a 1.38% average effective discount and a 32.99% margin, while Road Bikes had a 0.23% discount and a negative margin.

For Touring Bikes, removing the observed discount would still leave an estimated margin of about -9%. The findings therefore point toward reseller pricing relative to standard product cost, rather than discount depth alone. The underlying reason for the pricing structure was not established by this analysis.

### 5. Territory performance is uneven

- **Australia** contributed approximately 10% of sales but 29% of gross profit, at a margin of about 34%.
- **Central, Southeast, and Northeast** together contributed around 21% of sales while earning margins of roughly 2%.
- **Southwest, Canada, and Northwest** together generated about half of all sales, approximately \$56M.

The contrast between revenue contribution and profit contribution shows why territories should be assessed using both sales and margin.

## Recommendations

### 1. Review reseller pricing for finished bikes

Review reseller price lists against standard product costs for Touring, Road, and Mountain Bikes, starting with the Touring-1000 and Touring-3000 lines. The Touring Bike reseller channel recorded approximately **\$1.24M in gross losses**, and the bottom 10 products together lost approximately \$518K.

Discount caps alone are unlikely to resolve the issue because the observed average effective discounts were relatively small. Confirm standard costs and reseller pricing rules, especially because the same Touring Bikes were profitable through the Internet channel.

### 2. Grow sales of high-margin complementary categories

Consider bundling Accessories and Clothing with Bike purchases, for example helmets or shorts alongside a bike. Accessories had a 49.9% margin and Clothing had a 17.4% margin in this analysis. These categories may offer opportunities to improve the profitability of the overall product mix.

### 3. Audit pricing for Jerseys, Caps, and selected Road Bikes

Investigate reseller price lists for Jerseys, Caps, and Road-650 Red, 44. Reseller Jerseys had a -22.91% margin and Caps had a -18.17% margin. Review whether these products are being sold below an appropriate cost-based price.

### 4. Investigate low-margin territories

Prioritize Central, Southeast, and Northeast for further investigation. Compare their product mix, channel mix, and pricing patterns with stronger-performing territories such as Australia. The aim is to identify which factors explain the margin gap before deciding on corrective action.

## Limitations and Considerations

- **Partial final fiscal year:** the extract ends around mid-June 2020, so FY2020 covers about 11.5 months. Fiscal-year comparisons involving FY2020 should be read with that in mind. The SQL year-over-year analysis drops June 16–30 from every year to keep periods like-for-like, so its figures will differ slightly from report totals that include all dates.
- **Discount field quality:** `unit_price_discount_pct` was zero for every source row. Effective discounts were derived from Extended Amount and Sales Amount for analysis, but the cause of the source-field issue could not be confirmed from public documentation.
- **Missing ship dates:** 2,113 orders dated 9–15 June 2020 had no `ShipDateKey`. Ship-date analysis near the end of the reporting period should be treated cautiously.
- **Reseller pricing cause not confirmed:** The analysis identifies where reseller sales lose money but does not establish why reseller prices fall below standard product cost. Input from the pricing owner is needed.
- **Interpretation of sentinels:** The `-1` keys and the `1900-01-01` placeholder are modelling conventions, not real business entities or transaction dates. Counts of customers or resellers should exclude the `-1` rows.
- **Scope:** Findings describe the supplied AdventureWorks extract and its July 2017 – mid-June 2020 period; they should not be assumed to describe other periods without further validation.

## Skills Demonstrated

| Area | Evidence |
|---|---|
| Stakeholder management | Translated a broad request into scoped objectives, metrics, filters, and a defined reporting period |
| PostgreSQL / SQL | Data profiling, `FILTER` aggregates, key and duplicate checks, text normalization, regular-expression cleaning, window functions, and financial reconciliation |
| Data quality | Investigated missing ship dates, inconsistent discount information, sentinel keys, and cost calculations |
| ETL and data architecture | Implemented a Bronze / Silver / Gold workflow with rerunnable, transactional build scripts and layer-to-layer reconciliation |
| Dimensional modelling | Designed a sales fact table with customer, product, reseller, territory, and date dimensions |
| Power BI | Built a semantic model, configured relationships, and organized measures for report use |
| DAX | Created core profitability measures and fiscal time-intelligence calculations |
| Business analysis | Separated revenue performance from profitability and traced channel-level losses |
| Communication | Converted analysis into management-focused findings and actionable recommendations |

## Repository Structure

```text
operations-and-revenue-analysis/
├── README.md
├── sql/
│   ├── bronze/
│   ├── silver/
│   │   └── silver_layer_full.sql
│   └── gold/
│       └── gold_layer_full.sql
├── power-bi/
│   └── operations-and-revenue-analysis.pbix
├── images/
│   ├── executive-overview.png
│   └── product-performance.png
└── docs/
    └── Operations_and_Revenue_Analysis_Portfolio.pdf
```

**Note:** This is a suggested layout. Rename paths to match what your repository actually contains, add screenshots only once exported, and include the PBIX file only if you can share it.

## How to Explore the Project

1. Start with the executive summary to understand the business question and headline findings.
2. Review the SQL scripts to follow the profiling, cleaning, validation, and Gold-layer modelling process, or follow [Rebuilding the Database](#rebuilding-the-database) to recreate the layers yourself.
3. Inspect the star schema and confirm that the fact-table grain and dimension relationships support the analysis.
4. Open the Power BI report, if included, and use the date, territory, and channel filters to explore results.
5. Compare revenue and gross profit together, then investigate category, subcategory, and channel-level margins.
6. Use the recommendations as hypotheses for further business investigation, especially the reseller pricing issue.

---

## Final Takeaway

**Revenue growth is not the same as profitable growth.** This project demonstrates how data profiling, sound modelling, and business-focused analysis can move beyond reporting what happened to identify where management should investigate, and why looking at product and channel performance together can change the conclusion.

*Project documentation is based on the analysis and results described in this portfolio project.*
