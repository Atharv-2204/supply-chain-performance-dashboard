-- 1: Create dimension tables

CREATE TABLE dim_departments (
    department_id     INTEGER PRIMARY KEY,
    department_name   VARCHAR(100) NOT NULL
);

CREATE TABLE dim_categories (
    category_id        INTEGER PRIMARY KEY,
    category_name       VARCHAR(100) NOT NULL
);

CREATE TABLE dim_customers (
    customer_id        INTEGER PRIMARY KEY,
    customer_segment    VARCHAR(50),
    customer_city        VARCHAR(100),
    customer_state       VARCHAR(50),
    customer_country     VARCHAR(50)
);

CREATE TABLE dim_products (
    product_card_id     INTEGER PRIMARY KEY,
    product_name          VARCHAR(255),
    product_price         NUMERIC(12,2),
    product_status         SMALLINT,
    category_id            INTEGER REFERENCES dim_categories(category_id),
    department_id          INTEGER REFERENCES dim_departments(department_id)
);

-- 2: Create fact tables

CREATE TABLE fact_orders (
    order_id                        INTEGER PRIMARY KEY,
    customer_id                     INTEGER REFERENCES dim_customers(customer_id),
    order_date                       TIMESTAMP NOT NULL,
    shipping_date                    TIMESTAMP NOT NULL,
    market                            VARCHAR(50),
    order_region                      VARCHAR(50),
    order_country                     VARCHAR(100),
    order_state                       VARCHAR(100),
    order_city                        VARCHAR(100),
    order_status                      VARCHAR(50),
    shipping_mode                     VARCHAR(50),
    days_for_shipping_real            INTEGER,
    days_for_shipment_scheduled       INTEGER,
    delivery_status                   VARCHAR(50),
    late_delivery_risk                SMALLINT
);

CREATE TABLE fact_order_items (
    order_item_id            INTEGER PRIMARY KEY,
    order_id                  INTEGER REFERENCES fact_orders(order_id),
    product_card_id           INTEGER REFERENCES dim_products(product_card_id),
    order_item_type            VARCHAR(50),
    order_item_quantity         INTEGER,
    order_item_product_price     NUMERIC(12,2),
    order_item_discount           NUMERIC(12,2),
    order_item_discount_rate      NUMERIC(6,4),
    order_item_profit_ratio        NUMERIC(8,4),
    sales                            NUMERIC(12,2),
    sales_per_customer                NUMERIC(12,2),
    order_item_total                   NUMERIC(12,2),
    order_profit_per_order              NUMERIC(12,2),
    benefit_per_order                    NUMERIC(12,2)
);

CREATE TABLE web_access_logs (
    log_id       SERIAL PRIMARY KEY,
    product       VARCHAR(255),
    category       VARCHAR(100),
    log_date         TIMESTAMP,
    log_month           VARCHAR(10),
    log_hour               INTEGER,
    department               VARCHAR(100),
    ip                        VARCHAR(64),
    url                         TEXT
);

-- 3: Indexes

CREATE INDEX idx_orders_date          ON fact_orders (order_date);
CREATE INDEX idx_orders_region        ON fact_orders (order_region);
CREATE INDEX idx_orders_shipmode      ON fact_orders (shipping_mode);
CREATE INDEX idx_orders_late          ON fact_orders (late_delivery_risk);
CREATE INDEX idx_order_items_order    ON fact_order_items (order_id);
CREATE INDEX idx_order_items_product  ON fact_order_items (product_card_id);
CREATE INDEX idx_weblogs_date         ON web_access_logs (log_date);

-- 4: Fix date parsing (source dates are M/D/Y)

SET datestyle TO 'ISO, MDY';

-- 5: Create staging tables (mirror raw CSV columns)

CREATE TABLE staging_orders (
    "Type"                              TEXT,
    "Days for shipping (real)"          TEXT,
    "Days for shipment (scheduled)"     TEXT,
    "Benefit per order"                 TEXT,
    "Sales per customer"                TEXT,
    "Delivery Status"                   TEXT,
    "Late_delivery_risk"                TEXT,
    "Category Id"                       TEXT,
    "Category Name"                     TEXT,
    "Customer City"                     TEXT,
    "Customer Country"                  TEXT,
    "Customer Email"                    TEXT,
    "Customer Fname"                    TEXT,
    "Customer Id"                       TEXT,
    "Customer Lname"                    TEXT,
    "Customer Password"                 TEXT,
    "Customer Segment"                  TEXT,
    "Customer State"                    TEXT,
    "Customer Street"                   TEXT,
    "Customer Zipcode"                  TEXT,
    "Department Id"                     TEXT,
    "Department Name"                   TEXT,
    "Latitude"                          TEXT,
    "Longitude"                         TEXT,
    "Market"                            TEXT,
    "Order City"                        TEXT,
    "Order Country"                     TEXT,
    "Order Customer Id"                 TEXT,
    "order date (DateOrders)"           TEXT,
    "Order Id"                          TEXT,
    "Order Item Cardprod Id"            TEXT,
    "Order Item Discount"               TEXT,
    "Order Item Discount Rate"          TEXT,
    "Order Item Id"                     TEXT,
    "Order Item Product Price"          TEXT,
    "Order Item Profit Ratio"           TEXT,
    "Order Item Quantity"               TEXT,
    "Sales"                             TEXT,
    "Order Item Total"                  TEXT,
    "Order Profit Per Order"            TEXT,
    "Order Region"                      TEXT,
    "Order State"                       TEXT,
    "Order Status"                      TEXT,
    "Order Zipcode"                     TEXT,
    "Product Card Id"                   TEXT,
    "Product Category Id"               TEXT,
    "Product Description"               TEXT,
    "Product Image"                     TEXT,
    "Product Name"                      TEXT,
    "Product Price"                     TEXT,
    "Product Status"                    TEXT,
    "shipping date (DateOrders)"        TEXT,
    "Shipping Mode"                     TEXT
);

