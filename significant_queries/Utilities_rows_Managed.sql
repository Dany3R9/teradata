-- Load utilities are extremly useful in Teradata to Import/Export data quickly, but if used unproperly they can put the system under pressure due to the important usage of Awts in the system
-- You can use the following query to check when the utilities are instantiated and run in the system during the previous 15 days in order to check if you are using the utilities effectively
LOCK	ROW FOR access 
SELECT	CAST( CollectTimeStamp AS VARCHAR ( 10 )  ) AS DATA_ORA ,
		CASE 
	WHEN ( RowsInserted + RowsUpdated + RowsExported  ) = 0 THEN '00. Zero' 
	WHEN ( RowsInserted + RowsUpdated + RowsExported  ) < 1000 THEN '01. less than 1000' 
	WHEN ( RowsInserted + RowsUpdated + RowsExported  ) < 10000 THEN '02. less than 10000' 
	WHEN ( RowsInserted + RowsUpdated + RowsExported  ) < 100000 THEN '03. less than 100000' 
	WHEN ( RowsInserted + RowsUpdated + RowsExported  ) < 1000000 THEN '04. less than 1000000' 
	ELSE '05. more than 1000000' 
END	AS #ROWSManaged , COUNT ( * ) , AVG ( RowsInserted + RowsUpdated + RowsExported ) AS #Media_record ,
		median( RowsInserted + RowsUpdated + RowsExported  ) AS #Mediana_records 
FROM	PDCRINFO.DBQLUtilitytbl_hst --(the live table dbc.DBQLUtilitytbl can be used as well)
WHERE	DATA_ORA > DATE - 15 
GROUP BY 1 , 2 
ORDER BY 1 DESC , 2 ASC ;
