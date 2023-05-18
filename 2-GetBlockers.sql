

IF OBJECT_ID('tempdb..#Blocks') IS NOT NULL DROP TABLE #Blocks

SELECT spid,blocked,REPLACE(REPLACE(st.TEXT, CHAR(10),' '),CHAR(13),' ') batch 
INTO #Blocks
FROM sys.sysprocesses spr CROSS APPLY sys.dm_exec_sql_text(spr.SQL_HANDLE) st


;WITH BlockingTree(spid,blocking_spid,[level],batch)
AS 
	(SELECT blc.spid,blc.blocked,CAST(REPLICATE('0', 4-LEN(CAST (blc.spid AS VARCHAR)))+CAST(blc.spid AS VARCHAR) AS VARCHAR(1000)) [level],
	blc.batch
FROM #Blocks blc 
WHERE (blc.blocked = 0 OR blc.blocked = SPID) 
	AND EXISTS (SELECT * FROM #Blocks blc2 WHERE blc2.BLOCKED = blc.SPID AND blc2.BLOCKED <> blc2.SPID)

UNION ALL

SELECT blc.spid,blc.blocked,CAST(bt.[level] + RIGHT (CAST ((1000 + blc.SPID) AS VARCHAR (100)), 4) AS VARCHAR (1000)) [level],
	blc.batch
FROM #Blocks blc 
	INNER JOIN BlockingTree bt ON blc.blocked = bt.SPID 
WHERE blc.blocked > 0 AND blc.blocked <> blc.SPID)

	SELECT 
		DB_NAME(spr.dbid) [Database],
		N'' + ISNULL(REPLICATE (N'| ',LEN(LEVEL)/4-2),'') + CASE WHEN (LEN(LEVEL)/4-1)=0 THEN '' ELSE '|------ ' END
		+ CAST(bt.SPID AS NVARCHAR (10)) [BlockingTree],
		spr.lastwaittype [WaitType],
		spr.loginame [Login],
		st.[text] [SQL],
		spr.cmd [Command], 
		CASE WHEN ISNULL(spr.waitresource,' ') = ' ' THEN spr.waitresource ELSE dbo.[GetResourceName](spr.waitresource, default) END [WaitResource],
	spr.program_name [Program],spr.hostname [ComesFrom],spr.last_batch [LastBatchTime]
	FROM BlockingTree bt 
		LEFT OUTER JOIN sys.sysprocesses spr ON spr.spid = bt.spid
		CROSS APPLY sys.dm_exec_sql_text(spr.SQL_HANDLE) st 
	ORDER BY LEVEL
