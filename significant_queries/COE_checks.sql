---------
-- 1) System swapping
LOCK ROW FOR ACCESS
SELECT TheDate
  
,TheTime (FORMAT '99:99:99')

,NodeId   ,MemCtxtPageReads (FORMAT 'Z(14)9')

,MemCtxtPageReads/secs (FORMAT 'Z(14)9.9', named "pswpin/s")

,MemCtxtPageWrites (FORMAT 'Z(14)9')

,MemCtxtPageWrites/secs (FORMAT 'Z(14)9.9', named "pswpout/s")

,(MemCtxtPageReads+MemCtxtPageWrites)/secs (FORMAT 'Z(14)9.9', named "TotSwap/s")

,memtextpagereads SegIOReads

,MemFreeKB

,PageMajorFaults

from dbc.resusagespma WHERE thedate between date-30 and date;


-------
-- 2) CPU busy
LOCK ROW FOR ACCESS
SELECT

TheDate (FORMAT 'YYYY-MM-DD')

,CAST((TheTime (FORMAT '99:99:99')) as CHAR(8))

,Extract(HOUR FROM TheTime) as hr

,Extract(MINUTE FROM TheTime) as mn

,NodeID ,NodeType

,NCPUs ,WM_COD_CPU

, WM_COD_IO

,((CPUUServ + CPUUExec)  / (CPUUServ+CPUUExec+CPUIOWait+CPUIdle ) * 100) (NAMED "Busy%", FORMAT 'Z(3)9.99')

,(CPUUServ / (CPUUServ+CPUUExec+CPUIOWait+CPUIdle )*100) (NAMED "OS%", FORMAT 'Z(3)9.99')

,(CPUIOWait / (CPUUServ+CPUUExec+CPUIOWait+CPUIdle )*100) (NAMED "IOWait%", FORMAT 'Z(3)9.99')

,(CPUIdle / (CPUUServ+CPUUExec+CPUIOWait+CPUIdle )*100) (NAMED "Idle%", FORMAT 'Z(3)9.99')

,CPUPRocSwitches ,PageMajorFaults ,PageMinorFaults ,NLBActiveSessionsMax, NLBSessionsInuse, NLBSessionsCompleted,   NLBMsgFlowControlled, NLBMsgFlowControlledKB

--, (CPUUServ + CPUUExec)

FROM dbc.resusagespma WHERE TheDate  between date-30 and date;


-------
-- 3) Slow Lun query
LOCKING  dbc.ResUsageSpdsk FOR ACCESS
SELECT     TheDate

,CAST((TheTime (FORMAT '99:99:99')) AS CHAR(10))

,EXTRACT(HOUR FROM TheTime) AS hr

,EXTRACT(MINUTE FROM TheTime) AS mn

,NodeID

,PDiskGlobalId

,PDiskDeviceId  (FORMAT 'X(9)')

,PDiskType

,ReadCnt     (FORMAT 'Z(8)9')

,WriteCnt     (FORMAT 'Z(8)9')

,ReadKB     (FORMAT 'Z(8)9')

,WriteKB     (FORMAT 'Z(8)9')

/* Response totals are in centiseconds.  Multiply by 10 to get milliseconds*/

,ReadRespTot*10         (NAMED ReadRespTot_ms,FORMAT 'Z(8)9')

,WriteRespTot*10         (NAMED WriteRespTot_ms,FORMAT 'Z(8)9')

,cast(ConcurrentMax As Integer)   (FORMAT 'Z(8)9')

,cast(ConcurrentReadMax As Integer) (FORMAT 'Z(8)9')

,Cast(ConcurrentWriteMax As Integer) (FORMAT 'Z(8)9')

-- ,OutReqTime            (FORMAT 'Z(8)9')

,ReadRespTot_ms/NULLIFZERO(ReadCnt) (NAMED AvgReadResp_ms,FORMAT 'Z(8)9')

,WriteRespTot_ms/NULLIFZERO(WriteCnt) (NAMED AvgWriteResp_ms,FORMAT 'Z(8)9')

,cast(ReadRespMax As Integer) * 10    (Named ReadRespMax_ms, FORMAT 'Z(8)9')

,cast(WriteRespMax As Integer) * 10    (Named WriteRespMax_ms, FORMAT 'Z(8)9')

-- ,(CAST(SpareTmon00 as DECIMAL(6,2)) / 10.0) (Named COD, FORMAT 'ZZ9.99')

---------------------------------TVS------------------------------------------

/*  ,ExtAllocHot                     ,ExtAllocWarm                    ,ExtAllocTotal                   ,ExtAllocNonPacing               ,ExtAllocSystemPacing            ,ExtAllocStatic

 ,ExtMigrateIOTimeImprove         ,MigrationBlockedIos   ,ExtMigrateTotal   ,ExtMigrateFaster   ,(ExtMigrateTotal - ExtMigrateFaster) AS MigrateSlower   ,ExtMigrateReadRespTot   ,ExtMigrateWriteRespTot   ,ExtMigrateIOTimeCost   ,ExtMigrateIOTimeBenefit   ,ExtMigrateIOTimeImprove

*/ -----------------------------------------------------------------------------

