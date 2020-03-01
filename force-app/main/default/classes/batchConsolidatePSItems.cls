global class batchConsolidatePSItems implements Database.Batchable<sObject> 
{
    public batchConsolidatePSItems() 
    {

    }

    global Database.QueryLocator start(Database.BatchableContext BC)
    {
        String query = 'Select id  from ProductSubscription_POC__c where LastModifieddate >= yesterday and Status__c != \'CONSOLODATED\' order by LastModifieddate desc limit 200';  //reevaluate limit

        return Database.getQueryLocator(query);
     }
  
     global void execute(Database.BatchableContext BC, List<sObject> scope)
     {
        list<ProductSubscription_POC__c> poc2update = new List<ProductSubscription_POC__c>();
        for(SObject psPOC :scope)
           {
            ProductSubscriptionUtility.ConsolidateItems4Subs(psPOC.id);

            //after succesfull consolidation  do a merge
            psPOC.put('Status__c','CONSOLODATED');
           }

        database.update(scope);   

     }
  
     global void finish(Database.BatchableContext BC)
     {

     }    
}