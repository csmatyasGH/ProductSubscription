@istest
public with sharing class BuildSubscriptionPOCTest 
{


/********************************
call this method from inside all 
@istest(SeeAllData=true) methods. 
It return an Opp which surely has
CPQ QLI and OppLineItems we need. 
********************************/
private static ID getOppID4Test()
{
    OpportunityLineItem oli = [SELECT Id,Name,OpportunityId,Product2Id,Product_Name__c,Quantity,SBQQ__QuoteLine__c 
    FROM OpportunityLineItem
    where  SBQQ__QuoteLine__c != NULL
    and Opportunity.StageName in ('Closed DeBook Non-Quota','Closed DeBook Quota','Closed Won')
    and Start_Date__c != NULL and Quantity > 0
    limit 1                     
    ];   
    
    return oli.OpportunityID;

} 


@istest(SeeAllData=true)
/************************************************
get an existing opportunity and perform test.
************************************************/
private static void testCreatePOCItemswithSeeAD()
{
    ID oppID = getOppID4Test();

    Test.startTest() ;
    Set<ID> pocId = BuildSubscriptionPOC.buildSubscriptionFromOpportunityAccountLink(oppID);
    
    Test.stopTest();
    
    system.assertEquals(pocId.size() > 0,true,'we have a POC.');
    
    List<ProductSubscription_POC__c> thePOCs = [Select Id, Account__c, Product__c
                                               ,(Select Id,Parent_PS__c,Start_Date__c,End_Date__c,itemOrder__c,OppCreatedDate__c,
                                                OriginQuote_Line__c, OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.Name,OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__c,
                                                QuoteItem_NetTotal__c,ARR__c,MRR__c,TermNetValue__c,Duration__c
                                                from Product_SubscriptionItems__r )  
                                                from ProductSubscription_POC__c where id in :pocID];

    
    List<Product_SubscriptionItem__c> items = thePOCs[0].Product_SubscriptionItems__r;
    system.assertEquals(items.size()>0,true,'we have a POC Item');
}


@istest(SeeAllData=true)
/***********************************************
Tes AOL process
***********************************************/ 
 private static void testCreatePOCItemsWithAOL()
{ 
    Account onBehalf1 = (Account) TestFactory.createSObject(new Account(Name='ONBehalf1'), true);
    Account onBehalf2 = (Account) TestFactory.createSObject(new Account(Name='ONBehalf2'), true);

    ID oppID = getOppID4Test();

    List<OpportunityAccountLink__c> aols =  new List<OpportunityAccountLink__c>();    
    OpportunityAccountLink__c theOAL1 = new OpportunityAccountLink__c();
    theOAL1.Opportunity__c = oppID;
    theOAL1.Account__c = onBehalf1.id;
    theOAL1.Percentage__c = 50;
    aols.add(theOAL1);

    OpportunityAccountLink__c theOAL2 = new OpportunityAccountLink__c();
    theOAL2.Opportunity__c = oppID;
    theOAL2.Account__c = onBehalf2.id;
    theOAL2.Percentage__c = 50;
    aols.add(theOAL2);    

    Database.insert(aols,false);      

    Set<ID> pocId;
    Test.startTest();

    pocId = BuildSubscriptionPOC.buildSubscriptionFromOpportunityAccountLink(oppID);    
    
    Test.stopTest();

    system.assertEquals(pocId.size()>=2,true,'we have a POC Item');

    List<ProductSubscription_POC__c> thePOCs = [Select Id, Account__c, Product__c
                                               ,(Select Id,Parent_PS__c,Start_Date__c,End_Date__c,itemOrder__c,OppCreatedDate__c,
                                                OriginQuote_Line__c, OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.Name,OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__c,
                                                QuoteItem_NetTotal__c,ARR__c,MRR__c,TermNetValue__c,Duration__c
                                                from Product_SubscriptionItems__r )  
                                                from ProductSubscription_POC__c where id in :pocID];
 
   //all POCs  have the same number of itesm because all are distributed amongs the on-behalf accounts                                             
   List<Product_SubscriptionItem__c> items = thePOCs[0].Product_SubscriptionItems__r; 
   integer nrofitems = items.size();                                               

   Set<ID> involvedacc = new Set<Id>(); 
   for(ProductSubscription_POC__c poc :thePOCs)
      {
       System.assertEquals(poc.Product_SubscriptionItems__r.size(), nrofitems, 'we have the good  number of items');
       System.assertEquals(poc.Account__c == onBehalf1.id|| poc.Account__c == onBehalf2.id,true, 'we have POC for good accounts');
       involvedacc.add(poc.Account__c); 
      }
   System.assertEquals(involvedacc.size(),2, 'we have POCs  for both accounts');

}

@istest(SeeAllData=true)
/*****************************************
test the batch. Do not focus on the result 
because the batch call methods which were
already tested elswhere. Focus on coverage
*****************************************/
private static void testOppProcessBatch()
{
    ID oppID = getOppID4Test();
    System.Debug('CSABA_T Opp created Id = ' + oppID);

    Test.startTest();

    batchProcessAllOpps2PSPOC obj = new batchProcessAllOpps2PSPOC(oppID);
    DataBase.executeBatch(obj,1); 

    Test.stopTest();

    //do some assertion here. We should have POC  and Items too but at least POC
    List<ProductSubscription_POC__c> thePOCs = [Select Id, Account__c, Product__c
                                               ,(Select Id,Parent_PS__c,Start_Date__c,End_Date__c,itemOrder__c,OppCreatedDate__c,
                                                OriginQuote_Line__c, OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.Name,OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__c,
                                                QuoteItem_NetTotal__c,ARR__c,MRR__c,TermNetValue__c,Duration__c
                                                from Product_SubscriptionItems__r )  
                                                from ProductSubscription_POC__c ];

    System.assertEquals(thePOCs.size()>0,true, 'we have POC');                                            
}

@istest
/****************************************
test the Data Change Capture for an Opp.
Test only the that the Event has fired.
and BuildSubscriptionPOC method is called
Do not care about the result of that call
because that is tested elsewhere.
****************************************/
private static void testOpportunityDCC()
{
    Account accOD = (Account) TestFactory.createSObject(new Account(Name='ONDEAL_ONLY'), true);
    System.assertNotEquals(NULL,accOD.id,'we have account');

    Product2 testProd1 = (Product2) TestFactory.createSObject(new Product2(Name = 'Prod4PS'), true);  
    System.assertNotEquals(NULL,testProd1.id,'we have product');

    Opportunity opp4OD = (Opportunity) TestFactory.createSObject(new Opportunity(AccountId = accOD.Id, Name = 'OwnDealOpp'
                                                                                ,StageName = 'Attempting', Type = 'New Logo'
                                                                                , CurrencyIsoCode = 'USD'
                                                                                ), true);
    Test.getEventBus().deliver();                                                                                
    System.Debug('CSABA_T Opp created Id = ' + Opp4OD.id);    

    Test.startTest();  

    opp4OD.stageName = 'Inbound';
    update opp4OD;

    Test.stopTest();

    Test.getEventBus().deliver();

    //do some assertion is possible
    list<EventBusSubscriber> ebs = [Select id,Topic  from EventBusSubscriber  where Topic='OpportunityChangeEvent' and Type='ApexTrigger'];
    System.assertEquals(ebs.size(),1,ebs[0]);

    //the above does not test the entire Data Change Capture chain because closing opp have some dependencies which throw exception sometime
    List<String> oppIDs = new List<String>();
    oppIDs.add(opp4OD.id);
    List<ID> pocIDs = OppDataChangeCaptureTriggerXHandler.invokeQueueable4FirstPOC(oppIDs);
    System.assertEquals(pocIDs.size(),0,'We do not expect POC due to not closing Opp');

}

@istest
/*******************************************
test this sorter hepler method  Add negative
scenario too for fun  
*******************************************/
private static void testPushItemOrderRight()
{
//pushItemOrderRight(List<Product_SubscriptionItem__c> sortedPSIs, integer startIndex, integer endIndex, integer pushto)
}

    
}