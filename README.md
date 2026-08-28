# Supply Chain Performance Dashboard

> An interactive Power BI dashboard analyzing 65,000+ orders from a global supply chain dataset, built on a normalized PostgreSQL star schema.

---

## Overview

This project takes a raw, denormalized 180K-row supply chain CSV and turns it into a proper analytics stack:

1. **PostgreSQL** — designed a normalized star schema (dimension + fact tables) and loaded the data via `COPY` and staging tables.
2. **Power BI** — connected directly to PostgreSQL, built custom DAX measures for all business logic (no pre-computed columns), and delivered a 3-page interactive report.

No spreadsheet exports, no manual CSV shuffling between tools — Power BI queries the database directly, and every KPI on the dashboard is a live DAX calculation.

---

## Tech Stack

| Layer | Tool | Role |
|---|---|---|
| Database | PostgreSQL | Stores the normalized star schema — single source of truth |
| Data Load | SQL (`COPY`, staging tables) | Loads raw CSVs and splits them into dimension/fact tables |
| Visualization | Power BI Desktop | Connects live to PostgreSQL; all metrics computed via DAX |

---

## Data Model

Star schema with 4 dimension tables and 2 fact tables:

```
dim_customers ──< fact_orders >── fact_order_items >── dim_products ──< dim_categories
                                                                     └─< dim_departments
```

- **`fact_orders`** (65,752 rows) — order-level grain: dates, shipping mode, delivery status, late-delivery flag
- **`fact_order_items`** (180,519 rows) — order-line grain: sales, discount, profit
- **`dim_customers`**, **`dim_products`**, **`dim_categories`**, **`dim_departments`** — descriptive lookup tables

PII fields (email, password, name, street, zipcode) were excluded at the schema design stage.

See [`setup.sql`](./setup.sql) for the full pipeline — table creation, indexes, staging tables, and the `COPY` + `INSERT` statements that populate the schema from the raw CSVs.

---

## Dashboard

### Page 1 — Executive Overview
KPI cards (Total Orders, Late Delivery Rate, Profit at Risk), a world map of order volume, a Sales-vs-Profit combo chart, delivery status breakdown, and category sales ranking.

**Key finding:** Late delivery rate holds at 54.8% — nearly 4x above a 15% target.

### Page 2 — Delivery Performance
Late delivery rate by shipping mode and region (with a bookmark-driven toggle between a simple regional view and a region × shipping-mode heatmap matrix), monthly trend, and profit by delivery status.

**Key finding:** First Class — the fastest shipping option — has the *worst* late rate (95.3%), while Standard Class performs far better (38.1%).

### Page 3 — Product & Customer Insights
Top products by sales, profit margin by category, sales by customer segment, and a top-10 customers-by-profit table.

**Key finding:** A single product ("Field & Stream Sportsman 16 Gun Fire Safe") drives $6.9M in sales — 57% more than the next-highest product, a revenue concentration risk.

---

## Key DAX Measures

```dax
Late Delivery Rate % =
DIVIDE(
    COUNTROWS(FILTER(fact_orders, fact_orders[late_delivery_risk]=1)),
    COUNTROWS(fact_orders))

Profit at Risk =
SUMX(FILTER(fact_orders, fact_orders[late_delivery_risk]=1), [Total Profit])

Profit Margin % =
DIVIDE([Total Profit], [Total Sales])
```

Full measure list in the `.pbix` file under the `_Measures` table.

---

## Project Structure

```
supplylens-dashboard/
├── setup.sql                    # Full DB pipeline: schema, indexes, staging, COPY load
├── supply_chain_dashboard.pbix  # The Power BI report (3 pages)
├── README.md
└── screenshots/                 # Exported dashboard page images
```

---

## Setup / Reproduce

1. Create a PostgreSQL database: `CREATE DATABASE supply_chain;`
2. Open `setup.sql` in pgAdmin (or `psql`), update the two file paths in the `COPY` statements (Section 6) to point to your local copy of `DataCoSupplyChainDataset.csv` and `tokenized_access_logs.csv`.
3. Run the entire script — it creates the dimension/fact tables and indexes, stages the raw CSVs, and populates the normalized schema in one pass. The final query prints row counts per table to confirm the load.
4. Open `supply_chain_dashboard.pbix` in Power BI Desktop, update the PostgreSQL connection details (Home → Transform Data → Data source settings), and refresh.

---

## Dataset

Source: [DataCo Smart Supply Chain dataset](https://www.kaggle.com/datasets/shashwatwork/dataco-smart-supply-chain-for-big-data-analysis) (Kaggle), 180,519 order-line records across global markets.

---

## Screenshots

![Executive Overview](/screenshots/page1_executive_overview.png)

![Delivery Performance](/screenshots/page2_delivery_performance.png)

![Product & Customer Insights](/screenshots/page3_product_customer_insights.png)
