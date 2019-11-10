if exists(select name from sys.procedures where object_id = object_id('archiving.run')) 
	drop procedure archiving.run;
GO

create procedure archiving.run
	@serverName nvarchar(128) = @@servername
	, @databaseName nvarchar(128) = 'base'
	, @runId bigint = null out
AS 
set nocount on;
declare @procStartTs datetime2(2) = getdate()
declare @prepareStartTs datetime2(2) = getdate()

declare @innerSql nvarchar(max) = '
if OBJECT_ID (''CustomConfigurations'') is not null 
	drop table CustomConfigurations;
if OBJECT_ID (''tempdb.dbo.BookingIDsForArchival'') is not null 
	drop table tempdb.dbo.BookingIDsForArchival;
if OBJECT_ID (''tempdb.dbo.DocumentIDsForArchival'') is not null 
	drop table tempdb.dbo.DocumentIDsForArchival;
if OBJECT_ID (''tempdb.dbo.StandaloneConversationIDs'') is not null 
	drop table tempdb.dbo.StandaloneConversationIDs;
if OBJECT_ID (''tempdb.dbo.StandaloneCustomerConversations'') is not null 
	drop table tempdb.dbo.StandaloneCustomerConversations;
if OBJECT_ID (''tempdb.dbo.StandaloneSupplierConversations'') is not null 
	drop table tempdb.dbo.StandaloneSupplierConversations;
if OBJECT_ID (''tempdb.dbo.StandalonePassengerConversations'') is not null 
	drop table tempdb.dbo.StandalonePassengerConversations;
if OBJECT_ID (''tempdb.dbo.ConversationsIDsForArchival'') is not null 
	drop table tempdb.dbo.ConversationsIDsForArchival;


DECLARE @IsTestMode nvarchar(5);

DECLARE @BookingArchivalMonths INT = 0;
DECLARE @BookingDeletionMonths INT = 0;

DECLARE @StandaloneDocumentArchivalMonths INT = 0;

DECLARE @StandaloneSupplierEmailsArchivalMonths INT = 0;

DECLARE @StandaloneCustomerEmailsArchivalMonths INT = 0;

DECLARE @StandalonePassengerEmailsArchivalMonths INT = 0;

SET @IsTestMode =
(SELECT 
	CASE 
		WHEN oscc.KeyValue = ''False'' THEN ''%%''
		WHEN oscc.KeyValue = ''True''	THEN ''Test%''
	END
FROM dbo.OtherSystemCustomConfiguration oscc
WHERE oscc.KeyName = ''TestMode'' AND oscc.OtherSystemID = 1100000);

SELECT 
	oscc.KeyName,
	oscc.KeyValue
INTO CustomConfigurations
FROM dbo.OtherSystemCustomConfiguration oscc
WHERE othersystemID = 1100000
	AND oscc.KeyName LIKE @IsTestMode
	AND oscc.KeyValue != ''0''
	AND oscc.KeyName NOT LIKE ''%test%'';

SET @BookingArchivalMonths =
(SELECT KeyValue 
	FROM dbo.CustomConfigurations cc
	WHERE cc.KeyName LIKE ''%Booking archival age in months%'');

SET @StandaloneDocumentArchivalMonths =
(SELECT KeyValue 
	FROM dbo.CustomConfigurations cc
	WHERE cc.KeyName LIKE ''%Document archive age in months%'');

SET @StandaloneCustomerEmailsArchivalMonths =
(SELECT KeyValue 
	FROM dbo.CustomConfigurations cc
	WHERE cc.KeyName LIKE ''%Customer mail archive age in months%'');

SET @StandalonePassengerEmailsArchivalMonths =
(SELECT KeyValue 
	FROM dbo.CustomConfigurations cc
	WHERE cc.KeyName LIKE ''%Passenger mail archive age in months%'');

SET @StandaloneSupplierEmailsArchivalMonths =
(SELECT KeyValue 
	FROM dbo.CustomConfigurations cc
	WHERE cc.KeyName LIKE ''%Supplier mail archive age in months%'');

--Booking IDs for archival
SELECT 
	vr.sifra_velika_rezervacija
INTO tempdb.dbo.BookingIDsForArchival
FROM velike_rezervacije vr
WHERE 
	vr.datum_velika_rezervacija < DATEADD(month, (@BookingArchivalMonths * -1), GETDATE());


--Document IDs for archival
SELECT 
	d.sifra_dokument
INTO tempdb.dbo.DocumentIDsForArchival
FROM dokumenti d
WHERE 
	d.DocumentCreationTimeUTC < DATEADD(month, (@StandaloneDocumentArchivalMonths * -1), GETDATE())
	AND d.sifra_dokument NOT IN 
		(SELECT d.sifra_dokument 
		FROM dbo.dokumenti d 
		WHERE d.sifra_dokument NOT IN 
			(SELECT 
				vrd.sifra_dokument 
			FROM dbo.velike_rezervacije_dokumenti vrd)
		);

--Standalone conversations
SELECT 
	r.sifra_razgovor
