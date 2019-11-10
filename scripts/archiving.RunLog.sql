IF object_id('archiving.RunIdSeq') IS NULL
	create sequence archiving.RunIdSeq start with 0;


IF object_id('archiving.RunLog') IS NULL
BEGIN
	create table archiving.RunLog (
		id		bigint not null identity(1,1) primary key,
		runId	bigint not null,
		startTs datetime2(2) not null,
		endTs	datetime2(2) null,
		"rootTable"		nvarchar(270) null,
		"referencingTable" nvarchar(270) null, 
		"rowcount" int null,
		error	bit null,
		"message" nvarchar(max) null,
		"command"	nvarchar(max) null
	);
END
GO