create or replace view KSFPA.ONLINE_UGAM_PVT.CANCELLED_ORDERS_AMOUNT_ORDERSHARE(
	YEAR,
	PERIOD,
	WEEK,
	CANCELLED_DATE,
	FY_PERIOD_WEEK,
	STORE_CANCELLATION_AMOUNT,
	STORE_CANCELLATION_ORDERSHARE,
	UPFRONT_CANCELLATION_AMOUT,
	UPFRONT_CANCELLATION_ORDERSHARE,
	TOTAL_STORE_UPFRONT_CANCELLATION_AMOUNT,
	TOTAL_STORE_UPFRONT_CANCELLATION_ORDERSHARE
) as
SELECT T1.YEAR,
T1.PERIOD,
T1.WEEK,
T1.CANCELLED_DATE,
CONCAT('FY',RIGHT(T1.YEAR,2),'P',T1.PERIOD,'W',T1.WEEK) AS FY_PERIOD_WEEK,
T3.STORE_CANCELLATION_AMOUNT,
T1.STORE_CANCELLATION_ORDERSHARE,
T3.UPFRONT_CANCELLATION_AMOUT,
T2.UPFRONT_CANCELLATION_ORDERSHARE,
SUM(T3.STORE_CANCELLATION_AMOUNT+T3.UPFRONT_CANCELLATION_AMOUT) AS TOTAL_STORE_UPFRONT_CANCELLATION_AMOUNT,
SUM(T1.STORE_CANCELLATION_ORDERSHARE+T2.UPFRONT_CANCELLATION_ORDERSHARE) AS TOTAL_STORE_UPFRONT_CANCELLATION_ORDERSHARE
FROM KSFPA.ONLINE_UGAM_PVT.CANCELLED_ORDERS_STORE_CANCELLATION_ORDERSHARE T1
INNER JOIN KSFPA.ONLINE_UGAM_PVT.CANCELLED_ORDERS_UPFRONT_CANCELLATION_ORDERSHARE T2 ON T1.CANCELLED_DATE=T2.CANCELLED_DATE
INNER JOIN (SELECT  CANCELLED_DATE,
SUM(CASE WHEN Return_Reason IN ('HD Store Rejection (Exception)',
                            'Click & Collect Store Rejection - Customer chose free delivery',
                           'C&C Store Rejection (Exception)',
						   'Ready to Collect Order Not Collected') THEN cost END ) AS STORE_CANCELLATION_AMOUNT,
SUM(CASE WHEN Return_Reason IN ('Upfront Rejection (HD)') THEN cost END ) AS UPFRONT_CANCELLATION_AMOUT
FROM KSFPA.ONLINE_UGAM_PVT.CANCELLED_ORDERS_MAIN
GROUP BY CANCELLED_DATE) T3 ON T1.CANCELLED_DATE=T3.CANCELLED_DATE
GROUP BY T1.YEAR,
T1.PERIOD,
T1.WEEK,
T1.CANCELLED_DATE,
T3.STORE_CANCELLATION_AMOUNT,
T1.STORE_CANCELLATION_ORDERSHARE,
T3.UPFRONT_CANCELLATION_AMOUT,
T2.UPFRONT_CANCELLATION_ORDERSHARE;

