Solving Inventory Inefficiencies Using SQL

Poject Overview

This project focuses on analyzing and optimizing inventory operations for a retail company using structured SQL queries and data modeling techniques. Urban Retail Co., a mid-sized omnichannel retailer, faces recurring issues like stockouts of fast-moving products, overstocks of slow-moving ones, and a lack of integrated analytics for forecasting and inventory control. Our goal was to design a data-driven, SQL-powered solution to address these inefficiencies and support smarter inventory decisions.

We began by cleaning and exploring transactional data covering products, stores, inventory levels, forecasts, promotions, and weather. The raw dataset contained redundancies and was normalized into a well-structured schema consisting of stores, products, and inventory_facts tables to improve query efficiency and data integrity.

Key SQL implementations included calculating real-time stock levels using Common Table Expressions (CTEs) and designing reorder point (ROP) logic using the formula: ROP = (Average Daily Usage × Lead Time) + Safety Stock. We flagged products requiring urgent restocking and supported proactive inventory planning using a need_reorder field. We also performed inventory turnover analysis and classified items as slow, moderate, or fast-moving to identify overstock or underperforming products.

A series of analytical reports were generated to evaluate discount effectiveness, competitor pricing impact, seasonal performance, and weather-based demand. These insights were visualized through a Power BI dashboard to support business recommendations and forecasting strategies.

The project helped highlight actionable KPIs such as inventory turnover, stockout rate, average inventory, and inventory age. Overall, this SQL-based solution enables smarter demand forecasting, pricing strategy, and restocking decisions, reducing supply chain costs and increasing product availability.

Project Drive (SQL Queries, ERD, Dashboards):(https://drive.google.com/drive/folders/13Y-2fxllKmeJp0J2U-xuG-F98xhWfudQ)

ERD:
![image](https://github.com/user-attachments/assets/e32e4140-5212-44db-93aa-457067a15d0a)

Power BI Dahboard:
![Screenshot 2025-07-01 195131](https://github.com/user-attachments/assets/19cbcbfa-032e-4b05-810e-823da50a8f4c)

