/**
 * Copyright (c) 2014 Comity Designs
 * All rights reserved.
 *
 * This class is a wrapper class for oppotys and oppty line items for the Renewal Manager.
 *
 * History:
 * =========================================
 * Developer         Date        description
 * --------------------------------------------------------------------------------------------------
 * Ivan Melnikov     07/30/2014  Code refactoring 
 *
 * 
 **/
public with sharing class OpportunityRenewalWrapper {
    public Opportunity opportunityObj{get;set;}
    public List<OpportunityLineItem> opportunityLineItemObjList = new List<OpportunityLineItem>();
    public ID prductIdFirst; 
}