create or replace view KSFPA.ONLINE_UGAM_PVT.CANCELLED_ORDERS_DIM_TABLE(
	CANCELLED_DATE,
	YEAR,
	WEEK,
	PERIOD,
	PERIOD_WEEK,
	FY_PERIOD_WEEK,
	PERIOD_NUMBER
) as 
SELECT CANCELLED_DATE,
YEAR,
WEEK,
PERIOD,
CONCAT('P',PERIOD,' - ','W',WEEK) AS PERIOD_WEEK,
CONCAT('FY',RIGHT(YEAR,2),'P',PERIOD,'W',WEEK) AS FY_PERIOD_WEEK,
CONCAT('P',PERIOD) AS PERIOD_NUMBER
FROM 
(
SELECT DISTINCT T1.CANCELLED_DATE,T1.YEAR,T1.WEEK,T1.PERIOD
  
FROM KSFPA.ONLINE_UGAM_PVT.CANCELLED_ORDERS_MAIN T1
LEFT JOIN  KSFPA.ONLINE_UGAM_PVT.CANCELLED_ORDERS_STORE_CANCELLATION_ORDERSHARE T2 ON T1.CANCELLED_DATE=T2.CANCELLED_DATE
LEFT JOIN  KSFPA.ONLINE_UGAM_PVT.CANCELLED_ORDERS_UPFRONT_CANCELLATION_ORDERSHARE T3 ON T1.CANCELLED_DATE=T3.CANCELLED_DATE);

create or replace view KSFPA.ONLINE_UGAM_PVT.CANCELLED_ORDERS_MAIN(
	YEAR,
	PERIOD,
	WEEK,
	FY_PERIOD_WEEK,
	CANCELLED_DATE,
	COST,
	MOVING_COST,
	VAR,
	MOVING_COST_4_WEEKS,
	VAR_4_WEEKS,
	RETURN_REASON
) as 
SELECT 
ACCOUNTING_YEAR AS YEAR,
    ACCOUNTING_MONTH_NUMBER AS PERIOD,
    ACCOUNTING_WEEK_NUMBER AS WEEk,
CONCAT('FY',RIGHT(ACCOUNTING_YEAR,2),'P',ACCOUNTING_MONTH_NUMBER,'W',ACCOUNTING_WEEK_NUMBER) AS FY_PERIOD_WEEK,
Cancelled_Date,
cost,
moving_cost,
var,
moving_cost_4_weeks,
var_4_weeks,
Return_Reason
FROM
(
select 
Cancelled_Date,
cost as cost,
avg(cost) over (partition by Return_Reason order by Cancelled_Date rows between 84 preceding and 1 preceding) as moving_cost,
(cost/avg(cost) over (partition by Return_Reason order by Cancelled_Date rows between 84 preceding and 1 preceding))-1 as var,

avg(cost) over (partition by Return_Reason order by Cancelled_Date rows between 28 preceding and 1 preceding) as moving_cost_4_weeks,
(cost/avg(cost) over (partition by Return_Reason order by Cancelled_Date rows between 28 preceding and 1 preceding))-1 as var_4_weeks,

Return_Reason
from
(

select 
Cancelled_Date,
sum(cost) as cost,
Return_Reason

FROM 
(
Select soi.ExternalOrderID,
soi.UnitPrice * soi.Quantity as Cost,
DATE(soi.DO_Cancelled) AS Cancelled_Date,
CASE WHEN DATEDIFF(minute, soi.OrderDate, soi.DO_Created) < 45 
AND (ParentShipmentID = '0' OR ParentShipmentID is null) THEN 'Upfront Rejection (HD)' 
			ELSE 'HD Store Rejection (Exception)' 
			END AS Return_Reason
from "KSFPA"."OMS"."STOREORDERITEMS" soi
WHERE
  soi.DO_Created > '2020-06-29 00:00:00'
  and soi.DO_Created <  CONCAT(CURRENT_DATE()-1, ' 23:59:59')
  and soi.str_id ='9999'
  and soi.DO_Cancelled is not null
  and soi.DO_Cancelled < CONCAT(CURRENT_DATE()-1, ' 23:59:59')
  
UNION ALL
  
Select soi.ExternalOrderID, 
soi.UnitPrice * soi.Quantity as Cost, 
DATE(soi.DO_Cancelled) AS Cancelled_Date, 
CASE WHEN LTRIM(RTRIM(ModificationDescription)) = 'Cancelled'  THEN 'C&C Store Rejection (Exception)' 
			ELSE 'Click & Collect Store Rejection - Customer chose free delivery' 
			END AS Return_Reason
from "KSFPA"."OMS"."STOREORDERITEMS" soi
WHERE
  soi.DO_Created > '2020-06-29 00:00:00'
  and soi.DO_Created < CONCAT(CURRENT_DATE()-1, ' 23:59:59')
  and soi.str_id ='9996'
  and soi.DO_Cancelled is not null
  and soi.DO_Cancelled < CONCAT(CURRENT_DATE()-1, ' 23:59:59')

UNION ALL
  
Select soi.ExternalOrderID, 
soi.UnitPrice * soi.Quantity as Cost, 
DATE(soi.DO_Cancelled) AS Cancelled_Date, 
'Ready to Collect Order Not Collected' AS Return_Reason
from  "KSFPA"."OMS"."STOREORDERITEMS" soi
WHERE
  soi.DO_Cancelled > '2020-06-29 00:00:00'
  and soi.DO_Cancelled < CONCAT(CURRENT_DATE()-1, ' 23:59:59')
  and LTRIM(RTRIM(soi.ShipStatus)) = 'ItemCancelled'
  and QuantityReadyToCollect > '0'
  and soi.DO_Cancelled is not null
) 
group by Cancelled_Date,Return_Reason
order by Cancelled_Date
) ) T1
LEFT JOIN KSF_SOPHIA_DATA_INTELLIGENCE_HUB_PROD.COMMON_DIMENSIONS.DIM_DATE DD ON T1.Cancelled_Date = DD.DATE;

