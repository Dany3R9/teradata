-- General Space consumption queries - Teradata

-- Total Space in the system
SELECT SUM(MaxPerm) FROM DBC.DiskSpaceV;

----
-- Disk Space currently used

SELECT SUM(CurrentPerm),
SUM(MaxPerm),
((SUM(currentperm) / NULLIFZERO(SUM(maxperm)) * 100))
(TITLE '%MaxPerm', FORMAT 'zz9.99')
FROM DBC.DiskSpaceV;

---
--Disk Space for a given DB

SELECT sum(maxperm)
FROM DBC.DiskSpaceV WHERE databasename='xxxx';

-----
--Space available for Spool

SELECT (((SUM(MaxPerm) - SUM(CurrentPerm)) /
NULLIFZERO(SUM(MaxPerm))) * 100)
(TITLE'% Avail for Spool', format'zz9.99')
FROM DBC.DiskSpaceV;

---
--Used space per DB

SELECT Databasename (format 'X(12)')
,SUM(maxperm)
,SUM(currentperm)
,((SUM(currentperm))/
NULLIFZERO (SUM(maxperm)) * 100)
(FORMAT 'zz9.99%', TITLE 'Percent // Used')
FROM DBC.DiskSpaceV
GROUP BY 1
ORDER BY 4 DESC
WITH SUM (currentperm), SUM(maxperm);
