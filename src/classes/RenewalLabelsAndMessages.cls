/**
 * Copyright (c) 2014 Comity Designs
 * All rights reserved.
 *
 * This class class contains constants, labels and messages for the Renewal manager.
 *
 * History:
 * =========================================
 * Developer         Date        description
 * --------------------------------------------------------------------------------------------------
 * Ivan Melnikov     07/30/2014  Code refactoring 
 *
 * 
 **/
public with sharing class RenewalLabelsAndMessages {
    //*************************************Record Types**************************************    
    public static String renewalRTName = 'Renewal'; 
    ////*************************************Some URL Parameters*****************************************************
    //public static String opportunityTab = '006/o';
    public static String homePageUrl = '/home/home.jsp';    
    //*****************************************************************************Error Messages********************************************
    public static String ERROR_INVALID_RENEWAL_APP_SETUP = 'More than one \'Renewal App Setup\' record is found. Only one record must exist';
}