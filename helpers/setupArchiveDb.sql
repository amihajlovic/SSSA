SET NOCOUNT ON
DECLARE @table TABLE(
RowId INT PRIMARY KEY IDENTITY(1, 1),
ForeignKeyConstraintName NVARCHAR(200),
ForeignKeyConstraintTableSchema NVARCHAR(200),
ForeignKeyConstraintTableName NVARCHAR(200),
ForeignKeyConstraintColumnName NVARCHAR(200),
PrimaryKeyConstraintName NVARCHAR(200),
PrimaryKeyConstraintTableSchema NVARCHAR(200),
PrimaryKeyConstraintTableName NVARCHAR(200),
PrimaryKeyConstraintColumnName NVARCHAR(200)
)
INSERT INTO @table(ForeignKeyConstraintName, ForeignKeyConstraintTableSchema, ForeignKeyConstraintTableName, ForeignKeyConstraintColumnName)
SELECT
U.CONSTRAINT_NAME,
U.TABLE_SCHEMA,
U.TABLE_NAME,
U.COLUMN_NAME
FROM
INFORMATION_SCHEMA.KEY_COLUMN_USAGE U
INNER JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS C
ON U.CONSTRAINT_NAME = C.CONSTRAINT_NAME
WHERE
C.CONSTRAINT_TYPE = 'FOREIGN KEY'
UPDATE @table SET
PrimaryKeyConstraintName = UNIQUE_CONSTRAINT_NAME
FROM
@table T
INNER JOIN INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS R
ON T.ForeignKeyConstraintName = R.CONSTRAINT_NAME
UPDATE @table SET
PrimaryKeyConstraintTableSchema = TABLE_SCHEMA,
PrimaryKeyConstraintTableName = TABLE_NAME
FROM @table T
INNER JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS C
ON T.PrimaryKeyConstraintName = C.CONSTRAINT_NAME
UPDATE @table SET
PrimaryKeyConstraintColumnName = COLUMN_NAME
FROM @table T
INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE U
ON T.PrimaryKeyConstraintName = U.CONSTRAINT_NAME
--SELECT * FROM @table
--DROP CONSTRAINT:
SELECT
'
ALTER TABLE [' + ForeignKeyConstraintTableSchema + '].[' + ForeignKeyConstraintTableName + ']
DROP CONSTRAINT ' + quotename(ForeignKeyConstraintName) + ';'
FROM
@table
--ADD CONSTRAINT:
SELECT
'
ALTER TABLE [' + ForeignKeyConstraintTableSchema + '].[' + ForeignKeyConstraintTableName + ']
ADD CONSTRAINT ' + ForeignKeyConstraintName + ' FOREIGN KEY(' + quotename(ForeignKeyConstraintColumnName) + ') REFERENCES [' + PrimaryKeyConstraintTableSchema + '].[' + PrimaryKeyConstraintTableName + '](' + PrimaryKeyConstraintColumnName + ')
 
GO'
FROM
@table
GO

truncate table [dbo].[ConversationEmailAddresses]
truncate table [dbo].[razgovori]
truncate table [dbo].[razgovori_kupci]
truncate table [dbo].[razgovori_privitci]



truncate table [dbo].[CalculationItemDocumentTaxGroupedAmounts]
truncate table [dbo].[cekovi]
truncate table [dbo].[CreditAccountDebtItemsTransactions]
truncate table [dbo].[CurrentDocumentApprovalStatus]
truncate table [dbo].[CustomFieldsDocuments]
truncate table [dbo].[DocumentApproval]
truncate table [dbo].[DocumentSendingLogs]
truncate table [dbo].[DocumentSynchronization]
truncate table [dbo].[DocumentTaxRateInCurrency]
truncate table [dbo].[DocumentToSupplierDocumentRelation]
truncate table [dbo].[dokumenti]
truncate table [dbo].[dokumenti_bankovni_racuni]
truncate table [dbo].[dokumenti_putanje_jezici]
truncate table [dbo].[dokumenti_stavke_kalkulacija_aranzmana]
truncate table [dbo].[jedinice_dokumenti]
truncate table [dbo].[ReportStatsPriceDocumentData]
truncate table [dbo].[ReservationDocumentTaxGroupedAmounts]
truncate table [dbo].[ReservationTransactionDistributions]
truncate table [dbo].[rezervacije_dokumenti]
truncate table [dbo].[stope_dokumenti]
truncate table [dbo].[TransactionComponentAmounts]
truncate table [dbo].[TransactionReconciliations]
truncate table [dbo].[TransactionsDocuments]
truncate table [dbo].[TransactionsDocuments]
truncate table [dbo].[transakcije]
truncate table [dbo].[velike_rezervacije_dokumenti]



