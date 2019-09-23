if exists(select name from sys.procedures where object_id = object_id('archiving.GetRemoteDependencies')) 
	drop procedure archiving.GetRemoteDependencies;
GO

create proc archiving.GetRemoteDependencies
	  @serverName	nvarchar(128)
	, @databaseName nvarchar(128)
	, @schemaName	nvarchar(128)
	, @tableName	nvarchar(128)
    , @FilterClause  nvarchar(max)
	, @dryRun bit = 0
AS

declare @RootTableEx nvarchar(1000) = concat(quotename(@schemaName), '.', quotename(@tableName))

declare @innerSql nvarchar(max) = '

with base as (
    select
		fk.name as ForeignKey
		, ots.name BaseTabSchema
		, OnTable.name BaseTabName
        , quotename(ots.name) + ''.'' + quotename(OnTable.name) as BaseTabEx
        , BaseTabCol.name as BaseTabCol
        , ats.name as ParentTabSchema        
		, ParentTab.name as ParentTabName
        , quotename(ats.name) + ''.'' + quotename(ParentTab.name) as ParentTabEx
        , ParentTabCol.name as ParentTabCol      
    from 
        sys.foreign_keys fk
        join sys.foreign_key_columns fkcols
            on fk.object_id = fkcols.constraint_object_id
        join sys.objects OnTable
            on fk.parent_object_id = OnTable.object_id
        join sys.schemas ots
            on OnTable.schema_id = ots.schema_id
        join sys.objects ParentTab
            on fk.referenced_object_id = ParentTab.object_id
        join sys.schemas ats
            on ParentTab.schema_id = ats.schema_id
        join sys.columns BaseTabCol
            on fkcols.parent_column_id = BaseTabCol.column_id
            and fkcols.parent_object_id = BaseTabCol.object_id
        join sys.columns ParentTabCol
            on fkcols.referenced_column_id = ParentTabCol.column_id
            and fkcols.referenced_object_id = ParentTabCol.object_id
    where 1=1
        AND ParentTab.TYPE = ''U''
        AND OnTable.TYPE = ''U''
        AND OnTable.name not like ''sys%''
        AND OnTable.Name <> ParentTab.Name
    )
,recursioned as (
    select
		  BaseTabSchema
		, BaseTabName
        , BaseTabEx 
		, ParentTabSchema
		, ParentTabName
        , 1 as Lvl
        , CONVERT(nvarchar(4000), '' where '' + @FilterClause) as WhereClause    
        , CONVERT(nvarchar(1000), null) as ParentTabEx    
    from
        base
    where 1=1
        and BaseTabEx = @RootTableEx
    union all 
	select
          d.BaseTabSchema
		, d.BaseTabName
        , d.BaseTabEx 
		, d.ParentTabSchema
		, d.ParentTabName
        , r.Lvl + 1 as Lvl
        , CONVERT(nvarchar(4000), 
                            case r.Lvl when 1 then
                                '' where ['' + BaseTabCol + ''] '' + @FilterClause
                            else
                                '' where ['' + BaseTabCol + ''] in (select ['' + ParentTabCol + ''] from '' + d.ParentTabEx + '' '' + r.WhereClause + '')''
                            end
                            ) WhereClause    
        , CONVERT(nvarchar(1000), d.ParentTabEx) as ParentTabEx 
    from 
        base d
        join recursioned r
            on d.ParentTabEx = r.BaseTabEx
)
select 
        max(Lvl) as Lvl   		
	, BaseTabSchema
	, BaseTabName
    , BaseTabEx 

	, ParentTabSchema
	, ParentTabName
    , ParentTabEx
    , WhereClause        
from 
    recursioned
group by        
	  BaseTabSchema
	, BaseTabName
    , BaseTabEx 
	, ParentTabSchema
	, ParentTabName
    , ParentTabEx
    , WhereClause        
order by lvl desc
'




declare @sql nvarchar(max) = '
	execute ' + quotename(@serverName) + '.' + quotename(@databaseName) + '.dbo.sp_executesql
		  @innersql
		, N'' @RootTableEx  nvarchar(1000)
			, @FilterClause  nvarchar(max)''
		, @RootTableEx = @RootTableEx
		, @FilterClause = @FilterClause'

if @dryRun = 1
begin
	print @innerSql
	print @sql
end

exec sp_executesql 
	@sql
	, N' @RootTableEx  nvarchar(1000)
		, @FilterClause  nvarchar(1000)
		, @innerSql nvarchar(max) '
	, @innerSql = @innerSql
	, @RootTableEx = @RootTableEx
	, @FilterClause = @FilterClause
go