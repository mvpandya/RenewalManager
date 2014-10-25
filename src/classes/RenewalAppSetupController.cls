/**
 * Copyright (c) 2014 Comity Designs
 * All rights reserved.
 *
 * This class is controller class for the Renewal Manager configuration page.
 *
 * History:
 * =========================================
 * Developer         Date        description
 * --------------------------------------------------------------------------------------------------
 * Ivan Melnikov     07/30/2014  Code refactoring 
 *
 * 
 **/
public with sharing class RenewalAppSetupController {
       
    public Renewal_App_Setup__c renewalSetupObject;
    public Boolean showSaveMessage {get; set;}
        
    public Set<String> SetUnselectedOpptyFields = new Set<String>();
    public Set<String> SetSelectedOpptyFields = new Set<String> ();
    public List<String> selectedOpptyFields {get; set; }
    public List<String> unselectedOpptyFields {get; set; }
    
    public List<Opp_Record_Type_Mapping__c> oppRecTypeMappingList {get; set;}
    public List<RecordType> oppRecTypeList {get; set;}
    
    public Set<String> SetUnselectedOpptyLIFields = new Set<String>();
    public Set<String> SetSelectedOpptyLIFields = new Set<String> ();
    public List<String> selectedOpptyLIFields {get; set;}
    public List<String> unselectedOpptyLIFields {get; set;}
    
    public Map<String, String> mapOpptyNameLabel = new Map<String, String>();  
    public Map<String, String> mapOpptyLINameLabel = new Map<String, String>();
    private Boolean isValid = true; 
    
    /** Constructor */    
    public RenewalAppSetupController() {
        this.oppRecTypeMappingList = getOpportunityRecordTypeMapping();
    }
    
    private class CustomFieldsIds {
        public String customFieldId {get; set;}
    } 

    /**
     * @description     Initialize configuration data.
     */
    public void init() {
        this.getRenewalSetupObject();
        this.retrieveOpptyFields();
        this.retrieveOpptyLIFields();
    }

    public List<Opp_Record_Type_Mapping__c> getOpportunityRecordTypeMapping() {
        Map<ID, RecordType> recordTypeMap = new Map<ID, RecordType>([
            SELECT  r.SobjectType, r.Name, r.IsActive, r.Id, r.Description 
            FROM RecordType r 
            WHERE r.SobjectType = 'Opportunity' and  r.IsActive = true
        ]);
        
        List<Opp_Record_Type_Mapping__c> oppRecTypeMappingList = [
            SELECT id, Source_Opp_Record_Type_ID__c, Source_Opp_Record_Type_Name__c, Renewal_Opp_Record_Type_ID__c, 
                Renewal_Opp_Record_Type_Name__c, Name 
            FROM Opp_Record_Type_Mapping__c
            LIMIT :Limits.getLimitQueryRows()];
        this.oppRecTypeList = recordTypeMap.values();
        Integer iCount = -1;

        Map<ID, Opp_Record_Type_Mapping__c> oppRecTypeMappingMap = new Map<ID, Opp_Record_Type_Mapping__c>();
        
        System.debug(recordTypeMap.keySet()+ '\n\n~~~~10: ' + oppRecTypeMappingList);
        
        //Sync existing record type
        for (Opp_Record_Type_Mapping__c m : oppRecTypeMappingList) {
            iCount++;
            if (recordTypeMap.containsKey(m.Source_Opp_Record_Type_ID__c)) {
                m.Name = recordTypeMap.get(m.Source_Opp_Record_Type_ID__c).Name;
                m.Source_Opp_Record_Type_Name__c = recordTypeMap.get(m.Source_Opp_Record_Type_ID__c).Description;
                if (recordTypeMap.containsKey(m.Renewal_Opp_Record_Type_ID__c)) {
                    m.Renewal_Opp_Record_Type_Name__c = recordTypeMap.get(m.Renewal_Opp_Record_Type_ID__c).Name;
                } else {
                    m.Renewal_Opp_Record_Type_ID__c = m.Source_Opp_Record_Type_ID__c;
                    m.Renewal_Opp_Record_Type_Name__c = m.Name;
                }
                oppRecTypeMappingMap.put(m.Source_Opp_Record_Type_ID__c, m);
            }
        }
        System.debug(oppRecTypeMappingMap.keySet()+ '\n\n~~~~11: ' + recordTypeMap.keySet());
        
        //Add additional Record Type.
        for (RecordType rec : recordTypeMap.values()) {
            if (!oppRecTypeMappingMap.containsKey(rec.ID)) {
                Opp_Record_Type_Mapping__c m = new Opp_Record_Type_Mapping__c();
                m.Name = rec.Name;
                m.Source_Opp_Record_Type_ID__c = rec.id;
                m.Source_Opp_Record_Type_Name__c = rec.Description;
                m.Renewal_Opp_Record_Type_ID__c = m.Source_Opp_Record_Type_ID__c;
                m.Renewal_Opp_Record_Type_Name__c = m.Name;
                oppRecTypeMappingList.add(m);
            }
        }
        return oppRecTypeMappingList;
    }

    public List<SelectOption> OpportunityRecordTypeList { 
        get {
          list<SelectOption> options = new list<SelectOption>();
          for (RecordType rec : this.oppRecTypeList) { 
             options.add(new SelectOption(rec.ID,rec.Name)); 
          }
          return options;
        }
    }    
    
    public Renewal_App_Setup__c getRenewalSetupObject() {
 
        if (this.renewalSetupObject == null) {
            Renewal_App_Setup__c[] tmpSetupAr = [
                SELECT r.Renewal_Stage__c, r.Renewal_Opportunity_Type__c,  r.Prefix_for_Renewal_Opportunity_Name__c,
                    r.Asset__c, r.Opportunity_Field_To_Not_Copy_on_Renewal__c, r.Opportunity_Product_Fields_To_Not_Copy__c,
                    r.Renewal_Opportunity_Owner__c, r.User__c, r.Clone_Competitors_Related_List__c, r.Clone_Contact_Roles__c, 
                    r.Clone_Opp_Team_Related_List__c
            FROM Renewal_App_Setup__c r
            LIMIT :Limits.getLimitQueryRows()];
                                                      
            if (tmpSetupAr.size() == 1) {
                this.renewalSetupObject = tmpSetupAr[0];
            } else if (tmpSetupAr.size() == 0) {
                this.renewalSetupObject = new Renewal_App_Setup__c();
            } else if (tmpSetupAr.size() > 1) {
                this.setIsValid(false);
                this.addError(RenewalLabelsAndMessages.ERROR_INVALID_RENEWAL_APP_SETUP);
                for (Renewal_App_Setup__c tmpSetup : tmpSetupAr) {
                    this.addError('Record Id: ' + tmpSetup.Id);
                }
            } 
        }
        return this.renewalSetupObject;     
    }
    
    //save button
    public PageReference save() {
        String Opportunity_Field_To_Not_Copy_on_Renewal = '';
        String Opportunity_Product_Fields_To_Not_Copy = '';
        List<String> LSelectedOpptyFields = new List<String>();
        List<String> LSelectedOpptyLIFields = new List<String>();
        LSelectedOpptyFields.addAll(SetSelectedOpptyFields);
        Opportunity_Field_To_Not_Copy_on_Renewal = String.join(LSelectedOpptyFields, ';'); 
        renewalSetupObject.Opportunity_Field_To_Not_Copy_on_Renewal__c = Opportunity_Field_To_Not_Copy_on_Renewal ;
        LSelectedOpptyLIFields.addAll(SetSelectedOpptyLIFields);
        Opportunity_Product_Fields_To_Not_Copy = String.join(LSelectedOpptyLIFields, ';'); 
        renewalSetupObject.Opportunity_Product_Fields_To_Not_Copy__c = Opportunity_Product_Fields_To_Not_Copy ;
        if (renewalSetupObject.Renewal_Opportunity_Owner__c == 'A specific User') {
            if (renewalSetupObject.User__c == null) {
                ApexPages.addmessage(new ApexPages.message(ApexPages.severity.WARNING,'Please pick the user to whom renewal should get assigned.'));
                return null;
            }
        } else {
            renewalSetupObject.User__c = null;
        }
        upsert renewalSetupObject;
       
        List<Renewal_App_Setup__c> tempCheckList = new List<Renewal_App_Setup__c>([
            SELECT r.Opportunity_Field_To_Not_Copy_on_Renewal__c, r.Opportunity_Product_Fields_To_Not_Copy__c
            FROM Renewal_App_Setup__c r 
            LIMIT 1
        ]);      
        
        if (oppRecTypeMappingList != null && oppRecTypeMappingList.size() > 0) {
            upsert oppRecTypeMappingList;
        }
        
        ApexPages.addMessage(new ApexPages.message(ApexPages.severity.Confirm, 'Renewal App Setup saved successfully.'));
        return null;
    }
    
    //cancel button
    public PageReference cancel() {
        PageReference cancelPage = new PageReference(RenewalLabelsAndMessages.homePageUrl);
        cancelPage.setRedirect(true);       
        return cancelPage;
    }
    
    public void setIsValid(Boolean b) {
        this.isValid = b;
    }
    
    public Boolean getIsValid() {
        return this.isValid;
    }   
    
        //Method adds an error message to the page
    private void addError(String errorMsg) {         
        ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.ERROR,errorMsg);               
        ApexPages.addMessage(msg);
    }
    
    private void retrieveOpptyFields() {
        map<String, Schema.SobjectField> AllOpptyFields = Schema.SobjectType.Opportunity.fields.getMap();
        List<String> ListSelectedOpptyRecsInObj = new List<String>();
        map<String, String> mapSelectedOpptyRecsInObj = new map<String, String>();
        for (Schema.SobjectField sfield : AllOpptyFields.Values()) {
            String tempName;
            schema.describefieldresult dfield = sfield.getDescribe();
            tempName = dfield.getName();
            mapOpptyNameLabel.put(tempName.toLowerCase(), dfield.getLabel());                       
        }
        
        if (renewalSetupObject != null) {
            if (renewalSetupObject.Opportunity_Field_To_Not_Copy_on_Renewal__c != null) {
                String chosenOpportunity_Fields = renewalSetupObject.Opportunity_Field_To_Not_Copy_on_Renewal__c;
                ListSelectedOpptyRecsInObj = chosenOpportunity_Fields.split(';', -1);
            }
        }
        
        if (!ListSelectedOpptyRecsInObj.isEmpty()) {
            for (String s : ListSelectedOpptyRecsInObj) {
                mapSelectedOpptyRecsInObj.put(s.toLowerCase(), s);
            }
        }
        
        for (String s : AllOpptyFields.keySet()) {
            if (!mapSelectedOpptyRecsInObj.isEmpty()) {
                if (mapSelectedOpptyRecsInObj.containsKey(s.toLowerCase())) {
                    SetSelectedOpptyFields.add(s);
                } else {
                    SetUnselectedOpptyFields.add(s);
                }
            } else {
                SetUnselectedOpptyFields.add(s);
            }
            
        }
        //removing below set of fields from available list as these are set while renewal opp is created
        SetUnselectedOpptyFields.remove('ready_for_renewal__c');
        SetUnselectedOpptyFields.remove('name');  
        SetUnselectedOpptyFields.remove('type');
        SetUnselectedOpptyFields.remove('stagename');
        SetUnselectedOpptyFields.remove('closedate');
        SetUnselectedOpptyFields.remove('contact__c');
        SetUnselectedOpptyFields.remove('ownerid');
        SetUnselectedOpptyFields.remove('recordtypeid');
        SetUnselectedOpptyFields.remove('co_term_with__c');
        SetUnselectedOpptyFields.remove('original_term_expiration_date__c ');
        SetUnselectedOpptyFields.remove('id');      
        SetUnselectedOpptyFields.remove('pricebook2id');
        SetUnselectedOpptyFields.remove('upgrade_downgrade_reason__c');
        SetUnselectedOpptyFields.remove('upgrade_downgrade_amount__c');
        SetUnselectedOpptyFields.remove('upgrade_downgrade__c'); 
        
    }

    public List<SelectOption> selectedOptionsOpptyFields { 
        get {
            List<String> sorted = new List<String>(SetSelectedOpptyFields);
            sorted.sort();
            List<SelectOption> options = new List<SelectOption>();
            for (String s : sorted) {
                if (mapOpptyNameLabel.get(s.toLowerCase()) != null) {
                    options.add(new SelectOption(s, mapOpptyNameLabel.get(s.toLowerCase())));
                }
            }
            return options;
        }
    }

    public List<SelectOption> unSelectedOptionsOpptyFields { 
        get {
            List<String> sorted = new List<String>(SetUnselectedOpptyFields);
            sorted.sort();
            List<SelectOption> options = new List<SelectOption>();
            system.debug('mapOpptyNameLabel::'+mapOpptyNameLabel);
            for (String s : sorted) {
                system.debug('s::'+mapOpptyNameLabel);
                if (mapOpptyNameLabel.get(s.toLowerCase()) != null) {
                    options.add(new SelectOption(s, mapOpptyNameLabel.get(s.toLowerCase())));
                }
            }
            return options;
        }
    }
    
    public void doSelectOpptyFields() {
        if (!selectedOpptyFields.isEmpty()) {
            for (String s: selectedOpptyFields) {
                SetSelectedOpptyFields.add(s);
                SetUnselectedOpptyFields.remove(s);
            }
        }
    }
    
    public void doUnSelectOpptyFields() {
        if (!unselectedOpptyFields.isEmpty()) {
            for (String s: unselectedOpptyFields) {
                SetUnselectedOpptyFields.add(s);
                SetSelectedOpptyFields.remove(s);
            }
        }
    }  
    
    private void retrieveOpptyLIFields() {
        
        map<String, Schema.SobjectField> AllOpptyLIFields = Schema.SobjectType.OpportunityLineItem.fields.getMap(); 
        List<String> ListSelectedOpptyLIRecsInObj = new List<String>();  
        map<String, String> mapSelectedOpptyLIRecsInObj = new map<String, String>(); 
        
        for (Schema.SobjectField sfield : AllOpptyLIFields.Values()) {
            String tempName;
            schema.describefieldresult dfield = sfield.getDescribe();
            tempName = dfield.getName();
            mapOpptyLINameLabel.put(tempName.toLowerCase(), dfield.getLabel());              
        }
                
        if (renewalSetupObject != null) {
            if (renewalSetupObject.Opportunity_Product_Fields_To_Not_Copy__c != null) {
                String chosenOpportunityLI_Fields = renewalSetupObject.Opportunity_Product_Fields_To_Not_Copy__c;
                ListSelectedOpptyLIRecsInObj = chosenOpportunityLI_Fields.split(';', -1);
            }
        }
        
        if (!ListSelectedOpptyLIRecsInObj.isEmpty()) {
            for (String s : ListSelectedOpptyLIRecsInObj) {
                mapSelectedOpptyLIRecsInObj.put(s.toLowerCase(), s);
            }
        }
        
        for (String s : AllOpptyLIFields.keySet()) {
            if (!mapSelectedOpptyLIRecsInObj.isEmpty()) {
                if (mapSelectedOpptyLIRecsInObj.containsKey(s.toLowerCase())) {
                    SetSelectedOpptyLIFields.add(s);  
                } else {
                    SetUnselectedOpptyLIFields.add(s);  
                }
            } else {
                SetUnselectedOpptyLIFields.add(s);  
            }
        }
        //removing below set of fields from available list as these are set while renewal opp is created
        SetUnselectedOpptyLIFields.remove('totalprice');
        SetUnselectedOpptyLIFields.remove('opportunity_lineitem_id__c');
        SetUnselectedOpptyLIFields.remove('opportunity_lineitem_url__c');
        SetUnselectedOpptyLIFields.remove('commision_percentage__c');
        SetUnselectedOpptyLIFields.remove('entitlement_start_date__c');
        SetUnselectedOpptyLIFields.remove('entitlement_end_date__c');
        SetUnselectedOpptyLIFields.remove('servicedate');
        SetUnselectedOpptyLIFields.remove('unitprice');
    }

    public List<SelectOption> selectedOptionsOpptyLIFields { 
        get {
            List<String> sorted = new List<String>(SetSelectedOpptyLIFields);
            sorted.sort();
            List<SelectOption> options = new List<SelectOption>();
            for (String s : sorted) {
                if (mapOpptyLINameLabel.get(s.toLowerCase()) != null) {
                    options.add(new SelectOption(s, mapOpptyLINameLabel.get(s.toLowerCase())));
                }
            }
            return options;
        }
    }

    public List<SelectOption> unSelectedOptionsOpptyLIFields { 
        get {
            List<String> sorted = new List<String>(SetUnselectedOpptyLIFields);
            sorted.sort();
            List<SelectOption> options = new List<SelectOption>();
            for (String s : sorted) {
                if (mapOpptyLINameLabel.get(s.toLowerCase()) != null) {
                    options.add(new SelectOption(s, mapOpptyLINameLabel.get(s.toLowerCase())));
                }
            }
            return options;
        }
    }

    public List<SelectOption> OpportunityStageList { 
        get {
            List<OpportunityStage> OppStageList = new List<OpportunityStage>([
                SELECT MasterLabel 
                FROM OpportunityStage 
                ORDER BY DefaultProbability ASC, MasterLabel ASC
                LIMIT :Limits.getLimitQueryRows()
            ]);
            List<SelectOption> options = new List<SelectOption>();
            for (OpportunityStage s : OppStageList) {
                options.add(new SelectOption(s.MasterLabel, s.MasterLabel));
            }
            return options;
        }
    }

    public List<SelectOption> OpportunityTypeList { 
        get {
          list<SelectOption> options = new list<SelectOption>();
          // Get the object type of the SObject.
          Schema.sObjectType objType = Opportunity.getSObjectType(); 
          // Describe the SObject using its object type.
          Schema.DescribeSObjectResult objDescribe = objType.getDescribe();       
          // Get a map of fields for the SObject
          map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap(); 
          // Get the list of picklist values for this field.
          list<Schema.PicklistEntry> values =
             fieldMap.get('Type').getDescribe().getPickListValues();
          // Add these values to the selectoption list.
          for (Schema.PicklistEntry a : values) { 
             options.add(new SelectOption(a.getLabel(), a.getValue())); 
          }
          return options;
        }
    }    
            
    public void doSelectOpptyLIFields() {
        for (String s: selectedOpptyLIFields) {
            SetSelectedOpptyLIFields.add(s);
            SetUnselectedOpptyLIFields.remove(s);
        }
    }
    
    public void doUnSelectOpptyLIFields() {
        for (String s: unselectedOpptyLIFields) {
            SetUnselectedOpptyLIFields.add(s);
            SetSelectedOpptyLIFields.remove(s);
        }
    }
}