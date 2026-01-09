/*
**		  NodeStats v16 (contains columns added in the 16 TD release) 2019-10-16
**      Reviewed and validated for teradata 17 version              2023-04-01
**
**		Estrae le statistiche di sistema per nodo da ResUsageSPMA, ResUsageSVPR e ResUsageSAWT su sistemi con TD16.00+ e SLES11 da analizzare con MS Excel
**		ResUsageSVPR e ResUsageSAWT possono essere in Summery Mode o in Standard Mode
**
**		Unita di misura delle metriche:
**		_s = per secondo
**		_MBs = MegaByte per secondo
**		_msec = millisecondi
**		_sec = secondi
**		_KB = KiloByte	( 1KB = 1024 byte)
**		_MB = MegaByte
**		_GB = GigaByte
**
**    This is a Significant query to collect multiple metrics to use for overall site Analysis
*/
LOCK ROW FOR ACCESS
SELECT
	'v1720+r0' AS Version,
	Cast(Cast(Cast(SPMA_DT.LogDate AS Format 'YYYY-MM-DD') AS CHAR(10)) || ' ' ||
		Cast(Cast(SPMA_DT.LogTime AS Format '99:99:99') AS CHAR(8)) AS TIMESTAMP(0)) AS LogTimeStamp,
	Cast(SPMA_DT.LogDate AS Format 'YYYY-MM-DD') AS LogDate,
	Cast(SPMA_DT.LogTime AS Format '99:99:99') AS LogTime,
	CAL_DT.day_of_week - 1 AS DayOfWeek,																	/* 1 (Monday) through 7 (Sunday) */
	CAL_DT.week_of_year AS WeekOfYear,																		/* Week begins on Monday */
	SPMA_DT.NodeId AS NodeId,

	SPMA_DT.AMPs AS AMPs,
	SPMA_DT.PEs AS PEs,
	SPMA_DT.MemSizeGB AS MemSizeGB,
	SPMA_DT.VHCacheGB AS VHCacheSizeGB,
	SPMA_DT.EffCPUCoD AS CPUCoD,																				/* % of effective CPU CoD */
	SPMA_DT.EffIOCoD AS IOCoD,																					/* % of effective DiskIO CoD */

	Cast(SPMA_DT.LogPeriod * SPMA_DT.NCPUs AS INTEGER) AS CPUAvail_sec,
	(SPMA_DT.CPUOS_sec + SPMA_DT.CPUDB_sec) / CPUAvail_sec * 100 AS CPUBusyPct,
	SPMA_DT.CPUWaitIO_sec / CPUAvail_sec * 100 AS CPUWaitIOPct,
	SPMA_DT.CPUOS_sec / CPUAvail_sec * 100 AS CPUOSPct,												/* If OSPctOfCPU<20% and CPUBusyPct>80% probably bad product join or a heavy duplicate row check */

	(SPMA_DT.PhyReadMB + SPMA_DT.PhyWriteMB) / NullIfZero(SPMA_DT.LogPeriod) AS PhyDiskIO_MBs,
	SPMA_DT.PhyReadMB / NullIfZero(SPMA_DT.PhyReadMB + SPMA_DT.PhyWriteMB) * 100 AS DiskReadPct,
	SPMA_DT.PhyReadMB / NullIfZero(SPMA_DT.PhyReads) * 1024 AS AvgDiskReadSize_KB,
	(1 - SPMA_DT.PhyReadMB / NullIfZero(SPMA_DT.LogReadMB)) * 100 AS CacheEff,
	SPMA_DT.UsedIOTA / NullIfZero(SPMA_DT.FullPotentialIOTA) * 100 AS UsedFullIOTAPct,		/* see note in the SPMA_DT subquery */

	(SPMA_DT.PhyNetIOMB) / NullIfZero(SPMA_DT.LogPeriod) AS BynetIO_MBs,						/* Physical Bynet Traffic */
	SPMA_DT.PhyNetBrdIOMB / NullIfZero(SPMA_DT.PhyNetIOMB) * 100 AS BynetBrdPct,			/* Physical Bynet Broadcast Traffic */

	(SPMA_DT.HostWriteMB + SPMA_DT.HostReadMB) / NullIfZero(SPMA_DT.LogPeriod) AS HostIO_MBs,	/* HostWrite=Transferred out to the hosts, HosttRead=Transferred in from the hosts */
	SPMA_DT.HostReadMB / NullIfZero(SPMA_DT.LogPeriod) AS HostRead_MBs,

	SPMA_DT.MemFreeGB AS MinMemFree_GB,
	SPMA_DT.OSSegReads / NullIfZero(SPMA_DT.LogPeriod) AS OSSegReads_s,						/* Paging pagesize = 4K */
	SPMA_DT.SwapIOPages / NullIfZero(SPMA_DT.LogPeriod) AS SwapIOPages_s,					/* Swapping pagesize = 4K */

	SPMA_DT.AWTInuseMax AS AWTInuseMax,
	SPMA_DT.NodeLastDoneCnt  AS NodeLastDoneCnt,


	SVPR_DT.CPUAMPSecs / CPUAvail_sec * 100 AS CPUAMPPct,
	SVPR_DT.CPUPESecs / CPUAvail_sec * 100 AS CPUPEPct,
	SVPR_DT.CPUGtwSecs / CPUAvail_sec * 100 AS CPUGTWPct,
	SVPR_DT.CPUBLCSecs / CPUAvail_sec * 100 AS CPUBLCPct,
	SVPR_DT.CPUTBBLCSecs / CPUAvail_sec * 100 AS CPUTBBLCPct,

	(SVPR_DT.PhyPermReadMB + SVPR_DT.PhyPermWriteMB) / NullIfZero(SPMA_DT.LogPeriod) AS PhyPermIO_MBs,
	(SVPR_DT.PhySpoolReadMB + SVPR_DT.PhySpoolWriteMB) / NullIfZero(SPMA_DT.LogPeriod) AS PhySpoolIO_MBs,
	SVPR_DT.IORespMax_msec,

	SVPR_DT.VHCacheInUseGB AS VHCacheInUseGB,
	SVPR_DT.VHAgedOutMB / NullIfZero(SPMA_DT.LogPeriod) AS VHAgedOut_MBs,
	SVPR_DT.VHPhyReadMB / NullIfZero(SPMA_DT.LogPeriod) AS VHPhyRead_MBs,
	SVPR_DT.VHLogReadMB / NullIfZero(SVPR_DT.LogPermReadMB) * 100 AS VHPercOfLogPerm,	/* VERIFICARE LA FONTE */

	SVPR_DT.FCRRequests AS FCRRequests,
	SVPR_DT.SuccessfulFCRs / NullIfZero(SVPR_DT.FCRRequests) * 100 AS SuccessfulFCRPct,

	SVPR_DT.MiniCylPacks  / NullIfZero(SPMA_DT.LogPeriod) AS MiniCylPacks_s,

	SVPR_DT.WorkQlenMax AS WorkQlenMax,

	SAWT_DT.AWTLimit AS AWTLimit,
	SAWT_DT.AWTNewMax AS AWTNewMax,
	SAWT_DT.AWTOneMax AS AWTOneMax,
	SAWT_DT.AWTEightMax AS AWTEightMax,
	SAWT_DT.AWTNineMax AS AWTNineMax,
	SAWT_DT.AWTUnresvdAvailMin AS AWTUnresvdAvailMin,
	SAWT_DT.FlowCtlCnt AS FlowCtlCnt,
	SAWT_DT.FlowCtl_sec AS FlowCtl_sec