CREATE TABLE staging_weblogs (
    "Product"     TEXT,
    "Category"    TEXT,
    "Date"        TEXT,
    "Month"       TEXT,
    "Hour"        TEXT,
    "Department"  TEXT,
    "ip"          TEXT,
    "url"         TEXT
);

-- 6: COPY the CSVs into staging

COPY staging_orders
FROM 'D:\projects\personal projects\supply_chain_analysis\DataCoSupplyChainDataset.csv'
DELIMITER ','
CSV HEADER
ENCODING 'LATIN1';

COPY staging_weblogs
FROM 'D:\projects\personal projects\supply_chain_analysis\tokenized_access_logs.csv'
DELIMITER ','
CSV HEADER
ENCODING 'LATIN1';

-- 7: Populate dimension tables from staging

INSERT INTO dim_departments (department_id, department_name)
SELECT DISTINCT "Department Id"::INTEGER, "Department Name"
FROM staging_orders
WHERE "Department Id" IS NOT NULL;

INSERT INTO dim_categories (category_id, category_name)
SELECT DISTINCT "Category Id"::INTEGER, "Category Name"
FROM staging_orders
WHERE "Category Id" IS NOT NULL;

INSERT INTO dim_customers (customer_id, customer_segment, customer_city, customer_state, customer_country)
SELECT DISTINCT ON ("Customer Id")
    "Customer Id"::INTEGER,
    "Customer Segment",
    "Customer City",
    "Customer State",
    "Customer Country"
FROM staging_orders
WHERE "Customer Id" IS NOT NULL;

INSERT INTO dim_products (product_card_id, product_name, product_price, product_status, category_id, department_id)
SELECT DISTINCT ON ("Product Card Id")
    "Product Card Id"::INTEGER,
    "Product Name",
    "Product Price"::NUMERIC,
    "Product Status"::SMALLINT,
    "Category Id"::INTEGER,
    "Department Id"::INTEGER
FROM staging_orders
WHERE "Product Card Id" IS NOT NULL;

-- 8: Populate fact tables from staging

INSERT INTO fact_orders (
    order_id, customer_id, order_date, shipping_date, market, order_region,
    order_country, order_state, order_city, order_status, shipping_mode,
    days_for_shipping_real, days_for_shipment_scheduled, delivery_status, late_delivery_risk
)
SELECT DISTINCT ON ("Order Id")
    "Order Id"::INTEGER,
    "Customer Id"::INTEGER,
    "order date (DateOrders)"::TIMESTAMP,
    "shipping date (DateOrders)"::TIMESTAMP,
    "Market",
    "Order Region",
    "Order Country",
    "Order State",
    "Order City",
    "Order Status",
    "Shipping Mode",
    "Days for shipping (real)"::INTEGER,
    "Days for shipment (scheduled)"::INTEGER,
    "Delivery Status",
    "Late_delivery_risk"::SMALLINT
FROM staging_orders
WHERE "Order Id" IS NOT NULL;

INSERT INTO fact_order_items (
    order_item_id, order_id, product_card_id, order_item_type, order_item_quantity,
    order_item_product_price, order_item_discount, order_item_discount_rate,
    order_item_profit_ratio, sales, sales_per_customer, order_item_total,
    order_profit_per_order, benefit_per_order
)
SELECT
    "Order Item Id"::INTEGER,
    "Order Id"::INTEGER,
    "Product Card Id"::INTEGER,
    "Type",
    "Order Item Quantity"::INTEGER,
    "Order Item Product Price"::NUMERIC,
    "Order Item Discount"::NUMERIC,
    "Order Item Discount Rate"::NUMERIC,
    "Order Item Profit Ratio"::NUMERIC,
    "Sales"::NUMERIC,
    "Sales per customer"::NUMERIC,
    "Order Item Total"::NUMERIC,
    "Order Profit Per Order"::NUMERIC,
    "Benefit per order"::NUMERIC
FROM staging_orders;

-- 9: Populate web_access_logs from staging

INSERT INTO web_access_logs (product, category, log_date, log_month, log_hour, department, ip, url)
SELECT
    "Product",
    "Category",
    "Date"::TIMESTAMP,
    "Month",
    "Hour"::INTEGER,
    "Department",
    "ip",
    "url"
FROM staging_weblogs;

-- 10: Verify row counts

SELECT 'dim_departments' AS table_name, COUNT(*) FROM dim_departments
UNION ALL SELECT 'dim_categories', COUNT(*) FROM dim_categories
UNION ALL SELECT 'dim_customers', COUNT(*) FROM dim_customers
UNION ALL SELECT 'dim_products', COUNT(*) FROM dim_products
UNION ALL SELECT 'fact_orders', COUNT(*) FROM fact_orders
UNION ALL SELECT 'fact_order_items', COUNT(*) FROM fact_order_items
UNION ALL SELECT 'web_access_logs', COUNT(*) FROM web_access_logs;


