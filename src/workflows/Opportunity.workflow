<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <alerts>
        <fullName>Renewal_Opp_Creation_Notification_Alert</fullName>
        <description>Renewal Opp Creation Notification Alert</description>
        <protected>false</protected>
        <recipients>
            <type>creator</type>
        </recipients>
        <senderType>CurrentUser</senderType>
        <template>Renewal_Mgr_Email_Templates/Renewal_Opp_Creation_Notification</template>
    </alerts>
    <fieldUpdates>
        <fullName>Renewal_Flag</fullName>
        <description>auto set renewal flag for creation of renewal opportunities by App</description>
        <field>Ready_For_Renewal__c</field>
        <literalValue>1</literalValue>
        <name>Renewal Flag</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
    </fieldUpdates>
    <rules>
        <fullName>Auto Set Renewal Needed and Ready for It Flag</fullName>
        <actions>
            <name>Renewal_Flag</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <criteriaItems>
            <field>Opportunity.IsWon</field>
            <operation>equals</operation>
            <value>True</value>
        </criteriaItems>
        <description>Auto set renewal flag on opportunity</description>
        <triggerType>onCreateOrTriggeringUpdate</triggerType>
    </rules>
    <rules>
        <fullName>Renewal Opp Creation Notification</fullName>
        <actions>
            <name>Renewal_Opp_Creation_Notification_Alert</name>
            <type>Alert</type>
        </actions>
        <active>true</active>
        <criteriaItems>
            <field>Opportunity.RecordTypeId</field>
            <operation>equals</operation>
            <value>CD_Sales - Renewal</value>
        </criteriaItems>
        <triggerType>onCreateOnly</triggerType>
    </rules>
    <rules>
        <fullName>Renewal Reminder</fullName>
        <actions>
            <name>RemindertorenewtheClosedWonOpportunity</name>
            <type>Task</type>
        </actions>
        <active>false</active>
        <criteriaItems>
            <field>Opportunity.IsWon</field>
            <operation>equals</operation>
            <value>True</value>
        </criteriaItems>
        <description>Reminder to create a Renewal Opportunity when an Originating Opportunity gets closed/won</description>
        <triggerType>onCreateOrTriggeringUpdate</triggerType>
    </rules>
    <tasks>
        <fullName>RemindertorenewtheClosedWonOpportunity</fullName>
        <assignedToType>owner</assignedToType>
        <dueDateOffset>0</dueDateOffset>
        <notifyAssignee>false</notifyAssignee>
        <priority>Normal</priority>
        <protected>false</protected>
        <status>Not Started</status>
        <subject>Reminder to renew the Closed/Won Opportunity</subject>
    </tasks>
</Workflow>
