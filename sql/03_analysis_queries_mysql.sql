-- ============================================================
-- 03_analysis_queries_mysql.sql（MySQL 5.7 / 8.0 通用）
-- 5 条核心查询：跑完就能得到报告的 3 条结论
-- 前提：已执行 02_build_wide_table_mysql.sql
-- 只统计已送达订单（order_status = 'delivered'）
-- ============================================================

-- ------------------------------------------------------------
-- Q1. 差评率最高的品类（至少 200 单，避免小样本噪声）
-- 用途：结论①「差评集中在哪些品类」
-- ------------------------------------------------------------
SELECT
    category_en,
    COUNT(*)                                                    AS orders,
    SUM(review_score IS NOT NULL)                               AS reviewed,
    ROUND(SUM(is_bad_review = 1) / SUM(review_score IS NOT NULL), 4) AS bad_rate,
    ROUND(AVG(review_score), 2)                                 AS avg_score
FROM wide_orders
WHERE order_status = 'delivered'
GROUP BY category_en
HAVING reviewed >= 200
ORDER BY bad_rate DESC
LIMIT 10;


-- ------------------------------------------------------------
-- Q2. 履约漏斗：下单 → 支付 → 发货 → 签收 → 有评价
-- 用途：定位体验断点在哪一环
-- ------------------------------------------------------------
SELECT
    COUNT(*)                                   AS ordered,
    SUM(ts_approved  IS NOT NULL)              AS approved,
    SUM(ts_carrier   IS NOT NULL)              AS shipped,
    SUM(ts_delivered IS NOT NULL)              AS delivered,
    SUM(review_score IS NOT NULL)              AS reviewed,
    ROUND(SUM(ts_approved  IS NOT NULL) / COUNT(*), 4) AS rate_approved,
    ROUND(SUM(ts_delivered IS NOT NULL) / COUNT(*), 4) AS rate_delivered,
    ROUND(AVG(days_fulfill), 2)                AS avg_days_fulfill,
    ROUND(AVG(days_to_carrier), 2)             AS avg_days_to_carrier
FROM wide_orders;


-- ------------------------------------------------------------
-- Q3. 延迟天数分箱 × 平均评分 / 差评率
-- 用途：结论②「延迟与差评的量化关系」——全项目最硬的一条
-- ------------------------------------------------------------
SELECT
    CASE
        WHEN days_vs_estimate IS NULL  THEN '未签收/缺承诺时间'
        WHEN days_vs_estimate <= -10   THEN '提前10天以上'
        WHEN days_vs_estimate <= -5    THEN '提前5-10天'
        WHEN days_vs_estimate <= -1    THEN '提前1-5天'
        WHEN days_vs_estimate < 1      THEN '准时(±0天)'
        WHEN days_vs_estimate < 3      THEN '延迟1-3天'
        WHEN days_vs_estimate < 7      THEN '延迟3-7天'
        ELSE '延迟7天以上'
    END                                          AS delay_bucket,
    COUNT(*)                                     AS orders,
    ROUND(AVG(review_score), 2)                  AS avg_score,
    ROUND(SUM(is_bad_review = 1) / SUM(review_score IS NOT NULL), 4) AS bad_rate
FROM wide_orders
WHERE order_status = 'delivered'
GROUP BY delay_bucket
ORDER BY MIN(days_vs_estimate);


-- ------------------------------------------------------------
-- Q4. 卖家四象限：单量 vs 差评率（用子查询，兼容 MySQL 5.7）
-- 用途：结论③「治理优先级」——高单量 + 高差评 = 先治
-- ------------------------------------------------------------
SELECT
    seller_id,
    orders,
    bad_rate,
    avg_score,
    avg_delay_days,
    avg_ship_days,
    CASE
        WHEN orders >= 200 AND bad_rate >= 0.20 THEN 'A 高单量高差评(优先治理)'
        WHEN orders >= 200                     THEN 'B 高单量低差评(标杆)'
        WHEN bad_rate >= 0.20                  THEN 'C 低单量高差评(观察/整改)'
        ELSE 'D 低单量低差评'
    END AS quadrant
FROM (
    SELECT
        seller_id,
        COUNT(*)                                                     AS orders,
        ROUND(SUM(is_bad_review = 1) / SUM(review_score IS NOT NULL), 4) AS bad_rate,
        ROUND(AVG(review_score), 2)                                  AS avg_score,
        ROUND(AVG(days_vs_estimate), 2)                              AS avg_delay_days,
        ROUND(AVG(days_to_carrier), 2)                               AS avg_ship_days
    FROM wide_orders
    WHERE order_status = 'delivered' AND review_score IS NOT NULL
    GROUP BY seller_id
    HAVING COUNT(*) >= 30
) t
ORDER BY (orders >= 200 AND bad_rate >= 0.20) DESC, bad_rate DESC
LIMIT 50;


-- ------------------------------------------------------------
-- Q5. 地区差评率（Top 10，至少 300 单）
-- 用途：判断体验问题是否与物流覆盖/地区相关
-- ------------------------------------------------------------
SELECT
    customer_state,
    COUNT(*)                                                     AS orders,
    ROUND(AVG(days_fulfill), 2)                                  AS avg_days_fulfill,
    ROUND(AVG(is_late), 3)                                       AS late_rate,
    ROUND(SUM(is_bad_review = 1) / SUM(review_score IS NOT NULL), 4) AS bad_rate
FROM wide_orders
WHERE order_status = 'delivered'
GROUP BY customer_state
HAVING COUNT(*) >= 300
ORDER BY bad_rate DESC
LIMIT 10;
