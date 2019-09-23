if exists(select name from sys.procedures where object_id = object_id('archiving.CompareTableDefinitions')) 
	drop procedure archiving.GetRemoteColumns;
GO

create proc archiving.CompareTableDefinitions
	@serverName nvarchar(128)
	, @databaseName nvarchar(128)
	, @schemaName nvarchar(128)
	, @tableName nvarchar(128)
	, @dryrun bit = 0
AS
	set nocount on;
	DECLARE @innerSql nvarchar(max)
	DECLARE @sql nvarchar(max)

	set @innerSql = '
		SELECT
			c.name AS ColumnName
			, t.name ColumnType				
			, c.precision ColumnPrecision
			, c.scale ColumnScale
			, c.max_length ColumnMaxLength
			, CASE WHEN t.name IN (''varbinary'', ''varchar'', ''binary'', ''char'')
					THEN CONCAT(t.name, ''('', IIF(c.max_length = -1, ''max'', CAST(c.max_length AS NVARCHAR(10))), '')'')
					WHEN t.name IN (''nvarchar'', ''nchar'') THEN CONCAT(t.name, ''('', IIF(c.max_length = -1, ''max'', CAST(c.max_length / 2 AS NVARCHAR(10))), '')'')
					WHEN t.name IN (''decimal'', ''numeric'') THEN CONCAT(t.name, ''('', c.[precision], '', '', c.[scale], '')'')
					WHEN t.name = ''datetime2'' THEN CONCAT(t.name, ''('', c.[scale], '')'')
					ELSE t.name
			END AS ColumnTypeEx
			, c.[is_nullable] Nullable
			, c.[column_id]
		FROM
			sys.[columns] AS [c]
			JOIN (
					SELECT
						name
						, object_id
						, [schema_id]
					FROM
						sys.[tables]
					UNION ALL
					SELECT
						name
						, object_id
						, [schema_id]
					FROM
						sys.[views]
					) AS [t2]
				ON [t2].[object_id] = [c].[object_id]
			JOIN sys.[schemas] AS [s]
				ON [s].[schema_id] = [t2].[schema_id]
			JOIN sys.[types] AS [t]
				ON [t].[user_type_id] = [c].[user_type_id]
		WHERE
			t2.name = @tableName
			AND s.name = @schemaName
		'
		

	set @sql = concat('exec ', quotename(@serverName), '.', quotename(@databaseName),'.dbo.sp_executesql 
		@innerSql
		, N''@schemaName NVARCHAR(128), @tableName NVARCHAR(128)''
		, @tableName = @tableName
		, @schemaName = @schemaName
	');

	if object_id('tempdb..#remoteDefinition') is not null
		drop table #remoteDefinition;
	create table #remoteDefinition (
		ColumnName nvarchar(128) not null, 
		ColumnType nvarchar(128) not null, 
		ColumnPrecision int not null, 
		ColumnScale int not null, 
		ColumnMaxLength int not null, 
		ColumnTypeEx nvarchar(1000) not null,
		Nullable   bit not null,
		Column_id  int not null
	);
	

	if @dryrun = 1
	begin
		print @innerSql
		print @sql
	end

	insert into #remoteDefinition (ColumnName, ColumnType, ColumnPrecision, ColumnScale, ColumnMaxLength, ColumnTypeEx, Nullable, Column_id)
	exec sp_executesql 
		@sql
		, N'@innerSql nvarchar(max), @schemaName NVARCHAR(128), @tableName NVARCHAR(128)'
		, @innerSql = @innerSql
		, @tableName = @tableName
		, @schemaName = @schemaName;


	if object_id (quotename(@schemaName) + '.' + quotename(@tableName)) is null
	begin
		set @sql = concat('
			CREATE TABLE ', quotename(@schemaName) + '.' + quotename(@tableName), ' (
				', (
				SELECT 
					stuff((
						select top 20
							', ' + rd.ColumnName + ' ' + rd.ColumnTypeEx + ' NULL ' + char(10)
						from 
							#remoteDefinition rd
						order by 
							rd.Column_id
						for xml path('')), 1, 2, '')
				), '
			);		
		')
		
		if @dryrun = 1	
			print @sql		
		else		
			exec sp_executesql @sql
	end


	if object_id('tempdb..#localDefinition') is not null
		drop table #localDefinition;
	create table #localDefinition (
		ColumnName nvarchar(128) not null, 
		ColumnType nvarchar(128) not null, 
		ColumnPrecision int not null, 
		ColumnScale int not null, 
		ColumnMaxLength int not null, 
		ColumnTypeEx nvarchar(1000) not null,
		Nullable   bit not null,
		Column_id  int not null
	);
	insert into #localDefinition (ColumnName, ColumnType, ColumnPrecision, ColumnScale, ColumnMaxLength, ColumnTypeEx, Nullable, Column_id)
	SELECT
		c.name AS ColumnName
		, t.name ColumnType				
		, c.precision ColumnPrecision
		, c.scale ColumnScale
		, c.max_length ColumnMaxLength
		, CASE WHEN t.name IN ('varbinary', 'varchar', 'binary', 'char')
				THEN CONCAT(t.name, '(', IIF(c.max_length = -1, 'max', CAST(c.max_length AS NVARCHAR(10))), ')')
				WHEN t.name IN ('nvarchar', 'nchar') THEN CONCAT(t.name, '(', IIF(c.max_length = -1, 'max', CAST(c.max_length / 2 AS NVARCHAR(10))), ')')
				WHEN t.name IN ('decimal', 'numeric') THEN CONCAT(t.name, '(', c.[precision], ', ', c.[scale], ')')
				WHEN t.name = 'datetime2' THEN CONCAT(t.name, '(', c.[scale], ')')
				ELSE t.name
		END AS ColumnType
		, c.[is_nullable] Nullable
		, c.[column_id]
	FROM
		sys.[columns] AS [c]
		JOIN (
				SELECT
					name
					, object_id
					, [schema_id]
				FROM
					sys.[tables]
				UNION ALL
				SELECT
					name
					, object_id
					, [schema_id]
				FROM
					sys.[views]
				) AS [t2]
			ON [t2].[object_id] = [c].[object_id]
		JOIN sys.[schemas] AS [s]
			ON [s].[schema_id] = [t2].[schema_id]
		JOIN sys.[types] AS [t]
			ON [t].[user_type_id] = [c].[user_type_id]
	WHERE
		t2.name = @tableName
		AND s.name = @schemaName;



