CREATE OR ALTER PROCEDURE dbo.AddAllTablesToPublication
	@publicationName nvarchar(128) = 'ArchivePub'
AS 

EXEC sp_changepublication
	@publication = @publicationName,
	@property = N'allow_anonymous',
	@value = 'FALSE';

EXEC sp_changepublication
	@publication = @publicationName,
	@property = N'immediate_sync',
	@value = 'FALSE';

EXEC sp_changepublication
	@publication = @publicationName,
	@property = N'replicate_ddl',
	@value = '0';



with base as (
    select
		fk.name as ForeignKey
		, ots.name BaseTabSchema
		, OnTable.name BaseTabName
        , quotename(ots.name) + '.' + quotename(OnTable.name) as BaseTabEx
        , BaseTabCol.name as BaseTabCol
        , ats.name as ParentTabSchema        
		, ParentTab.name as ParentTabName
        , quotename(ats.name) + '.' + quotename(ParentTab.name) as ParentTabEx
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
        AND ParentTab.TYPE = 'U'
        AND OnTable.TYPE = 'U'
        AND OnTable.name not like 'sys%'
        AND OnTable.Name <> ParentTab.Name
    )
,recursioned as (
    select
		DISTINCT
		  BaseTabSchema
		, BaseTabName
        , BaseTabEx 
		, cast(NULL as sysname) ParentTabSchema
		, cast(NULL as sysname) ParentTabName
        , 1 as Lvl
        , CONVERT(nvarchar(1000), null) as ParentTabEx    
    from
        base
    where 1=1
        and BaseTabEx in('[dbo].[razgovori]', '[dbo].[velike_rezervacije]', '[dbo].[dokumenti]') 
    union all 
	select
          d.BaseTabSchema
		, d.BaseTabName
        , d.BaseTabEx 
		, d.ParentTabSchema
		, d.ParentTabName
        , r.Lvl + 1 as Lvl

        , CONVERT(nvarchar(1000), d.ParentTabEx) as ParentTabEx 
    from 
        base d
        join recursioned r
            on d.ParentTabEx = r.BaseTabEx
)
select 
      BaseTabSchema as TableSchema
	, BaseTabName as TableName
into 
	#ignoreTabs
from 
    recursioned
group by        
	  BaseTabSchema
	, BaseTabName;



DECLARE @sql NVARCHAR(max)
select 
	@sql = string_agg(concat(cast('' as nvarchar(max)), '
		exec sp_addarticle 
			@publication = @publicationName,
			@article = ''', tab.name, ''',
			@source_owner = ''', schema_name(tab.schema_id), ''',
			@source_object = ''', tab.[name], ''''), CHAR(10))
from sys.tables tab
    join sys.indexes pk
        on tab.object_id = pk.object_id 
		AND pk.is_primary_key = 1
	
	left join 
	(sysarticles a		
	join syspublications pub
		on a.pubid = pub.pubid
			AND pub.name = @publicationName)
			on a.objid = tab.object_id
	left join #ignoreTabs it
		on tab.name = it.TableName
			AND schema_name(tab.schema_id) = it.TableSchema
where
	a.artid is null
	AND it.TableName IS NULL;

EXEC sp_executesql @sql, N'@publicationName nvarchar(128)', @publicationName = @publicationName;
	


EXEC sp_refreshsubscriptions @publication = @publicationName;
EXEC sp_startpublication_snapshot @publication = @publicationName;
