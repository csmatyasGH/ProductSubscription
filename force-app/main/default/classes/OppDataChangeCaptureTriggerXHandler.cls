/******************************************************************************
Try to capture the moment when an opp is Closed. If the rigth stages in place
call a chain if  queueable methods to process Product Subscriptions fot the opp
******************************************************************************/
public with sharing class OppDataChangeCaptureTriggerXHandler extends TriggerX 
{

    public override void onAfterInsert() 
    {
        for (OpportunityChangeEvent event : (List<OpportunityChangeEvent>) records) 
        {
          EventBus.ChangeEventHeader header = event.ChangeEventHeader;
          System.debug('CSABAW change event for ' + header.entityName + ' for the ' + header.changeType);
      
          List<String> recordIds = header.getRecordIds();

          List<ID> pocs2Consolidate =  new List<ID>();
      
          if (header.changetype == 'UPDATE') 
          {
              for (String field : header.changedFields) 
              {  
              if(field != 'StageName')  
                { 
                continue; 
                }
      
              String stageVal = String.valueOf(event.get(field));
              
              if(StageVal != 'Closed Won' && StageVal != 'Closed DeBook Quota' && StageVal != 'Closed DeBook Non-Quota')  
                 {
                  continue;   
                 }  
      
              //if we are here we have things to do. Get the Opportunity IDs and call the POC/Item creator method.
              for(String oppId :recordIds)
                 {
                  set<ID> pocIDs = BuildSubscriptionPOC.buildSubscriptionFromOpportunityAccountLink(oppID);
                  pocs2Consolidate.addAll(pocIDs);     //call the queueable from here
                  System.enqueueJob(new queueableConsolidatePSIs(pocs2Consolidate,0));     
                 }
      
              }
          }
      
      
        } //end for   
    } 


  



    
}