/**
 * Copyright (c) 2014 Comity Designs
 * All rights reserved.
 *
 * This class is Helper class for the Renewal Manager.
 *
 * History:
 * =========================================
 * Developer         Date        description
 * --------------------------------------------------------------------------------------------------
 * Ivan Melnikov     07/30/2014  Code refactoring 
 *
 * 
 **/
public with sharing class OpportunityRenewalHelper { 

    /*This below map (RENEWAL_RECORD_TYPE_MAPPING) will be refresh FROM OppRecordTypeMappingDML trigger. 
        * Key = ID of source Opportunity RecordTypeID, 
        * Value = Renewal Opportunity RecordTypeID.
    */
    public static Map<ID, ID> RENEWAL_RECORD_TYPE_MAPPING = getRenewalOpportunityRecordTypeMap();
    
    // Get mapping details //Key = ID of source Opportunity RecordTypeID, Value = Renewal Opportunity RecordTypeID.
    public static Map<ID, ID> getRenewalOpportunityRecordTypeMap() {
        Map<ID, ID> renewalOpportunityRecordTypeMap = new Map<ID, ID>();
        Integer Cnt = [Select Count() From Opp_Record_Type_Mapping__c];
        If (Cnt == 0){
            List<RecordType> RL = new List<RecordType>([Select Id, Name From RecordType Where Name = 'CD_Sales' OR Name = 'CD_Sales_Renewal']);
            ID CDSalesRecordTypeID, CDSalesRenewalRecordTypeID;
            for(RecordType RT: RL){
                If(RT.Name == 'CD-Sales'){
                    CDSalesRecordTypeID = RT.Id;
                } else {
                    CDSalesRenewalRecordTypeID = RT.Id;
                }
            }
            List<Opp_Record_Type_Mapping__c> OppMapList = new List<Opp_Record_Type_Mapping__c>();
            OppMapList.add(new Opp_Record_Type_Mapping__c(Source_Opp_Record_Type_ID__c = CDSalesRecordTypeID, Renewal_Opp_Record_Type_ID__c = CDSalesRenewalRecordTypeID));
            OppMapList.add(new Opp_Record_Type_Mapping__c(Source_Opp_Record_Type_ID__c = CDSalesRenewalRecordTypeID, Renewal_Opp_Record_Type_ID__c = CDSalesRenewalRecordTypeID));
            Insert OppMapList;
        }
        for (Opp_Record_Type_Mapping__c m: [SELECT Source_Opp_Record_Type_ID__c, Renewal_Opp_Record_Type_ID__c 
                                            FROM Opp_Record_Type_Mapping__c
                                            LIMIT :Limits.getLimitQueryRows()]) {
            renewalOpportunityRecordTypeMap.put(m.Source_Opp_Record_Type_ID__c, m.Renewal_Opp_Record_Type_ID__c);
        }
       
        return renewalOpportunityRecordTypeMap;
    }
    
    public static ID getRenewalOpportunityRecordType(ID sourceOpportunityRecordTypeID) {
        RENEWAL_RECORD_TYPE_MAPPING = getRenewalOpportunityRecordTypeMap();        
        if (RENEWAL_RECORD_TYPE_MAPPING.containsKey(sourceOpportunityRecordTypeID)) {
            return RENEWAL_RECORD_TYPE_MAPPING.get(sourceOpportunityRecordTypeID);
        }
        return sourceOpportunityRecordTypeID;
    }
    public static Map<ID, Opportunity> getActionableOpptyDetailsMap(List<Opportunity> updatedOpportunityList, 
            Map<ID, Opportunity> oldOpportunityList, String OppFieldToNotCopy, String OppLineItemFieldsToNotCopy) {

        //Step-10: Put all actionalbe Opportunity-ID's in map for bulk process.
        /// Opportunity is actionalble only if it's stage equals to 'closed won' and 'ready for renewal' flag is checked. 
        String opportunityFields = getDynamicFieldsFROMObject('Opportunity', OppFieldToNotCopy, 'o.');
        String oppLineItemFields = getDynamicFieldsFROMObject('OpportunityLineItem', OppLineItemFieldsToNotCopy, 'l.');
        String oliQuery = ', (SELECT ' + oppLineItemFields + ', PricebookEntry.Product2Id, PricebookEntry.Pricebook2Id, ' +
            'PriceBookEntry.Name, Asset__r.ID FROM OpportunityLineItems l ORDER BY l.Entitlement_End_Date__c) ';
        
        oliQuery += ', (SELECT Id, OpportunityId, UserId, TeamMemberRole, OpportunityAccessLevel FROM OpportunityTeamMembers) ';
        oliQuery += ', (SELECT Id, OpportunityId, AccountToId, Role, IsPrimary, ReversePartnerId FROM OpportunityPartnersFROM) ';
        oliQuery += ', (SELECT Id, OpportunityId, ContactId, Role, IsPrimary FROM OpportunityContactRoles) ';
        oliQuery += ', (SELECT Id, OpportunityId, CompetitorName, Strengths, Weaknesses FROM OpportunityCompetitors) ';
                
        String finalOppQuery = 'SELECT ' + opportunityFields + oliQuery + ' FROM Opportunity o WHERE o.HasOpportunityLineItem = TRUE and o.id IN (';
        System.debug('\n\n ~~~ updatedOpportunityList: ' + updatedOpportunityList);
        String closedWonOppIDs = '';

        for (Opportunity newOpportunity: updatedOpportunityList) {
            Opportunity oldOpportunity = oldOpportunityList.get(newOpportunity.ID);
            System.debug('\n\n ~~~ Ready_For_Renewal__c: ' + newOpportunity.Ready_For_Renewal__c);
            if (newOpportunity.StageName != oldOpportunity.StageName && newOpportunity.StageName == 'Closed Won' && newOpportunity.Ready_For_Renewal__c) {
                closedWonOppIDs += ', \'' + oldOpportunity.ID + '\'';
            }
        }
        
        if (closedWonOppIDs.length() < 2) {
            return null;
        }

        closedWonOppIDs = closedWonOppIDs.substring(2);
        finalOppQuery += closedWonOppIDs + ')';
        System.debug('\n\n ~~~ finalOppQuery: ' + finalOppQuery);
        List<Opportunity> actionableOpptyList = Database.query(finalOppQuery);
        Map<ID, Opportunity> actionableOpptyDetailsMap = new Map<ID, Opportunity>();
        for (Opportunity opp: actionableOpptyList) {
            actionableOpptyDetailsMap.put(opp.id, opp);
        }
        return actionableOpptyDetailsMap;
    }
    
    //This method returns all the fields (in CSV FROMat) FROM given object. 
    //It excludes fields given in fieldsNotToCopy (in CSV format).
    public static String getDynamicFieldsFROMObject(String objectName, String fieldsNotToCopy, String preFix) {
        
        String returnFields = '';
        Map<String, Schema.SObjectField> objectFieldsMap = new Map<String, Schema.SObjectField>(getObjectFieldsMap(objectName));
        
        //Need to remove few fields
        if (fieldsNotToCopy != null && fieldsNotToCopy.length() > 0) {
            List<String> fieldsNotToCopyList = fieldsNotToCopy.split(';', -1);
            for (String f : fieldsNotToCopyList) {
                // Remove fieldsNotToCopy.
                objectFieldsMap.remove(f.toLowerCase());
            }
        }

        for (String f : objectFieldsMap.keySet()) {
            returnFields += preFix + f + ', ';
        }

        if (returnFields.length() > 2) {
            returnFields = returnFields.substring(0, returnFields.length()-2);
        }
        return returnFields;
    }
    
    public static Map<String, Map<String, OpportunityLineItem>> getSplitedLineItemMap(Opportunity opt, Map<ID, Product2> product2Map) {
        /// objective of this routine is to see if we need to create multiple renewal opportunities FROM one source opportunity in case it contains multiple product line items coming to entitlement end at different times
        List <OpportunityLineItem> lineItemsList = opt.OpportunityLineItems;
        String dtFrmt;
        Map<String, OpportunityLineItem> yyyyMMddOpportunityLineItemMap = new Map<String, OpportunityLineItem>();
        Map<String, OpportunityLineItem> yyyyMMddSplitedLineItemMap;
        Map<String, Map<String, OpportunityLineItem>> yyyymmMap = new Map<String, Map<String, OpportunityLineItem>>();
        Datetime dt;  
        Integer EntTerm;
        Date myDate;

        for (OpportunityLineItem lineItem: lineItemsList) {
            //taking out non-renewal products
            if (Product2Map.get(lineItem.PricebookEntry.Product2Id).Use_this_same_product_in_Renewal_Opp__c  == TRUE || 
                    Product2Map.get(lineItem.PricebookEntry.Product2Id).Product_To_Use_In_Renewal__c != NULL) {
                //apply entitlement startdate, end date logic and update entitlement start date, term and end date in lineitem list itself
                if (lineItem.Entitlement_Start_Date__c == null) { 
                    lineItem.Entitlement_Start_Date__c = opt.CloseDate;
                    dt = opt.CloseDate;
                    if (lineItem.Entitlement_Term__c == NULL || lineItem.Entitlement_Term__c == 0) {
                        dt += EntTerm;
                        lineItem.Entitlement_Term__c = EntTerm;
                    } else {
                        dt += (Integer)lineItem.Entitlement_Term__c;
                    }
                } else {
                    dt = lineItem.Entitlement_Start_Date__c;
                    if (lineItem.Entitlement_Term__c == NULL || lineItem.Entitlement_Term__c == 0) {
                        dt += EntTerm;
                        lineItem.Entitlement_Term__c = EntTerm; //eTemplate.Term;
                    } else {
                        system.debug('dt   ' + dt);
                        system.debug('Entitlement End Date  ' + lineItem.Entitlement_End_Date__c);
                        dt = lineItem.Entitlement_End_Date__c;
                        dt = dt.addDays(2); //dt.addMonths((Integer)lineItem.Entitlement_Term__c);
                        system.debug('dt1  ' + dt);
                    }
                }

                if (dt != null) {
                    system.debug('dt2 ' + dt);
                    myDate = date.newinstance(dt.year(), dt.month(), dt.day());
                    system.debug('My Date  ' + myDate);
                    lineItem.Entitlement_End_Date__c = myDate;//Reset correct calculated date.
                    dtFrmt = dt.format('yyyyMMdd') + ':' + lineItem.ID;
                } else {
                    dtFrmt = 'NULL:' + lineItem.ID;
                }
                System.debug('calculated entitlement end date: ' + dtFrmt  );
                yyyyMMddOpportunityLineItemMap.put(dtFrmt,lineItem); 
            }
         
            List<String> keys = new List<String>(yyyyMMddOpportunityLineItemMap.keySet());
            if (keys != null && keys.size()>0) {
                keys.sort();
                for (String keyYYYYmmDD: keys) {
                    OpportunityLineItem lineItemDetail = yyyyMMddOpportunityLineItemMap.get(keyYYYYmmDD);
                    // this is so that when end date falls as like 12-01-2013 00:00:000, it will not translate it to 
                    // year month as 201311 instead it will do correct translation to 201312
                    dt = lineItemDetail.Entitlement_End_Date__c;
                    dt = dt.addHours(5); 
                    if (dt != null) {
                        dtFrmt = dt.format('yyyyMM');
                    } else {
                        dtFrmt ='NULL-DATE';
                    }
                    System.debug('year month: ' + dtFrmt + ' ' + dt );
                    if (yyyymmMap.containsKey(dtFrmt)) {
                        yyyymmMap.get(dtFrmt).put(keyYYYYmmDD,lineItemDetail);
                    } else {
                        yyyyMMddSplitedLineItemMap = new Map<String, OpportunityLineItem>();
                        yyyyMMddSplitedLineItemMap.put(keyYYYYmmDD,lineItemDetail);
                        yyyymmMap.put(dtFrmt,yyyyMMddSplitedLineItemMap);
                    }
                }
            }
        }

        System.debug('\n\n\n~~~~1. yyyymmMap: ' + yyyymmMap.Size() );        
        return yyyymmMap;
    }

    public static void setProductIdFROMOpptyLineItemsStep1(Opportunity oppty, Set<String> productIdSet, Set<ID> assetIdSet) {
        for (OpportunityLineItem lineItem: oppty.OpportunityLineItems) {
            productIdSet.add(lineItem.PricebookEntry.Product2Id);
            if (lineItem.Asset__r.ID != null) {
                assetIdSet.add(lineItem.Asset__r.ID);
            }
            System.debug('\n\n\n~~~~CP1. lineItem: ' + lineItem);
        }
    }
    
    /* //Step-20.2: Retrieve all the useful product-details */
    public static Map<ID, Product2> getProductDetailsMapSetAccountID(List<Opportunity> opptyList, Set<ID> renewableOpptysAccountSet, 
            Set<ID> assetIdSet) {
        Set<String> productIdSet = new Set <String>();
        for (Opportunity oppty: opptyList) {
            if (oppty.AccountId != null) {
                renewableOpptysAccountSet.add(oppty.AccountId);
            }
            OpportunityRenewalHelper.setProductIdFROMOpptyLineItemsStep1(oppty, productIdSet, assetIdSet);
        } 
        if (productIdSet.size()==0) { 
            return null;
        }
        
        //Step-20.2: Retrieve all the useful product-details
        //build renewableProductID set for easier query while retrieving renewal term and all
        List<Product2> renewalProductList = new List<Product2>([
            SELECT p.Product_To_Use_In_Renewal__c 
            FROM Product2 p 
            WHERE p.ID IN :productIdSet AND p.Product_To_Use_In_Renewal__c != NULL]);
        Set<String> renewalProductIdSet = new Set<String>();
        for (Product2 RenewalProduct : renewalProductList) {
            renewalProductIdSet.add(RenewalProduct.Product_To_Use_In_Renewal__c);
        }        
        
        Map<ID, Product2> product2Map = new Map<ID, Product2>([
            SELECT p.Product_To_use_In_Renewal__c, p.ProductCode, p.Name, p.IsActive, p.Id, 
                p.Use_this_same_product_in_Renewal_Opp__c, p.Renewal_Term_Months__c, (
                    SELECT Name FROM Renewal_Opp_Owner_Mappings__r LIMIT 1
                )
             FROM Product2 p 
             WHERE p.id IN :productIdSet OR p.id IN :renewalProductIdSet]
        );

        if (product2Map.size()==0) { 
            return null;
        }
        return product2Map;     
    }

    public static integer getEntitlementTemplate(ID renewableProductID, Map<ID, Product2> product2Map) {        
        //read entitlement term FROM product set-up and store it in variable
        Integer EntTerm;
        system.debug('Map Size: ' + Product2Map.size());  
        system.debug('Product ID: ' + renewableProductID);
        system.debug('ID FROM map: ' + Product2Map.get(renewableProductID).Id);                 
        system.debug('Renewal Term: ' + Product2Map.get(renewableProductID).Renewal_Term_Months__c);
        if (Product2Map.get(renewableProductID).Renewal_Term_Months__c == NULL) {
            EntTerm = 0;
        } else {
            EntTerm = Product2Map.get(renewableProductID).Renewal_Term_Months__c.intValue(); 
        }
       return EntTerm;
    }

    public static ID getProductIDFROMRenewableLineItems(OpportunityLineItem renewableOpptyLineItem, Map<ID, Product2> product2Map) {
        Product2 renewableProduct =  product2Map.get(renewableOpptyLineItem.PricebookEntry.Product2Id);
        if (renewableProduct == null) {
            System.debug('~~~\n\nError:20- For Renewal Product found for Product-ID: ' + renewableOpptyLineItem.PricebookEntry.Product2Id);
            return null;
        }
        ID renewableProductID = renewableProduct.ID;
        if (renewableProduct.Use_this_same_product_in_Renewal_Opp__c != TRUE) {
            if (renewableProduct.Product_To_Use_In_Renewal__c != null) {
                //Pick Different Product to use in Renewal 
                renewableProductID = renewableProduct.Product_To_Use_In_Renewal__c;
                if (product2Map.containsKey(renewableProductID)) {
                    renewableProduct = product2Map.get(renewableProductID);
                }
            }
        }
        return renewableProductID;
    }

    private static PricebookEntry getPricebookEntryData(ID prdID, ID opptyPricebook2Id) {
        List<PricebookEntry> pricebookEntryList = [SELECT p.UnitPrice, p.Product2Id, p.Pricebook2Id, p.Id 
                                                    FROM PricebookEntry p 
                                                    WHERE p.Product2Id = :prdID AND p.Pricebook2Id = :opptyPricebook2Id];
        if (pricebookEntryList == null || pricebookEntryList.size() != 1) {
            System.debug('~~~\n\nError:30- PricebookEntry not/many-records found for Product2Id: ' + prdID);
            return null;
        }
        return pricebookEntryList[0];
    }

    private static OpportunityRenewalWrapper getOpportunityRenewalForFirstLineItem(OpportunityLineItem renewableOpptyLineItem, 
        List<Opportunity> opptyList, Map<ID, Product2> product2Map, Renewal_App_Setup__c rAppSetup, Map<ID, Account> renewableOpptysAccountMap) {
        Opportunity oppty = opptyList[0];
        Date renewedEntitlementEndDate;
        Date sContractStartDate;
        Integer sContractTerm;

        ID prdID = getProductIDFROMRenewableLineItems(renewableOpptyLineItem, product2Map);
        if (prdID == null) {
            System.debug('~~~\n\nError:40- Product ID FROM Renewable Line Items not found for Renewable-ID: ' + renewableOpptyLineItem.ID);
            return null;
        }
        Integer EntTerm;
        EntTerm = getEntitlementTemplate(prdID, Product2Map);
        if (renewableOpptyLineItem.Entitlement_Start_Date__c == null) { 
            renewedEntitlementEndDate = oppty.CloseDate;
            sContractStartDate = oppty.CloseDate;
            if (renewableOpptyLineItem.Entitlement_Term__c == NULL || renewableOpptyLineItem.Entitlement_Term__c == 0) {
               renewedEntitlementEndDate = renewableOpptyLineItem.Entitlement_Start_Date__c.addMonths(EntTerm);
            } else {
                renewedEntitlementEndDate = renewableOpptyLineItem.Entitlement_Start_Date__c.addMonths((Integer)renewableOpptyLineItem.Entitlement_Term__c); // MP - (Long)renewableOpptyLineItem.Entitlement_Term__c;
            }
        } else {
            renewedEntitlementEndDate = renewableOpptyLineItem.Entitlement_Start_Date__c;
            sContractStartDate = renewableOpptyLineItem.Entitlement_Start_Date__c;
            
            if (renewableOpptyLineItem.Entitlement_Term__c == NULL || renewableOpptyLineItem.Entitlement_Term__c == 0) {
                renewedEntitlementEndDate = renewableOpptyLineItem.Entitlement_Start_Date__c.addMonths(EntTerm); //EntTerm; // eTemplate.Term;
            } else {
            system.debug('Renewal Entitlement Term   ' + renewableOpptyLineItem.Entitlement_Term__c);
            system.debug('RenewalEntitlement End Date  ' + renewedEntitlementEndDate);
            system.debug('Renewal Entitlement End Date  ' + renewableOpptyLineItem.Entitlement_Start_Date__c);            
                //renewedEntitlementEndDate = renewableOpptyLineItem.Entitlement_Start_Date__c.addMonths((Integer)renewableOpptyLineItem.Entitlement_Term__c); //(Long)renewableOpptyLineItem.Entitlement_Term__c;
            renewedEntitlementEndDate = renewableOpptyLineItem.Entitlement_End_Date__c;
            system.debug('RenewalEntitlement End Date  ' + renewedEntitlementEndDate);
            }
        }
        
        PricebookEntry pricebookEntryData = getPricebookEntryData(prdID, oppty.Pricebook2Id);
        //Found some data error
        if (pricebookEntryData == null) {
            return null;
        }           
        OpportunityRenewalWrapper oppRenewalWrapper = new OpportunityRenewalWrapper();
        //Step-40
        //Naming logic for Renewal Opps. Example - Source Opp name is 'Test' and it's first renewal occurs on 12/2013
        // Name of first renewal FROM Test is 'Test : Renewal - 12/2013'. Then when renewal of 'Test : Renewal - 12/2013'
        //occurs on 12/2014 - below will name second renewal correctly to 'Test : Renewal - 12/2014'
        String RenewalOppName; 
        String ServiceContractName;
        if (oppty.Name.indexof(':') > 0) {
            RenewalOppName =  oppty.Name.Left(oppty.Name.indexof(':')-1) + ' : '  + rAppSetup.Prefix_for_Renewal_Opportunity_Name__c + ' - ' + renewedEntitlementEndDate.Month() + '/' + renewedEntitlementEndDate.Year();
            ServiceContractName = oppty.Name.Left(oppty.Name.indexof(':')-1) + ' : SC - ' + sContractStartDate.Month() + '/' + sContractStartDate.year() + '-' + renewedEntitlementEndDate.Month() + '/' + renewedEntitlementEndDate.year();
        } else {
            RenewalOppName =  oppty.Name + ' : '  + rAppSetup.Prefix_for_Renewal_Opportunity_Name__c + ' - ' + renewedEntitlementEndDate.Month() + '/' + renewedEntitlementEndDate.Year();                         
            ServiceContractName = oppty.Name + ' : SC - ' + sContractStartDate.Month() + '/' + sContractStartDate.year() + '-' + renewedEntitlementEndDate.Month() + '/' + renewedEntitlementEndDate.year();
        } 

        Opportunity renewedOppty = oppty.clone(false,true);
        
        if (oppty.Co_Term_With__c == NULL) {            
                renewedOppty.Name = RenewalOppName;
                // current colsed-won Opportunity ID as source opp for renewal opp to be created
                renewedOppty.Originating_Opportunity__c = oppty.ID; 
                renewedOppty.Type = rAppSetup.Renewal_Opportunity_Type__c;
                renewedOppty.StageName = rAppSetup.Renewal_Stage__c; 
                renewedOppty.AccountId = oppty.AccountId; 
                renewedOppty.CloseDate = renewedEntitlementEndDate; 
                system.debug('Renewed Opp Close Date  ' + renewedOppty.CloseDate); //MP
                renewedOppty.contact__c = oppty.contact__c;
                if (rAppSetUp.Renewal_Opportunity_Owner__c == 'Account Owner of Acct tied to Renewal') { 
                    //Original A/c owner of source oppty
                    renewedOppty.OwnerId = renewableOpptysAccountMap.get(oppty.AccountId).OwnerId; 
                } else if (rAppSetUp.Renewal_Opportunity_Owner__c == 'Same as Source Opportunity Owner') {
                    renewedOppty.OwnerId = oppty.OwnerId;
                } else {
                    renewedOppty.OwnerId = rAppSetUp.User__c;
                }
                //setting renewal record type for renewal opp
                renewedOppty.RecordTypeID = getRenewalOpportunityRecordType(oppty.RecordTypeID); 
                renewedOppty.Co_Term_With__c = NULL;
                //re-using this field that was added with contract based renewal to store original renewal close date so 
                // that Renewal Period formula works as-is
                renewedOppty.Original_Term_Expiration_Date__c = renewedEntitlementEndDate; 
                renewedOppty.Ready_For_Renewal__c = false;
                renewedOppty.Upgrade_Downgrade_Reason__c = NULL;
                oppRenewalWrapper.opportunityObj = renewedOppty;
        } else {
            //Find ID of Renewal Opp that has already been created for Co_Term_With Opp
           // No cloning is needed here as when this was created originally, it was cloned.
           //need to compare just months and year here for Close_Date and EntitlementEndDate
   /*        String oppLineItemFields = getDynamicFieldsFROMObject('OpportunityLineItem', '', 'l.');
           String oliQuery = ', (SELECT ' + oppLineItemFields + ', PricebookEntry.Product2Id, PricebookEntry.Pricebook2Id, ' +
            'PriceBookEntry.Name, Asset__r.ID FROM OpportunityLineItems l ORDER BY l.Entitlement_End_Date__c) ';
           
           String ExistingRenewalOppQuery = 'SELECT Id, Name, Type, StageName, AccountID, CloseDate, contact__c, OwnerId, RecordTypeID,';
           ExistingRenewalOppQuery += 'Base_Line_Amount__c, Amount, isClosed ' + oliQuery + ' FROM Opportunity WHERE Id IN (';
           ExistingRenewalOppQuery += 'SELECT Renewal_Opp__c FROM Source_Opp_Mapping__c WHERE Source_Opp__c = ' + oppty.Co_Term_With__c + ')';
            system.debug(' Existing Renewal Opp Query  ' + ExistingRenewalOppQuery); */
           //ExistingRenewalOppQuery += 'SELECT Renewal_Opp__c FROM Source_Opp_Mapping__c WHERE Source_Opp__c = :' + oppty.Co_Term_With__c + 'AND (Close_Date__c = :' + renewedEntitlementEndDate + ' OR Close_Date__c < :' + renewedEntitlementEndDate + '))';
           
                
           system.debug('RenewalCo-TermEndDate  ' + renewedEntitlementEndDate);
            //List<Opportunity> ExistingRenewedOpp = new List<Opportunity>(); //[
            oppRenewalWrapper.RenewedOpportunityObjList = [SELECT Id, Name, Type, StageName, AccountID, CloseDate, contact__c, OwnerId, RecordTypeID, 
                    Base_Line_Amount__c, Amount, isClosed 
                FROM Opportunity WHERE Id IN (
                    SELECT Renewal_Opp__c 
                    FROM Source_Opp_Mapping__c 
                    WHERE Source_Opp__c = :oppty.Co_Term_With__c AND (Close_Date__c = :renewedEntitlementEndDate OR Close_Date__c < :renewedEntitlementEndDate)
                )
            ]; 

system.debug('ExistingRenewedOpp::'+oppRenewalWrapper.RenewedOpportunityObjList);            
            if (oppRenewalWrapper.RenewedOpportunityObjList == null || oppRenewalWrapper.RenewedOpportunityObjList.size() < 1) {
                System.debug('\n\nERROR: Please make sure that source opportunity with which this add-on is co-termed with is closed and renewal opp created FROM closure of source opp has not been deleted.\n');
                //throw new InvalidOperationException('<p/>Please make sure that source opportunity with which this add-on is co-termed with is closed and renewal opp created FROM closure of source opp has not been deleted.<p/>'); 
            } else {
                // if open, then continue, otherwise create new oppty, like on the line 347.
                if (oppRenewalWrapper.RenewedOpportunityObjList[0].isClosed) {
                    renewedOppty.Name = RenewalOppName;
                    // current colsed-won Opportunity ID as source opp for renewal opp to be created
                    
                    // TODO: Temp fix
                    
                    // TODO: Do we need to copy from renewal or from the original? AccountId, OwnerId, RecordTypeID
                    renewedOppty.Originating_Opportunity__c = oppty.Id; 
                    
                    renewedOppty.Type = rAppSetup.Renewal_Opportunity_Type__c;
                    renewedOppty.StageName = rAppSetup.Renewal_Stage__c; 
                    renewedOppty.AccountId = oppty.AccountId; 
                    renewedOppty.CloseDate = renewedEntitlementEndDate; 
                    renewedOppty.contact__c = oppty.contact__c;
                    if (rAppSetUp.Renewal_Opportunity_Owner__c == 'Account Owner of Acct tied to Renewal') { 
                        //Original A/c owner of source oppty
                        renewedOppty.OwnerId = renewableOpptysAccountMap.get(oppty.AccountId).OwnerId; 
                    } else if (rAppSetUp.Renewal_Opportunity_Owner__c == 'Same as Source Opportunity Owner') {
                        renewedOppty.OwnerId = oppty.OwnerId;
                    } else {
                        renewedOppty.OwnerId = rAppSetUp.User__c;
                    }
                    //setting renewal record type for renewal opp
                    renewedOppty.RecordTypeID = getRenewalOpportunityRecordType(oppty.RecordTypeID); 
                    renewedOppty.Co_Term_With__c = NULL;
                    renewedOppty.Is_Add_on_Opportunity__c = NULL;
                    //re-using this field that was added with contract based renewal to store original renewal close date
                    // so that Renewal Period formula works as-is
                    renewedOppty.Original_Term_Expiration_Date__c = renewedEntitlementEndDate; 
                    //renewedOppty.Mark_Up__c = oppty.Mark_Up__c;
                    renewedOppty.Ready_For_Renewal__c = false;
                    renewedOppty.Upgrade_Downgrade_Reason__c = NULL;
                    oppRenewalWrapper.opportunityObj = renewedOppty;   

                    system.debug('renewedOppty::'+renewedOppty);
                } else {
                    Opportunity AlreadyExistingRenewedOpp = new Opportunity (
                        Id = oppRenewalWrapper.RenewedOpportunityObjList[0].Id,
                        Name = oppRenewalWrapper.RenewedOpportunityObjList[0].Name,
                        // this is a renewal of co-termed opp, so originating opp here is the co-termed with opp
                        Originating_Opportunity__c = oppty.Id,
                        Type = oppRenewalWrapper.RenewedOpportunityObjList[0].Type,
                        StageName = oppRenewalWrapper.RenewedOpportunityObjList[0].StageName, 
                        AccountId = oppRenewalWrapper.RenewedOpportunityObjList[0].AccountId, 
                        CloseDate = oppRenewalWrapper.RenewedOpportunityObjList[0].CloseDate,
                        contact__c = oppRenewalWrapper.RenewedOpportunityObjList[0].contact__c,
                        //Original A/c owner of source oppty
                        OwnerId = oppRenewalWrapper.RenewedOpportunityObjList[0].OwnerId, 
                        //setting renewal record type for renewal opp
                        RecordTypeID = oppRenewalWrapper.RenewedOpportunityObjList[0].RecordTypeID, 
                        //oppty.Co_Term_With__c NO need to set co-term with for renewal opp, this affects trigger on 
                        //Opportunity Line Item object which does entitlement date calculations and all
                        Co_Term_With__c = NULL, 
                        // re-using this field that was added with contract based renewal to store original renewal close 
                        // date so that Renewal Period formula works as-is
                        Original_Term_Expiration_Date__c = oppRenewalWrapper.RenewedOpportunityObjList[0].CloseDate, 
                        //adding Base Line Amount so that when renewal is appended for co-term it gets set correctly
                        Base_Line_Amount__c = oppRenewalWrapper.RenewedOpportunityObjList[0].Amount, //Base_Line_Amount__c 
                        Amount = oppRenewalWrapper.RenewedOpportunityObjList[0].Amount
                    );                
                    oppRenewalWrapper.opportunityObj = AlreadyExistingRenewedOpp;   
                }

            }
        }
        system.debug('renewedOppty::'+renewedOppty);
        oppRenewalWrapper.prductIdFirst = prdID;
        return oppRenewalWrapper;
    }
//============================================================Main iteration===================

    public static OpportunityRenewalWrapper getRenewableLineItemWithOpportunity (
        Map<String, OpportunityLineItem> renewableOpptyLineItemBunch,
        List<Opportunity> opptyList, 
        Map<ID, Product2> product2Map,
        Map<ID, Account> renewableOpptysAccountMap,
        Renewal_App_Setup__c rAppSetup,
        Map<ID, Asset> assetObjMap
    ) {
        Opportunity oppty = opptyList[0];
        System.debug('\n\n\n~~~~1. Opportunity: ' + oppty.Name + ' with no. of OpportunityLineItem: ' + renewableOpptyLineItemBunch.size());
        if (renewableOpptyLineItemBunch == null || renewableOpptyLineItemBunch.size()==0) {
            System.debug('~~~~1.0. No OpportunityLineItem found for Opportunity: ' + oppty.Name);
            return null;
        }
        OpportunityRenewalWrapper oppRenewalWrapper;
        OpportunityLineItem renewableOpptyLineItem;
        List<String> keyYYYYmmDDList = new List<String>(renewableOpptyLineItemBunch.keySet());
        Map<String, OpportunityLineItem> ProductMapOfRenewedOpportunityLineItems = new Map<String, OpportunityLineItem>();
        keyYYYYmmDDList.sort();
        for (String oliKey: keyYYYYmmDDList) {
            System.debug('~~~~1.0.1 ent end test: ' + oliKey);
            renewableOpptyLineItem = renewableOpptyLineItemBunch.get(oliKey);
            if (oppRenewalWrapper == null) {//For first renewableOpptyLineItem
                // Creates oppty record.               
                oppRenewalWrapper = getOpportunityRenewalForFirstLineItem(renewableOpptyLineItem, new List<Opportunity>{oppty}, product2Map, rAppSetup, renewableOpptysAccountMap); 
                //Found some data error
                if (oppRenewalWrapper == null) {
                    return null;
                }
            }
            
            ID prdID = getProductIDFROMRenewableLineItems(renewableOpptyLineItem, product2Map);
            if (prdID == null) {
                System.debug('~~~1.0.2. Product ID FROM Renewable Line Items not found for Renewable-ID: ' + renewableOpptyLineItem.ID );
                return null;
            }
            
            PricebookEntry pricebookEntryData = getPricebookEntryData(prdID, oppty.Pricebook2Id);
            if (pricebookEntryData == null) {//Found some data error
                return null;
            }
            Integer EntTerm;
            EntTerm =  getEntitlementTemplate(prdID, Product2Map);
            if (oppRenewalWrapper.RenewedOpportunityObjList != null && oppRenewalWrapper.RenewedOpportunityObjList.size() > 0){
               //String oppLineItemFields = getDynamicFieldsFROMObject('OpportunityLineItem', '', 'l.');
               //String oliQuery = 'SELECT ' + oppLineItemFields + ', PricebookEntry.Product2Id, PricebookEntry.Pricebook2Id, ';
               //oliQuery += 'PriceBookEntry.Name, Asset__r.ID FROM OpportunityLineItems l Where OpportunityId IN (' + oppRenewalWrapper.RenewedOpportunityObjList[0].Id + ')' ;
                
               oppRenewalWrapper.RenewedOpportunityLineItemObjList = [Select Id, Quantity, UnitPrice, OpportunityId, Product2Id, PricebookEntry.Product2Id, PricebookEntry.Pricebook2Id, Entitlement_Start_Date__c, Entitlement_Term__c, Entitlement_End_Date__c From OpportunityLineItem Where OpportunityId = :oppRenewalWrapper.RenewedOpportunityObjList[0].Id]; 
               system.debug('Renewed Opportunity Line Items ' + oppRenewalWrapper.RenewedOpportunityLineItemObjList);   
               If (oppRenewalWrapper.RenewedOpportunityLineItemObjList != NULL && oppRenewalWrapper.RenewedOpportunityLineItemObjList.Size() > 0){
                   for(OpportunityLineItem RenewedOppLineItems : oppRenewalWrapper.RenewedOpportunityLineItemObjList){
                       ProductMapOfRenewedOpportunityLineItems.put(RenewedOppLineItems.Product2Id, RenewedOppLineItems);
                   }
               } 
               system.debug('Renewed Opportunity Line Items Map ' + ProductMapOfRenewedOpportunityLineItems); 
               If(ProductMapOfRenewedOpportunityLineItems.containsKey(prdID)){
                   
                   OpportunityLineItem AlreadyExistingRenewedLineItem = new OpportunityLineItem (
                        Id = ProductMapOfRenewedOpportunityLineItems.get(prdID).Id,
                        Quantity = ProductMapOfRenewedOpportunityLineItems.get(prdID).Quantity + renewableOpptyLineItem.Quantity,
                        UnitPrice = ProductMapOfRenewedOpportunityLineItems.get(prdID).UnitPrice,
                        OpportunityId = ProductMapOfRenewedOpportunityLineItems.get(prdID).OpportunityId,
                        Entitlement_Term__c = ProductMapOfRenewedOpportunityLineItems.get(prdID).Entitlement_Term__c
                        );
                   oppRenewalWrapper.opportunityLineItemObjList.add(AlreadyExistingRenewedLineItem);     
                  system.debug('Same Product Exists' + AlreadyExistingRenewedLineItem);
               } else {
                   EntTerm = oppRenewalWrapper.RenewedOpportunityLineItemObjList[0].Entitlement_Term__c.intValue();
                    //Step-60
                    // Creates opptyline itemes.
                    OpportunityLineItem newProduct = renewableOpptyLineItem.clone(false,true); 
                    newProduct.ServiceDate = oppRenewalWrapper.opportunityObj.closeDate; 
                    newProduct.OpportunityId = oppRenewalWrapper.RenewedOpportunityObjList[0].Id;
                    newProduct.Originating_Opportunity__c = oppty.ID;           
                    newProduct.PricebookEntryId = pricebookEntryData.Id;
                    newProduct.TotalPrice = NULL; 
                    if (renewableOpptyLineItem.PricebookEntry.Product2Id != prdID) { //on Co-Term also copy discounts || oppty.Co_Term_With__c != NULL) {
                        // copy price FROM pricebook when product being added is different
                        newProduct.UnitPrice = pricebookEntryData.UnitPrice;
                    } else {
                        // set it FROM Original OppLineItem so that sales price calculated based on cost, mark-up, 
                        // list pricce FROM OpportunityLineItem trigger gets carried forward in renewal opportunitypricebookEntryData.UnitPrice;                
                        newProduct.UnitPrice = renewableOpptyLineItem.Sales_Price_Per_Unit_Per_Ent_Term__c; //renewableOpptyLineItem.UnitPrice; // 
                    }          
                    //copying entitlement end date to start date
                    newProduct.Entitlement_Start_Date__c = renewableOpptyLineItem.Entitlement_End_Date__c; //.addDays(1);
                    system.debug('Opp Line Item Start Date ' + newProduct.Entitlement_Start_Date__c); //MP
                    If (oppty.Co_Term_With__c != NULL) { 
                        newProduct.Entitlement_Term__c = EntTerm; //set entitlement term as defined in product set-up from a co-termed Opportunity
                        system.debug('Entitlement Term  ' + newProduct.Entitlement_Term__c);
                    }
                    /// set entitlement term and entitlement end date for Lithium's custom logic here - read custom field FROM oppty
                    newProduct.Entitlement_End_Date__c = newProduct.Entitlement_Start_Date__c.addMonths(EntTerm);
                    newProduct.Entitlement_End_Date__c = newProduct.Entitlement_End_Date__c.addDays(-1);
                    system.debug('Entitlement End Date  ' + newProduct.Entitlement_End_Date__c);
                    String renuwedProductURL = URL.getSalesforceBaseUrl().toExternalForm() + '/' + renewableOpptyLineItem.ID;
                    newProduct.Opportunity_LineItem_ID__c = renewableOpptyLineItem.ID;
                    newProduct.Opportunity_LineItem_URL__c = renuwedProductURL;
                    if (renewableOpptyLineItem.Is_asset__c == TRUE) {
                        if (assetObjMap.containsKey(renewableOpptyLineItem.ID) && assetObjMap.get(renewableOpptyLineItem.ID).ID == null) {
                            assetObjMap.remove(renewableOpptyLineItem.ID);//Asset is already created no need to recreate.
                        }
                    } else if (assetObjMap.containsKey(renewableOpptyLineItem.ID)) {
                        newProduct.Is_asset__c = TRUE;
                    } else {
                        System.debug('~~~1.0.3. Some logical error while setting Asset data for renewableOpptyLineItem:' + renewableOpptyLineItem.ID );
                    }
                    oppRenewalWrapper.opportunityLineItemObjList.add(newProduct);
                }     
            } else {
                    OpportunityLineItem newProduct = renewableOpptyLineItem.clone(false,true); 
                    newProduct.ServiceDate = oppRenewalWrapper.opportunityObj.closeDate; 
                    newProduct.Originating_Opportunity__c = oppty.ID;           
                    newProduct.PricebookEntryId = pricebookEntryData.Id;
                    newProduct.TotalPrice = NULL; 
                    if (renewableOpptyLineItem.PricebookEntry.Product2Id != prdID) { //on Co-Term also copy discounts || oppty.Co_Term_With__c != NULL) {
                        // copy price FROM pricebook when product being added is different
                        newProduct.UnitPrice = pricebookEntryData.UnitPrice;
                    } else {
                        // set it FROM Original OppLineItem so that sales price calculated based on cost, mark-up, 
                        // list pricce FROM OpportunityLineItem trigger gets carried forward in renewal opportunitypricebookEntryData.UnitPrice;                
                        newProduct.UnitPrice = renewableOpptyLineItem.Sales_Price_Per_Unit_Per_Ent_Term__c; //renewableOpptyLineItem.UnitPrice; // 
                    }          
                    //copying entitlement end date to start date
                    newProduct.Entitlement_Start_Date__c = renewableOpptyLineItem.Entitlement_End_Date__c; //.addDays(1);
                    system.debug('Opp Line Item Start Date ' + newProduct.Entitlement_Start_Date__c); //MP
                    If (oppty.Co_Term_With__c != NULL) { 
                        newProduct.Entitlement_Term__c = EntTerm; //set entitlement term as defined in product set-up from a co-termed Opportunity
                        system.debug('Entitlement Term  ' + newProduct.Entitlement_Term__c);
                    }
                    /// set entitlement term and entitlement end date for Lithium's custom logic here - read custom field FROM oppty
                    newProduct.Entitlement_End_Date__c = newProduct.Entitlement_Start_Date__c.addMonths(EntTerm);
                    newProduct.Entitlement_End_Date__c = newProduct.Entitlement_End_Date__c.addDays(-1);
                    system.debug('Entitlement End Date  ' + newProduct.Entitlement_End_Date__c);
                    String renuwedProductURL = URL.getSalesforceBaseUrl().toExternalForm() + '/' + renewableOpptyLineItem.ID;
                    newProduct.Opportunity_LineItem_ID__c = renewableOpptyLineItem.ID;
                    newProduct.Opportunity_LineItem_URL__c = renuwedProductURL;
                    if (renewableOpptyLineItem.Is_asset__c == TRUE) {
                        if (assetObjMap.containsKey(renewableOpptyLineItem.ID) && assetObjMap.get(renewableOpptyLineItem.ID).ID == null) {
                            assetObjMap.remove(renewableOpptyLineItem.ID);//Asset is already created no need to recreate.
                        }
                    } else if (assetObjMap.containsKey(renewableOpptyLineItem.ID)) {
                        newProduct.Is_asset__c = TRUE;
                    } else {
                        System.debug('~~~1.0.3. Some logical error while setting Asset data for renewableOpptyLineItem:' + renewableOpptyLineItem.ID );
                    }
                    oppRenewalWrapper.opportunityLineItemObjList.add(newProduct);
           }            

        }
        return oppRenewalWrapper;
    }

    /** This method will add new Assets object against OpportunityLineItem-ID in input-param assetObjMap  */
    public static void setAssetsLineItemOfOpportunity(Opportunity originalOppty, Map<ID, Asset> assetObjMap, 
        Map<ID, Asset> availableAssetObjMap) {
        for (OpportunityLineItem oli: originalOppty.OpportunityLineItems) {
            Asset assetObj;
             if (oli.Is_asset__c != TRUE ) {
                /*Asset Info*/
                //one assect for each OpportunityLineItem
                assetObj = new Asset();
                //Asset name to be same as product name 
                assetObj.Name = oli.PriceBookEntry.Name; 
                //changed purchase_Opp__c to Source_Opp__c in order to not conflict with ProductToAssetConvertor App
                assetObj.Source_Opp__c = originalOppty.ID; 
                assetObj.ContactId = originalOppty.contact__c; 
                assetObj.Product2Id = oli.pricebookEntry.Product2Id;
                assetObj.Quantity = oli.Quantity;
                // keep unit price to be same as for original product
                assetObj.Price = oli.UnitPrice; 
                assetObj.AccountId = originalOppty.AccountId;
                assetObj.UsageEndDate = oli.Entitlement_End_Date__c;
                assetObj.Originating_LineItem_ID__c = oli.ID;
                assetObj.Originating_Opportunity_LineItem_URL__c = URL.getSalesforceBaseUrl().toExternalForm() + '/' + oli.ID; 
                //apply below logic to pick install date for asset
                if (oli.Asset_Install_Date__c != NULL) {
                    assetObj.InstallDate = oli.Asset_Install_Date__c;
                } else {
                    assetObj.InstallDate = oli.Entitlement_Start_Date__c;
                }
                assetObj.Entitlement_Start_Date__c = oli.Entitlement_Start_Date__c;
                assetObj.Entitlement_Term__c = oli.Entitlement_Term__c;
                assetObj.Entitlement_End_Date__c = oli.Entitlement_End_Date__c;                
                assetObjMap.put(oli.ID, assetObj);
            } else {
                if (availableAssetObjMap.containsKey(oli.Asset__c)) {
                    assetObj = availableAssetObjMap.get(oli.Asset__c);
                    assetObj.Quantity = oli.Quantity;
                    assetObj.UsageEndDate = oli.Entitlement_End_Date__c;
                    assetObj.Originating_LineItem_ID__c = oli.ID;
                    assetObj.Entitlement_Term__c = oli.Entitlement_Term__c;
                    assetObj.Entitlement_End_Date__c = oli.Entitlement_End_Date__c;
                    assetObj.Price = oli.UnitPrice; // Take the price from Renewal Opportunity in case entitlement term has changed -- IDIOP change as per Ryan's email on Oct 21 2014
                    assetObjMap.put(oli.ID, assetObj);
                }
            }
        }
        system.debug('asset object map  ' + assetObjMap);
    }

    /** This method will reset renewal Opportunity for Assets in input-param assetObjMap  */
    public static void reSetAssetsLineItemOfOpportunity(Opportunity originalOppty, Opportunity renewedOpty, 
        Map<ID, Asset> assetObjMap, Map<ID, Product2> product2Map) {
        if (originalOppty != null) {
            for (OpportunityLineItem oli: originalOppty.OpportunityLineItems) {
                Asset assetObj = assetObjMap.get(oli.ID);
                 if (assetObj != null) {
                    Product2 oProduct =  product2Map.get(oli.PricebookEntry.Product2Id);
                    //Not to tie asset to renewal opp when it is for non-renewable products
                    if (oProduct.Use_this_same_product_in_Renewal_Opp__c == TRUE || oProduct.Product_To_Use_In_Renewal__c != null) {
                        // changed Renewal_Opportunity__c to Renewal_Opp__c to not conflict with ProductToAssetConvertor App
                        assetObj.Renewal_Opp__c = renewedOpty.ID; 
                    }
                }
            }
        }
    }

    /** This method will clone the Opportunities' OpportunityTeamMember  oojects and assigned to renewed Opportunity. */
    public static void setClonedOpportunityTeamMembers(Opportunity originalOppty, Opportunity renewedOpty, 
        List<OpportunityTeamMember> finalList) {
        OpportunityTeamMember cloned;
        if (originalOppty !=null) {
            for (OpportunityTeamMember clonableObj: originalOppty.OpportunityTeamMembers) {
                cloned = clonableObj.clone();
                cloned.OpportunityId = renewedOpty.ID;
                finalList.add(cloned);
            }
        }
    }
    
    /** This method will clone the Opportunities' OpportunityPartnersFROM  oojects and assigned to renewed Opportunity. */
    public static void setClonedOpportunityPartners(Opportunity originalOppty, Opportunity renewedOpty, List<OpportunityPartner> finalList) {
        OpportunityPartner cloned;
        if (originalOppty != null) {
            for (OpportunityPartner clonableObj: originalOppty.OpportunityPartnersFROM) {
                cloned = clonableObj.clone();
                finalList.add(cloned);
            }
        }
    }

    /** This method will clone the Opportunities' OpportunityContactRole  oojects and assigned to renewed Opportunity. */
    public static void setClonedOpportunityContactRoles(Opportunity originalOppty, Opportunity renewedOpty, List<OpportunityContactRole> finalList) {
        OpportunityContactRole cloned;
        if (originalOppty != null) {        
            for (OpportunityContactRole clonableObj: originalOppty.OpportunityContactRoles) {
                cloned = clonableObj.clone();
                cloned.OpportunityId = renewedOpty.ID;
                finalList.add(cloned);
            }
        }
    }
    /** This method will clone the Opportunities' OpportunityCompetitor  oojects and assigned to renewed Opportunity. */
    public static void setClonedOpportunityCompetitors(Opportunity originalOppty, Opportunity renewedOpty, List<OpportunityCompetitor> finalList) {
        OpportunityCompetitor cloned;
        if (originalOppty != null) {
            for (OpportunityCompetitor clonableObj: originalOppty.OpportunityCompetitors) {
                cloned = clonableObj.clone();
                cloned.OpportunityId = renewedOpty.ID;
                finalList.add(cloned);
            }
        }
    }

    /******************************************************
     * Retrieve meta-data fields name FROM SObject
     ******************************************************/
    public static String getObjectFields(Map<String, Schema.SObjectField> fieldsMap) {
        String ssql = '';
        Boolean bfirst = true;
        for (String fieldName:fieldsMap.keySet()) {
            if (bfirst) {
                ssql = fieldName;
                bfirst = false;
            } else {
                ssql = ssql + ',' + fieldName;
            } 
        }
        return ssql;        
    } 

    /******************************************************
     * Create Map for SObject field names
     ******************************************************/  
    private static Map<String, Schema.SObjectType> gd = null;  
    public static Map<String, Schema.SObjectField> getObjectFieldsMap(String objectName) {
        //get global describe
        if (gd == null) {
            gd = Schema.getGlobalDescribe(); 
        }
        //get token to an sobject    
        Schema.sObjectType t = gd.get(objectName);
        Map<String, Schema.SObjectField> fieldsMap = t.getDescribe().fields.getMap();
        return fieldsMap;        
      }
          
    /******************************************************
     * Construct and build sql statement based on the fields name,
     * object name, and criteria.
     ******************************************************/
    public static String buildSQLStatement(String fields, String objectName, String criteria) {
        String sql = 'SELECT ' + fields + ' FROM ' + objectName + (criteria != null && !''.equals(criteria) ? criteria : '');
        System.debug('buildSQLStatement sql: ' + sql);
        System.debug('\n\n Query: ' + sql);     
        return sql;
    } 
}