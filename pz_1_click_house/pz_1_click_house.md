# ПЗ №1. Основы ClickHouse: установка, типы данных, движки таблиц
## Вариант 004
## Цель занятия
Получить практические навыки работы с колоночной СУБД ClickHouse: подключиться к облачному серверу, освоить создание баз данных и таблиц с правильным выбором типов данных и движков семейства MergeTree.

### Задание 1. Создание таблицы продаж

```sql
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
```
### Ззаполнение таблицы
```sql
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
```

### Задание 2. Аналитические запросы

#### Общая выручка по категориям 
```sql
SELECT 
    category,
    SUM(quantity * unit_price * (1 - discount_pct)) AS total_revenue
FROM sales_var004
GROUP BY category
ORDER BY total_revenue DESC;
```
<img width="662" height="310" alt="image" src="https://github.com/user-attachments/assets/6a27acc4-4040-4bc1-9c84-171d00f7e1fc" />

#### Топ-3 клиента по количеству покупок
```sql
SELECT 
    customer_id,
    COUNT(*) AS purchase_count,
    SUM(quantity) AS total_quantity
FROM sales_var004
GROUP BY customer_id
ORDER BY purchase_count DESC
LIMIT 3;
```

<img width="902" height="218" alt="image" src="https://github.com/user-attachments/assets/68b0747b-adf8-47ad-92ab-eff1f0beb9db" />

#### Средний чек по месяцам 
```sql
SELECT 
    toYYYYMM(sale_timestamp) AS month,
    AVG(quantity * unit_price) AS avg_check
FROM sales_var004
GROUP BY month
ORDER BY month;
```

<img width="652" height="238" alt="image" src="https://github.com/user-attachments/assets/41c68dcc-21e3-4c1d-9262-569bf241e596" />

#### Фильтрация по партиции
```sql
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
```

<img width="2348" height="456" alt="image" src="https://github.com/user-attachments/assets/a19a7415-63f0-4d36-a6d5-1f9d84602637" />

#### Проверка через EXPLAIN
```sql

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
```
<img width="848" height="236" alt="image" src="https://github.com/user-attachments/assets/d766e24a-10c2-4524-bfd3-fe5b294a2c0b" />

### Задание 3. ReplacingMergeTree — справочник товаров
#### Создание таблицы products_var004
```sql
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
```

#### Заполенение талицы products_var004
```sql
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
```
#### Для 3 товаров вставляем обновлённые записи
```sql
INSERT INTO products_var004
(product_id, version, product_name, category, base_price, is_available)
VALUES
    (40, 2, 'Смартфон Model 40', 'Electronics', 12.99, 0),
    (43, 2, 'Футболка Cotton', 'Clothing', 24.99, 0),
    (46, 2, 'Книга "SQL Guide"', 'Books', 44.99, 0);
```

#### Выполнили SELECT * FROM products_var004
<img width="2344" height="460" alt="image" src="https://github.com/user-attachments/assets/d822035c-1438-44aa-985c-25f30380ee7e" />

#### Выполнили OPTIMIZE TABLE products_var004 FINAL и повторяем запрос SELECT * FROM products_var004
<img width="2342" height="442" alt="image" src="https://github.com/user-attachments/assets/2d32dc2c-a842-4c6f-ae1d-1399c5fb5795" />

#### Показываю результаты запроса SELECT * FROM products_varNNN FINAL
<img width="2342" height="442" alt="image" src="https://github.com/user-attachments/assets/2d32dc2c-a842-4c6f-ae1d-1399c5fb5795" />


### Задание 4. SummingMergeTree — агрегация метрик
#### Создание таблицы daily_metrics_var004 и заполение данными
```sql
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
```

#### Вставляем повторные строки с теми же ключами
```sql
INSERT INTO daily_metrics_var004 VALUES

('2024-01-01', 41, 'social', 500, 25, 3, 25000),   
('2024-01-01', 41, 'search', 750, 38, 4, 37500),
('2024-01-02', 42, 'social', 1050, 53, 6, 52500),
('2024-01-03', 43, 'search', 1850, 93, 10, 92500),
('2024-01-04', 41, 'social', 650, 33, 4, 32500),
('2024-01-05', 42, 'search', 1450, 73, 8, 72500);
```