create or replace view KSFPA.ONLINE_UGAM_PVT.CANCELLED_ORDERS_STORE_CANCELLATION_ORDERSHARE(
	YEAR,
	PERIOD,
	WEEK,
	CANCELLED_DATE,
	STORE_CANCELLATION_AMOUNT,
	STORE_CANCELLATION_ORDERSHARE
) as 
SELECT  
ACCOUNTING_YEAR AS YEAR,
    ACCOUNTING_MONTH_NUMBER AS PERIOD,
    ACCOUNTING_WEEK_NUMBER AS WEEk,
    CANCELLED_DATE,
    STORE_CANCELLATION_AMOUNT,
    STORE_CANCELLATION_ORDERSHARE
FROM 
(
SELECT CANCELLED_DATE,
  STORE_CANCELLATION_AMOUNT,
    STORE_CANCELLED_ORDERS/TOTAL_ORDER_DO_PACKING AS STORE_CANCELLATION_ORDERSHARE
FROM
(
SELECT Cancelled_Date,COUNT(DISTINCT ExternalOrderID) AS STORE_CANCELLED_ORDERS, SUM(COST) AS STORE_CANCELLATION_AMOUNT
FROM 
(

Select soi.ExternalOrderID,
soi.UnitPrice * soi.Quantity as Cost,
DATE(soi.DO_Cancelled) AS Cancelled_Date,
CASE WHEN DATEDIFF(minute, soi.OrderDate, soi.DO_Created) < 45 
AND (ParentShipmentID = '0' OR ParentShipmentID is null) THEN 'Upfront Rejection (HD)' 
			ELSE 'HD Store Rejection (Exception)' 
			END AS Return_Reason
from "KSFPA"."OMS"."STOREORDERITEMS" soi
WHERE
  soi.DO_Created > '2020-06-29 00:00:00'
  and soi.DO_Created <  CONCAT(CURRENT_DATE()-1, ' 23:59:59')
  and soi.str_id ='9999'
  and soi.DO_Cancelled is not null
  and soi.DO_Cancelled < CONCAT(CURRENT_DATE()-1, ' 23:59:59')
  
UNION ALL
  
Select soi.ExternalOrderID, 
soi.UnitPrice * soi.Quantity as Cost, 
DATE(soi.DO_Cancelled) AS Cancelled_Date, 
CASE WHEN LTRIM(RTRIM(ModificationDescription)) = 'Cancelled'  THEN 'C&C Store Rejection (Exception)' 
			ELSE 'Click & Collect Store Rejection - Customer chose free delivery' 
			END AS Return_Reason
from "KSFPA"."OMS"."STOREORDERITEMS" soi
WHERE
  soi.DO_Created > '2020-06-29 00:00:00'
  and soi.DO_Created < CONCAT(CURRENT_DATE()-1, ' 23:59:59')
  and soi.str_id ='9996'
  and soi.DO_Cancelled is not null
  and soi.DO_Cancelled < CONCAT(CURRENT_DATE()-1, ' 23:59:59') 


UNION ALL

Select soi.ExternalOrderID, 
soi.UnitPrice * soi.Quantity as Cost, 
DATE(soi.DO_Cancelled) AS Cancelled_Date, 
'Ready to Collect Order Not Collected' AS Return_Reason
from  "KSFPA"."OMS"."STOREORDERITEMS" soi
WHERE
  soi.DO_Cancelled > '2020-06-29 00:00:00'
  and soi.DO_Cancelled < CONCAT(CURRENT_DATE()-1, ' 23:59:59')
  and LTRIM(RTRIM(soi.ShipStatus)) = 'ItemCancelled'
  and QuantityReadyToCollect > '0'
  and soi.DO_Cancelled is not null
) where Return_Reason NOT IN ('Upfront Rejection (HD)') 
  GROUP BY Cancelled_Date
  
 ) T1
  
LEFT JOIN (
SELECT DATE(DO_Packing) AS DO_Packing,
COUNT(DISTINCT ExternalOrderID) AS TOTAL_ORDER_DO_PACKING
FROM "KSFPA"."OMS"."STOREORDER"
WHERE DO_Packing > '2020-06-29 00:00:00'
AND DO_Packing < CONCAT(CURRENT_DATE()-1, ' 23:59:59')
GROUP BY DATE(DO_Packing)

) T2 ON T1.Cancelled_Date=T2.DO_Packing 
) T3 LEFT JOIN KSF_SOPHIA_DATA_INTELLIGENCE_HUB_PROD.COMMON_DIMENSIONS.DIM_DATE DD ON T3.Cancelled_Date = DD.DATE;

