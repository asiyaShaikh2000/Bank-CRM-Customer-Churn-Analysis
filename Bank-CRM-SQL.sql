-- Data Cleaning and Preparation
Create database CapstonProject;
use CapstonProject;

select * from activecustomer;
select * from bank_churn;
select * from creditcard;
select * from customerinfo;
select * from exitcustomer;
select * from gender;
select * from geography;

-- to change the Bank DOJ datatype text to date/time

SET SQL_SAFE_UPDATES = 0;

UPDATE customerinfo SET Bank_DOJ_backup = `Bank DOJ`;

UPDATE customerinfo
SET `Bank DOJ` = STR_TO_DATE(`Bank DOJ`, '%d/%m/%Y');

ALTER TABLE customerinfo
MODIFY COLUMN `Bank DOJ` DATE;

SELECT CustomerId, `Bank DOJ` FROM customerinfo LIMIT 10;

SET SQL_SAFE_UPDATES = 1;

-- Objective questions

-- 2. Identify the top 5 customers with the highest Estimated Salary in the last quarter of the year.
SELECT CustomerId, Surname, EstimatedSalary
FROM customerinfo
WHERE QUARTER(`Bank DOJ`) = 4
ORDER BY EstimatedSalary DESC
LIMIT 5;

-- 3. Calculate the average number of products used by customers who have a credit card. 
SELECT AVG(NumOfProducts) AS Avg_Products_With_CreditCard
FROM bank_churn
WHERE HasCrCard = 1;

-- 4. Determine the churn rate by gender for the most recent year in the dataset.
SELECT MAX(YEAR(`Bank DOJ`)) AS LatestYear FROM customerinfo;

-- 5. Compare the average credit score of customers who have exited and those who remain.
SELECT  Exited,
  AVG(CreditScore) AS Average_CreditScore
FROM   bank_churn
GROUP BY   Exited;

-- 6. Which gender has a higher average estimated salary, and how does it relate to the number of active accounts? 
with ActiveAccounts as(
select CustomerId, count(*) as ActiveAccounts
from bank_churn
where IsActiveMember=1
group by CustomerId)
select case
		when c.GenderID=1 then "Male" else "Female" end as Gender,
        count(a.CustomerId) as ActiveAccounts,
        round(avg(c.EstimatedSalary),2) as AvgSalary
from customerinfo c 
left join ActiveAccounts a  on c.CustomerId= a.CustomerId
group by Gender 
order by AvgSalary desc;
    
-- 7. Segment the customers based on their credit score and identify the segment with the highest exit rate.  
 WITH CreditSegments AS (
  SELECT 
    CustomerId,
    CASE
      WHEN CreditScore >= 800 THEN 'Excellent'
      WHEN CreditScore BETWEEN 740 AND 799 THEN 'Very Good'
      WHEN CreditScore BETWEEN 670 AND 739 THEN 'Good'
	  WHEN CreditScore BETWEEN 580 AND 669 THEN 'Fair'
	  WHEN CreditScore BETWEEN 500 AND 579 THEN 'Poor' 
      ELSE "Very Poor"
	END AS Credit_Score_Segment,
    Exited
  FROM bank_churn),
ExitStats AS (
  SELECT 
    Credit_Score_Segment,
    COUNT(*) AS TotalCustomers,
    SUM(Exited) AS ExitedCustomers,
    ROUND(SUM(Exited) * 100.0 / COUNT(*), 2) AS ExitRate
  FROM CreditSegments
  GROUP BY Credit_Score_Segment)
SELECT *
FROM ExitStats
ORDER BY ExitRate DESC;

-- 8. Find out which geographic region has the highest number of active customers with a tenure greater than 5 years. 
SELECT 
  g.GeographyLocation AS Region,
  COUNT(b.CustomerId) AS ActiveCustomers
FROM bank_churn b
JOIN customerinfo c ON b.CustomerId = c.CustomerId
JOIN geography g ON c.GeographyID = g.GeographyID
WHERE b.IsActiveMember = 1
	  AND b.Tenure > 5
GROUP BY g.GeographyLocation
ORDER BY ActiveCustomers DESC
LIMIT 1;

-- 9. What is the impact of having a credit card on customer churn, based on the available data?
SELECT 
  HasCrCard,
  COUNT(*) AS TotalCustomers,
  SUM(Exited) AS ChurnedCustomers,
  ROUND(SUM(Exited) * 100.0 / COUNT(*), 2) AS ChurnRatePercentage
