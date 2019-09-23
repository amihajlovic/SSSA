IF NOT EXISTS (SELECT  schema_name FROM    information_schema.schemata WHERE   schema_name = 'archiving' ) 
	EXEC sp_executesql N'CREATE SCHEMA archiving';
GO