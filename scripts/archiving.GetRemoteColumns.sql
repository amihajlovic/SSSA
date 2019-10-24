if exists(select name from sys.procedures where object_id = object_id('archiving.GetRemoteColumns')) 
	drop procedure archiving.GetRemoteColumns;
GO

create proc [archiving].[GetRemoteColumns]
	@serverName nvarchar(128)
	, @databaseName nvarchar(128)
	, @schemaName nvarchar(128)
	, @tableName nvarchar(128)
	, @columnList nvarchar(max) output
	, @dryrun bit = 0
as
set nocount on;
declare @innerSql nvarchar(max) = '
	set @columnList = stuff((
		select 
			'', '' + c.name 
		from 
			sys.columns c 
		where
			c.object_id = object_id(quotename(@schemaName) + ''.'' + quotename(@tableName))
		for xml path('''')), 1, 2, '''');'

declare @sql nvarchar(max) = '
	execute ' + quotename(@serverName) + '.' + quotename(@databaseName) + '.dbo.sp_executesql @innerSql
		, N''@schemaName nvarchar(128)
			, @tableName nvarchar(128)
			, @columnList nvarchar(max) output''
		, @schemaName = @schemaName
		, @tableName = @tableName
		, @columnList =  @columnList out';


if @dryrun = 1 
begin
	print @innerSql
	print @sql
end
exec sp_executesql @sql
	, N'  @innerSql nvarchar(max)
		, @schemaName nvarchar(128)
		, @tableName nvarchar(128)
		, @columnList nvarchar(max) output'
	, @innerSql = @innerSql
	, @schemaName = @schemaName
	, @tableName = @tableName
	, @columnList = @columnList out;
GO