truncate table [dbo].[CancellationData]
truncate table [dbo].[CancellationDataItem]
truncate table [dbo].[CancellationDataItemReservationDetails]
truncate table [dbo].[CancellationDataItemReservationDetails]
truncate table [dbo].[cijene_rezervacija_detalja_po_danu]
truncate table [dbo].[CreditAccountDebtItemsReservations]
truncate table [dbo].[CreditAccounts]
truncate table [dbo].[CustomerLoyaltyPointsLog]
truncate table [dbo].[CustomFieldsPassengersReservations]
truncate table [dbo].[CustomFieldsReservationItems]
truncate table [dbo].[DocumentToSupplierDocumentRelation]
truncate table [dbo].[DocumentToSupplierDocumentRelation]
truncate table [dbo].[dodatna_polja_velika_rezervacija]
truncate table [dbo].[FlightTickets]
truncate table [dbo].[napomene_velike_rezervacije]
truncate table [dbo].[oznake_velikih_rezervacija_velike_rezervacije]
truncate table [dbo].[PaymentPlanReservation]
truncate table [dbo].[RecurringActions]
truncate table [dbo].[RecurringActionsTriggers]
truncate table [dbo].[ReportStatsBasicData]
truncate table [dbo].[ReportStatsBasicData]
truncate table [dbo].[ReportStatsFactReservationData]
truncate table [dbo].[ReportStatsPriceData]
truncate table [dbo].[ReportStatsPriceDocumentData]
truncate table [dbo].[ReservationDetailPriceInCurrency]
truncate table [dbo].[ReservationDetailsPayers]
truncate table [dbo].[ReservationDocumentTaxGroupedAmounts]
truncate table [dbo].[ReservationDocumentTaxGroupedAmounts]
truncate table [dbo].[ReservationItemCalculationItem]
truncate table [dbo].[ReservationItemCashAdvanceItems]
truncate table [dbo].[ReservationItemDetailReservationItemPassenger]
truncate table [dbo].[ReservationItemDetailReservationItemPassenger]
truncate table [dbo].[ReservationItemNeedsConfirmation]
truncate table [dbo].[ReservationItemOtherSystemLog]
truncate table [dbo].[ReservationItemOtherSystemLog]
truncate table [dbo].[ReservationPartnerDebtPaymentRules]
truncate table [dbo].[ReservationPartnerDebts]
truncate table [dbo].[ReservationsPayers]
truncate table [dbo].[ReservationsSentEmails]
truncate table [dbo].[ReservationsTravelInformation]
truncate table [dbo].[ReservationSubstatusHistory]
truncate table [dbo].[ReservationTransactionDistributions]
truncate table [dbo].[ReservationTriggerDefinitionQueueActions]
truncate table [dbo].[ReservationTriggerDefinitions]
truncate table [dbo].[ReservationTriggerDefinitions]
truncate table [dbo].[rezervacije]
truncate table [dbo].[rezervacije_akcije]
truncate table [dbo].[rezervacije_akcije]
truncate table [dbo].[rezervacije_destinacije]
truncate table [dbo].[rezervacije_detalji]
truncate table [dbo].[rezervacije_detalji_gosti]
truncate table [dbo].[rezervacije_detalji_gosti]
truncate table [dbo].[rezervacije_dokumenti]
truncate table [dbo].[rezervacije_gosti]
truncate table [dbo].[rezervacije_gosti]
truncate table [dbo].[rezervacije_html_opisi]
truncate table [dbo].[rezervacije_kapaciteta_na_dan]
truncate table [dbo].[rezervacije_rezervacije_aranzmana]
truncate table [dbo].[rezervacije_status]
truncate table [dbo].[transferi]
truncate table [dbo].[velike_rezervacije]
truncate table [dbo].[velike_rezervacije_dokumenti]
truncate table [dbo].[velike_rezervacije_statusi]
truncate table [dbo].[velike_rezervacije_zadatci]