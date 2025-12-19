create database Customers_transactions;
update customers set Gender = null where Gender ="";
update customers set Age = null where Age ="";
alter table Customers modify AGE int null;

select * from customers;


#список клиентов с непрерывной историей за год, то есть каждый месяц на регулярной основе без пропусков за указанный годовой период, 
#средний чек за период с 01.06.2015 по 01.06.2016, 
#средняя сумма покупок за месяц, 
#количество всех операций по клиенту за период;

WITH tx AS (
    SELECT
        t.id_client,
        DATE_FORMAT(t.data_new, '%Y-%m-01') AS month,
        t.sum_payment
    FROM transactions t
    WHERE t.data_new BETWEEN '2015-06-01' AND '2016-06-01'
),
clients_12_months AS (
    SELECT
        id_client
    FROM tx
    GROUP BY id_client
    HAVING COUNT(DISTINCT month) = 12
)
SELECT
    c.id_client,
    AVG(tx.sum_payment)              AS avg_check_year,
    SUM(tx.sum_payment) / 12         AS avg_month_amount,
    COUNT(*)                         AS total_operations
FROM clients_12_months c12
JOIN tx ON tx.id_client = c12.id_client
JOIN customers c ON c.id_client = c12.id_client
GROUP BY c.id_client
ORDER BY c.id_client;


#информация в разрезе месяцев:
	#средняя сумма чека в месяц;
	#среднее количество операций в месяц;
	#среднее количество клиентов, которые совершали операции;
	#долю от общего количества операций за год и долю в месяц от общей суммы операций;
	#вывести % соотношение M/F/NA в каждом месяце с их долей затрат;

WITH tx AS (
    SELECT
        DATE_FORMAT(t.data_new, '%Y-%m-01') AS month,
        t.id_client,
        t.sum_payment
    FROM transactions t
    WHERE t.data_new BETWEEN '2015-06-01' AND '2016-06-01'
),
year_totals AS (
    SELECT
        COUNT(*) AS total_ops_year,
        SUM(sum_payment) AS total_sum_year
    FROM tx
)
SELECT
    month,
    AVG(sum_payment)                            AS avg_check_month,
    COUNT(*)                                   AS operations_cnt,
    COUNT(DISTINCT id_client)                  AS clients_cnt,
    COUNT(*) / yt.total_ops_year               AS ops_share_year,
    SUM(sum_payment) / yt.total_sum_year       AS sum_share_year
FROM tx
JOIN year_totals yt
GROUP BY month, yt.total_ops_year, yt.total_sum_year
ORDER BY month;

WITH tx AS (
    SELECT
        DATE_FORMAT(t.data_new, '%Y-%m-01') AS month,
        COALESCE(c.gender, 'NA') AS gender,
        t.sum_payment
    FROM transactions t
    JOIN customers c ON c.id_client = t.id_client
    WHERE t.data_new BETWEEN '2015-06-01' AND '2016-06-01'
),
month_totals AS (
    SELECT
        month,
        COUNT(*) AS total_ops,
        SUM(sum_payment) AS total_sum
    FROM tx
    GROUP BY month
)
SELECT
    tx.month,
    tx.gender,
    COUNT(*) / mt.total_ops        AS gender_ops_pct,
    SUM(tx.sum_payment) / mt.total_sum AS gender_sum_pct
FROM tx
JOIN month_totals mt ON mt.month = tx.month
GROUP BY tx.month, tx.gender, mt.total_ops, mt.total_sum
ORDER BY tx.month, tx.gender;

#возрастные группы клиентов с шагом 10 лет и отдельно клиентов, у которых нет данной информации, 
#с параметрами сумма и количество операций за весь период, и поквартально - средние показатели и %.

WITH tx AS (
    SELECT
        t.sum_payment,
        c.age
    FROM transactions t
    JOIN customers c ON c.id_client = t.id_client
    WHERE t.data_new BETWEEN '2015-06-01' AND '2016-06-01'
)
SELECT
    CASE
        WHEN age IS NULL THEN 'NA'
        ELSE CONCAT(FLOOR(age / 10) * 10, '-', FLOOR(age / 10) * 10 + 9)
    END AS age_group,
    COUNT(*)        AS operations_cnt,
    SUM(sum_payment) AS total_sum
FROM tx
GROUP BY age_group
ORDER BY age_group;

WITH tx AS (
    SELECT
        CONCAT(YEAR(t.data_new), '-Q', QUARTER(t.data_new)) AS quarter,
        t.sum_payment,
        c.age
    FROM transactions t
    JOIN customers c ON c.id_client = t.id_client
    WHERE t.data_new BETWEEN '2015-06-01' AND '2016-06-01'
),
age_groups AS (
    SELECT
        quarter,
        CASE
            WHEN age IS NULL THEN 'NA'
            ELSE CONCAT(FLOOR(age / 10) * 10, '-', FLOOR(age / 10) * 10 + 9)
        END AS age_group,
        sum_payment
    FROM tx
),
quarter_totals AS (
    SELECT
        quarter,
        COUNT(*) AS total_ops,
        SUM(sum_payment) AS total_sum
    FROM age_groups
    GROUP BY quarter
)
SELECT
    ag.quarter,
    ag.age_group,
    AVG(ag.sum_payment)            AS avg_check,
    COUNT(*)                       AS operations_cnt,
    COUNT(*) / qt.total_ops        AS ops_pct,
    SUM(ag.sum_payment) / qt.total_sum AS sum_pct
FROM age_groups ag
JOIN quarter_totals qt ON qt.quarter = ag.quarter
GROUP BY ag.quarter, ag.age_group, qt.total_ops, qt.total_sum
ORDER BY ag.quarter, ag.age_group;