FROM bank_churn
GROUP BY HasCrCard;

-- 10. For customers who have exited, what is the most common number of products they have used?
SELECT 
  NumOfProducts,
  COUNT(*) AS ExitedCustomerCount
FROM bank_churn
WHERE Exited = 1
GROUP BY NumOfProducts
ORDER BY ExitedCustomerCount DESC;

-- 11. Examine the trend of customers joining over time and identify any seasonal patterns (yearly or monthly). Prepare the data through SQL and then visualize it.
-- Monthly Trend Analysis
SELECT 
  YEAR(`Bank DOJ`) AS JoinYear,
  MONTH(`Bank DOJ`) AS JoinMonth,
  COUNT(*) AS NewCustomers
FROM customerinfo
GROUP BY 
  YEAR(`Bank DOJ`), MONTH(`Bank DOJ`)
ORDER BY 
  JoinYear, JoinMonth;

-- Yearly Trend Analysis
SELECT 
  YEAR(`Bank DOJ`) AS JoinYear,
  COUNT(*) AS NewCustomers
FROM customerinfo
GROUP BY YEAR(`Bank DOJ`)
ORDER BY JoinYear;


-- 12. Analyze the relationship between the number of products and the account balance for customers who have exited.
SELECT 
  NumOfProducts,
  ROUND(AVG(Balance), 2) AS Avg_Balance,
  COUNT(*) AS Exited_Customers
FROM bank_churn
WHERE Exited = 1
GROUP BY NumOfProducts
ORDER BY NumOfProducts;

-- 13. Identify any potential outliers in terms of balance among customers who have remained with the bank.
WITH stats AS (
  SELECT 
    AVG(Balance) AS avg_balance,
    STDDEV(Balance) AS std_balance
  FROM bank_churn
  WHERE Exited = 0)
SELECT 
  CustomerId,
  Balance
FROM bank_churn, stats
WHERE Exited = 0
  AND Balance > (avg_balance + 2 * std_balance);

-- 15. Using SQL, write a query to find out the gender-wise average income of males and females in each geography id. Also, rank the gender according to the average value.
SELECT 
    c.GeographyID,
    g.GenderCategory,
    ROUND(AVG(c.EstimatedSalary), 2) AS Avg_Income,
    RANK() OVER (PARTITION BY c.GeographyID ORDER BY AVG(c.EstimatedSalary) DESC) AS Income_Rank
FROM customerinfo c
JOIN gender g ON c.GenderID = g.GenderID
GROUP BY c.GeographyID, g.GenderCategory
ORDER BY c.GeographyID, Income_Rank;


-- 16. Using SQL, write a query to find out the average tenure of the people who have exited in each age bracket (18-30, 30-50, 50+)
SELECT
  CASE 
    WHEN c.Age BETWEEN 18 AND 30 THEN '18-30'
    WHEN c.Age > 30 AND c.Age <= 50 THEN '31-50'
    ELSE '50+' 
  END AS Age_Bracket,
  AVG(b.Tenure) AS Avg_Tenure
FROM customerinfo c
JOIN bank_churn b ON c.CustomerId = b.CustomerId
WHERE b.Exited = 1
GROUP BY Age_Bracket
ORDER BY Age_Bracket;

-- 17. s there any direct correlation between salary and the balance of the customers? And is it different for people who have exited or not?
SELECT 
  b.Exited,
  ROUND(AVG(c.EstimatedSalary), 2) AS Avg_Salary,
  ROUND(AVG(b.Balance), 2) AS Avg_Balance
FROM 
  customerinfo c
JOIN 
  bank_churn b ON c.CustomerId = b.CustomerId
GROUP BY 
  b.Exited;
  
  -- 19. Rank each bucket of credit score as per the number of customers who have churned the bank.
WITH CreditBuckets AS (
  SELECT CustomerId,
    CASE 
      WHEN CreditScore >= 800 THEN 'Excellent'
      WHEN CreditScore BETWEEN 740 AND 799 THEN 'Very Good'
      WHEN CreditScore BETWEEN 670 AND 739 THEN 'Good'
      WHEN CreditScore BETWEEN 580 AND 669 THEN 'Fair'
      WHEN CreditScore BETWEEN 500 AND 579 THEN 'Poor'
      ELSE 'Very Poor'
    END AS CreditScoreBucket,
    Exited
  FROM bank_churn),
