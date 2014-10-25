@isTest (seeAllData=true)
/**
    Copyright (c) 2010 Comity Designs 
    All rights reserved.
*/
/**
    Tester class for RenewalAppSetupController controller
*/
public with sharing class RenewalAppSetupControllerTest {
    /**
        test happy flow
    */    
    private static Renewal_App_Setup__c firstAppSetupRecord;
    
    public static testMethod void testValidAppSetup(){
        
        //delete all the renewal app setup records
        Renewal_App_Setup__c[] arAppSetup = [select id from Renewal_App_Setup__c limit 1000];
        delete arAppSetup;
        firstAppSetupRecord = createRenewalAppSetupRecord();

        PageReference appSetupPage = Page.renewalAppSetupPage;
        Test.setCurrentPage(appSetupPage);        
        //create controller
        RenewalAppSetupController controller = new RenewalAppSetupController();
        
        test.startTest();
        
        controller.init();
        //Assert that validation is successful
        System.assertEquals(controller.getIsValid(), true);        
        //assert that save button works
        //System.assertNotEquals(controller.save(), null);  
        
        // check opportunity fields selection lists functionalities
        List<SelectOption> list_selectedOptionsOpptyFields = controller.selectedOptionsOpptyFields;
        List<SelectOption> list_unSelectedOptionsOpptyFields = controller.unSelectedOptionsOpptyFields;
        
        controller.selectedOpptyFields = new List<String>();
        controller.unselectedOpptyFields = new List<String>();
        controller.SetSelectedOpptyFields.clear();
        controller.SetUnselectedOpptyFields.clear();
        controller.selectedOpptyFields.add('accountid');
        controller.selectedOpptyFields.add('amount');
        controller.doSelectOpptyFields();
        System.assert(controller.SetSelectedOpptyFields.size() == 2, 'Opprtunity fields are selected from list');
        
        controller.unselectedOpptyFields.add('amount');
        controller.doUnSelectOpptyFields();
        System.assert(controller.SetUnselectedOpptyFields.size() == 1,  'Opprtunity fields are Unselected from list');        
        
        List<SelectOption> list_selectedOptionsOpptyLIFields = controller.selectedOptionsOpptyLIFields;
        List<SelectOption> list_unSelectedOptionsOpptyLIFields = controller.unSelectedOptionsOpptyLIFields;
        
        // check opportunity LI fields selection lists functionalities
        controller.selectedOpptyLIFields = new List<String>();
        controller.unselectedOpptyLIFields = new List<String>();
        controller.SetSelectedOpptyLIFields.clear();
        controller.SetUnselectedOpptyLIFields.clear();
        controller.selectedOpptyLIFields.add('createdbyid');
        controller.selectedOpptyLIFields.add('createddate');
        controller.doSelectOpptyLIFields();
        System.assert(controller.SetSelectedOpptyLIFields.size() == 2, 'OpprtunityLI fields are selected from list');
        
        controller.unselectedOpptyLIFields.add('createddate');
        controller.doUnSelectOpptyLIFields();
        System.assert(controller.SetUnselectedOpptyLIFields.size() == 1,  'OpprtunityLI fields are Unselected from list'); 
        
        //check oppty type picklist
        List<SelectOption> list_OpportunityTypeList = controller.OpportunityTypeList;
        System.assert(list_OpportunityTypeList!=null, 'Opportunity Type dropdown list is null.');
        
        //check oppty stage picklist
        List<SelectOption> list_OpportunityStageList = controller.OpportunityStageList;
        System.assert(list_OpportunityStageList!=null, 'Opportunity Stage dropdown list is null.');
        //assert that save button works
        controller.renewalSetupObject.Renewal_Opportunity_Owner__c = 'A specific User';
        //assert that save button works
        System.assertEquals(controller.save(), null);   
        test.stopTest();     
    }

    /**
        test invalid scenario
    */
    public static testMethod void testInvalidAppSetup(){
        //delete all the renewal app setup records
        Renewal_App_Setup__c[] arAppSetup = [select id from Renewal_App_Setup__c limit 1000];
        delete arAppSetup;
        //insert first record        
        firstAppSetupRecord = new Renewal_App_Setup__c(Renewal_Stage__c='Prospecting',Opportunity_Field_To_Not_Copy_on_Renewal__c = 'Base_Line_Amount__c; is_add_on_opportunity__c; invoice_number__c',
                                                                                Opportunity_Product_Fields_To_Not_Copy__c = 'Asset_Sr_No__c; commision_amount__c; commision_percentage__c', 
                                                                                Renewal_Opportunity_Owner__c = 'Same as Source Opportunity Owner', Renewal_Opportunity_Type__c = 'Existing Customer - Renewal',
                                                                                Prefix_for_Renewal_Opportunity_Name__c = 'Renewal');   
        insert firstAppSetupRecord;        
        
        test.startTest();
        
        PageReference appSetupPage = Page.renewalAppSetupPage;
        Test.setCurrentPage(appSetupPage);        
        //create controller
        RenewalAppSetupController controller = new RenewalAppSetupController();        
        //create another Renewal_App_Setup__c record        
   /*     Renewal_App_Setup__c secondAppSetupRecord = new Renewal_App_Setup__c(Renewal_Stage__c='stage', Renewal_Record_Type_Name__c='renewal', 
                                                                            Renewal_Probability__c=10, Renewal_Opportunity_Type__c='type',
                                                                            Renewal_Forecast_Category__c='category', Originating_Opportunity_Id__c='id',
                                                                            Originating_Opportunity_Id_Name__c='id', Original_Term_Expiration_Id__c='id',
                                                                            Closed_Won_Stage_Name__c='stage',
                                                                            Base_Line_Amount_Id__c='1000', Is_Renewal_Reminder_Task_Enabled__c = true, 
                                                                            Renewal_Opportunity_Owner__c = 'A specific User', User__c = NULL);*/
                                                                            
        Renewal_App_Setup__c secondAppSetupRecord = new Renewal_App_Setup__c(Renewal_Stage__c='Prospecting', 
                                                                                Opportunity_Field_To_Not_Copy_on_Renewal__c = 'Base_Line_Amount__c; is_add_on_opportunity__c; invoice_number__c',
                                                                                Opportunity_Product_Fields_To_Not_Copy__c = 'Asset_Sr_No__c; commision_amount__c; commision_percentage__c', 
                                                                                Renewal_Opportunity_Owner__c = 'A specific User', Renewal_Opportunity_Type__c = 'Existing Customer - Renewal',
                                                                                Prefix_for_Renewal_Opportunity_Name__c = 'Renewal', User__c = NULL); 
                                                                                                                                                            
        insert secondAppSetupRecord;        
        controller.init();
        //Assert that validation failed
        System.assertEquals(controller.getIsValid(), false);
        //call incrementrows
        //controller.incrementRows();        
        //assert that cancel button works
        System.assertNotEquals(controller.cancel(), null);
        
        test.stopTest();     
    }    
    /**
    * Reusable non-test method - that creates a configuration record
    */    
    public static Renewal_App_Setup__c createRenewalAppSetupRecord(){    
        if(firstAppSetupRecord==null){
            //delete all the renewal app setup records
            Renewal_App_Setup__c[] arAppSetup = [select id from Renewal_App_Setup__c limit 1000];
            delete arAppSetup;          
            /*firstAppSetupRecord = new Renewal_App_Setup__c(Renewal_Stage__c='stage', Renewal_Record_Type_Name__c='Renewal', 
                                                                                Renewal_Probability__c=10, Renewal_Opportunity_Type__c='type',
                                                                                Renewal_Forecast_Category__c='category', 
                                                                                Originating_Opportunity_Id__c='id',
                                                                                Originating_Opportunity_Id_Name__c='id', Original_Term_Expiration_Id__c='id',
                                                                                Closed_Won_Stage_Name__c='Closed Won',
                                                                                Base_Line_Amount_Id__c='1000', Is_Renewal_Reminder_Task_Enabled__c = true,
                                                                                Contract_Id__c='Contract_Id__c');*/
                                                                                
            firstAppSetupRecord = new Renewal_App_Setup__c(Renewal_Stage__c='Prospecting',
                                                                                Opportunity_Field_To_Not_Copy_on_Renewal__c = 'Base_Line_Amount__c; is_add_on_opportunity__c; invoice_number__c',
                                                                                Opportunity_Product_Fields_To_Not_Copy__c = 'Asset_Sr_No__c; commision_amount__c; commision_percentage__c', 
                                                                                Renewal_Opportunity_Owner__c = 'Same as Source Opportunity Owner', Renewal_Opportunity_Type__c = 'Existing Customer - Renewal',
                                                                                Prefix_for_Renewal_Opportunity_Name__c = 'Renewal');    
            insert firstAppSetupRecord;
        }
        return firstAppSetupRecord;
    }
}