#### Запрос до оптимизации 
```sql
SELECT 'До оптимизации' as stage, metric_date, campaign_id, channel, 
       impressions, clicks, conversions, spend_cents
FROM daily_metrics_var004
WHERE (metric_date = '2024-01-01' AND campaign_id = 41 AND channel = 'social')
ORDER BY metric_date, campaign_id, channel;
```
<img width="2198" height="170" alt="image" src="https://github.com/user-attachments/assets/4c158a1a-71de-447e-b32e-ebfaae7a116e" />

#### Запрос после OPTIMIZE TABLE daily_metrics_var004 FINAL
```sql
SELECT 'После оптимизации' as stage, metric_date, campaign_id, channel, 
       impressions, clicks, conversions, spend_cents
FROM daily_metrics_var004
WHERE (metric_date = '2024-01-01' AND campaign_id = 41 AND channel = 'social')
ORDER BY metric_date, campaign_id, channel;
```

<img width="2242" height="126" alt="image" src="https://github.com/user-attachments/assets/bbd44f87-9a05-4dcb-9366-215b204eb221" />

#### Запрос: суммарные clicks / impressions (CTR) по каналам
```sql
SELECT 
    channel,
    sum(clicks) as total_clicks,
    sum(impressions) as total_impressions,
    round(sum(clicks) / sum(impressions) * 100, 2) as ctr_percent
FROM daily_metrics_var004
GROUP BY channel
ORDER BY channel;
```

<img width="1032" height="176" alt="image" src="https://github.com/user-attachments/assets/9f89f159-7c98-4d51-a099-4e83f8094b8f" />

### Задание 5. Комплексный анализ и самопроверка
#### 1. Проверка партиций 
```sql
SELECT
    _partition_id AS partition,
    count() AS total_rows
FROM sales_var004
GROUP BY _partition_id
ORDER BY partition;
```

<img width="540" height="228" alt="image" src="https://github.com/user-attachments/assets/1af78433-3cb2-4feb-a486-deaddc234b94" />

#### 2.JOIN между таблицами
```sql
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
```

<img width="774" height="320" alt="image" src="https://github.com/user-attachments/assets/98581f85-efdd-4800-b24e-022318f0a733" />

#### 3.Типы данных
```sql
DESCRIBE TABLE sales_var004;
DESCRIBE TABLE products_var004;
DESCRIBE TABLE daily_metrics_var004;
```

<img width="1994" height="468" alt="image" src="https://github.com/user-attachments/assets/5981c5e4-db2e-437d-a540-8745a611137f" />

<img width="2070" height="452" alt="image" src="https://github.com/user-attachments/assets/473a1f76-23dc-4f1b-93ba-777d78f8de8e" />

<img width="2070" height="452" alt="image" src="https://github.com/user-attachments/assets/74f54f81-35d7-41d1-97bc-14c200a8c411" />


#### 4. Запрос с массивом (создал временную таблицу tags_var004, заполнил ее данными и выполнил зарпос)
```sql
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
```

<img width="534" height="376" alt="image" src="https://github.com/user-attachments/assets/6a881802-eda8-4cf5-bbe1-154024679226" />

#### 5.Контрольная сумма
```sql
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
```

<img width="794" height="232" alt="image" src="https://github.com/user-attachments/assets/82d5b067-11d2-4af7-a4d4-501d837a4476" />


## 1. Почему LowCardinality(String) эффективнее обычного String для столбца category?

**LowCardinality** — это специализированный тип данных ClickHouse, оптимизированный для хранения столбцов с небольшим количеством уникальных значений (до ~1 миллиона).

### Преимущества перед обычным String:

