CREATE DATABASE Capstone;
USE Capstone;

-- 1.	What is the average number of orders per customer?  

SELECT SUM(order_count)/COUNT(DISTINCT CustomerID) AS Avg_orders_per_customer
FROM(
     SELECT CustomerID,COUNT(orderID) AS order_count
     FROM orders
     GROUP BY CustomerID
     ORDER BY CustomerID
	 ) s;

-- Are there high-value repeat customers?

SELECT o.CustomerID,
		COUNT(o.OrderID) AS order_count,
        ROUND(SUM((od.UnitPrice*od.Quantity)*(1-od.Discount)),2)AS Order_amount
FROM Orders o 
JOIN order_details od 
ON o.OrderID=od.OrderID
GROUP BY o.CustomerID
HAVING COUNT(o.OrderID)>=3
    AND SUM((od.UnitPrice*od.Quantity)*(1-od.Discount))>=1000
ORDER BY o.CustomerID;

-- 2.	How do customer order patterns vary by city or country?

SELECT 
    o.ShipCountry,o.ShipCity,
    COUNT(DISTINCT o.CustomerID) AS total_customers,
    COUNT(o.OrderID) AS total_orders,
    COUNT(o.OrderID) / COUNT(DISTINCT o.CustomerID) AS orders_per_customer
FROM 
    orders o
GROUP BY 
    o.ShipCity,o.ShipCountry
ORDER BY 
    orders_per_customer DESC;

-- 3.	Can we cluster customers based on total spend, order count, and preferred categories?
WITH CTE AS(
	SELECT o.CustomerID,c.CategoryName,SUM(od.Quantity)as Total_quantity,
            SUM((od.UnitPrice*od.Quantity)*(1-od.Discount)) AS Total_spend,
		   row_number() OVER(PARTITION BY CustomerID ORDER BY SUM(od.Quantity) DESC) rn
	FROM orders o 
	JOIN order_details od ON o.OrderID=od.OrderID
	JOIN products p ON od.ProductID = p.ProductID
	JOIN  category c ON p.CategoryID=c.CategoryID
	GROUP BY 
		 o.customerID,c.CategoryName
)
SELECT * FROM CTE
WHERE rn=1;
     
-- 4b.	Which product categories or products contribute most to order revenue?

SELECT 
    c.CategoryName,
    ROUND(SUM(od.Quantity*od.UnitPrice),2) AS total_revenue
FROM orders o
JOIN order_details od ON o.OrderID = od.OrderID
JOIN products p ON od.ProductID = p.ProductID
JOIN Category c on p.CategoryID=c.CategoryID
GROUP BY c.categoryName
ORDER BY total_revenue DESC;

-- 4b .Are there any correlations between orders and customer location or product category?

SELECT 
    o.ShipCountry,c.CategoryName,SUM(od.Quantity)AS Total_qty,COUNT(od.OrderID) AS order_count
FROM orders o
JOIN order_details od ON o.OrderID = od.OrderID
JOIN products p ON od.ProductID = p.ProductID
JOIN Category c on p.CategoryID=c.CategoryID
GROUP BY o.ShipCountry,c.CategoryName
ORDER BY o.ShipCountry DESC;

-- 5.	How frequently do different customer segments place orders?

SELECT 
    CustomerID,
    Total_orders_per_customer,  
    ROUND(AVG(days_diff),0) AS Frequent_days_order,
    CASE 
        WHEN Total_orders_per_customer >= 15 THEN 'VIP - High Frequency'
        WHEN Total_orders_per_customer >= 10 THEN 'Premium - Moderate Frequency'
        WHEN Total_orders_per_customer >= 5 THEN 'Regular - Medium Frequency'
        WHEN Total_orders_per_customer >= 2 THEN 'Occasional - Low Frequency'
        ELSE 'One-Time Customer'
    END AS Customer_Segment
