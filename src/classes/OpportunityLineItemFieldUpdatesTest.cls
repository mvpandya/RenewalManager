@isTest (seeAllData = true)
private class OpportunityLineItemFieldUpdatesTest {

    static testMethod void testUpdateParentAccount() {
        // Create configuration data.
        Renewal_App_Setup__c renewalAppSetupRec = TestHelper.getRenewalAppSetup();
        upsert renewalAppSetupRec;

        // Set up Opportunity Record first
        Date OppCloseDate = Date.newinstance(2012, 12, 01);
        String OppName = 'Test Opportunity for Trigger Test';
        String OppStage = 'Prospecting';

        Account acc = new Account(Name = 'Teradata International');
        insert acc;

        Opportunity o = new Opportunity(AccountID = acc.Id, Name = OppName,  StageName = OppStage, CloseDate = OppCloseDate); //'005E000000DIQnIAK',);
        insert o;

        //set up Product record
        string ProductName = 'Lotus 123';
        string ProductDescription = 'Lotus Notes Description';
        Decimal RenewalTerm = 12.0;
        Product2 Prod = new Product2(Name = ProductName, Description = ProductDescription, use_this_same_product_in_renewal_opp__c = true, prorate_price__c = true, renewal_term_months__c = RenewalTerm, isactive = true);
        insert Prod;

        //insert standard price for product
        Pricebook2 standardPB = [select id from Pricebook2 where isStandard = true limit 1];
        Decimal StdPrice = 10.00;
        PriceBookEntry PBEntry1 = new PriceBookEntry(UnitPrice = StdPrice, PriceBook2Id = standardPB.Id, Product2ID = Prod.Id, IsActive = true, UseStandardPrice = false);
        insert PBEntry1;

        //insert OppLineItem
        OpportunityLineItem Opp = new OpportunityLineItem(UnitPrice = StdPrice , Quantity = 5.0, PricebookEntryId = PBEntry1.Id, OpportunityId = o.Id);
        insert Opp;

        //Making product renewable to test further
        Prod.use_this_same_product_in_renewal_opp__c = true;
        upsert Prod;
        Opp.Description = NULL;
        upsert Opp;

        upsert Prod;
        Opp.Description = NULL;
        upsert Opp;

        //having mark up being entered and cost coming from product set up
        Decimal MarkUp = 100;
        //Opp.Mark_up__c = MarkUp;
        upsert Opp;
        //entering user entered cost as well
        Decimal Cost = 500;
        upsert Opp;

        //doing co-term check
        Opportunity CoTermOpp = new Opportunity(AccountID = acc.Id, Name = OppName,  StageName = OppStage, CloseDate = OppCloseDate, Co_Term_With__c = o.Id, Is_Add_on_Opportunity__c = 'yes');
        insert CoTermOpp;
        //insert OppLineItem
        OpportunityLineItem coTermOppLineItem = new OpportunityLineItem(UnitPrice = StdPrice , Quantity = 5.0, PricebookEntryId = PBEntry1.Id, OpportunityId = CoTermOpp.Id);
        insert coTermOppLineItem ;
        // insert Asset record to test out AssetHistoryTrigger
        Asset AssetObj = new Asset( Name = Prod.Name , Source_Opp__c = o.Id, Product2Id = Prod.Id, Quantity = 5, Price = 100.00, AccountId = o.AccountId, InstallDate = system.today());
        insert AssetObj;
        AssetObj.Quantity = 10;
        Upsert AssetObj;

        //insert Opp Record Type and Test OppRecordTypeMappingDML
        RecordType r = [Select Id, Description, Name From RecordType Where  IsActive = true limit 1];

        Opp_Record_Type_Mapping__c oppRec;
        oppRec = new Opp_Record_Type_Mapping__c(Renewal_Opp_Record_Type_ID__c = r.Id, Renewal_Opp_Record_Type_Name__c = 'Test', Source_Opp_Record_Type_ID__c = r.Id, Source_Opp_Record_Type_Name__c = 'Test');
        insert OppRec;
        system.assertEquals(oppRec.Source_Opp_Record_Type_Name__c, 'Test');
    }
}