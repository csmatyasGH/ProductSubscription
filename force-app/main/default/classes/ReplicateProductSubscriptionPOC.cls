/******************************************************************************************

******************************************************************************************/
global class ReplicateProductSubscriptionPOC implements Database.Batchable<AggregateResult>
{
global final String query = 'SELECT Related_Opportunity__c, min(Primary_Product_Subscription__c)  FROM ProductSubscriptionOpportunity__c where Related_Opportunity__r.SBQQ__PrimaryQuote__c != NULL group by Related_Opportunity__c order by count(ID) desc';

public ReplicateProductSubscriptionPOC()
{
}

public ReplicateProductSubscriptionPOC(String theQ)
{
    query = theQ;
}

global Iterable<AggregateResult> start(Database.BatchableContext BC)
{ 
Iterable<AggregateResult> itrez = new AggregateResultIterable(query); 
System.Debug('CSABAX itrez from batch = ' + itrez);
return itrez; 
} 

global void execute(Database.BatchableContext BC, List<sObject> scope)
{ 

System.Debug('CSABAX size = ' +  scope.size());  
for(sObject s : scope)
  { 
  System.debug('CSABAX s = ' + s); 
  } 
} 

global void finish(Database.BatchableContext BC)
{ 
AsyncApexJob a = [Select Id, Status, NumberOfErrors, JobItemsProcessed,TotalJobItems,CreatedBy.Email FROM AsyncApexJob WHERE Id = :BC.getJobId()]; 
System.debug('********: ' + a.Id); 
}

}