FROM 	(
	SELECT
		SPMA.TheDate AS LogDate,
		SPMA.TheTime AS LogTime,
		SPMA.NodeId AS NodeId,
		SPMA.Vproc1 AS AMPs,
		SPMA.Vproc2 AS PEs,
		SPMA.Centisecs / 100.0 AS LogPeriod,
		SPMA.NCPUs AS NCPUs,
		SPMA.MemSize / 1024 AS MemSizeGB,
--		Cast (SPMA.Spare10 / 1048576 AS INTEGER) AS VHCacheGB,		/* In TD14.10 e 15.0 Spare10=VHCacheKB. Spare10 does not exist in 13.10 */
		SPMA.VHCacheKB / 1048576 AS VHCacheGB,
--		CASE WHEN SPMA.CodFactor > SPMA.Spare11 THEN SPMA.Spare11 ELSE SPMA.CodFactor END AS EffCPUCoD,	/* In TD14.10: CodFactor=PM_CPU_COD, Spare11=WM_CPU_COD. CodFactor and Spare11 do not exist in 13.10 */
--		CASE WHEN SPMA.PM_CPU_COD > SPMA.WM_CPU_COD THEN SPMA.WM_CPU_COD ELSE SPMA.PM_CPU_COD END AS EffCPUCoD,
		CASE WHEN SPMA.PM_COD_CPU > SPMA.WM_COD_CPU THEN SPMA.WM_COD_CPU ELSE SPMA.PM_COD_CPU END AS EffCPUCoD,	/* For TD16+ */
--		CASE WHEN SPMA.SpareInt > SPMA.Spare12 THEN SPMA.SpareInt ELSE SPMA.Spare12 END AS EffIOCoD,			/* In TD14.10: SpareInt=PM_IO_COD, Spare12=WM_IO_COD. SpareInt and Spare12 do not exist in 13.10 */
--		CASE WHEN SPMA.PM_IO_COD > SPMA.WM_IO_COD THEN SPMA.WM_IO_COD ELSE SPMA.PM_IO_COD END AS EffIOCoD,
		CASE WHEN SPMA.PM_COD_IO > SPMA.WM_COD_IO THEN SPMA.WM_COD_IO ELSE SPMA.PM_COD_IO END AS EffIOCoD,				/* For TD16+ */

		SPMA.CPUUExec / 100.0 AS CPUDB_sec,
		SPMA.CPUUServ / 100.0 AS CPUOS_sec,
		SPMA.CPUIoWait / 100.0 AS CPUWaitIO_sec,
		(SPMA.FileAcqReadKB + SPMA.FilePreReadKB) / 1024 AS PhyReadMB,
		SPMA.FileAcqReads + SPMA.FilePreReads AS PhyReads,
		SPMA.FileAcqKB / 1024 AS LogReadMB,
		SPMA.FileWriteKB / 1024 AS PhyWriteMB,
--		The following are IO token allocations, based on the IO size and read-write percent but it is not totally accurate today (they are what TASM uses to prioritise IO)
--		SPMA.Spare07 AS FullPotentialIota,											/* In TD14.10: Spare07=FullPotetialIota. Spare07 does not exist in 13.10 */
		SPMA.FullPotentialIota AS FullPotentialIOTA,							/* Only for TD15+ */
--		SPMA.Spare09 AS UsedIOta,													/* In TD14.10: Spare09=UsedIota. Spare09 does not exist in 13.10 */
		SPMA.UsedIota AS UsedIOTA,												/* Only for TD15+ */
		(SPMA.NetMsgPtPWriteKB + SPMA.NetMsgBrdWriteKB + SPMA.NetMsgPtPReadKB + SPMA.NetMsgBrdWriteKB) / 1024 AS PhyNetIOMB,
		(SPMA.NetMsgBrdWriteKB + SPMA.NetMsgBrdWriteKB) / 1024 AS PhyNetBrdIOMB,
		SPMA.MemFreeKB / 1048576 AS MemFreeGB,							/* Approximate amount of memory that is available for use. MemFreeKB definition will be updated in TD15. */
		SPMA.HostReadKB / 1024 AS HostReadMB,
		SPMA.HostWriteKB / 1024 AS HostWriteMB,
		SPMA.MemTextPageReads AS OSSegReads,
		SPMA.MemCtxtPageReads + SPMA.MemCtxtPageWrites AS SwapIOPages,
		Cast(SPMA.AwtInuseMax AS INTEGER) AS AWTInuseMax,
		SPMA.MsgChnLastDone AS NodeLastDoneCnt							/* The last AMP to finish send a last done message indicating the work is done */
	FROM
		DBC.ResUsageSPMA SPMA
--		SYSMNGDB_HIST.ResUsageSpma_HIST SPMA
	) SPMA_DT
