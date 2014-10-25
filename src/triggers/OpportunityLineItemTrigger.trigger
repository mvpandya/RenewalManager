trigger OpportunityLineItemTrigger on OpportunityLineItem (before insert, before update) {
    OpportunityLineItemTriggerHandler.oportunityLineItemBeforeInsertUpdateHandler(Trigger.new);
}