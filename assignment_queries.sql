1. What is the count of purchases per month (excluding refunded purchases)?

SELECT
    substr(purchase_time, 1, 7) AS month,   
    COUNT(*) AS purchases_count
FROM transactions
WHERE refund_item = '' OR refund_item IS NULL
GROUP BY substr(purchase_time, 1, 7)
ORDER BY month;

Explanation: For this question, I first made sure to exclude all refunded purchases. In our dataset, refunds are stored as empty strings, so I filtered those out. Since SQLite doesn’t support functions like date_trunc, I extracted the month directly from the timestamp using substr(purchase_time, 1, 7) which gives me YYYY-MM. Then I simply grouped the records by month and counted the non-refunded purchases.



2. How many stores receive at least 5 orders/transactions in October 2020?

SELECT COUNT(*) AS stores_with_5_or_more_orders
FROM (
    SELECT store_id
    FROM transactions
    WHERE substr(purchase_time, 1, 7) = '2020-10'
    GROUP BY store_id
    HAVING COUNT(*) >= 5
);

Explanation: Here, I focused only on transactions from October 2020. After filtering the records by month, I grouped them by store and counted each store’s orders. Stores with 5 or more orders were selected using a HAVING condition. Finally, I counted how many such stores existed.


3. For each store, what is the shortest interval (in min) from purchase to refund time?

SELECT
  store_id,
  MIN( (julianday(NULLIF(refund_item,'')) - julianday(purchase_time)) * 24.0 * 60.0 )
    AS shortest_refund_minutes
FROM transactions
WHERE NULLIF(refund_item,'') IS NOT NULL
GROUP BY store_id
ORDER BY store_id;

Explanation: To solve this, I considered only transactions where a refund date actually exists. I used SQLite’s julianday function to convert the timestamps into numerical values. The difference between the refund time and purchase time gives the duration, which I converted into minutes. Then I took the minimum value for each store to get the shortest refund time.

4. What is the gross_transaction_value of every store’s first order?

SELECT store_id, purchase_time, gross_transaction_value
FROM (
  SELECT
    store_id,
    purchase_time,
    gross_transaction_value,
    ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY purchase_time ASC) AS rn
  FROM transactions
) t
WHERE rn = 1
ORDER BY store_id;

Explanation: In this case, I had to identify the earliest purchase made for each store. For that, I used the ROW_NUMBER() window function, which allows me to sort transactions within each store by date. The first row for each store represents its first order, and I selected its gross_transaction_value.


5. What is the most popular item name that buyers order on their first purchase?

WITH first_purchase_per_buyer AS (
  SELECT
    buyer_id,
    store_id,
    item_id,
    ROW_NUMBER() OVER (PARTITION BY buyer_id ORDER BY purchase_time ASC) AS rn
  FROM transactions
)
SELECT
  COALESCE(i.item_name, fp.item_id) AS item_display_name,
  COUNT(*) AS times_ordered_on_first_purchase
FROM first_purchase_per_buyer fp
LEFT JOIN items i
  ON fp.store_id = i.store_id
  AND fp.item_id = i.item_id
WHERE fp.rn = 1
GROUP BY item_display_name
ORDER BY times_ordered_on_first_purchase DESC, item_display_name
LIMIT 1;


Explanation: I started by finding each buyer’s first transaction using ROW_NUMBER() grouped by buyer. After isolating their first purchases, I joined this data with the items table to get readable item names. Then I counted how many times each item appeared as a first purchase and selected the most frequent one.


6. Create a flag in the transaction items table indicating whether the refund can be processed or not. The condition for a refund to be processed is that it has to happen within 72 of Purchase time.



ALTER TABLE transactions ADD COLUMN refund_processable INTEGER;

UPDATE transactions
SET refund_processable =
  CASE
    WHEN NULLIF(refund_item,'') IS NOT NULL
      AND ( (julianday(NULLIF(refund_item,'')) - julianday(purchase_time)) * 24.0 ) <= 72.0
    THEN 1
    ELSE 0
  END;


Explanation: I added a new column refund_processable and set it to 1 when a refund timestamp exists and the difference between refund_item and purchase_time is ≤ 72 hours (using julianday() to compute time difference in hours). Otherwise I set it to 0. Based on the sample data, only one refund meets the 72-hour condition.


7. Create a rank by buyer_id column in the transaction items table and filter for only the second purchase per buyer. (Ignore refunds here)


ALTER TABLE transactions ADD COLUMN buyer_rank INTEGER;

WITH ranked AS (
  SELECT
    rowid AS rid,
    ROW_NUMBER() OVER (PARTITION BY buyer_id ORDER BY purchase_time ASC) AS rn
  FROM transactions
)
UPDATE transactions
SET buyer_rank = (
  SELECT rn FROM ranked WHERE ranked.rid = transactions.rowid
);

SELECT *
FROM transactions
WHERE buyer_rank = 2
ORDER BY buyer_id;

Explanation: I added a buyer_rank column and used ROW_NUMBER() partitioned by buyer_id (ordered by purchase_time) to assign each buyer’s purchases a sequential rank. Then I selected only rows where buyer_rank = 2, which returns each buyer’s second purchase. (Because I didn’t exclude refunded rows from the ranking, this matches the requirement to ignore refunds for ranking.)


8. How will you find the second transaction time per buyer (don’t use min/max; assume there were more transactions per buyer in the table)

SELECT buyer_id, purchase_time AS second_purchase_time
FROM (
  SELECT
    buyer_id,
    purchase_time,
    ROW_NUMBER() OVER (PARTITION BY buyer_id ORDER BY purchase_time ASC) AS rn
  FROM transactions
) t
WHERE rn = 2
ORDER BY buyer_id;

Explanation: I used a window function (ROW_NUMBER() partitioned by buyer_id and ordered by purchase_time) and picked rows where rn = 2. This returns the second transaction timestamp for each buyer without relying on any MIN/MAX logic.



