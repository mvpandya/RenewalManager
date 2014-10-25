/**
 * Copyright (c) 2014 Comity Designs
 * All rights reserved.
 *
 * This is test helper class contains methods for test classes of Renewal manager.
 *
 * History:
 * =========================================
 * Developer         Date        description
 * --------------------------------------------------------------------------------------------------
 * Ivan Melnikov     07/30/2014  Code refactoring 
 *
 * 
 **/
public with sharing class TestHelper {

    public static final String PRICEBOOK_NAME = 'Default pricebook name';
    public static final String OPPORTUNITY_NAME = 'Default Oppty Name';
    public static final String OPPORTUNITY_OPEN_STAGE = 'Prospecting';
    public static final String OPPORTUNITY_CLOSED_STAGE = 'Closed Won';

    public static final String PRODUCT_NAME = 'Default Product Name';
    public static final String PRODUCT_DESCRIPTION = 'Default Product description';
    public static final Decimal PRODUCT_RENEWAL_TERM = 12.0;
    public static final Decimal PRODUCT_STANDARD_UNIT_PRICE = 12.0;
    
    public static final Decimal OLI_QUANTITY = 5;

    public static final String ACCOUNT_NAME = 'Org Test Account';

    public static final String RENEWAL_APP_SETUP_RENEWAL_OPPTY_TYPE_EXISITING = 'Existing Customer - Renewal';
    public static final String RENEWAL_APP_SETUP_RENEWAL_OPPTY_STAGE = 'Needs Analysis';

    // Configuration data, should exist only one record.
    private static Renewal_App_Setup__c renewalAppSetup;
    public static Renewal_App_Setup__c getRenewalAppSetup() {
        List<Renewal_App_Setup__c> renewalAppSetupList = [
            SELECT User__c, Clone_Competitors_Related_List__c, Clone_Contact_Roles__c, Clone_Opp_Team_Related_List__c,
                Asset__c, Opportunity_Field_To_Not_Copy_on_Renewal__c, Opportunity_Product_Fields_To_Not_Copy__c,
                Renewal_Stage__c, Renewal_Opportunity_Owner__c, Renewal_Opportunity_Type__c, Prefix_for_Renewal_Opportunity_Name__c
            FROM Renewal_App_Setup__c 
            LIMIT 1
        ];

        if (!renewalAppSetupList.isEmpty()) {
            renewalAppSetup = renewalAppSetupList[0];
        } else {
            renewalAppSetup = new Renewal_App_Setup__c(
                Renewal_Stage__c = RENEWAL_APP_SETUP_RENEWAL_OPPTY_STAGE,
                Renewal_Opportunity_Type__c = RENEWAL_APP_SETUP_RENEWAL_OPPTY_TYPE_EXISITING
            );
        }
        return renewalAppSetup;
    }

    public static Account getDefaultAccount() {
        return new Account(Name = ACCOUNT_NAME);
    }

    public static Contact getDefaultContact(Id accountId) {
        return new Contact(AccountId = accountId,
            LastName = 'Test',
            FirstName = 'Test');
    }

    public static Opportunity getDefaultOpenOpportunity(Id accountId) {
        	List<RecordType> RL = new List<RecordType>([Select Id, Name From RecordType Where Name = 'CD_Sales' LIMIT 1]);
        	ID CDSalesRecordTypeID = RL[0].Id;
        	
        return new Opportunity(
            AccountId = accountId, 
            Name = OPPORTUNITY_NAME,
            StageName = OPPORTUNITY_OPEN_STAGE, 
            RecordTypeId = CDSalesRecordTypeID,
            CloseDate = Date.today()
        );
    }

    public static OpportunityLineItem getDefaultOpportunityLineItem(Id opptyId, Id pricebookEntryId) {
        return new OpportunityLineItem(
            UnitPrice = PRODUCT_STANDARD_UNIT_PRICE, 
            Quantity = OLI_QUANTITY, 
            PricebookEntryId = pricebookEntryId, 
            OpportunityId = opptyId
        );
    }

    public static Product2 getRenewalProduct() {
        return new Product2(
            Name = PRODUCT_NAME, 
            Description = PRODUCT_DESCRIPTION,
            use_this_same_product_in_renewal_opp__c = true, 
            prorate_price__c = true, 
            renewal_term_months__c = PRODUCT_RENEWAL_TERM, 
            isactive = true
        );

    }

    public static PricebookEntry getDefaultPricebookEntry(Id productId) {
        return new PricebookEntry(
            UnitPrice = PRODUCT_STANDARD_UNIT_PRICE, 
            PriceBook2Id = Test.getStandardPricebookId(), 
            Product2ID = productId, 
            IsActive = true, 
            UseStandardPrice = false
        );
    }
}