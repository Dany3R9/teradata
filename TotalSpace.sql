- Global Teradata site Space check
-- 2023-04
-- Use this query in order to have an overview of the space used in your teradata system and to evaluate the max space available
lock row for access
select
cast(sum(currentperm)/1024/1024/1024 as decimal (10,3)) #Used_GB,
cast(sum(maxperm)/1024/1024/1024 as decimal (10,3)) #Total_Available_GB,
cast((#Total_Available_GB*0.65) as decimal (10,3)) #Max_data_usable_GB,
nullifzero(#Max_data_usable_GB-#Used_GB) #Available_data_GB,
nullifzero(#Total_Available_GB-#Max_data_usable_GB) #Operational_GB,
nullifzero(#Used_GB/#Max_data_usable_GB) #Used_data,
nullifzero(#Used_GB/#Total_Available_GB) #Used_on_total
from dbc.diskspacev;
