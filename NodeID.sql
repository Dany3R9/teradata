-- Use the following query to collect the basic teradata site information (eg. Nodes IDs, PEs)
Lock row for access 
Select	Distinct    NodeID, NodeType, VProcType1 || ': ' || TRIM(VProc1) AS AMPs     ,
		VProcType2 || ': ' || TRIM(VProc2) AS PEs     ,VProcType3 || ': ' || VProc3 AS GTW      ,
		VProcType4 || ': ' || VProc4 AS RSG      ,VProcType5 || ': ' || VProc5 AS TVS      ,
		VProcType6 || ': ' || VProc6 AS VProc6     ,VProcType7 || ': ' || VProc7 AS VProc7 
From	DBC.ResUsageSpma 
Order By NodeID;