/*****ADD COLUMNS*****/
DECLARE @addColumnsSql nvarchar(max) = 
		(
			select 
				'ALTER TABLE ' + quotename(@schemaName) + '.' + quotename(@tableName) + ' ADD ' + rd.ColumnName + ' ' + rd.ColumnTypeEx + ' NULL;' + char(10)
			from 
				#remoteDefinition rd
				full outer join #localDefinition ld
					on rd.ColumnName = ld.ColumnName
			where 
				ld.ColumnName is null
			for xml path('')
		);

/***** ALTER COLUMNS *****/

--same type, remote larger
DECLARE @alterColumnSizeSql nvarchar(max) =  
		(
			select 
				'ALTER TABLE ' + quotename(@schemaName) + '.' + quotename(@tableName) + ' ALTER COLUMN ' + rd.ColumnName + ' ' + rd.ColumnTypeEx + ' NULL;' + char(10)
			from 
				#remoteDefinition rd
				join #localDefinition ld
					on rd.ColumnName = ld.ColumnName
			where 
				ld.ColumnType = rd.ColumnType
				AND (
						ld.ColumnMaxLength < rd.ColumnMaxLength
						OR ld.ColumnPrecision < rd.ColumnPrecision
						OR ld.ColumnScale < rd.ColumnScale
					)
			for xml path('')
		);

		
DECLARE @changeDataTypeColumnsSql nvarchar(max) = 	 
		(			
			select 
				'RAISERROR(''Data type changed. Automatic alter not implemented.'', 16, 16);' + char(10)
			from 
				#remoteDefinition rd
				join #localDefinition ld
					on rd.ColumnName = ld.ColumnName
			where 
				ld.ColumnType <> rd.ColumnType
			for xml path('')
		);
		
/***** DROP COLUMNS *****/
/***** COLUMNS ARE NEVER DROPPED. NULLABLE COLUMNS REMAIN AS IS. NOT NULLABLE COLUMNS ARE ALTERED TO BE NULLABLE *****/
DECLARE @nullDropedColumnsSql nvarchar(max) = 
		(
			select 
				'ALTER TABLE ' + quotename(@schemaName) + '.' + quotename(@tableName) + ' ALTER COLUMN ' + ld.ColumnName + ' ' + ld.ColumnTypeEx + ' NULL;' + char(10)
			from 
				#remoteDefinition rd
				full outer join #localDefinition ld
					on rd.ColumnName = ld.ColumnName
			where 
				rd.ColumnName is null
			for xml path('')
		);

	if @dryrun = 1
	begin
		print @addColumnsSql
		print @alterColumnSizeSql
		print @changeDataTypeColumnsSql
		print @nullDropedColumnsSql
	end
	else
	begin
		exec sp_executesql @addColumnsSql
		exec sp_executesql @alterColumnSizeSql
		exec sp_executesql @changeDataTypeColumnsSql
		exec sp_executesql @nullDropedColumnsSql
	end
GO
