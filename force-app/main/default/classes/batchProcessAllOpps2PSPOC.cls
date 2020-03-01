/************************************************************************************************************
 collect all applicable opps call buildSubscriptionFromOpportunityAccountLink this batch will be called only 
 once to process historical data ad will have bacth size = 1
 ***********************************************************************************************************/
global class batchProcessAllOpps2PSPOC  implements Database.Batchable<SObject>, Database.RaisesPlatformEvents
{
    global Batch_Job_Monitor__c theBJM;
    
    private ID  opp2process; //opp 2 test with
    public batchProcessAllOpps2PSPOC(ID oppId) 
    {
        opp2process = oppId;
    }

    global Database.QueryLocator start(Database.BatchableContext BC)
    {
        //try to add monitoring
        theBJM = batchProcessAccountAlocator.CreateBatchMonitor(bc.getJobId(),'batchProcessAllOpps2PSPOC',0,0,'COMMMENT SOMETHING');

        String query = 'SELECT ID  FROM Opportunity where  ';
        if(opp2process != NULL)
           {
            query = query + ' Id = \'' + opp2process + '\' and ';
           }

        query = query + ' StageName in (\'Closed DeBook Non-Quota\',\'Closed DeBook Quota\',\'Closed Won\') and SBQQ__PrimaryQuote__c != NULL ';             

        System.Debug('CSABAY Query ' + query);

        return Database.getQueryLocator(query);
     }
  
     global void execute(Database.BatchableContext BC, List<sObject> scope)
     {

        //try to add some error/exception handling here and write to bacth monitor objects
        for(SObject opps :scope)
        { 
            Set<ID> pocIDs = BuildSubscriptionPOC.buildSubscriptionFromOpportunityAccountLink(opps.id);
            System.Debug('CSABAW Opportunity  generated ' + pocIDs.size() + ' POC records');
            for(ID poc :pocIDs)
                {
                    List<Product_SubscriptionItem__c> items = ProductSubscriptionUtility.ConsolidateItems4SubsBBSUM(poc);
                    
                    if(items != NULL && items.size() > 0)
                      {
                      System.Debug('CSABAW consolidated POC: ' + poc + ' has ' + items.size() + ' consolidated items');    
                      System.Debug('CSABAW OOTB PS ID = ' + items[0].Parent_PS__c);  
                      //ig the Paent is available we can call the Merge too
                      Set<ID> ootbPSIDs =  new Set<ID>();
                      ootbPSIDs.add(items[0].Parent_PS__c);  
                      ProductSubscriptionUtility.MergeAllItems2Terms(ootbPSIDs);
                      }
                }
        }   

     }
  
     global void finish(Database.BatchableContext BC)
     {

     }   

}