FROM 
    (
        SELECT CustomerID,OrderDate,
			   COUNT(OrderID) OVER(PARTITION BY CustomerID) AS Total_orders_per_customer,
               DATEDIFF(LEAD(OrderDate) OVER(PARTITION BY CustomerID ORDER BY OrderDate),OrderDate) AS days_diff
        FROM orders
    ) AS subquery
GROUP BY 
    CustomerID, Total_orders_per_customer
ORDER BY Total_orders_per_customer DESC;

-- 6.	What is the geographic and title-wise distribution of employees?

SELECT Title,City,Country,Region,
       COUNT(EmployeeID) AS Employee_Count
FROM employee
GROUP BY Title, City, Region, Country
ORDER BY Country, City, Title;

-- 7.	What trends can we observe in hire dates across employee titles?

SELECT 
    YEAR(HireDate) AS Hire_Year,
    Title,
    COUNT(EmployeeID) AS Employees_Hired
FROM 
    employee
GROUP BY 
    YEAR(HireDate), Title
ORDER BY 
    Hire_Year, Title;

-- 8.	What patterns exist in employee title and courtesy title distributions?

SELECT 
    Title,
    TitleOfCourtesy,
    COUNT(*) as count
FROM employee
GROUP BY Title, TitleOfCourtesy
ORDER BY Title, TitleOfCourtesy;

-- 9.	Are there correlations between product pricing, stock levels, and sales performance?

SELECT 
    od.OrderID,
    od.ProductID,
    od.UnitPrice as OrderUnitPrice,
    od.Quantity,
    od.Discount,
    p.ProductName,
    p.UnitPrice as ProductUnitPrice,
    p.UnitsInStock,
    p.UnitsOnOrder,
    p.ReorderLevel,
    ROUND((od.UnitPrice * od.Quantity * (1 - od.Discount)),2) as TotalSales,
    ROUND((od.Quantity/p.UnitsInStock),2) as Stock_turnover,
    ROUND(((od.UnitPrice * od.Quantity * (1 - od.Discount))/od.Quantity),2) AS Performance_Index,
    CASE 
        WHEN p.UnitsInStock = 0 THEN 'Out of Stock'
        WHEN p.UnitsInStock < 25 THEN 'Low Stock'
        WHEN p.UnitsInStock < 75 THEN 'Medium Stock'
        ELSE 'High Stock'
    END as StockLevel,
    CASE 
        WHEN p.UnitPrice < 20 THEN 'Low Price'
        WHEN p.UnitPrice < 50 THEN 'Medium Price'
        WHEN p.UnitPrice < 100 THEN 'High Price'
        ELSE 'Premium Price'
    END as PriceRange
FROM order_details od
INNER JOIN Products p ON od.ProductID = p.ProductID
WHERE p.Discontinued = 0; 

-- 10.	How does product demand change over months or seasons?
-- MONTHLY DEMAND OF PRODUCTS
SELECT 
    p.ProductID,
    p.ProductName,
    p.CategoryID,
    YEAR(o.OrderDate) as Year,
    MONTH(o.OrderDate) as Month,
    MONTHNAME(o.OrderDate) as MonthName,
    SUM(od.Quantity) as QuantitySold,
    COUNT(DISTINCT od.OrderID) as OrderCount,
    ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)),2) as Total_Revenue,
    AVG(od.Quantity) as AvgQuantityPerOrder
FROM Orders o
INNER JOIN Order_Details od ON o.OrderID = od.OrderID
INNER JOIN Products p ON od.ProductID = p.ProductID
GROUP BY p.ProductID, p.ProductName, p.CategoryID, 
         YEAR(o.OrderDate), MONTH(o.OrderDate), MONTHNAME(o.OrderDate)
ORDER BY p.ProductName, Year, Month;

