/* DS query
System CPU busy/available - 2016 march 01
--hints: remove the node column to get the overall CPU use per day
2018 10 31 -- updated with calculated column #Percent_busy
*/
LOCK   ROW FOR access
SELECT _DDate , SUM ( CPU_USR + CPU_SYS ) AS CPU_Busy ,
                SUM ( CPU_WIO + CPU_IDLE ) AS CPU_IDLE ,
                SUM ( CPU_USR + CPU_SYS + CPU_WIO + CPU_IDLE ) AS CPU_available ,
                CAST( CPU_Busy / CPU_available  AS DEC ( 15 , 3 )  ) (NAMED #Percent_busy )
FROM   (
SELECT thedate AS _DDate , nodeid AS Nodo , CAST( CAST( CAST( TheTime AS FORMAT '99:99:99.99'  ) AS CHAR ( 11 )  ) AS TIME( 6 )  ) AS time_of_day ,
                        SUM ( CPUUExec ) / 100 AS CPU_USR , SUM ( CPUUServ ) / 100 AS CPU_SYS ,
                        SUM ( CPUIoWait ) / 100 AS CPU_WIO , SUM ( CPUIdle ) / 100 AS CPU_IDLE
FROM   dbc.resusagespma  -- (use the PDCR hist table if needed)
WHERE TheDate >= DATE - 70
GROUP BY thedate , nodeid , thetime ) Intern
GROUP BY 1
ORDER BY _DDate DESC ;
