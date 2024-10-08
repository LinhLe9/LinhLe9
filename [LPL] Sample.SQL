--Looking at number of Order by Month,2015
Select MONTH(OrderDate) as Month,SUM(OrderQuantity) As Quantity
FROM Sale15
GROUP BY MONTH(OrderDate)
ORDER BY Month(OrderDate)

--Looking at Products that are not on the sale list--
SELECT *
FROM [Linhle_portfolio].[dbo].[Products]
WHERE Productkey NOT IN ( Select Productkey FROM Sale)
ORDER BY Productkey ASC

--Looking at number of Order by ProductCategoryKey
SELECT C.ProductCategoryKey,C.CategoryName,Sale.TerritoryKey,SUM(Sale.orderquantity) AS Quantity
FROM (SELECT*FROM [Linhle_portfolio].[dbo].[Sale15] UNION SELECT*FROM [Linhle_portfolio].[dbo].[Sale16] UNION SELECT* FROM [Linhle_portfolio].[dbo].[Sale17]) AS Sale 
      INNER JOIN [Linhle_portfolio].[dbo].[Products] AS A ON A.Productkey=Sale.Productkey
      INNER JOIN [Linhle_portfolio].[dbo].[Subcategories] AS B ON A.ProductSubcategoryKey=B.ProductSubcategorykey
      INNER JOIN [Linhle_portfolio].[dbo].[Categories] AS C ON C.ProductCategoryKey=B.ProductcategoryKey
GROUP BY C.ProductCategoryKey,C.CategoryName,Sale.TerritoryKey
ORDER BY C.ProductCategoryKey,Sale.TerritoryKey

--Looking at revenue by CustomerKey and insert into a new table--
SELECT DISTINCT A.CustomerKey, B.Prefix+ B.FirstName+B.Lastname AS Name, SUM(A.Orderquantity*C.ProductPrice) AS Revenue 
INTO Revenue_by_Customerkey
FROM [Linhle_portfolio].[dbo].[Sale16] AS A INNER JOIN [Linhle_portfolio].[dbo].[Customers] AS B On A.CustomerKey=B.CustomerKey
      INNER JOIN [Linhle_portfolio].[dbo].[Products] AS C ON C.Productkey=A.ProductKey
GROUP BY A.CustomerKey, B.Prefix+ B.FirstName+B.Lastname  HAVING SUM(A.Orderquantity*C.ProductPrice) BETWEEN 10 AND 50
ORDER BY SUM(A.Orderquantity*C.ProductPrice) DESC

--Calculate returnrate--
SELECT *
INTO SALE
FROM [LINHLE_portfolio].[dbo].[Sale16] 
      UNION SELECT * FROM [LINHLE_portfolio].[dbo].[Sale17]
      UNION SELECT * FROM [LINHLE_portfolio].[dbo].[Sale15]

SELECT C.*,B.Productname,
	    CASE WHEN A.Returnquantity>0 THEN A.Returnquantity ELSE 0 END AS returnquantity
INTO Return_rate
FROM (Select Productkey,Territorykey,SUM(OrderQuantity) AS OrderQuantity FROM SALE GROUP BY Productkey,territorykey) AS C
      LEFT JOIN (SELECT Productkey,TerritoryKey,SUM(Returnquantity) AS returnquantity 
                 FROM [LINHLE_portfolio].[dbo].[Returns]
                 GROUP BY Productkey,TerritoryKey) AS A
	    ON C.Productkey=A.Productkey AND C.TerritoryKey=A.TerritoryKey
	    INNER JOIN [LINHLE_portfolio].[dbo].[Products] AS B ON B.Productkey=C.Productkey
ORDER BY C.Orderquantity DESC

SELECT ProductKey,TerritoryKey,returnquantity/orderquantity as returnrate
FROM Return_rate
ORDER BY returnquantity/orderquantity DESC

