/**********************************************************************************
 Prod Subsc Current Term lookup migth not be accurate all the time. As time pass 
 the actual current Term migth not be the real term. Try to syncronize here 
 *********************************************************************************/
global class batchSynchronizeProdSubscrTerms implements Database.Batchable<sObject> 
{
    ID psID;

    public batchSynchronizeProdSubscrTerms() 
    {

    }

    public batchSynchronizeProdSubscrTerms(id ps2sync) 
    {
    psID = ps2sync;
    }

    /***************************************************************

    ***************************************************************/
    global Database.QueryLocator start(Database.BatchableContext BC)
    {
        String query = 'Select id,SyncStatus__c,SubscriptionStatus__c,CurrentSubscriptionTerm__c ,External_Id__c  ';  
        query = query + ', (Select id from Subscription_Terms__r where  EndDate__c <= TODAY and StartDate__c >= TODAY) ';
        query = query + ' from ProductSubscription__c where SyncStatus__c = \'out of sync\'';

        if(psID != NULL)
          {
          query =  query + ' and id = \'' + psID + '\'';   
          }

        System.Debug('CSABAX ' + query);
        return Database.getQueryLocator(query);
     }
  

     /************************************************************************************
     iterate through the out of sync Prod Subscr and try to refresh the CurrentTerm/Status  
     ************************************************************************************/
     global void execute(Database.BatchableContext BC, List<ProductSubscription__c> scope)
     {
        for(ProductSubscription__c ps :scope)
        {
          ps.SubscriptionStatus__c = 'Expired';
          ps.CurrentSubscriptionTerm__c = NULL;
          System.Debug('CSABAX number of active prods subscr terms: ' + ps.Subscription_Terms__r.size() + ' status = ' + ps.SubscriptionStatus__c);
           for(ProductSubscriptionTerm__c pst  :ps.Subscription_Terms__r)
           {
            ps.CurrentSubscriptionTerm__c = pst.id;
            ps.SubscriptionStatus__c = 'Active';
            break;
           }
           System.Debug('CSABAX  status = ' + ps.SubscriptionStatus__c);        
        }

        Set<String> dmlErrMsg =  new Set<String>();        
        List<Database.SaveResult> durps;        
        durps = Database.Update(scope,false);  
        processSaveResult(durps,'ProductSubscription',dmlErrMsg);        
     }

/**********************************************************************************************************
helper method  durig debug 
**********************************************************************************************************/
public static Set<ID> processSaveResult(List<Database.SaveResult> durs, String objType,Set<String> errmsg )
{
 Set<ID> newRecordIDs = new Set<ID>(); 
 for(Database.SaveResult dur :durs) 
   {
   if(dur.isSuccess())
      {
       System.Debug('CSABAX success: ' + dur.getId());
       newRecordIDs.add(dur.getId());
      }
   else 
      {
      for(Database.Error de :dur.getErrors())
         {
          errmsg.add(objType + ' upsert Error: ' + de.message);  
          System.Debug('ObjType upsert Error: ' + de.message); 
         } 
      }   
   } 

 return newRecordIDs;    
}

/***********************************************
once Prod Ssubscr were refeshed call the batch
whih will re-build the ProductsonAccount field 
***********************************************/
global void finish(Database.BatchableContext BC)
{
      //once the ProdSubscr were syncronized call the ProductOnAccount builder batch
      batchBuildDynamicAcountPSRel batchu = new batchBuildDynamicAcountPSRel(false); 
      ID baID = Database.executeBatch(batchu, 10);   
}     

}