INTO tempdb.dbo.StandaloneConversationIDs
FROM dbo.razgovori r
WHERE r.sifra_zadatak NOT IN 
	(SELECT z.sifra_zadatak
	FROM dbo.zadatci z
	WHERE z.sifra_zadatak NOT IN 
		(SELECT 
			vrz.sifra_zadatak 
			FROM dbo.velike_rezervacije_zadatci vrz));

--Standalone conversations for customers and customers/suppliers
SELECT 
	rk.sifra_razgovor
INTO tempdb.dbo.StandaloneCustomerConversations
FROM dbo.razgovori_kupci rk
	JOIN dbo.kupci k ON rk.sifra_kupci = k.id
	JOIN dbo.tvrtka t ON k.sifra_tvrtka = t.sifra_tvrtka
WHERE rk.sifra_razgovor IN 
	(SELECT 
		* 
		FROM tempdb.dbo.StandaloneConversationIDs)
	AND t.tvrtka_vrsta IN (1,3);

--Standalone conversations for suppliers
SELECT 
	rk.sifra_razgovor
INTO tempdb.dbo.StandaloneSupplierConversations
FROM dbo.razgovori_kupci rk
	JOIN dbo.kupci k ON rk.sifra_kupci = k.id
	JOIN dbo.tvrtka t ON k.sifra_tvrtka = t.sifra_tvrtka
WHERE rk.sifra_razgovor IN 
	(SELECT 
		* 
		FROM tempdb.dbo.StandaloneConversationIDs)
	AND t.tvrtka_vrsta IN (2);

--Standalone conversations for passengers
SELECT 
	r.sifra_razgovor
INTO tempdb.dbo.StandalonePassengerConversations
FROM dbo.razgovori r
WHERE r.sifra_razgovor IN 
	(SELECT 
		* 
		FROM tempdb.dbo.StandaloneConversationIDs)
	AND r.sifra_razgovor NOT IN 
		(SELECT 
			* 
			FROM tempdb.dbo.StandaloneSupplierConversations)
	AND r.sifra_razgovor NOT IN 
		(SELECT 
			* 
			FROM tempdb.dbo.StandaloneCustomerConversations);

SELECT *
INTO tempdb.dbo.ConversationsIDsForArchival
FROM (
	SELECT * FROM tempdb.dbo.StandaloneCustomerConversations --razgovori
	UNION 
	SELECT * FROM tempdb.dbo.StandaloneSupplierConversations --razgovori
	UNION
	SELECT * FROM tempdb.dbo.StandalonePassengerConversations --razgovori
) r;

'
declare @sql nvarchar(max) = CONCAT(N'exec ', quotename(@serverName), '.', quotename(@databaseName), '.dbo.sp_executesql @innerSql');
exec sp_executesql @sql, N'@innerSql nvarchar(max)', @innerSql = @innerSql;

declare @rc int;
set @sql = CONCAT(N'exec ', quotename(@serverName), '.', quotename(@databaseName), '.dbo.sp_executesql @innerSql, N''@rc int out'', @rc = @rc out; ');

set @innerSql = N'SELECT @rc = count(1) FROM tempdb.dbo.BookingIDsForArchival;'
exec sp_executesql @sql, N'@innerSql nvarchar(max), @rc int out', @innerSql = @innerSql, @rc = @rc out;
declare @bookingRc int = @rc;

set @innerSql = N'SELECT @rc = count(1) FROM tempdb.dbo.DocumentIDsForArchival;'
exec sp_executesql @sql, N'@innerSql nvarchar(max), @rc int out', @innerSql = @innerSql, @rc = @rc out;
declare @documentRc int = @rc;

set @innerSql = N'SELECT @rc = count(1) FROM tempdb.dbo.ConversationsIDsForArchival;'
exec sp_executesql @sql, N'@innerSql nvarchar(max), @rc int out', @innerSql = @innerSql, @rc = @rc out;
declare @conversationRc int = @rc;

exec archiving.log 
				@runId = @runId out,
				@startTs = @prepareStartTs,
				@rowcount = @rc,
				@message = N'Prepare IDs'



exec archiving.ArchiveTable 
	  @serverName = @serverName
	, @databaseName = @databaseName
	, @schemaName = 'dbo'
	, @tableName = 'razgovori'
	, @filterClause = N'sifra_razgovor IN (SELECT * FROM tempdb.dbo.ConversationsIDsForArchival)'
	, @expectedRc = @conversationRc
	, @runId = @runId out;

exec archiving.ArchiveTable 
	  @serverName = @serverName
	, @databaseName = @databaseName
	, @schemaName = 'dbo'
	, @tableName = 'dokumenti'
	, @filterClause = N'sifra_dokument IN (SELECT * FROM tempdb.dbo.DocumentIDsForArchival)'
	, @expectedRc = @documentRc
	, @runId = @runId out;

exec archiving.ArchiveTable 
	  @serverName = @serverName
	, @databaseName = @databaseName
	, @schemaName = 'dbo'
	, @tableName = 'velike_rezervacije'
	, @filterClause = N'sifra_velika_rezervacija IN (SELECT * FROM tempdb.dbo.BookingIDsForArchival)'
	, @expectedRc = @bookingRc
	, @runId = @runId out;

exec archiving.log 
				@runId = @runId out,
				@startTs = @prepareStartTs,
				@rowcount = @rc,
				@message = N'Archiving complete'

go