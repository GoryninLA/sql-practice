CREATE TABLE sales_var004 (
    sale_id        UInt64,
    sale_timestamp DateTime64(3),
    product_id     UInt32,
    category       LowCardinality(String),
    customer_id    UInt64,
    region         LowCardinality(String),
    quantity       UInt16,
    unit_price     Decimal64(2),
    discount_pct   Float32,
    is_online      UInt8,
    ip_address     IPv4
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(sale_timestamp)
ORDER BY (sale_timestamp, customer_id, product_id);

INSERT INTO sales_var004 
(sale_id, sale_timestamp, product_id, category, customer_id, region, quantity, unit_price, discount_pct, is_online, ip_address)
SELECT 
    number + 4001 AS sale_id,
    toDateTime64(
        CASE 
            WHEN number < 34 THEN 
                concat('2024-11-15 ', 
                       leftPad(toString(10 + (number % 14)), 2, '0'), ':',
                       leftPad(toString(number % 60), 2, '0'), ':00')
            WHEN number < 67 THEN 
                concat('2024-12-20 ', 
                       leftPad(toString(8 + (number % 16)), 2, '0'), ':',
                       leftPad(toString(number % 60), 2, '0'), ':00')
            ELSE 
                concat('2025-01-10 ', 
                       leftPad(toString(9 + (number % 15)), 2, '0'), ':',
                       leftPad(toString(number % 60), 2, '0'), ':00')
        END,
        3
    ) AS sale_timestamp,
    40 + (number % 20) AS product_id,
    CASE (number % 5)
        WHEN 0 THEN 'Electronics'
        WHEN 1 THEN 'Clothing'
        WHEN 2 THEN 'Books'
        WHEN 3 THEN 'Home & Garden'
        ELSE 'Sports'
    END AS category,
    400 + (number % 100) AS customer_id,
    CASE (number % 6)
        WHEN 0 THEN 'North'
        WHEN 1 THEN 'South'
        WHEN 2 THEN 'East'
        WHEN 3 THEN 'West'
        WHEN 4 THEN 'Central'
        ELSE 'International'
    END AS region,
    1 + (number % 9) AS quantity,
    toDecimal64(14 + (number % 501), 2) AS unit_price,
    (number % 100) / 100.0 AS discount_pct,
    number % 2 AS is_online,
    toIPv4(
        concat(
            toString(192 + (number % 64)),
            '.',
            toString(168 + (number % 88)),
            '.',
            toString(number % 256),
            '.',
            toString(1 + (number % 254))
        )
    ) AS ip_address
FROM numbers(100);

--Общая выручка по категориям
SELECT 
    category,
    SUM(quantity * unit_price * (1 - discount_pct)) AS total_revenue
FROM sales_var004
GROUP BY category
ORDER BY total_revenue DESC;

--Топ-3 клиента по количеству покупок
SELECT 
    customer_id,
    COUNT(*) AS purchase_count,
    SUM(quantity) AS total_quantity
FROM sales_var004
GROUP BY customer_id
ORDER BY purchase_count DESC
LIMIT 3;

--Средний чек по месяцам
SELECT 
    toYYYYMM(sale_timestamp) AS month,
    AVG(quantity * unit_price) AS avg_check
FROM sales_var004
GROUP BY month
ORDER BY month;

--Фильтрация по партиции (2025)
SELECT 
    sale_id,
    sale_timestamp,
    product_id,
    category,
    customer_id,
    region,
    quantity,
    unit_price,
    discount_pct,
    is_online,
    ip_address
FROM sales_var004
WHERE sale_timestamp >= '2025-01-01 00:00:00' 
  AND sale_timestamp < '2025-02-01 00:00:00'
ORDER BY sale_timestamp;

EXPLAIN 
SELECT 
    sale_id,
    sale_timestamp,
    product_id,
    category,
    customer_id,
    region,
    quantity,
    unit_price,
    discount_pct,
    is_online,
    ip_address
FROM sales_var004
WHERE sale_timestamp >= '2025-01-01 00:00:00' 
  AND sale_timestamp < '2025-02-01 00:00:00';

CREATE TABLE products_var004 (
    product_id    UInt32,
    product_name  String,
    category      LowCardinality(String),
    supplier      String,
    base_price    Decimal64(2),
    weight_kg     Float32,
    is_available  UInt8,
    updated_at    DateTime,
    version       UInt64
)
ENGINE = ReplacingMergeTree(version)
ORDER BY (product_id);

INSERT INTO products_var004 
(product_id, version, product_name, category, base_price, is_available)
VALUES
    (40, 1, 'Смартфон Model 40', 'Electronics', 14.00, 1),
    (41, 1, 'Ноутбук Model 41', 'Electronics', 514.00, 1),
    (42, 1, 'Наушники Model 42', 'Electronics', 149.99, 1),
    (43, 1, 'Футболка Cotton', 'Clothing', 29.99, 1),
    (44, 1, 'Джинсы Classic', 'Clothing', 79.99, 1),
    (45, 1, 'Книга "SQL Guide"', 'Books', 49.99, 1),
    (46, 1, 'Садовый инвентарь', 'Home & Garden', 89.99, 1),
    (47, 1, 'Футбольный мяч Pro', 'Sports', 39.99, 1),
    (48, 1, 'Умная колонка', 'Electronics', 199.99, 1);

INSERT INTO products_var004
(product_id, version, product_name, category, base_price, is_available)
VALUES
    (40, 2, 'Смартфон Model 40', 'Electronics', 12.99, 0),
    (43, 2, 'Футболка Cotton', 'Clothing', 24.99, 0),
    (46, 2, 'Книга "SQL Guide"', 'Books', 44.99, 0);


SELECT * FROM products_var004;

OPTIMIZE TABLE products_var004 FINAL;

INSERT INTO products_var004
(product_id, version, product_name, category, base_price, is_available)
VALUES
    (40, 1, 'Смартфон Model 40', 'Electronics', 14.00, 1);

SELECT * FROM products_var004 FINAL;

CREATE TABLE daily_metrics_var004 (
    metric_date    Date,
    campaign_id    UInt32,
    channel        LowCardinality(String),
    impressions    UInt64,
    clicks         UInt64,
    conversions    UInt32,
    spend_cents    UInt64
)
ENGINE = SummingMergeTree()
ORDER BY (metric_date, campaign_id, channel);

INSERT INTO daily_metrics_var004 VALUES

('2024-01-01', 41, 'social', 1000, 50, 5, 50000),
('2024-01-01', 41, 'search', 1500, 75, 8, 75000),
('2024-01-01', 42, 'social', 2000, 100, 10, 100000),
('2024-01-01', 42, 'search', 2500, 125, 12, 125000),
('2024-01-01', 43, 'social', 3000, 150, 15, 150000),
('2024-01-01', 43, 'search', 3500, 175, 18, 175000),


('2024-01-02', 41, 'social', 1100, 55, 6, 55000),
('2024-01-02', 41, 'search', 1600, 80, 9, 80000),
('2024-01-02', 42, 'social', 2100, 105, 11, 105000),
('2024-01-02', 42, 'search', 2600, 130, 13, 130000),
('2024-01-02', 43, 'social', 3100, 155, 16, 155000),
('2024-01-02', 43, 'search', 3600, 180, 19, 180000),


('2024-01-03', 41, 'social', 1200, 60, 7, 60000),
('2024-01-03', 41, 'search', 1700, 85, 10, 85000),
('2024-01-03', 42, 'social', 2200, 110, 12, 110000),
('2024-01-03', 42, 'search', 2700, 135, 14, 135000),
('2024-01-03', 43, 'social', 3200, 160, 17, 160000),
('2024-01-03', 43, 'search', 3700, 185, 20, 185000),


('2024-01-04', 41, 'social', 1300, 65, 8, 65000),
('2024-01-04', 41, 'search', 1800, 90, 11, 90000),
('2024-01-04', 42, 'social', 2300, 115, 13, 115000),
('2024-01-04', 42, 'search', 2800, 140, 15, 140000),
('2024-01-04', 43, 'social', 3300, 165, 18, 165000),
('2024-01-04', 43, 'search', 3800, 190, 21, 190000),


('2024-01-05', 41, 'social', 1400, 70, 9, 70000),
('2024-01-05', 41, 'search', 1900, 95, 12, 95000),
('2024-01-05', 42, 'social', 2400, 120, 14, 120000),
('2024-01-05', 42, 'search', 2900, 145, 16, 145000),
('2024-01-05', 43, 'social', 3400, 170, 19, 170000),
('2024-01-05', 43, 'search', 3900, 195, 22, 195000),

('2024-01-06', 41, 'social', 1500, 75, 10, 75000),
('2024-01-06', 41, 'search', 2000, 100, 13, 100000),
('2024-01-06', 42, 'social', 2500, 125, 15, 125000),
('2024-01-06', 42, 'search', 3000, 150, 17, 150000),
('2024-01-06', 43, 'social', 3500, 175, 20, 175000),
('2024-01-06', 43, 'search', 4000, 200, 23, 200000),


('2024-01-07', 41, 'social', 1600, 80, 11, 80000),
('2024-01-07', 41, 'search', 2100, 105, 14, 105000),
('2024-01-07', 42, 'social', 2600, 130, 16, 130000),
('2024-01-07', 42, 'search', 3100, 155, 18, 155000),
('2024-01-07', 43, 'social', 3600, 180, 21, 180000),
('2024-01-07', 43, 'search', 4100, 205, 24, 205000);


INSERT INTO daily_metrics_var004 VALUES

('2024-01-01', 41, 'social', 500, 25, 3, 25000),   
('2024-01-01', 41, 'search', 750, 38, 4, 37500),
('2024-01-02', 42, 'social', 1050, 53, 6, 52500),
('2024-01-03', 43, 'search', 1850, 93, 10, 92500),
('2024-01-04', 41, 'social', 650, 33, 4, 32500),
('2024-01-05', 42, 'search', 1450, 73, 8, 72500);


SELECT 'До оптимизации' as stage, metric_date, campaign_id, channel, 
       impressions, clicks, conversions, spend_cents
FROM daily_metrics_var004
WHERE (metric_date = '2024-01-01' AND campaign_id = 41 AND channel = 'social')
ORDER BY metric_date, campaign_id, channel;


OPTIMIZE TABLE daily_metrics_var004 FINAL;


SELECT 'После оптимизации' as stage, metric_date, campaign_id, channel, 
       impressions, clicks, conversions, spend_cents
FROM daily_metrics_var004
WHERE (metric_date = '2024-01-01' AND campaign_id = 41 AND channel = 'social')
ORDER BY metric_date, campaign_id, channel;


SELECT 
    channel,
    sum(clicks) as total_clicks,
    sum(impressions) as total_impressions,
    round(sum(clicks) / sum(impressions) * 100, 2) as ctr_percent
FROM daily_metrics_var004
GROUP BY channel
ORDER BY channel;



SELECT
    _partition_id AS partition,
    count() AS total_rows
FROM sales_var004
GROUP BY _partition_id
ORDER BY partition;


SELECT
    p.product_name,
    p.category,
    sum(s.quantity * s.unit_price * (1 - s.discount_pct)) AS revenue
FROM sales_var004 AS s
INNER JOIN products_var004 AS p
    ON s.product_id = p.product_id
GROUP BY p.product_name, p.category
ORDER BY revenue DESC
LIMIT 5;


DESCRIBE TABLE sales_var004;
DESCRIBE TABLE products_var004;
DESCRIBE TABLE daily_metrics_var004;


CREATE TABLE IF NOT EXISTS tags_var004 (
    item_id  UInt32,
    item_name String,
    tags     Array(String)
) ENGINE = MergeTree()
ORDER BY item_id;

INSERT INTO tags_var004 VALUES
    (1, 'Item A', ['sale', 'popular', 'new']),
    (2, 'Item B', ['premium', 'limited']),
    (3, 'Item C', ['sale', 'clearance']);


SELECT
    arrayJoin(tags) AS tag,
    count()         AS items_count
FROM tags_var004
GROUP BY tag
ORDER BY items_count DESC;


SELECT
    'sales'   AS tbl, 
    count() AS rows, 
    sum(quantity) AS check_sum 
FROM sales_var004
UNION ALL
SELECT
    'products', 
    count(), 
    sum(toUInt64(product_id)) 
FROM products_var004
UNION ALL
SELECT
    'metrics',  
    count(), 
    sum(clicks) 
FROM daily_metrics_var004;