create or replace view KSFPA.ONLINE_UGAM_PVT.CANCELLED_ORDERS_SUMMARY(
	YEAR,
	PERIOD,
	WEEK,
	DATE_RANGE,
	CANCELLED_ORDERS,
	TOTAL_ORDERS,
	CANCELLATION_AMOUT,
	FY_PERIOD_WEEK,
	CANCELLED_ORDERS_LY,
	TOTAL_ORDERS_LY,
	CANCELLATION_AMOUT_LY,
	PERIOD_WEEK,
	PERIOD_NUMBER
) as 
select *,
lag(CANCELLED_ORDERS, 52, 0) over (order by year,period,week) as CANCELLED_ORDERS_LY,
lag(TOTAL_ORDERS, 52, 0) over (order by year,period,week) as TOTAL_ORDERS_LY,
lag(CANCELLATION_AMOUT, 52, 0) over (order by year,period,week) as CANCELLATION_AMOUT_LY,
CONCAT('P',PERIOD,' - ','W',WEEK) AS PERIOD_WEEK,
CONCAT('P',PERIOD) AS PERIOD_NUMBER
from KSFPA.ONLINE_UGAM_PVT.CANCELLED_ORDERS_TOTAL_WEEK_LEVEL
order by year,period,week;

create or replace view KSFPA.ONLINE_UGAM_PVT.CANCELLED_ORDERS_TOTAL_WEEK_LEVEL(
	YEAR,
	PERIOD,
	WEEK,
	DATE_RANGE,
	CANCELLED_ORDERS,
	TOTAL_ORDERS,
	CANCELLATION_AMOUT,
	FY_PERIOD_WEEK
) as
SELECT  
ACCOUNTING_YEAR AS YEAR,
    ACCOUNTING_MONTH_NUMBER AS PERIOD,
    ACCOUNTING_WEEK_NUMBER AS WEEk,
	CONCAT(CALENDAR_WEEK_END_DATE-6,' -- ',CALENDAR_WEEK_END_DATE) AS DATE_RANGE,
    SUM(CANCELLED_ORDERS) AS CANCELLED_ORDERS,
    SUM(TOTAL_ORDERS) AS TOTAL_ORDERS,
    SUM(CANCELLATION_AMOUT) AS CANCELLATION_AMOUT,
    CONCAT('FY',RIGHT(ACCOUNTING_YEAR,2),'P',ACCOUNTING_MONTH_NUMBER,'W',ACCOUNTING_WEEK_NUMBER) AS FY_PERIOD_WEEK
