if exists(select name from sys.procedures where object_id = object_id('archiving.ArchiveTable')) 
	drop procedure archiving.ArchiveTable;
GO

CREATE procedure [archiving].[ArchiveTable]
	@serverName nvarchar(128),
	@databaseName nvarchar(128),
	@schemaName nvarchar(128),
	@tableName nvarchar(128),
	@filterClause nvarchar(max),
	@expectedRc int,
	@runId bigint out,
	@dryRun bit = null out
as
begin try
	set nocount on;
	declare @procStartTs datetime2(2) = getdate();
	declare @rc int = 0;
	declare @totalRc int = 0;

	declare @RootTableEx  nvarchar(1000) = concat(quotename(@schemaName), '.', quotename(@tableName))
	
	if object_id ('tempdb..#toArchive') is not null
		drop table #toArchive;

	create table #toArchive (
		Lvl int not null,

		BaseTabSchema nvarchar(128) not null,
		BaseTabName nvarchar(128) not null,
		BaseTabEx nvarchar(1000) not null,
		
		ParentTabSchema nvarchar(128) null,
		ParentTabName nvarchar(128) null,
		ParentTabEx nvarchar(1000)  null,

		WhereClause nvarchar(max) not null
	);
	create clustered index cidx on #toArchive (lvl);
		
	insert into #toArchive (Lvl, BaseTabSchema, BaseTabName, BaseTabEx, ParentTabSchema, ParentTabName, ParentTabEx, WhereClause)
	exec archiving.getRemoteDependencies
		  @serverName	= @serverName
		, @databaseName = @databaseName
		, @schemaName = @schemaName
		, @tableName = @tableName
		, @FilterClause = @filterClause
		, @dryRun = @dryRun

	declare 
		  @Lvl int
		, @BaseTabSchema nvarchar(128)
		, @BaseTabName   nvarchar(128)
		, @BaseTabEx nvarchar(1000)
		, @WhereClause nvarchar(max)
		, @columnList nvarchar(max) 

	declare @sql nvarchar(max)
	declare @innerSql nvarchar(max)
	
	begin transaction;
	DECLARE tabs CURSOR FOR 
			SELECT DISTINCT 
				lvl
				, BaseTabSchema
				, BaseTabName
				, BaseTabEx
				, WhereClause
			FROM 
				#toArchive
			ORDER BY lvl desc
	open tabs
	while 1=1
	begin
		fetch next from tabs into @lvl, @basetabschema, @basetabname, @basetabex, @whereclause
		if @@rowcount = 0 
			break;

		declare @tabStartTs datetime2(2) = getdate();

		exec archiving.CompareTableDefinitions @serverName = @serverName, @databaseName = @databaseName, @schemaName = @BaseTabSchema, @tableName = @BaseTabName, @dryrun = @dryrun;
		exec archiving.GetRemoteColumns @serverName = @serverName, @databaseName = @databaseName, @schemaName = @BaseTabSchema, @tableName = @BaseTabName, @columnList = @columnList out, @dryrun = @dryrun;

		set @innerSql = concat('
			SELECT ', @columnList, ' FROM ', @BaseTabEx, ' with(updlock) ', @whereClause, ';
			DELETE FROM ', @BaseTabEx, ' ', @whereClause, ';');
		set @sql = concat('
		insert into ', @BaseTabEx, '(', @columnList, ')
		exec ', quotename(@serverName), '.', quotename(@databaseName),'.dbo.sp_executesql @innerSql
		');

		if @dryrun = 1
		begin
			print @innerSql
			print @sql
		end
		else
		begin
			exec sp_executesql @sql, N'@innerSql nvarchar(max)', @innerSql = @innerSql;
			set @rc = @@ROWCOUNT;
			set @totalRc += @rc;

			exec archiving.log 
					@runId = @runId out,
					@startTs = @tabStartTs,
					@rootTable = @RootTableEx,
					@referencingTable = @BaseTabEx,
					@rowcount = @rc,
					@message = 'Delete - Insert';


			if @Lvl = 1 AND @rc <> @expectedRc
				raiserror('Expected count not equal to archived rc. Rolling back.', 16, 16);
		end

	end
	close tabs;
	deallocate tabs;
	exec archiving.log 
			@runId = @runId out,
			@startTs = @procStartTs,
			@rootTable = @RootTableEx,
			@rowcount = @totalRc,
			@message = 'Root table done';

	commit;
end try
begin catch
	declare @errorMessage nvarchar(max) = error_message();
	if @@TRANCOUNT > 0
		rollback;
	exec archiving.log 
					@runId = @runId out,
					@startTs = @procStartTs,
					@rootTable = @RootTableEx,
					@referencingTable = @BaseTabEx,
					@rowcount = @rc,
					@error = 1,
					@message = @errorMessage,
					@command = @innerSql;
	throw;
end catch
GO