LEFT OUTER JOIN (
	SELECT
		SVPR.TheDate AS LogDate,
		SVPR.TheTime AS LogTime,
		SVPR.NodeId AS NodeId,

		Sum(SVPR.CPUUServPart09 + SVPR.CPUUExecPart09 + SVPR.CPUUServPart11 + SVPR.CPUUExecPart11) / 100.0 AS CPUAMPSecs,	/* Filesys & AWT */
		Sum(SVPR.CPUUExecPart12 + SVPR.CPUUServPart12 + SVPR.CPUUExecPart13 + SVPR.CPUUServPart13 +
			SVPR.CPUUExecPart14 + SVPR.CPUUServPart14) / 100.0 AS CPUPESecs,																			/* Session, Dispatch & Parser */
		Sum(SVPR.CPUUExecPart10 + SVPR.CPUUServPart10) / 100.0 AS CPUGtwSecs,
		Sum(SVPR.FileCompCPU + SVPR.FileUncompCPU) / 1000000.0 AS CPUBLCSecs,
		Sum(SVPR.FileTempCPU) / 1000000.0 AS CPUTBBLCSecs,											/* Assunto divisore identico al precedente */
		Sum(SVPR.FilePDbAcqKB + SVPR.FilePCiAcqKB) / 1024 AS LogPermReadMB,
		Sum(SVPR.FileSDbAcqKB + SVPR.FileSCiAcqKB) / 1024 AS LogSpoolReadMB,
		Sum(SVPR.FilePDbAcqReadKB + SVPR.FilePCiAcqReadKB + SVPR.FilePDbPreReadKB + SVPR.FilePCiPreReadKB) / 1024 AS PhyPermReadMB,
		Sum(SVPR.FileSDbAcqReadKB + SVPR.FileSCiAcqReadKB + SVPR.FileSDbPreReadKB + SVPR.FileSCiPreReadKB) / 1024 AS PhySpoolReadMB,
		Sum(SVPR.FilePDbFWriteKB + SVPR.FilePCiFWriteKB + SVPR.FilePDbDyAWriteKB + SVPR.FilePCiDyAWriteKB) / 1024 AS PhyPermWriteMB,
		Sum(SVPR.FileSDbFWriteKB + SVPR.FileSCiFWriteKB + SVPR.FileSDbDyAWriteKB + SVPR.FileSCiDyAWriteKB) / 1024 AS PhySpoolWriteMB,
		Max(SVPR.IoRespMax) AS IORespMax_msec,					/*  Maximum I/O response time in milliseconds on an AMP */
--		Sum(SVPR.Spare07) / 1024 AS VHCacheInUseGB,						/* In 14.10 Spare07=VHCacheInUseKB, Size of VH cache in KB. Spare07 does not exist in 13.10 */
		Sum(SVPR.VHCacheInuseKB) / 1048576 AS VHCacheInUseGB,		/* Only for TD15+ ? */
--		Sum(SVPR.Spare01) / 1024 AS VHAgedOutMB,					/* In 14.10 Spare01=VHAgedOutKB, Volume of data segments in KB that were aged out from VH cache. Spare01 does not exist in 13.10 */
		Sum(SVPR.VHAgedOutKB) / 1024 AS VHAgedOutMB,			/* Only for TD15+ */
--		Sum(SVPR.Spare03) / 1024 AS VHLogReadMB,					/* In 14.10 Spare03=VHLogicalDBReadKB, Volume of logical reads in KB from VH cache. Spare03 does not exist in 13.10 */
		Sum(SVPR.VHLogicalDBReadKB) / 1024 AS VHLogReadMB,	/* Only for TD15+ */
--		Sum(SVPR.Spare05) / 1024 AS VHPhyReadMB,					/* In 14.10 Spare05=VHPhysicalDBReadKB, Volume of VH reads in KB that were handled by physical disk I/O due to a VH cache miss. Spare05 does not exist in 13.10 */
		Sum(SVPR.VHPhysicalDBReadKB) / 1024 AS VHPhyReadMB,	/* Only for TD15+ */
		Sum(SVPR.FileFcrRequests) AS FCRRequests,
		Sum(SVPR.FileFcrRequests - SVPR.FileFcrDeniedUser - SVPR.FileFcrDeniedKern) AS SuccessfulFCRs,	/* refused da FSGCAche? */

		Cast(Max(SVPR.MsgWorkQlenMax) AS INTEGER) AS WorkQlenMax,			/* Maximum number of work requests waiting in the message queue */

		Sum(SVPR.FileMCylPacks) AS MiniCylPacks
	FROM
		DBC.ResUsageSVPR SVPR
--		SYSMNGDB_HIST.ResUsageSvpr_HIST SVPR
	GROUP	BY 1, 2, 3
	) SVPR_DT