| Характеристика | String | LowCardinality(String) |
|----------------|--------|------------------------|
| **Хранение** | Каждое значение хранится отдельно | Использует словарь уникальных значений + индексы |
| **Память** | Высокое потребление при повторениях | Значительная экономия (иногда в 10-100 раз) |
| **Скорость чтения** | Обычная | Выше за счёт кэширования словаря в CPU L1/L2 |
| **Сравнение** | Посимвольное | Сравнение целочисленных индексов |

### Пример:
```sql
-- Для столбца с 3 категориями: 'electronics', 'clothing', 'food'
-- String:      1 000 000 строк × ~10 байт = ~10 MB
-- LowCardinality: словарь {0→'electronics', 1→'clothing', 2→'food'} = ~30 байт
--                  + 1 000 000 × 1 байт (индекс) = ~1 MB
```

**Вывод:** Для поля `category` с ограниченным набором значений (например, 10-50 категорий) LowCardinality даёт многократную экономию памяти и ускорение запросов с фильтрацией и группировкой.

---

## 2. В чём разница между ORDER BY и PRIMARY KEY в ClickHouse?

### ORDER BY
- **Обязательный** параметр при создании таблицы семейства MergeTree
- Определяет **физический порядок** хранения данных на диске
- Все партиции сортируются согласно ORDER BY
- Может включать несколько столбцов в любом порядке

### PRIMARY KEY
- **Опциональный** параметр (если не указан, равен ORDER BY)
- Должен быть **префиксом** ORDER BY
- Используется для построения **разреженного индекса**
- По умолчанию индексная гранулярность = 8192 строки

### Сравнение:

```sql
-- Пример 1: PRIMARY KEY совпадает с ORDER BY
CREATE TABLE t1 (
    date Date,
    user_id UInt32,
    event String
) ENGINE = MergeTree()
ORDER BY (date, user_id);  -- PRIMARY KEY = (date, user_id)

-- Пример 2: PRIMARY KEY — префикс ORDER BY
CREATE TABLE t2 (
    date Date,
    user_id UInt32,
    event String
) ENGINE = MergeTree()
ORDER BY (date, user_id, event)
PRIMARY KEY (date, user_id);  -- Индекс только по (date, user_id)
```

| Аспект | ORDER BY | PRIMARY KEY |
|--------|----------|-------------|
| **Назначение** | Физическая сортировка данных | Логический индекс для поиска |
| **Обязательность** | Обязателен | Опционален |
| **Состав** | Любой набор столбцов | Только префикс ORDER BY |
| **Влияние на запросы** | Определяет эффективность чтения диапазонов | Ускоряет точечные запросы и JOIN |

**Ключевое правило:** `PRIMARY KEY ⊆ ORDER BY` (первичный ключ всегда является подмножеством столбцов сортировки).

---

## 3. Когда следует использовать ReplacingMergeTree вместо MergeTree?

**ReplacingMergeTree** следует использовать в сценариях **дедупликации данных** по первичному ключу:

### Ситуации для применения:

#### А. Обработка повторных вставок (идемпотентность)
```sql
-- Система может прислать один заказ дважды
INSERT INTO orders VALUES (1001, '2024-01-15', 'new');
INSERT INTO orders VALUES (1001, '2024-01-15', 'new');  -- Дубликат
-- ReplacingMergeTree оставит только одну строку
```

#### Б. Стриминг обновлений статусов
```sql
CREATE TABLE order_status (
    order_id UInt64,
    status String,
    updated_at DateTime
) ENGINE = ReplacingMergeTree(updated_at)
ORDER BY order_id;

INSERT INTO order_status VALUES (1, 'pending', '2024-01-01 10:00');
INSERT INTO order_status VALUES (1, 'shipped', '2024-01-02 14:00');
-- После OPTIMIZE останется строка с статусом 'shipped'
```

#### В. Ежедневная перезаливка данных
- ETL-процесс каждый день загружает полный снимок за последние 30 дней
- Старые записи автоматически заменяются новыми

### Когда НЕ использовать:
- Обычное логирование (используйте MergeTree)
- Данные без дубликатов по ключу
- Если нужна полная история изменений

---

## 4. Почему SummingMergeTree не заменяет GROUP BY в аналитических запросах?

