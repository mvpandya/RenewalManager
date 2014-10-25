/**
 * Copyright (c) 2014 Comity Designs
 * All rights reserved.
 *
 * This class is Opportunity Line Item trigger handler for the Renewal Manager.
 *
 * History:
 * =========================================
 * Developer         Date        description
 * --------------------------------------------------------------------------------------------------
 * Ivan Melnikov     07/30/2014  Code refactoring 
 *
 * 
 **/
public with sharing class OpportunityLineItemTriggerHandler {
    public static void oportunityLineItemBeforeInsertUpdateHandler(List<OpportunityLineItem> newOliList) {
        /*Purpose of trigger is as follows:
        When a product is added or updated to an opportunity, perform below check
        1. if Asset_Install_Date__c field on OpportunityLineItem is blank or less than Opportunity CloseDate then set it Opportunity CloseDate 
        2. if Entitlement_Start_Date__c field on OpportunityLineItem is blank or less than Opportunity CloseDate then set it Opportunity CloseDate
        3. if Entitlement_Term__c field on OpportunityLineItem is blank then read the entitlement term tied to Product on this opportunityLineItem and set Entitlement_Term__c = entitlement term from that entitlement template.
        4. Set Entitlement_End_Date__c = Entitlement_Start_Date__c + Entitlement_Term
        5. - We will make Entitlement_End_Date__c on Opportunity Product Layout as readonly field
        6. Pro-rate prices based on entitlement term
        7. carry forward discount on same product from co-termed with opp
        8. Apply upsell commission when new item is added to opportunity with renewable record type // Deprecated
        9. Apply new business commission when item is added to opportunity with non-renewable (i.e. sales) record type // Deprecated
        */
        //Create a set of all affected Opportunity IDs from Trigger
        Set<Id> OpportunityIDs = new Set<Id>();
        for (OpportunityLineItem oli : newOliList) {
            OpportunityIDs.add(oli.OpportunityId);
        }
        //Create OpportunityMap and read relevant fields from Opportunity Object
        Map<Id, Opportunity> Opp = new Map<Id, Opportunity>([
            SELECT Opportunity.Id, Opportunity.CloseDate, Opportunity.Co_Term_With__c, Opportunity.RecordTypeId 
            FROM Opportunity
            WHERE id in :OpportunityIDs
        ]);
        //Create OpportunityLineItem list and assign to it from trigger
        List<OpportunityLineItem> OppLineItem = new List<OpportunityLineItem>();
        OppLineItem = newOliList;
        //Create set of PriceBookEntryIDs from OpportunityLineItem list for use in SOQL while creation of pricebookentry map
        Set<Id> PriceBookEntryIDs = new Set<Id>();
        for (OpportunityLineItem Oppli : OppLineItem) {
            PriceBookEntryIDs.add(Oppli.PricebookEntryId);
        }
        //Create Pricebookentry map    
        Map<ID, PricebookEntry> PriceBookEntryList = new Map<ID, PricebookEntry>([
            SELECT Id, Product2Id 
            FROM PricebookEntry 
            WHERE Id IN :PricebookEntryIDs
        ]);
        //create product ID set as well as Map to map PricebookEntryID to Product ID
        Set<Id> ProductIDs = new Set<Id>();
        Map<ID, ID> PriceBookToProduct = new Map<ID, ID>();
        for (Id PID : PriceBookEntryList.keyset()) {
            ProductIDs.add(PriceBookEntryList.get(PID).Product2ID);
            PriceBookToProduct.put(PID, PriceBookEntryList.get(PID).Product2ID);
        }    
        //Create Product2Map for use to look up description and prorating set up fields    
        Map<Id, Product2> Product2Map = new Map<Id, Product2>([
            SELECT Id, Description, ProRate_Price__c, Renewal_Term_Months__c, Use_this_same_product_in_Renewal_Opp__c, 
                Product_To_Use_In_Renewal__c 
            FROM Product2 
            WHERE Id IN :ProductIDs
        ]);
        List<Renewal_App_Setup__c> rAppSetupList = [
            SELECT r.ID, r.Prefix_for_Renewal_Opportunity_Name__c, r.Renewal_Stage__c, r.Renewal_Opportunity_Type__c,
                    r.Asset__c 
            FROM Renewal_App_Setup__c r
            LIMIT :Limits.getLimitQueryRows()
        ];
        Renewal_App_Setup__c rAppSetup;
        if (rAppSetupList == null || rAppSetupList.size() != 1) {
            System.debug('~~~0. Error:- Renewal_App_Setup has no/many records...');
            return;
        } else {
            rAppSetup = rAppSetupList[0];
        }
                
        //Retrieving Renewal Record Type ID based on set up on Renewal App Set Up tab
        String RenewalRecordTypeKeyword;            
        //Main loop and updating values of fields for record in trigger
        for (OpportunityLineItem oli : newOliList) {
            //populating service date on line item from close date of opportunity on a new record
            if (oli.ServiceDate == NULL) { 
                oli.ServiceDate = Opp.get(oli.OpportunityId).CloseDate;
            }
            if (oli.Description == NULL) {
                oli.Description = Product2Map.get(PriceBookToProduct.get(oli.PricebookEntryID)).Description;
            }     
            if (oli.Asset_Install_Date__c == NULL) { //set asset_install_date to service date on a new record insert 
                oli.Asset_Install_Date__c = oli.ServiceDate;
            }
            //read entitlement term from product set-up and store it in variable  
            Integer EntTerm;
            if (Product2Map.get(PriceBookToProduct.get(oli.PricebookEntryID)).Renewal_Term_Months__c != NULL && oli.Entitlement_Term__c == NULL) {
                //EntTemplateMap.get(ProductEntTemplate.get(PriceBookToProduct.get(oli.PricebookEntryID)).EntitlementTemplateID).Term); 
                EntTerm = Product2Map.get(PriceBookToProduct.get(oli.PricebookEntryID)).Renewal_Term_Months__c.intValue();
            } else {
                EntTerm = Integer.valueOf(oli.Entitlement_Term__c);
            }
            system.debug('Entitlement Term ' + EntTerm);
            //go through entitlement calc logic only for renewable products
            if (Product2Map.get(PriceBookToProduct.get(oli.PricebookEntryID)).Use_this_same_product_in_Renewal_Opp__c == true || 
                Product2Map.get(PriceBookToProduct.get(oli.PricebookEntryID)).Product_To_Use_In_Renewal__c != NULL) { 
                //set entitlement_start_date to service on a new record insert 
                system.debug('Entitlement Start Date ' + oli.Entitlement_Start_Date__c);
                if (oli.Entitlement_Start_Date__c == NULL) { 
                    oli.Entitlement_Start_Date__c = oli.ServiceDate;
                }
                // populating entitlement end date on a new record insert
     //           if (oli.Entitlement_End_Date__c == NULL) {
                    // this isn't an Add-on Opportunity, so NO co-term calculation
                    if (Opp.get(oli.OpportunityId).Co_Term_With__c == NULL) { 
                        oli.Entitlement_End_Date__c = oli.Entitlement_Start_Date__c;
                        oli.Entitlement_End_Date__c = oli.Entitlement_End_Date__c.addMonths(EntTerm);       
                        oli.Entitlement_End_Date__c = oli.Entitlement_End_Date__c.addDays(-1);
                        oli.Entitlement_Term__c = EntTerm;
                    //it's an Add-On opportunity, so perform co-term calculation    
                    } else { 
                        List<OpportunityLineItem> OppEndDate = new List<OpportunityLineItem>([
                            SELECT o.Entitlement_End_Date__c, o.Discount 
                            FROM OpportunityLineItem o 
                            WHERE o.PricebookEntryID = :oli.PricebookEntryID AND o.OpportunityID = :Opp.get(oli.OpportunityId).Co_Term_With__c
                        ]);
                        if (OppEndDate.size() > 0) {
                            //same product was sold on Co-Termed With Opportunity
                            oli.Entitlement_End_Date__c = OppEndDate[0].Entitlement_End_Date__c;
                            //Applying discounts from opportunity being co-termed with when same product as on add-on is also sold on original opp
                            oli.Discount = OppEndDate[0].Discount;
                        //same product was NOT sold on Co-Termed With Opportunity
                        } else {
                            //>= and Order By in below select would also cover scenarios where in source opp there are products with 90 days and 365 days term but in
                            // add-on a different product with 60 days entitlement term is added at different date
                            List<OpportunityLineItem> OppEndDateWithDiffProduct = new List<OpportunityLineItem>([
                                SELECT o.Entitlement_End_Date__c 
                                FROM OpportunityLineItem o 
                                WHERE o.OpportunityID = :Opp.get(oli.OpportunityId).Co_Term_With__c AND o.Entitlement_Term__c >= :EntTerm 
                                ORDER BY o.Entitlement_Term__c ASC
                            ]);                        
                            if (OppEndDateWithDiffProduct.size() > 0) {
                                oli.Entitlement_End_Date__c = OppEndDateWithDiffProduct[0].Entitlement_End_Date__c;
                            }    
                        }

      //          }
                        // calculate entitlement term based on to see if there was any change to it in case this line item is co-termed with some other line item on opportunity
                        decimal CalculatedEntTerm; 
                        date EntStartDate, EntEndDate;
                        EntStartDate = oli.Entitlement_Start_Date__c;
                        EntEndDate = oli.Entitlement_End_Date__c;
                        If (EntEndDate != NULL) {
                            if( EntStartDate.month()== EntEndDate.month() && EntStartDate.year()== EntEndDate.year() )
                            {
                                CalculatedEntTerm =  decimal.valueOf((EntStartDate.daysBetween(EntEndDate) ))/decimal.valueOf(date.daysInMonth(EntStartDate.year(),EntStartDate.month()));
                            }
                            else
                            {
                                Integer monthsBetween = EntStartDate.monthsBetween(EntEndDate)-1;
                                system.debug('months between ' + monthsBetween);
                                decimal firstMonth = decimal.valueOf(date.daysInMonth(EntStartDate.year() , EntStartDate.month())-EntStartDate.day()+1)/decimal.valueOf(date.daysInMonth(EntStartDate.year(), EntStartDate.month()));
                                system.debug('first month ' + firstMonth.setScale(2, roundingMode.HALF_UP));
                                decimal lastMonth =  decimal.valueOf(EntEndDate.toStartOfMonth().daysBetween(EntEndDate)+1)/decimal.valueOf(date.daysInMonth(EntEndDate.year(), EntEndDate.month()));
                                system.debug('lastMonth ' + lastMonth.setScale(2, roundingMode.HALF_UP));
                                CalculatedEntTerm = firstMonth.setScale(2, roundingMode.HALF_UP) + monthsBetween + lastMonth.setScale(2, roundingMode.HALF_UP);         
                            }
            
                            
                           // CalculatedEntTerm = MonthsBetween(EntStartDate, EntEndDate); //oli.Entitlement_Start_Date__c.monthsBetween(oli.Entitlement_End_Date__c);
                            oli.Entitlement_Term__c = CalculatedEntTerm.setScale(1, roundingMode.HALF_UP); //set entitlement term to be calculated entitlement term
                           }
                     }
            }    
            //when opp is created via Renewal trigger, list price is NULL as it's a read only field where as UnitPrice is set there
            if (oli.ListPrice != NULL) { 
                //setting sale price as list price from pricebook as no mark-up is entered
                //oli.UnitPrice = oli.ListPrice; 
                if (oli.UnitPrice == NULL && oli.ListPrice != NULL) {
                    oli.UnitPrice = oli.ListPrice;
                } 
            
                //Pro-rate prices if product set-up allows it//do pro-rating only for renewable products
                if (Product2Map.get(PriceBookToProduct.get(oli.PricebookEntryID)).Use_this_same_product_in_Renewal_Opp__c == true || Product2Map.get(PriceBookToProduct.get(oli.PricebookEntryID)).Product_To_Use_In_Renewal__c != NULL) { 
                    if (Product2Map.get(PriceBookToProduct.get(oli.PricebookEntryID)).ProRate_Price__c == TRUE) {
                        //changing pro-rating to be based on months a renewal term is based on months on product set-up page
                        oli.UnitPrice = oli.UnitPrice * (oli.Entitlement_Term__c/(oli.Entitlement_Start_Date__c.MonthsBetween(oli.Entitlement_Start_Date__c.addMonths(Product2Map.get(PriceBookToProduct.get(oli.PricebookEntryID)).Renewal_Term_Months__c.intValue()))));
                    }
                }  
            }
        }
    }
    

}