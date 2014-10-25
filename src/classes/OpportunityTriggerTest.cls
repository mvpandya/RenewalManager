/**
 * Copyright (c) 2014 Comity Designs
 * All rights reserved.
 *
 * This class is test class for the Opportunity trigger.
 *
 * History:
 * =========================================
 * Developer         Date        description
 * --------------------------------------------------------------------------------------------------
 * Ivan Melnikov     07/30/2014  Code refactoring 
 *
 * 
 **/
@isTest (seeAllData = true)
private class OpportunityTriggerTest {
    static testMethod void testSameProductbeingRenewable() {
        // Create configuration data.
        Renewal_App_Setup__c renewalAppSetupRec = TestHelper.getRenewalAppSetup();
        upsert renewalAppSetupRec;

        Account acc = TestHelper.getDefaultAccount();
        insert acc;

        Opportunity  baseOppty = TestHelper.getDefaultOpenOpportunity(acc.Id);
        insert baseOppty;

        system.debug('baseOppty::'+baseOppty);

        Product2 prod = TestHelper.getRenewalProduct();
        insert prod;

        PriceBookEntry pbEntry = TestHelper.getDefaultPricebookEntry(prod.Id);
        insert pbEntry;

        OpportunityLineItem oli = TestHelper.getDefaultOpportunityLineItem(baseOppty.Id, pbEntry.Id);
        insert oli;

        // Close opportunity.
        baseOppty.StageName = TestHelper.OPPORTUNITY_CLOSED_STAGE;

        Test.startTest();
        upsert baseOppty;
        Test.stopTest();

        // Validate that mapping records has been created.
        List<Source_Opp_Mapping__c> sourceOppMappingList = [
            SELECT Source_Opp__c, Renewal_Opp__c, Account_Name__c, Close_Date__c
            FROM Source_Opp_Mapping__c
            WHERE Source_Opp__c = : baseOppty.Id
        ];
        System.assertEquals(sourceOppMappingList.size(),1);
        // TODO: how close date is getting set?
        //System.assertEquals(sourceOppMappingList[0].Close_Date__c, baseOppty.CloseDate); 
        System.assertEquals(sourceOppMappingList[0].Account_Name__c, acc.Name);

        sourceOppMappingList = [
            SELECT Source_Opp__c, Renewal_Opp__c, Account_Name__c, Close_Date__c
            FROM Source_Opp_Mapping__c
            WHERE Renewal_Opp__c = : baseOppty.Id
        ];
        System.assertEquals(sourceOppMappingList.size(),1);
        // TODO: how close date is getting set?
        //System.assertEquals(sourceOppMappingList[0].Close_Date__c, baseOppty.CloseDate);
        System.assertEquals(sourceOppMappingList[0].Account_Name__c, acc.Name);

        // Validate that new renewal opportunity has been created.
        List<Opportunity> renewalOpptyList = [
            SELECT Originating_Opportunity__c 
            FROM Opportunity 
            WHERE Originating_Opportunity__c = :baseOppty.Id    
        ];
        System.assertEquals(renewalOpptyList.size(), 1);
    }

    static testMethod void testDifferentProductbeingRenewable() {

        Account acc = TestHelper.getDefaultAccount();
        insert acc;

        Opportunity  baseOppty = TestHelper.getDefaultOpenOpportunity(acc.Id);
        insert baseOppty;

        Product2 prod = TestHelper.getRenewalProduct();
        insert prod;

        Product2 prod2 = TestHelper.getRenewalProduct();
        prod2.Product_To_Use_In_Renewal__c = prod.id;
        prod2.Use_this_same_product_in_Renewal_Opp__c = false;        
        insert prod2;        

        PriceBookEntry pbEntry = TestHelper.getDefaultPricebookEntry(prod2.Id);
        insert pbEntry;

        OpportunityLineItem oli = TestHelper.getDefaultOpportunityLineItem(baseOppty.Id, pbEntry.Id);
        insert oli;

        // Close opportunity.
        baseOppty.StageName = TestHelper.OPPORTUNITY_CLOSED_STAGE;

        Test.startTest();
        upsert baseOppty;
        Test.stopTest();

        // Validate results.
        // Validate that mapping records has NOT been created.
        List<Source_Opp_Mapping__c> sourceOppMappingList = [
            SELECT Source_Opp__c, Renewal_Opp__c, Account_Name__c, Close_Date__c
            FROM Source_Opp_Mapping__c
            WHERE Source_Opp__c = : baseOppty.Id
        ];
        System.assertEquals(sourceOppMappingList.size(), 0);        
    }