FROM 
(
SELECT T1.CANCELLED_DATE,
    CANCELLED_ORDERS AS CANCELLED_ORDERS,
	TOTAL_ORDER_DO_PACKING AS TOTAL_ORDERS,
	CANCELLATION_AMOUT

FROM (

SELECT Cancelled_Date,
COUNT(DISTINCT ExternalOrderID) AS CANCELLED_ORDERS
FROM 
(

Select soi.ExternalOrderID,
soi.UnitPrice * soi.Quantity as Cost,
DATE(soi.DO_Cancelled) AS Cancelled_Date,
CASE WHEN DATEDIFF(minute, soi.OrderDate, soi.DO_Created) < 45 
AND (ParentShipmentID = '0' OR ParentShipmentID is null) THEN 'Upfront Rejection (HD)' 
			ELSE 'HD Store Rejection (Exception)' 
			END AS Return_Reason
from "KSFPA"."OMS"."STOREORDERITEMS" soi
WHERE
  soi.DO_Created > '2020-06-29 00:00:00'
  and soi.DO_Created <  CONCAT(CURRENT_DATE()-1, ' 23:59:59')
  and soi.str_id ='9999'
  and soi.DO_Cancelled is not null
  and soi.DO_Cancelled < CONCAT(CURRENT_DATE()-1, ' 23:59:59')
  
UNION ALL
  
Select soi.ExternalOrderID, 
soi.UnitPrice * soi.Quantity as Cost, 
DATE(soi.DO_Cancelled) AS Cancelled_Date, 
CASE WHEN LTRIM(RTRIM(ModificationDescription)) = 'Cancelled'  THEN 'C&C Store Rejection (Exception)' 
			ELSE 'Click & Collect Store Rejection - Customer chose free delivery' 
			END AS Return_Reason
from "KSFPA"."OMS"."STOREORDERITEMS" soi
WHERE
  soi.DO_Created > '2020-06-29 00:00:00'
  and soi.DO_Created < CONCAT(CURRENT_DATE()-1, ' 23:59:59')
  and soi.str_id ='9996'
  and soi.DO_Cancelled is not null
  and soi.DO_Cancelled < CONCAT(CURRENT_DATE()-1, ' 23:59:59') 


UNION ALL

Select soi.ExternalOrderID, 
soi.UnitPrice * soi.Quantity as Cost, 
DATE(soi.DO_Cancelled) AS Cancelled_Date, 
'Ready to Collect Order Not Collected' AS Return_Reason
from  "KSFPA"."OMS"."STOREORDERITEMS" soi
WHERE
  soi.DO_Cancelled > '2020-06-29 00:00:00'
  and soi.DO_Cancelled < CONCAT(CURRENT_DATE()-1, ' 23:59:59')
  and LTRIM(RTRIM(soi.ShipStatus)) = 'ItemCancelled'
  and QuantityReadyToCollect > '0'
  and soi.DO_Cancelled is not null
)
  GROUP BY Cancelled_Date
  
 ) T1
  
LEFT JOIN (
SELECT DATE(DO_Packing) AS DO_Packing,
COUNT(DISTINCT ExternalOrderID) AS TOTAL_ORDER_DO_PACKING
FROM "KSFPA"."OMS"."STOREORDER"
WHERE DO_Packing > '2020-06-29 00:00:00'
AND DO_Packing < CONCAT(CURRENT_DATE()-1, ' 23:59:59')
GROUP BY DATE(DO_Packing)

) T2 ON T1.Cancelled_Date=T2.DO_Packing 
INNER JOIN (SELECT  CANCELLED_DATE,
SUM(cost) AS CANCELLATION_AMOUT
FROM KSFPA.ONLINE_UGAM_PVT.CANCELLED_ORDERS_MAIN
GROUP BY CANCELLED_DATE) T3 ON T1.CANCELLED_DATE=T3.CANCELLED_DATE

) T4 LEFT JOIN KSF_SOPHIA_DATA_INTELLIGENCE_HUB_PROD.COMMON_DIMENSIONS.DIM_DATE DD ON T4.Cancelled_Date = DD.DATE
GROUP BY YEAR,PERIOD,WEEK,CALENDAR_WEEK_END_DATE;

