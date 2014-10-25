/**
 * Copyright (c) 2014 Comity Designs
 * All rights reserved.
 *
 * This class is an Opportunity trigger handler class for the Renewal Manager.
 *
 * History:
 * =========================================
 * Developer         Date        description
 * --------------------------------------------------------------------------------------------------
 * Ivan Melnikov     07/30/2014  Code refactoring 
 *
 * 
 **/
public with sharing class OpportunityTriggerHandler {
    public static void opportunityAfterUpdateHandler(List<Opportunity> newOpptyList, Map<Id, Opportunity> oldOpptyMap) {
        Map<ID, Opportunity> actionableOpptyDetailsMap = null;
        try {
            Map<String, OpportunityRenewalWrapper> opptyRenewalWrapperMap = new Map<String, OpportunityRenewalWrapper>();
            Map<String,Opportunity> renewedOpptyMap   = new Map<String,Opportunity>();
            List<OpportunityLineItem> renewedOpptyProductList   = new List<OpportunityLineItem>();
            List<Source_Opp_Mapping__c> sourceRenewedOpptyMappingList= new List<Source_Opp_Mapping__c>();
            Set<ID> renewableOpptysAccountSet = new Set<ID>(); 

            /* Retrieve Renewal_App_Setup details. There will be only one record in this object */
            //Read asset and entitlement creation flag setting as well in below query
            //modified to include Renewal_Record_Type_Name__c so that record type can be found based on this.
            List<Renewal_App_Setup__c> rAppSetupList = [
                SELECT r.ID, r.Prefix_for_Renewal_Opportunity_Name__c, r.Renewal_Stage__c, r.Renewal_Opportunity_Type__c, r.Asset__c, 
                    r.Opportunity_Field_To_Not_Copy_on_Renewal__c, r.Opportunity_Product_Fields_To_Not_Copy__c, r.Renewal_Opportunity_Owner__c, 
                    r.User__c, Clone_Competitors_Related_List__c, Clone_Contact_Roles__c, Clone_Opp_Team_Related_List__c 
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

                          
            //Step-10: Put all actionable Opportunity-ID's in map for bulk process. check where opp status has changed to 'closedwon' or not
            //Step-20.1 Retrieve all actionable Opportunities details and put them in map for bulk process. 
            /*Creating a map of all actionable opportunity line items when opportunity stage has changed to 'closedwon'
            Below map stores all opportunity line items of source opportunity where product tied to source opportunity line item
            is renewable based on looking at set-up of that product in Product2 object */
            actionableOpptyDetailsMap = OpportunityRenewalHelper.getActionableOpptyDetailsMap(newOpptyList, 
                oldOpptyMap, rAppSetup.Opportunity_Field_To_Not_Copy_on_Renewal__c, rAppSetup.Opportunity_Product_Fields_To_Not_Copy__c);
            
            if (actionableOpptyDetailsMap == null || actionableOpptyDetailsMap.size()==0) { 
                System.debug(LoggingLevel.INFO,'\n\n~~~:- actionableOpptyDetailsMap has no records...');
                return; 
            }

            /*Get all the useful product-ID's and A/c ID's */     
            //Step-20.2: Retrieve all the useful Renewable product-details from source opportunity
            //Creating map of all renewal products to use in renewal opportunity line items based on set-up of products on
            //source opportunity line item. Also creating map of account ids from source opportunity
            Set<ID> assetIdSet = new Set<ID>();
            Map<ID, Product2> product2Map = OpportunityRenewalHelper.getProductDetailsMapSetAccountID(
                actionableOpptyDetailsMap.values(), renewableOpptysAccountSet, assetIdSet);
            if (product2Map == null || product2Map.size()==0) {
                System.debug(LoggingLevel.INFO,'\n\n~~~:- product2Map has no records...');
                return;        
            }

            //Read source opportunity account info such as acct owner, acct type, acct shipping country
            Map<ID, Account> renewableOpptysAccountMap = new Map<ID, Account>([
                SELECT a.OwnerId, a.Id, a.Type, a.ShippingCountry 
                FROM Account a 
                WHERE a.id in :renewableOpptysAccountSet
            ]);
            Map<ID, Asset> availableAssetObjMap = new Map<ID, Asset>();
            if (assetIdSet.size() > 0) {
                availableAssetObjMap = new Map<ID, Asset>([
                    SELECT Id, Quantity 
                    FROM Asset 
                    WHERE Id IN :assetIdSet 
                ]);
            }

            //START: - Data setup for bulk process, 
            Integer iCount = 0;
            /* To add new Assets objects against original OpportunityLineItem-ID as key */
            Map<ID, Asset> assetObjMap = new Map<ID, Asset>();
            for (Opportunity oppty: actionableOpptyDetailsMap.values()) {  
                if (rAppSetup.Asset__c == True) {
                    OpportunityRenewalHelper.setAssetsLineItemOfOpportunity(oppty, assetObjMap, availableAssetObjMap);
                } 
                //Applying entitlement template setting from product set-up tied to opportunity product line
                //calculating entitlement start date, term, end date
                //creating 'YYYYMM' key for each source opportunity line item based on calculated entitlement end date
                //passing Product2Map to read renewal term from it
                Map<String, Map<String, OpportunityLineItem>> splitedLineItemMap =  OpportunityRenewalHelper.getSplitedLineItemMap(oppty, product2Map); 

                //START: - Data setup for selected OpportunityLineItems 
                //for each distinct 'YYYYMM' key from opp line items, a separate renewal opp will be created            
                for (Map<String, OpportunityLineItem> renewableOpptyLineItemBunch: splitedLineItemMap.values()) {
                    //creating oppRenewalWrapper which contains Opportunity Obj, List of OppLineItems, ServiceContract Obj
                    //list of entitlement, list of service contract line items
                    OpportunityRenewalWrapper oppRenewalWrapper = null;
                    try {
                        oppRenewalWrapper = OpportunityRenewalHelper.getRenewableLineItemWithOpportunity(
                            renewableOpptyLineItemBunch, new List<Opportunity>{oppty}, product2Map, renewableOpptysAccountMap, rAppSetup, assetObjMap);
                    } catch(InvalidOperationException e) {
                        if (actionableOpptyDetailsMap.size() == 1) {
                            throw e;
                        } 
                    }
                    if (oppRenewalWrapper == null) {
                        continue;
                    }
                    //Set all the data in opptyRenewalWrapperMap for later use.
                    if (oppRenewalWrapper.opportunityObj != null) {
                        opptyRenewalWrapperMap.put(''+iCount, oppRenewalWrapper);
                        renewedOpptyMap.put(''+iCount, oppRenewalWrapper.opportunityObj);
                        iCount++;   
                    }
                }
                //END: - Data setup for selected OpportunityLineItems 
            }
            //END: - Data setup for bulk process, 
            // No records found for new renewable.
            system.debug('renewedOpptyMap:'+renewedOpptyMap);
            if (renewedOpptyMap.size() == 0) {
                return; 
            } 
            upsert renewedOpptyMap.values();
            List <OpportunityTeamMember> bulkListOpportunityTeamMember = new List<OpportunityTeamMember>();
            List <OpportunityPartner> bulkListOpportunityPartner = new List<OpportunityPartner>();
            List <OpportunityContactRole> bulkListOpportunityContactRole = new List<OpportunityContactRole>();
            List <OpportunityCompetitor> bulkListOpportunityCompetitor = new List<OpportunityCompetitor>();

system.debug('renewedOpptyMap::'+renewedOpptyMap);
            List<ID> OpportunityIDs = new List<ID>();
            //Step-50 + 60: Create old and new Opportunities mapping
            for (String iCounter: renewedOpptyMap.keySet()) {
                Opportunity renewedOpty = renewedOpptyMap.get(iCounter);
                OpportunityIDs.add(renewedOpty.Id);
                System.debug('\n\n' + iCounter + '.~~~~SUCCESS: Renewed Opportunity created: ' + renewedOpty.Name);
                
                /* Create a list for Source-Renewed-Oppty-Mapping-List */
                //it's not an add-on
system.debug('renewedOpty::'+renewedOpty);                
                if (renewedOpty.Co_Term_With__c == NULL) {
system.debug('opt::1');                    
                    sourceRenewedOpptyMappingList.add(
                        new Source_Opp_Mapping__c(
                                Source_Opp__c = renewedOpty.Originating_Opportunity__c, 
                                Renewal_Opp__c = renewedOpty.ID
                        )
                    ); 
                    sourceRenewedOpptyMappingList.add(
                        new Source_Opp_Mapping__c(
                                Source_Opp__c = renewedOpty.ID, 
                                Renewal_Opp__c = renewedOpty.Originating_Opportunity__c
                        )
                    ); 
                } else {
system.debug('opt::2');                                        
                    sourceRenewedOpptyMappingList.add(
                        new Source_Opp_Mapping__c(
                                Source_Opp__c = renewedOpty.Originating_Opportunity__c, 
                                Renewal_Opp__c = renewedOpty.ID
                        )
                    ); 
                    sourceRenewedOpptyMappingList.add(
                        new Source_Opp_Mapping__c(
                                Source_Opp__c = renewedOpty.ID, 
                                Renewal_Opp__c = renewedOpty.Originating_Opportunity__c
                        )
                    );                 
                }

                //create opportunity line items. Link OppLineItems to respective opportunity object created earlier
                List<OpportunityLineItem> opportunityLineItemObjList = opptyRenewalWrapperMap.get(iCounter).opportunityLineItemObjList;
                If (opportunityLineItemObjList != NULL && opportunityLineItemObjList.size() > 0){
                    for (OpportunityLineItem lItem : opportunityLineItemObjList) {
                        If (renewedOpty.ID != NULL && lItem.Id == NULL) {
                            lItem.OpportunityId=renewedOpty.ID;
                        }
                        //OpportunityLineItem List
                        renewedOpptyProductList.add(lItem);
                    }
                }               
system.debug('actionableOpptyDetailsMap::'+actionableOpptyDetailsMap);
system.debug('actionableOpptyDetailsMap.get(renewedOpty.Originating_Opportunity__c)::'+actionableOpptyDetailsMap.get(renewedOpty.Originating_Opportunity__c));
                //Create Assets
                OpportunityRenewalHelper.reSetAssetsLineItemOfOpportunity(actionableOpptyDetailsMap.get(renewedOpty.Originating_Opportunity__c),renewedOpty,assetObjMap, product2Map);
                
                //Cloning related lists
                if (rAppSetup.Clone_Opp_Team_Related_List__c) {
                   OpportunityRenewalHelper.setClonedOpportunityTeamMembers(actionableOpptyDetailsMap.get(renewedOpty.Originating_Opportunity__c),renewedOpty,bulkListOpportunityTeamMember);
                }
                //if (rAppSetup.Clone_Partner_Related_List__c) {
                    //OpportunityRenewalHelper.setClonedOpportunityPartners(actionableOpptyDetailsMap.get(renewedOpty.Originating_Opportunity__c),renewedOpty,bulkListOpportunityPartner);
                //}
                if (rAppSetup.Clone_Contact_Roles__c) {
                    OpportunityRenewalHelper.setClonedOpportunityContactRoles(actionableOpptyDetailsMap.get(renewedOpty.Originating_Opportunity__c),renewedOpty,bulkListOpportunityContactRole);
                }
                if (rAppSetup.Clone_Competitors_Related_List__c) {
                    OpportunityRenewalHelper.setClonedOpportunityCompetitors(actionableOpptyDetailsMap.get(renewedOpty.Originating_Opportunity__c),renewedOpty,bulkListOpportunityCompetitor);
                }               
            }

            system.debug('sourceRenewedOpptyMappingList::'+sourceRenewedOpptyMappingList);
            insert sourceRenewedOpptyMappingList;
            // OpportunityLineItem
            upsert renewedOpptyProductList; 
            if (bulkListOpportunityTeamMember.size() > 0) {
                insert bulkListOpportunityTeamMember;
            }
            if (bulkListOpportunityContactRole.size() > 0) {
                insert bulkListOpportunityContactRole;
            }
            if (bulkListOpportunityCompetitor.size() > 0) {
                insert bulkListOpportunityCompetitor;
            }

            Map<ID, Opportunity> OppAmountListMap = new Map<ID, Opportunity>([Select Id, Amount From Opportunity Where Id In :OpportunityIDs]);
            
            List<OpportunityLineItem> AllLineItemsOfOpp = new List<OpportunityLineItem>([Select Id, OpportunityId, UnitPrice, Quantity, Sales_Price_Per_Unit_Per_Ent_Term__c, Entitlement_Term__c, Product_Entitlement_Term_Set_Up__c, Discount, TotalPrice From OpportunityLineItem Where OpportunityId In :OpportunityIDs]);
            Map<ID, OpportunityLineItem> AllLineItemsOfOppMap = new Map<ID, OpportunityLineItem>();
            for (OpportunityLineItem OL : AllLineItemsOfOpp){
                AllLineItemsOfOppMap.put(OL.OpportunityId, OL);
            }
            system.debug('All Line Item ' + AllLineItemsOfOpp);
            // Adding below logic to set Base_Line_Amount on renewal opportunity to Amount so that upgrade/downgrade logic works on renewal opp
            // Reason for adding this at end of this flow here so that OpportunityLineItem trigger also does it's magic to calculate pro-rate price and all
            for (String iCounter: renewedOpptyMap.keySet()) {
        /*        decimal baselineamount = 0.00;
                if (renewedOpptyMap.get(iCounter).Base_Line_Amount__c != NULL) {
                    baselineamount = renewedOpptyMap.get(iCounter).Base_Line_Amount__c;
                }*/
              
                for (OpportunityLineItem BaseLineOppList : renewedOpptyProductList) {
                    if (BaseLineOppList.Opportunity_LineItem_ID__c != null && assetObjMap.containsKey(BaseLineOppList.Opportunity_LineItem_ID__c)) {
                        //Reset new OLI.
                        assetObjMap.get(BaseLineOppList.Opportunity_LineItem_ID__c).Originating_LineItem_ID__c = BaseLineOppList.ID;
                    }
                    
                 /*   if (BaseLineOppList.OpportunityId == renewedOpptyMap.get(iCounter).ID) {
                        decimal LineItemTotal = 0.00;
                        If (BaseLineOppList.Product_Entitlement_Term_Set_Up__c == NULL) {
                               LineItemTotal = BaseLineOppList.UnitPrice * BaseLineOppList.Quantity;
                        } else { 
                        LineItemTotal = BaseLineOppList.UnitPrice * BaseLineOppList.Quantity * (BaseLineOppList.Entitlement_Term__c / BaseLineOppList.Product_Entitlement_Term_Set_Up__c ); // * BaseLineOppList.Sales_Price_Per_Unit_Per_Ent_Term__c * (BaseLineOppList.Entitlement_Term__c / BaseLineOppList.Product_Entitlement_Term_Set_Up__c ); // BaseLineOppList.UnitPrice;
                        }
                        system.debug('LineItemTotal:  ' + LineItemTotal);
                        if ( BaseLineOppList.Discount != NULL) {
                            baselineamount += LineItemTotal * ((100 - BaseLineOppList.Discount)/100);
                        } else {
                            baselineamount += LineItemTotal;
                            system.debug('baselineamount :  ' + baselineamount );
                        }               
                    }*/
                } 
                system.debug('Amount 123 ' + renewedOpptyMap.get(iCounter).Amount);
                decimal baselineamount = 0.00;
                for (OpportunityLineItem OL : AllLineItemsOfOpp){
                    system.debug('OppID ' + renewedOpptyMap.get(iCounter).Id);
                    system.debug('Opp Line Item ID ' + OL.Id);
                    If (OL.OpportunityId == renewedOpptyMap.get(iCounter).Id){
                        baselineamount += OL.Quantity * OL.UnitPrice * (OL.Entitlement_Term__c / OL.Product_Entitlement_Term_Set_Up__c );
                        system.debug('Base Line Amount1 ' + baselineamount);
                    }                
                }
                system.debug('Base Line Amount ' + baselineamount);
                renewedOpptyMap.get(iCounter).Base_Line_Amount__c = OppAmountListMap.get(renewedOpptyMap.get(iCounter).Id).Amount; //baselineamount; //renewedOpptyMap.get(iCounter).Amount; //baselineamount; 
            }
            //re-run it in order to update Base_Line_Amount field in opportunity entry    
            upsert renewedOpptyMap.values(); 
             
            if (assetObjMap.size() > 0) {
                system.debug('asset object map in trigger  '  + assetObjMap);
                upsert assetObjMap.values();
            }
            Map<ID, OpportunityLineItem> oliMap = new Map<ID, OpportunityLineItem>(renewedOpptyProductList);
            oliMap = new Map<ID, OpportunityLineItem>([SELECT ID, Opportunity_LineItem_ID__c from OpportunityLineItem where Opportunity_LineItem_ID__c != NULL AND ID in : oliMap.keySet()]);
            List<OpportunityLineItem> updateOpportunityLineItemWithAssetList = new List<OpportunityLineItem>();
            for (OpportunityLineItem newProduct : oliMap.values()) {
                if (assetObjMap.containsKey(newProduct.Opportunity_LineItem_ID__c)) {
                    newProduct.Asset__c = assetObjMap.get(newProduct.Opportunity_LineItem_ID__c).ID;
                    updateOpportunityLineItemWithAssetList.add(newProduct);
                }
            }
            if (updateOpportunityLineItemWithAssetList.size() > 0) {
                update updateOpportunityLineItemWithAssetList;
            }
        } catch (DmlException e) {
            System.debug('~~~~~~~~~~Error-1:' + e.getMessage());
            throw e;
        } catch (InvalidOperationException e) {
            System.debug(actionableOpptyDetailsMap.size() + '\n\n~~~~~~~~~~ERROR-2:' + e.getMessage());
            if (newOpptyList.size() == 1) {
                newOpptyList.get(0).addError(' Please make sure that source opportunity with which this add-on is co-termed with is closed and renewal opp created from closure of source opp has not been deleted.');
                System.debug('~~~~~~~~~~ERROR-21:' + actionableOpptyDetailsMap);
            }
        } catch (Exception e) {
            System.debug('~~~~~~~~~~ERROR-3:' + e.getMessage());
             throw e;
        }  
    }
}