/*****************************************************************************
try to capture the moment when Opportunity is closed and initiate the POC/Item
creation process
*****************************************************************************/
trigger OpportunityChangeEventTrigger on OpportunityChangeEvent (after insert) 
{

TriggerX.handleTrigger(OppDataChangeCaptureTriggerXHandler.class);  

}