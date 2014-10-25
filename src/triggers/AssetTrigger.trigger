trigger AssetTrigger on Asset (after update) {
    List<Asset_History__c> assetHisroryList = new List<Asset_History__c>();
    for (Asset a : Trigger.oldMap.values()) {
        Asset_History__c h = new Asset_History__c();
        h.Asset__c = a.ID;
        h.Originating_LineItem_ID__c = a.Originating_LineItem_ID__c;
        h.Originating_Opportunity_LineItem_URL__c = a.Originating_Opportunity_LineItem_URL__c;
        h.Quantity__c = a.Quantity;
        h.UsageEndDate__c = a.UsageEndDate;
        assetHisroryList.add(h);
    }
    if (assetHisroryList.size() > 0) {
        insert assetHisroryList;
    }
}