**SummingMergeTree** выполняет суммирование только **на этапе слияния кусков данных (merge)**, а не во время запроса.

### Принципиальные отличия:

| Характеристика | SummingMergeTree | GROUP BY |
|----------------|------------------|----------|
| **Момент агрегации** | При фоновом слиянии партов | В момент выполнения запроса |
| **Гарантия полноты** | Частичная (не все парты слиты) | Полная (обрабатывает все строки) |
| **Производительность** | Не влияет на SELECT | Замедляет SELECT |
| **Типы агрегации** | Только SUM для числовых столбцов | Любые агрегатные функции |
| **Точность** | Приблизительная без FINAL | Точная |

### Пример проблемы:
```sql
-- SummingMergeTree без FINAL
SELECT campaign_id, sum(clicks)
FROM daily_metrics
WHERE date = '2024-01-01'
-- Может вернуть НЕПОЛНУЮ сумму, если парты ещё не слиты

-- Правильный запрос с GROUP BY
SELECT campaign_id, sum(clicks)
FROM daily_metrics
WHERE date = '2024-01-01'
GROUP BY campaign_id
-- Всегда точный результат
```

### Правильная стратегия использования:
```sql
-- SummingMergeTree — для предварительной агрегации при хранении
-- GROUP BY — для итоговой агрегации при запросе
SELECT 
    channel,
    sum(clicks) AS total_clicks,      -- GROUP BY гарантирует полноту
    sum(impressions) AS total_impressions
FROM daily_metrics
GROUP BY channel;
```

**Вывод:** SummingMergeTree — это оптимизация хранения (уменьшение объёма данных), но не замена аналитической агрегации. Всегда используйте GROUP BY для точных результатов.

---

## 5. Что произойдёт, если не выполнить OPTIMIZE TABLE FINAL для ReplacingMergeTree?

### Последствия отсутствия OPTIMIZE:

#### А. **Дубликаты в результатах запросов**
```sql
-- Без OPTIMIZE
SELECT * FROM order_status WHERE order_id = 1;
-- Результат: может вернуть ОБЕ строки:
-- 1 | pending  | 2024-01-01
-- 1 | shipped  | 2024-01-02

-- С OPTIMIZE TABLE order_status FINAL
-- Результат: только одна строка:
-- 1 | shipped  | 2024-01-02
```

#### Б. **Неактуальные данные**
- Старые версии записей продолжают участвовать в запросах
- Аналитика может использовать устаревшие статусы

#### В. **Увеличенное использование диска**
- Хранятся все версии строк
- Размер таблицы может быть в 2-3 раза больше необходимого

### Как работает дедупликация:

```
Вставка данных → Парты хранятся отдельно → 
Фоновый процесс merge (постепенно) → 
OPTIMIZE FINAL (принудительно и полностью)
```

### Способы получения корректных результатов:

```sql
-- Способ 1: Использовать FINAL в запросе (медленно)
SELECT * FROM order_status FINAL WHERE order_id = 1;

-- Способ 2: Использовать аргумент версионности
SELECT 
    order_id, 
    argMax(status, updated_at) AS last_status
FROM order_status 
GROUP BY order_id;

-- Способ 3: Периодический OPTIMIZE (рекомендуется)
OPTIMIZE TABLE order_status FINAL;
```

### Рекомендация:
Для критически важных данных настройте периодический запуск `OPTIMIZE TABLE ... FINAL` (например, раз в сутки в нерабочее время) или используйте `FINAL` в запросах с осторожностью, понимая его влияние на производительность.

---

## Выводы

1. **LowCardinality** критически важен для оптимизации хранения категориальных данных
2. **ORDER BY** определяет физический порядок, **PRIMARY KEY** — логический индекс
3. **ReplacingMergeTree** решает задачу дедупликации, но требует OPTIMIZE
4. **SummingMergeTree** и **GROUP BY** решают разные задачи и должны использоваться вместе
5. Без **OPTIMIZE TABLE FINAL** специальные движки MergeTree работают не полностью, отдавая неконсолидированные данные
