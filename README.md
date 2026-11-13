Olist E-Commerce Experience Governance Analysis

Review-score attribution and delivery-performance analysis on 99,441 Brazilian e-commerce orders (2016–2018).

[![Dashboard preview](images/dashboard.png)](https://public.tableau.com/views/Olist_17945512696070/1?:language=zh-CN&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)

> Live dashboard: https://public.tableau.com/views/Olist_17945512696070/1?:language=zh-CN&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link

> Full report: [report/olist-experience-governance-report.pdf](report/olist-experience-governance-report.pdf)

---

Finding | Evidence

|---|---|---|
| 1 |  The funnel is healthy — 97.0% of orders are delivered.** The bottleneck is *punctuality*, not delivery. | 96,478 / 99,441 delivered; 99.84% payment approval; 12.54 days average fulfillment |

| 2 |  Late delivery is the strongest controllable driver of bad reviews.** | Avg. score 4.29 (on time) → 3.29 (1–4 days late) → 1.86 (≥4 days late); bad-review rate 9.2% → 25.4% → 61.3% → 78.3% |

| 3 |  SP and RJ account for 54.9% of orders, but experience quality diverges sharply.** RJ is the weak link. | SP: 41,746 orders, 97% delivery rate. RJ: 12,852 orders, 96.1% delivery rate, 18.3% bad-review rate, 15.3 days to deliver |

| 4 |   96.9% of customers ordered only once** — there is almost no repeat-purchase buffer. | 93,099 of 96,096 unique customers are one-time buyers; only 49 ordered 4+ times |

**So what:** a small, identifiable slice of orders (5.35% delayed by 3+ days) drives most of the negative experience, and in a market where 96.9% of customers never return, one late delivery usually means the customer is gone for good.

---

Why this project

Marketplace experience teams need to know *where* negative experience originates and *what can be fixed upstream*. Descriptive dashboards ("orders by state") do not answer that. This project works backwards from the negative signal — 1–2 star reviews — to the operational levers that produce it: delivery punctuality, seller shipping speed, carrier coverage and category mix.

---

Data

- Source: [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle, public).
- Scope: 2016-09 to 2018-10, **9 tables, 1,550,922 rows, 99,441 orders**.
- Grain: one row per order in the analytical layer; order-level aggregates are built before any joins.

---

Method

1. Load — 9 CSVs → MySQL 8.0 via Python (`pandas` + `SQLAlchemy`); date columns cast to `DATETIME` on import.
2. Model — build an order-level wide table `wide_orders` (**99,441 rows × 27 columns**). Items and reviews are aggregated to *one row per order first*, then joined to orders, customers, products, sellers and the category translation table. This avoids the fan-out (row multiplication) that a naive multi-table join causes — the single most common source of wrong "order counts" in this dataset.
3. Analyze — SQL for funnel conversion, delay buckets, category ranking, seller quadrants and state-level performance.
4. Visualize — Tableau Public: 5 KPI cards + 6 charts + an insight panel.

---

Key metrics

| Metric | Value |
|---|---|
| Total orders                                   | 99,441 |
| Delivered orders                            | 96,478 (97.0%) |
| Average fulfillment time                 | 12.54 days |
| Average seller shipping time          | 3.21 days |
| Late orders (>1 day past estimate)  | 6,534 (6.8%) |
| Average review score                     | 4.09 / 5 |
| Bad-review rate (1–2 stars)             | 12.8% |
| Gross revenue (product value)        | R$ 13.6M |
| Unique customers                          | 96,096 |
| One-time customers                       | 93,099 (96.9%) |

---

Definitions & caveats

- Delivered: `order_status = 'delivered'`.
- Bad review: `review_score ≤ 2`; bad-review rate = bad reviews ÷ orders **with** a review (not all orders — otherwise non-reviewed orders silently deflate the rate).
- Late: delivered **more than 1 day** after the estimated delivery date. Under a stricter definition (any delay > 0), the rate is 8.1%. Both are defensible; the report states the one used.
- Review de-duplication: ~551 orders carry more than one review record. The pipeline keeps the **highest** score, which can slightly understate complaints; taking the *latest* review would be stricter.
- Scope: single platform, single market. Conclusions should be re-validated before transfer to other markets.

---

Repository structure
.
├── README.md
├── .gitignore
├── sql/
│   ├── 01_load_olist_mysql.py          # CSV → MySQL (credentials via env vars)
│   ├── 02_build_wide_table_mysql.sql   # order-level wide table + indexes
│   └── 03_analysis_queries_mysql.sql   # 5 core analyses
├── data/
│   ├── kpi_summary.csv                 # 5 KPI values
│   ├── monthly_summary.csv             # monthly orders / delivery rate
│   └── customer_frequency.csv          # one-time / occasional / loyal split
├── report/
│   └── olist-experience-governance-report.pdf
└── images/
    └── dashboard.png

Raw CSVs are **not** committed (see `.gitignore`); download them from Kaggle.

---

Reproduce

bash
0) prerequisites
pip install pandas sqlalchemy pymysql cryptography

1) download the 9 CSVs from Kaggle into ./olist_data/

2) set credentials (never hard-code them)
export MYSQL_HOST=127.0.0.1
export MYSQL_PORT=3306
export MYSQL_USER=root
export MYSQL_PASSWORD=your_password
export MYSQL_DB=olist

3) load + build + analyze
python sql/01_load_olist_mysql.py
mysql -u "$MYSQL_USER" -p olist < sql/02_build_wide_table_mysql.sql
mysql -u "$MYSQL_USER" -p olist < sql/03_analysis_queries_mysql.sql

On Windows PowerShell use `Get-Content sql\02_build_wide_table_mysql.sql -Raw | mysql -u root -p olist`.

---

Limitations & next steps

- Reviews contain star ratings only — no text — so "quality vs. logistics vs. description mismatch" cannot be separated. A topic-clustering pass over review comments is the natural next step.
- Returns and customer-service tickets are not included; the negative-experience metric is therefore narrow.
- The A/B design in the report (proactive delay notification + voucher for high-risk orders, with GMV and refund rate as guardrail metrics) has not been run — it is a proposed, testable next step.

---

Contact

Li Zhihao — [Tableau Public profile] (https://public.tableau.com/views/Olist_17945512696070/1?:language=zh-CN&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)