-- SEASONAL DEMAND OF PRODUCTS
SELECT 
    YEAR(o.OrderDate) as Year,
    CASE 
        WHEN MONTH(o.OrderDate) IN (12, 1, 2) THEN 'Winter'
        WHEN MONTH(o.OrderDate) IN (3, 4, 5) THEN 'Spring'
        WHEN MONTH(o.OrderDate) IN (6, 7, 8) THEN 'Summer'
        WHEN MONTH(o.OrderDate) IN (9, 10, 11) THEN 'Fall'
    END as Season,
    COUNT(DISTINCT od.OrderID) as TotalOrders,
    SUM(od.Quantity) as TotalQuantitySold,
    ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)),2) as TotalRevenue,
    ROUND(AVG(od.UnitPrice * od.Quantity * (1 - od.Discount)),2) as AvgOrderValue,
    COUNT(DISTINCT od.ProductID) as UniqueProductsSold
FROM Orders o
INNER JOIN Order_Details od ON o.OrderID = od.OrderID
GROUP BY YEAR(o.OrderDate), Season
ORDER BY Year, 
    FIELD(Season, 'Winter', 'Spring', 'Summer', 'Fall');
    
-- 11.	Can we identify anomalies in product sales or revenue performance?

WITH monthly_sales AS (
    SELECT 
        p.ProductID,
        p.ProductName,
        DATE_FORMAT(o.OrderDate, '%Y-%m') as sale_month,
        SUM(od.Quantity) as total_quantity,
        SUM(od.Quantity * od.UnitPrice * (1 - od.Discount)) as total_revenue,
        COUNT(DISTINCT o.OrderID) as order_count
    FROM products p
    JOIN order_details od ON p.ProductID = od.ProductID
    JOIN orders o ON od.OrderID = o.OrderID
    GROUP BY p.ProductID, p.ProductName, DATE_FORMAT(o.OrderDate, '%Y-%m')
),
avg_stats AS (
    SELECT 
        ProductID,
        ProductName,
        AVG(total_quantity) as avg_monthly_quantity,
        STDDEV(total_quantity) as stddev_quantity,
        AVG(total_revenue) as avg_monthly_revenue,
        STDDEV(total_revenue) as stddev_revenue
    FROM monthly_sales
    GROUP BY ProductID, ProductName
),
latest_month AS (
    SELECT 
        ProductID,
        total_quantity as current_quantity,
        total_revenue as current_revenue,
        sale_month
    FROM monthly_sales
    WHERE sale_month = (SELECT MAX(sale_month) FROM monthly_sales)
)
SELECT 
    a.ProductID,
    a.ProductName,
    l.sale_month as latest_month,
    ROUND(a.avg_monthly_quantity, 2) as avg_quantity,
    COALESCE(l.current_quantity, 0) as current_quantity,
    ROUND(a.avg_monthly_revenue, 2) as avg_revenue,
    COALESCE(l.current_revenue, 0) as current_revenue,
    ROUND(((COALESCE(l.current_quantity, 0) - a.avg_monthly_quantity) / 
           NULLIF(a.avg_monthly_quantity, 0)) * 100, 2) as quantity_change_pct,
    ROUND(((COALESCE(l.current_revenue, 0) - a.avg_monthly_revenue) / 
           NULLIF(a.avg_monthly_revenue, 0)) * 100, 2) as revenue_change_pct,
    CASE 
        WHEN COALESCE(l.current_quantity, 0) = 0 AND a.avg_monthly_quantity > 5 THEN 'No Sales - Critical'
        WHEN ((COALESCE(l.current_quantity, 0) - a.avg_monthly_quantity) / 
              NULLIF(a.avg_monthly_quantity, 0)) < -0.5 THEN 'Sharp Decline'
        WHEN ((COALESCE(l.current_quantity, 0) - a.avg_monthly_quantity) / 
              NULLIF(a.avg_monthly_quantity, 0)) > 1.0 THEN 'Sharp Increase'
        ELSE 'Normal'
    END as anomaly_status
