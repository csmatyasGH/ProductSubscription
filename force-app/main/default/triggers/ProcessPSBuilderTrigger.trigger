trigger ProcessPSBuilderTrigger on ProductSubscription_POC__c (before insert,after insert) 
{


if(trigger.isBefore)
{
    for(ProductSubscription_POC__c psb :trigger.new)
       {
        psb.ExternalID__c = psb.Account__C + '_' + psb.Product__c;   
       }
}
else if (trigger.isAfter)
{
    
}


}