--Create Procudure to display monthly revenue of the specified customer key--
CREATE PROCEDURE Month_Customer 
@CustomerKey smallint
AS
IF NOT EXISTS (SELECT*FROM[LINHLE_portfolio].[dbo].[Customers] WHERE CustomerKey=@CustomerKey)
BEGIN
      PRINT 'Customerkey is not available'
      RETURN -1
END 
SELECT A.CustomerKey,Prefix+FirstName+LastName AS HOTEN,YEAR(Orderdate) AS YEAR, MONTH(Orderdate) AS MONTH, SUM(ProductPrice*Orderquantity) AS Revenue
FROM [LINHLE_portfolio].[dbo].[Customers] AS A JOIN SALE AS B ON A.Customerkey=B.Customerkey
	    JOIN [LINHLE_portfolio].[dbo].[Products] AS C ON C.Productkey=B.Productkey
WHERE @CustomerKey=A.CustomerKey
GROUP BY A.CustomerKey,Prefix+FirstName+LastName,YEAR(Orderdate),MONTH(Orderdate)
ORDER BY YEAR(Orderdate),MONTH(Orderdate) DESC
GO

--Apply procedure--
EXECUTE Month_Customer '11000'

-- Create view [catalog_01] shows top 10 highest revenue products—
CREATE VIEW [catalog_01] AS
SELECT TOP 10 A.Productkey, ProductName, ProductSKU,B.SubcategoryName,C.CategoryName, SUM(D.OrderQuantity*A.ProductPrice) AS Revenue
FROM [LINHLE_portfolio].[dbo].[Products] AS A INNER JOIN [LINHLE_portfolio].[dbo].[Subcategories] AS B ON A.ProductSubcategoryKey=B.ProductSubcategoryKey
	 	  INNER JOIN [LINHLE_portfolio].[dbo].[Categories] AS C ON C.ProductCategoryKey=B.ProductCategoryKey
		  LEFT JOIN [LINHLE_portfolio].[dbo].[Sale17] AS D ON D.Productkey=A.ProductKey
GROUP BY A.Productkey,ProductName, ProductSKU,B.SubcategoryName,C.CategoryName 
ORDER BY SUM(OrderQuantity*ProductPrice) DESC

-- Create procedure update total number of products by subcategory—
ALTER TABEL [Linhle_portfolio].[dbo].[Subcategories]
ADD TNOP int -- Add column TNOP --
CREATE PROCEDURE TNOP_auto (@subcategoryKey tinyint)
AS
IF NOT EXISTS (SELECT* FROM[Linhle_portfolio].[dbo].[Subcategories] WHERE @subcategoryKey=ProductSubcategoryKey)
BEGIN 
    	PRINT 'SubcategoryKey does not exist'
    	RETURN -1
END
UPDATE[Linhle_portfolio].[dbo].[Subcategories]
SET TNOP= (SELECT C.Total FROM (SELECT SUM(Productkey) AS total 
			FROM [Linhle_portfolio].[dbo].[Subcategories] AS A INNER JOIN [Linhle_portfolio].[dbo].[Products] AS B
			ON A.ProductSubcategoryKey=B.ProductSubcategoryKey 
			WHERE @subcategoryKey=A.ProductSubcategoryKey
			GROUP BY A.ProductSubcategoryKey) AS C)
WHERE @subcategoryKey=ProductSubcategoryKey
GO

-- Apply --
EXECUTE TNOP_auto [1]

-- Create trigger update TNOP on Subcategories table whenever insert product to products table—
CREATE Trigger Sub_ProductInsert
ON [LINHLE_portfolio].[dbo].[Products] 
FOR INSERT
AS
IF NOT EXISTS (SELECT * FROM [LINHLE_portfolio].[dbo].[Subcategories] , INSERTED 
				WHERE [LINHLE_portfolio].[dbo].[Subcategories].ProductSubcategoryKey=INSERTED.ProductSubcategoryKey)
ROLLBACK TRANSACTION
ELSE
UPDATE [LINHLE_portfolio].[dbo].[Subcategories]
SET TNOP= TNOP+1
FROM INSERTED
WHERE [LINHLE_portfolio].[dbo].[Subcategories].