ON
	SPMA_DT.LogDate = SVPR_DT.LogDate AND SPMA_DT.LogTime = SVPR_DT.LogTime AND SPMA_DT.NodeId = SVPR_DT.NodeId
LEFT OUTER JOIN (
	SELECT
		SAWT.TheDate AS LogDate,
		SAWT.TheTime AS LogTime,
		SAWT.NodeId,

--		Cast(Avg(SAWT.AWTLimit) AS INTEGER) AS AWTLimit,									/* AWTLimit does not exist in 13.10 */
		Cast(Avg(SAWT.AWTsConfigured) AS INTEGER) AS AWTLimit,						/* For TD16.0+ */
		Cast(Max(SAWT.WorkTypeMax00) AS INTEGER) AS AWTNewMax,
		Cast(Max(SAWT.WorkTypeMax01) AS INTEGER) AS AWTOneMax,
		Cast(Max(SAWT.WorkTypeMax08) AS INTEGER) AS AWTEightMax,
		Cast(Max(SAWT.WorkTypeMax09) AS INTEGER) AS AWTNineMax,
		Cast(Min(SAWT.AvailableMin) AS INTEGER) AS AWTUnresvdAvailMin,			/* AvailableMin does not exist in 13.10 */

		Sum(SAWT.FlowCtlCnt) AS FlowCtlCnt,
		Sum(SAWT.FlowCtlTime) / 1000 AS FlowCtl_sec
	FROM
		DBC.ResUsageSAWT SAWT
--		SYSMNGDB_HIST.ResUsageSawt_HIST SAWT
	GROUP BY 1, 2, 3
	) SAWT_DT
ON
	SPMA_DT.LogDate = SAWT_DT.LogDate AND SPMA_DT.LogTime = SAWT_DT.LogTime AND SPMA_DT.NodeId = SAWT_DT.NodeId
INNER JOIN (
	SELECT
		calendar_date,
		day_of_week,
		week_of_year
	FROM
		SYS_CALENDAR.CALENDAR
	) CAL_DT
ON
	SPMA_DT.LogDate = CAL_DT.calendar_date
WHERE
	/* ### Se necessario aggiungere una condizione sul NodeId e modificare il range di date selezionato  */
	SPMA_DT.LogDate BETWEEN '2018-03-15' AND '2018-03-16'
ORDER BY 2, 3, 4;