ChurnedCounts AS (
  SELECT CreditScoreBucket,
    COUNT(*) AS ChurnedCustomers
  FROM CreditBuckets
  WHERE Exited = 1
  GROUP BY CreditScoreBucket),
RankedBuckets AS (
  SELECT 
    CreditScoreBucket,
    ChurnedCustomers,
    RANK() OVER (ORDER BY ChurnedCustomers DESC) AS ChurnRank
  FROM ChurnedCounts)
SELECT * FROM RankedBuckets;

-- 20. According to the age buckets find the number of customers who have a credit card. Also retrieve those buckets that have lesser than average number of credit cards per bucket.
WITH AgeBuckets AS (
  SELECT 
    CASE 
      WHEN Age BETWEEN 18 AND 30 THEN '18-30'
      WHEN Age BETWEEN 31 AND 50 THEN '31-50'
      ELSE '51+'
    END AS Age_Bucket,
    COUNT(*) AS CreditCardHolders
  FROM customerinfo c
  JOIN bank_churn b ON c.CustomerId = b.CustomerId
  WHERE b.HasCrCard = 1
  GROUP BY Age_Bucket),
AverageCreditCardCount AS (
  SELECT AVG(CreditCardHolders) AS AvgCardCount
  FROM AgeBuckets)
SELECT ab.*
FROM AgeBuckets ab
JOIN AverageCreditCardCount avgcc
  ON ab.CreditCardHolders < avgcc.AvgCardCount;

-- 21. Rank the Locations as per the number of people who have churned the bank and average balance of the customers.
SELECT 
  g.GeographyLocation,
  COUNT(b.CustomerId) AS ChurnedCustomers,
  AVG(b.Balance) AS AvgBalance,
  RANK() OVER (ORDER BY COUNT(b.CustomerId) DESC) AS Rank_By_Churn,
  RANK() OVER (ORDER BY AVG(b.Balance) DESC) AS Rank_By_Balance
FROM bank_churn b
JOIN customerinfo c ON b.CustomerId = c.CustomerId
JOIN geography g ON c.GeographyID = g.GeographyID
WHERE b.Exited = 1
GROUP BY g.GeographyLocation;

-- 22. As we can see that the “CustomerInfo” table has the CustomerID and Surname, now if we have to join it with a table where the primary key is also a combination of CustomerID and Surname, come up with a column where the format is “CustomerID_Surname”.
SELECT 
  CustomerID,
  Surname,
  CONCAT(CustomerID, '_', Surname) AS CustomerID_Surname
FROM customerinfo;

-- 23. Without using “Join”, can we get the “ExitCategory” from ExitCustomers table to Bank_Churn table? If yes do this using SQL.
SELECT 
  b.CustomerID,
  b.Exited,
  ( SELECT e.ExitCategory 
    FROM exitcustomer e 
    WHERE e.ExitID = b.Exited
  ) AS ExitCategory
FROM bank_churn b;

-- 25. Write the query to get the customer IDs, their last name, and whether they are active or not for the customers whose surname ends with “on”.
SELECT 
  c.CustomerId,
  c.Surname,
  CASE 
    WHEN b.IsActiveMember = 1 THEN 'Active'
    ELSE 'Inactive'
  END AS ActiveStatus
FROM customerinfo c
JOIN bank_churn b ON c.CustomerId = b.CustomerId
WHERE c.Surname LIKE '%on';

-- 26. Can you observe any data disrupency in the Customer’s data? As a hint it’s present in the IsActiveMember and Exited columns. One more point to consider is that the data in the Exited Column is absolutely correct and accurate.
SELECT COUNT(*)
FROM bank_churn
WHERE Exited = 1 AND IsActiveMember = 1;

-- Subjective Questions

-- 8. Utilize SQL queries to segment customers based on demographics and account details.
SELECT 
    g.GeographyLocation AS Region,
    COUNT(c.CustomerID) AS num_of_customers,
    AVG(b.Balance) AS avg_balance
FROM 
    bank_churn b
JOIN 
    customerinfo c ON b.CustomerID = c.CustomerID
JOIN 
    geography g ON c.GeographyID = g.GeographyID
GROUP BY 
    g.GeographyLocation;


-- 14. In the “Bank_Churn” table how can you modify the name of the “HasCrCard” column to “Has_creditcard”?
ALTER TABLE Bank_Churn
CHANGE COLUMN HasCrCard Has_creditcard INT;

select * from bank_churn