FROM avg_stats a
LEFT JOIN latest_month l ON a.ProductID = l.ProductID
WHERE a.avg_monthly_quantity > 2
HAVING anomaly_status != 'Normal'
ORDER BY ABS(revenue_change_pct) DESC;


-- 12.	Are there any regional trends in supplier distribution and pricing?
-- Regional Trens in Supplier Distribution
SELECT 
    s.Country,
    s.Region,
    COUNT(DISTINCT s.SupplierID) as supplier_count,
    COUNT(DISTINCT p.ProductID) as product_count,
    ROUND(AVG(p.UnitPrice), 2) as avg_product_price,
    ROUND(MIN(p.UnitPrice), 2) as min_price,
    ROUND(MAX(p.UnitPrice), 2) as max_price,
    SUM(p.UnitsInStock) as total_stock,
    SUM(p.UnitsOnOrder) as total_on_order
FROM Suppliers s
LEFT JOIN Products p ON s.SupplierID = p.SupplierID
GROUP BY s.Country, s.Region
ORDER BY supplier_count DESC, avg_product_price DESC;

-- Regional Trends in Pricing

SELECT 
    s.Country,
    s.Region,
    c.CategoryName,
    COUNT(DISTINCT p.ProductID) as product_count,
    ROUND(AVG(p.UnitPrice), 2) as avg_price,
    ROUND(STDDEV(p.UnitPrice), 2) as price_stddev,
    ROUND(MIN(p.UnitPrice), 2) as min_price,
    ROUND(MAX(p.UnitPrice), 2) as max_price,
    GROUP_CONCAT(DISTINCT p.ProductName ORDER BY p.UnitPrice DESC SEPARATOR '; ') as top_products
FROM Suppliers s
JOIN Products p ON s.SupplierID = p.SupplierID
JOIN category c ON p.CategoryID = c.CategoryID
WHERE p.Discontinued = 0
GROUP BY s.Country, s.Region, c.CategoryNames
HAVING product_count > 0
ORDER BY s.Country, c.CategoryName, avg_price DESC;

-- 13.	How are suppliers distributed across different product categories?

SELECT 
    c.CategoryID,
    c.CategoryName,
    COUNT(DISTINCT s.SupplierID) as supplier_count,
    COUNT(DISTINCT p.ProductID) as product_count,
    ROUND(AVG(p.UnitPrice), 2) as avg_price,
    SUM(p.UnitsInStock) as total_stock,
    COUNT(DISTINCT CASE WHEN p.Discontinued = 0 THEN p.ProductID END) as active_products,
    COUNT(DISTINCT CASE WHEN p.Discontinued = 1 THEN p.ProductID END) as discontinued_products
FROM category c
LEFT JOIN Products p ON c.CategoryID = p.CategoryID
LEFT JOIN Suppliers s ON p.SupplierID = s.SupplierID
GROUP BY c.CategoryID, c.CategoryName
ORDER BY supplier_count DESC, product_count DESC;

-- 14.	How do supplier pricing and categories relate across different regions?

SELECT 
    s.Country,
    s.Region,
    c.CategoryName,
    COUNT(DISTINCT s.SupplierID) as supplier_count,
    COUNT(DISTINCT p.ProductID) as product_count,
    ROUND(AVG(p.UnitPrice), 2) as avg_price,
    ROUND(MIN(p.UnitPrice), 2) as min_price,
    ROUND(MAX(p.UnitPrice), 2) as max_price,
    ROUND(STDDEV(p.UnitPrice), 2) as price_stddev,
    SUM(p.UnitsInStock) as total_stock,
    ROUND(AVG(p.UnitsInStock), 2) as avg_stock_per_product
FROM Suppliers s
JOIN Products p ON s.SupplierID = p.SupplierID
JOIN Category c ON p.CategoryID = c.CategoryID
WHERE p.Discontinued = 0
GROUP BY s.Country, s.Region, c.CategoryID, c.CategoryName
HAVING supplier_count > 0
ORDER BY s.Country, c.CategoryName, avg_price DESC;


