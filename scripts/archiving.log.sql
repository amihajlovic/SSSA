if exists(select name from sys.procedures where object_id = object_id('archiving.log')) 
	drop procedure archiving.log;
GO

create or alter procedure archiving.log 
	@runId bigint = NULL out,
	@startTs datetime2(2) = NULL,
	@endTs datetime2(2) = NULL,
	@rootTable nvarchar(270) = NULL,
	@referencingTable nvarchar(270) = NULL,
	@rowcount int = NULL,
	@error bit = NULL,
	@message nvarchar(max) = NULL,
	@command nvarchar(max) = NULL
as
	
	if @runId is null
		set @runId = next value for archiving.runIdSeq;

	insert into archiving.RunLog(runId, startTs, endTs, "message", error, "rowcount", "rootTable", "referencingTable", command)
	values(@runId, isnull(@startTs, getdate()), isnull(@endTs, getdate()), @message, @error, @rowcount, @rootTable, @referencingTable, @command);
GO