FROM  dbc.ResUsageSpdsk

Where  TheDate = date --and thetime > '04:00:00'     /*Eliminate false max values DR136322*/

AND  ReadRespMax_ms LT (CentiSecs*10)

AND  WriteRespMax_ms LT (CentiSecs*10)     /*Eliminate devices for other nodes*/

And   (ReadCnt NE 0 and WriteCnt NE 0)

--and   NodeID in ( 108, 109)

--and pdiskglobalid between 10700 and 11000

--AND PDiskType EQ 'SSD'

--and   TheTime GT 120000 and TheTime LT 150000

order   by TheDate,TheTime,NodeID,PDiskGlobalId ;


-------
-- 4) ResUsageSAWT
locking row for access

sel TheDate,

TheTime,

NodeID,

--VprID,

--NodeType,

avg(MailBoxDepth/Active) AvgMailboxDepth,

sum(FlowControlled) NumAmpsInFlowControl,

Sum(FlowCtlCnt) SumFlowCtlCnt,

sum(FlowCtlTime) SumFlowCtlTime,

AVG(WorkTypeInuse00/Active) as AvgWorkNew,

MAX(WorkTypeInuse00/Active) as MaxWorkNew,

Avg(WorkTypeInuse01/Active) as AvgWorkOne,

MAX(WorkTypeInuse01/Active) as MaxWorkOne,

avg(WorkTypeInuse08/Active) as AvgWorkEight,

max(WorkTypeInuse08/Active) as MaxWorkEight,

avg(WorkTypeInuse09/Active) as AvgWorkNine,

max(WorkTypeInuse09/Active) as MaxWorkNine,

Avg(WorkTypeMax00) as AvgWorkNewMax,

max(WorkTypeMax00) as MaxWorkNewMax,

avg(WorkTypeMax01) as AvgWorkOneMax,

max(WorkTypeMax01) as MaxWorkOneMax,

avg(WorkTypeMax08) as AvgWorkEightMax,

max(WorkTypeMax08) as MaxWorkEightMax,

avg(WorkTypeMax09) as AvgWorkNineMax,

max(WorkTypeMax09) as MaxWorkNineMax,

avg(InUseMax) AvgInUseMax,

max(InUseMax) MaxInUseMax

from   dbc.ResUsageSawt

where  thedate between date-30 and date

--and extract(hour from thetime) in ('07', '09')

--and nodeid in ( '0309', '0208', '0408')

group by 1,2,3

  
-----
-- 5) I/O Bandwidth
LOCK ROW FOR ACCESS
 SELECT

TheDate,

TheTime,

extract(hour from TheTime) TheHour,

NodeID,

NodeType,                 /* manually determine SSD/HCRI */

--  case when pdiskglobalid < 24 then 'HCRI' else 'SSD ' end

pdisktype,      sum(ReadKB+WriteKB)/sum(ReadCNT+WriteCNT)/1024 avgblocksizeMB,                 (                 (                 ((SUM(ReadKB/secs )) ) +                 ((SUM(WriteKB/secs)) )                 ) / 1024                 ) as IObandwidth                 ,((SUM(ReadKB/secs )) ) / 1024 as rds

,((SUM(WriteKB/secs)) ) / 1024 as wrts

,(rds / IObandwidth) * 100  as pct_reads

,(wrts / IObandwidth) * 100 as pct_writes

FROM dbc.ResUsageSpdsk

WHERE thedate between date-30 and date

And (ReadCnt NE 0 and WriteCnt NE 0)

GROUP BY 1,2,3,4,5,6

  
-----
-- 6)  LastDone AMP
LOCKING DBC.ResUsageSVPR for access

SELECT         TheDate (FORMAT'yyyy/mm/dd')

--                      ,TheTime (FORMAT'99:99:99')

,Extract(Hour FROM TheTime) as hr

,Extract(Minute FROM TheTime) AS mn

,NodeId

,VprId

,MsgChnLastDone   (NAMED LastDone)

,MsgWorkQLenMax (Named WorkQLenMax)

FROM DBC.ResUsageSVPR

WHERE VprType LIKE 'AM%'

AND                TheDate GE DATE-5

ORDER          BY TheDate,hr,mn,NodeID,VprID ;


-----
-- 7)  Software Event Log Data
locking DBC.SW_Event_Log for access

sel

TheDate

,TheTime

,Event_Tag

,Category

,Severity

,PMA

,Vproc

,Partition

,Task

,TheFunction

,SW_Version

,Line

,substr(Text,1,1000) thetext

from dbc.sw_Event_log

--and thetime > '160000'

where thedate between date-1 and date

--and thetext like '%ADAPTER RESET ISSUED%'

order by thedate, thetime, line