create or replace view KSFPA.ONLINE_UGAM_PVT.CANCELLED_ORDERS_UPFRONT_CANCELLATION_ORDERSHARE(
	YEAR,
	PERIOD,
	WEEK,
	CANCELLED_DATE,
	UPFRONT_CANCELLATION_AMOUT,
	UPFRONT_CANCELLATION_ORDERSHARE
) as 
SELECT  
ACCOUNTING_YEAR AS YEAR,
    ACCOUNTING_MONTH_NUMBER AS PERIOD,
    ACCOUNTING_WEEK_NUMBER AS WEEk,
    CANCELLED_DATE,
    UPFRONT_CANCELLATION_AMOUT,
    UPFRONT_CANCELLATION_ORDERSHARE
FROM 
(
SELECT CANCELLED_DATE,
    UPFRONT_CANCELLED_ORDERS/TOTAL_ORDER_DO_CREATED AS UPFRONT_CANCELLATION_ORDERSHARE,UPFRONT_CANCELLATION_AMOUT
FROM
(
SELECT Cancelled_Date,COUNT(DISTINCT ExternalOrderID) AS UPFRONT_CANCELLED_ORDERS,SUM(COST) AS UPFRONT_CANCELLATION_AMOUT
FROM 
(
Select soi.ExternalOrderID,
soi.UnitPrice * soi.Quantity as Cost,
DATE(soi.DO_Cancelled) AS Cancelled_Date,
CASE WHEN DATEDIFF(minute, soi.OrderDate, soi.DO_Created) < 45 
AND (ParentShipmentID = '0' OR ParentShipmentID is null) THEN 'Upfront Rejection (HD)' 
			ELSE 'HD Store Rejection (Exception)' 
			END AS Return_Reason
from "KSFPA"."OMS"."STOREORDERITEMS" soi
WHERE
  soi.DO_Created > '2020-06-29 00:00:00'
  and soi.DO_Created <  CONCAT(CURRENT_DATE()-1, ' 23:59:59')
  and soi.str_id ='9999'
  and soi.DO_Cancelled is not null
  and soi.DO_Cancelled < CONCAT(CURRENT_DATE()-1, ' 23:59:59')
  ) where Return_Reason IN ('Upfront Rejection (HD)') 
GROUP BY Cancelled_Date
 ) T1
  
LEFT JOIN (
SELECT DATE(DO_Created) AS DO_Created,
COUNT(DISTINCT ExternalOrderID) AS TOTAL_ORDER_DO_CREATED
FROM "KSFPA"."OMS"."STOREORDER"
WHERE DO_Created > '2020-06-29 00:00:00'
AND DO_Created < CONCAT(CURRENT_DATE()-1, ' 23:59:59')
GROUP BY DATE(DO_Created)

) T2 ON T1.Cancelled_Date=T2.DO_Created 
) T3 LEFT JOIN KSF_SOPHIA_DATA_INTELLIGENCE_HUB_PROD.COMMON_DIMENSIONS.DIM_DATE DD ON T3.Cancelled_Date = DD.DATE;