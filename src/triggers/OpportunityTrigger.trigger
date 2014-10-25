trigger OpportunityTrigger on Opportunity (after update) {
    if (Trigger.isInsert) {
        //OpportunityTriggerHandler.opportunityAfterInsertHandler();
    } else if (Trigger.isUpdate) {
        OpportunityTriggerHandler.opportunityAfterUpdateHandler(Trigger.new, Trigger.oldMap);
    }
}