    static testMethod void testCoTermOpp() {

        Account acc = TestHelper.getDefaultAccount();
        insert acc;

        Opportunity  baseOppty = TestHelper.getDefaultOpenOpportunity(acc.Id);
        insert baseOppty;

        Product2 prod = TestHelper.getRenewalProduct();
        insert prod;

        Product2 prod2 = TestHelper.getRenewalProduct();
        prod2.Product_To_Use_In_Renewal__c = prod.id;
        prod2.Use_this_same_product_in_Renewal_Opp__c = false;        
        insert prod2; 

        PriceBookEntry pbEntry = TestHelper.getDefaultPricebookEntry(prod2.Id);
        insert pbEntry;

        OpportunityLineItem oli = TestHelper.getDefaultOpportunityLineItem(baseOppty.Id, pbEntry.Id);
        insert oli;

        // Close opportunity.
        baseOppty.StageName = TestHelper.OPPORTUNITY_CLOSED_STAGE;

        upsert baseOppty;

        // Insert co-term oppty.
        Opportunity coTermOppty = TestHelper.getDefaultOpenOpportunity(acc.Id);
        coTermOppty.Co_Term_With__c = baseOppty.Id; 
        coTermOppty.Is_Add_on_Opportunity__c = 'yes';
        insert coTermOppty;

        // Insert OppLineItem for CoTerm
        OpportunityLineItem cotermOli = TestHelper.getDefaultOpportunityLineItem(coTermOppty.Id, pbEntry.Id);
        insert cotermOli;

        // Close coTermOppty.
        coTermOppty.StageName = TestHelper.OPPORTUNITY_CLOSED_STAGE;

        Test.startTest();
        upsert coTermOppty;
        Test.stopTest();

        // Verify results.
        // Validate that mapping records has NOT been created.
        List<Source_Opp_Mapping__c> sourceOppMappingList = [
            SELECT Source_Opp__c, Renewal_Opp__c, Account_Name__c, Close_Date__c
            FROM Source_Opp_Mapping__c
            WHERE Source_Opp__c = : baseOppty.Id
        ];
        System.assertEquals(sourceOppMappingList.size(), 0);  
    }

    static testMethod void testEntitlementContact() {    
       
          // Set up Opportunity Record first
        Date OppCloseDate = Date.newinstance(2012,12,01);
        String OppName = 'Test Opportunity for Trigger Test';
        String OppStage = 'Prospecting';

        Account Acc = new Account(Name='Org Test Account');
        insert Acc;

        Contact c = TestHelper.getDefaultContact(Acc.Id);
        insert c;
                        
        Opportunity o = new Opportunity(AccountID=Acc.Id, Name=OppName,  StageName=OppStage, CloseDate=OppCloseDate, Contact__c = c.Id); //'005E000000DIQnIAK',);
        insert o;

        //set up Product record
        String ProductName = 'Lotus 123';
        String ProductDescription = 'Lotus Notes Description';   
        Decimal RenewalTerm = 12.0;   
        Product2 Prod = new Product2(Name=ProductName, Description=ProductDescription, use_this_same_product_in_renewal_opp__c = true, prorate_price__c = true, renewal_term_months__c = RenewalTerm, isactive = true);
        insert Prod;

        Product2 Prod2 = new Product2(Name='XYZ-1', Description=ProductDescription, use_this_same_product_in_renewal_opp__c = true, prorate_price__c = true, renewal_term_months__c = RenewalTerm, isactive = true);
        insert Prod2;
          
        Prod.Product_To_Use_In_Renewal__c = Prod2.id;
        Prod.Use_this_same_product_in_Renewal_Opp__c = false;
        upsert Prod;

        Decimal StdPrice = 10.00;
        PriceBookEntry PBEntry1 = new PriceBookEntry(UnitPrice=StdPrice, PriceBook2Id=Test.getStandardPricebookId(), Product2ID=Prod.Id, IsActive = true, UseStandardPrice = false);
        insert PBEntry1;      
          
        //insert OppLineItem
        OpportunityLineItem Opp = new OpportunityLineItem(UnitPrice=StdPrice , Quantity=5.0, PricebookEntryId=PBEntry1.Id, OpportunityId=o.Id);
        insert Opp;
          
          
        o.StageName = 'Closed Won';
        upsert o;

        // Validate that mapping records has NOT been created.
        List<Source_Opp_Mapping__c> sourceOppMappingList = [
            SELECT Source_Opp__c, Renewal_Opp__c, Account_Name__c, Close_Date__c
            FROM Source_Opp_Mapping__c
            WHERE Source_Opp__c = : o.Id
        ];
        System.assertEquals(sourceOppMappingList.size(), 0);          
      }    
}