@istest
global class BuildSubscription_test 
{

@testsetup
private static void setup()
{
    DisablePB('Opportunity_Process');  

    Account accOD = (Account) TestFactory.createSObject(new Account(Name='ONDEAL_ONLY'), true);
    System.assertNotEquals(NULL,accOD.id,'we have account');

    Product2 testProd1 = (Product2) TestFactory.createSObject(new Product2(Name = 'Prod4PS'), true);  
    System.assertNotEquals(NULL,testProd1.id,'we have product');

    ProductSubscription_POC__c header =  new ProductSubscription_POC__c();
    header.Account__c = accOD.id;
    header.Product__c = testProd1.id;
 	header = (ProductSubscription_POC__c)TestFactory.createSObject(header,true);   
    System.assertNotEquals(NULL,header.id,'we have POC');

    Test.startTest();  
    /********************************* OWN DEAL ONLY START **************************************************/
    Opportunity opp4OD = new Opportunity(AccountId = accOD.Id, Name = 'OwnDealOpp' ,StageName = 'Closed Won', Type = 'New Logo', CurrencyIsoCode = 'USD',closeDate = System.Date.Today().addDays(1) );
    insert  opp4OD;                                                                           
    System.assertNotEquals(opp4OD.id,Null,'we hae an opp');

   
    /****************************************************************************************/
    // create quote for own deal only account
    SBQQ__Quote__c quoteOD = new SBQQ__Quote__c(
            SBQQ__Opportunity2__c = opp4OD.Id,
            SBQQ__Primary__c = true
            ,CurrencyIsoCode = 'USD'
            );
    insert  quoteOD;       
    System.assertNotEquals(quoteOD.id,Null,'we hae a quote');  
    /****************************************************************************************/ 

    //CreateQLI_OLI(quoteOD.Id,opp4OD.Id,testProd1.Id,null);        create exception for sure
    Test.stopTest();

}


/*******************************************
we can have only 1 Custom settings.
*******************************************/
private static void DisablePB(String PNName)
{
    PB_Skipper__c skipper;

    skipper = new PB_Skipper__c ();
    skipper.PB_Name__c = PNName;
    skipper.DoSkip__c = true;
    insert skipper;
    
}


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
/*****************************************
test the batch. Do not focus on the result 
because the batch call methods which were
already tested elswhere. Focus on coverage
*****************************************/
private static void testOppProcessBatch()
{
    SBQQ__Quote__c quoteOD = [Select Id,SBQQ__Opportunity2__c,SBQQ__Primary__c  //,SBQQ__Opportunity2__r.TriggerCounter__c 
    from SBQQ__Quote__c 
    where  SBQQ__Opportunity2__r.Name ='OwnDealOpp' 
    limit 1];
    Product2 testProd1 = [Select id  from Product2 where Name = 'Prod4PS' limit 1];

    ID qliID = CreateQLI_OLI(quoteOD.Id,quoteOD.SBQQ__Opportunity2__c,testProd1.Id,NULL);  

    Test.startTest() ;
    batchProcessAllOpps2PSPOC obj = new batchProcessAllOpps2PSPOC(quoteOD.SBQQ__Opportunity2__c);
    DataBase.executeBatch(obj,1); 

    Test.stopTest();

}

@istest
/****************************************
Add QLI and OLI to Qoute and Opportunity
create POC/Otems from Opp and do assert.
****************************************/
private static void testCreatePOCItems1()
{
SBQQ__Quote__c quoteOD = [Select Id,SBQQ__Opportunity2__c,SBQQ__Primary__c  //,SBQQ__Opportunity2__r.TriggerCounter__c 
                          from SBQQ__Quote__c 
                          where  SBQQ__Opportunity2__r.Name ='OwnDealOpp' 
                          limit 1];
Product2 testProd1 = [Select id  from Product2 where Name = 'Prod4PS' limit 1];
System.assertNotEquals(NULL,testProd1.id,'we have prod');

system.assertEquals(quoteOD != NULL,true,'we have a quote');
system.assertEquals(quoteOD.SBQQ__Primary__c,true,'we have a primary quote');

ID qliID;
ID oliID;
Test.startTest() ;
//DisablePB('Quote_Process'); //to avoid firing PB which might lead to CPU Limit
qliID = CreateQLI_OLI(quoteOD.Id,quoteOD.SBQQ__Opportunity2__c,testProd1.Id,NULL);  

Test.stopTest();

oliID = CreateQLI_OLI(quoteOD.Id,quoteOD.SBQQ__Opportunity2__c,testProd1.Id,qliID);   
system.assertEquals(qliID != NULL,true,'we have a quoteLineItem');

List<OpportunityLineItem> olis = [Select ID  from OpportunityLineItem 
                                  where SBQQ__QuoteLine__c = :qliID
                                  ];
//system.assertEquals(olis.size() > 0,true,'we have a OLIs');

Set<ID> pocId = BuildSubscriptionPOC.buildSubscriptionFromOpportunityAccountLink(quoteOD.SBQQ__Opportunity2__c);
system.assertEquals(pocId.size() > 0,true,'we have a POC.');

ProductSubscription_POC__c thePOc = [Select Id, Account__c, Product__c
                                     ,(Select Id,Parent_PS__c,Start_Date__c,End_Date__c,itemOrder__c,OppCreatedDate__c,
                                     OriginQuote_Line__c, OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.Name,OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__c,
                                     QuoteItem_NetTotal__c,ARR__c,MRR__c,TermNetValue__c,Duration__c
                                     from Product_SubscriptionItems__r )  
                                    from ProductSubscription_POC__c where id in :pocID];
Id thepocidu;
for(ID pocIdu :pocId)
   {
    thepocidu = pocIDu;
    break;
   }
system.assertEquals(thePOc.id,thepocidu,'we have a POC');

List<Product_SubscriptionItem__c> items = thePOC.Product_SubscriptionItems__r;
system.assertEquals(items.size(),1,'we have a POC Item');

}

@istest
/*****************************************
Test AOL process
*****************************************/ 
 private static void testCreatePOCItems2()
{ 
    Account onBehalf1 = (Account) TestFactory.createSObject(new Account(Name='ONBehalf1'), true);
    Account onBehalf2 = (Account) TestFactory.createSObject(new Account(Name='ONBehalf2'), true);

    SBQQ__Quote__c quoteOD = [Select Id,SBQQ__Opportunity2__c from SBQQ__Quote__c where  SBQQ__Opportunity2__r.Name ='OwnDealOpp' limit 1];
    Product2 testProd1 = [Select id  from Product2 where Name = 'Prod4PS'  limit 1];

    List<OpportunityAccountLink__c> aols =  new List<OpportunityAccountLink__c>();

    OpportunityAccountLink__c theOAL1 = new OpportunityAccountLink__c();
    theOAL1.Opportunity__c = quoteOD.SBQQ__Opportunity2__c;
    theOAL1.Account__c = ONBehalf1.id;
    theOAL1.Percentage__c = 50;
    aols.add(theOAL1);

    OpportunityAccountLink__c theOAL2 = new OpportunityAccountLink__c();
    theOAL2.Opportunity__c = quoteOD.SBQQ__Opportunity2__c;
    theOAL2.Account__c = ONBehalf2.id;
    theOAL2.Percentage__c = 50;
    aols.add(theOAL2);    

    Database.insert(aols,false);      
    ID qli;
    Test.startTest() ;

    qli = CreateQLI_OLI(quoteOD.Id,quoteOD.SBQQ__Opportunity2__c,testProd1.Id,NULL);
    
    Test.stopTest();
    ID oliID = CreateQLI_OLI(quoteOD.Id,quoteOD.SBQQ__Opportunity2__c,testProd1.Id,qli);
    Set<ID> pocId = BuildSubscriptionPOC.buildSubscriptionFromOpportunityAccountLink(quoteOD.SBQQ__Opportunity2__c);    
    system.assertEquals(pocId.size(),2,'we have a POC Item');

}

@istest
/******************************************
Test AOL process and NO AOL process in one.
******************************************/ 
 private static void testCreatePOCItems1_2()
{ 
    SBQQ__Quote__c quoteOD = [Select Id,SBQQ__Opportunity2__c,SBQQ__Opportunity2__r.AccountID from SBQQ__Quote__c where  SBQQ__Opportunity2__r.Name ='OwnDealOpp' limit 1];
    Product2 testProd1 = [Select id  from Product2 where Name = 'Prod4PS'  limit 1];

  
    ID qli;
    Test.startTest() ;
    //DisablePB('Quote_Process'); //to avoid firing PB which might lead to CPU Limit
    qli = CreateQLI_OLI(quoteOD.Id,quoteOD.SBQQ__Opportunity2__c,testProd1.Id,NULL);
    
    Test.stopTest();


    //once this is done test the AOL too
    Account onBehalf1 = (Account) TestFactory.createSObject(new Account(Name='ONBehalf1'), true);
    Account onBehalf2 = (Account) TestFactory.createSObject(new Account(Name='ONBehalf2'), true);

    List<OpportunityAccountLink__c> aols =  new List<OpportunityAccountLink__c>();

    OpportunityAccountLink__c theOAL1 = new OpportunityAccountLink__c();
    theOAL1.Opportunity__c = quoteOD.SBQQ__Opportunity2__c;
    theOAL1.Account__c = ONBehalf1.id;
    theOAL1.Percentage__c = 50;
    aols.add(theOAL1);

    OpportunityAccountLink__c theOAL2 = new OpportunityAccountLink__c();
    theOAL2.Opportunity__c = quoteOD.SBQQ__Opportunity2__c;
    theOAL2.Account__c = ONBehalf2.id;
    theOAL2.Percentage__c = 50;
    aols.add(theOAL2);    
  

    Database.insert(aols,false);    

    ID oliID = CreateQLI_OLI(quoteOD.Id,quoteOD.SBQQ__Opportunity2__c,testProd1.Id,qli);
    Set<ID> pocId = BuildSubscriptionPOC.buildSubscriptionFromOpportunityAccountLink(quoteOD.SBQQ__Opportunity2__c);    
    system.assertEquals(pocId.size(),2,'we have a POC Item');

    theOAL1.Percentage__c = 0;
    theOAL2.Percentage__c = 0;    
    update aols;

    pocId = BuildSubscriptionPOC.buildSubscriptionFromOpportunityAccountLink(quoteOD.SBQQ__Opportunity2__c);   
    system.assertEquals(pocId.size(),1,'we have a POC Item');

    List<Task> myt = [Select id from Task where Subject = 'SKIP PB Opportunity_Process' limit 1];
    //NOT IMPLEMENTED IN DEV system.assertEquals(myt != NULL,true,'we really skipped PB. Goooood.');    
}

/************************************************************************
method called from test method
*************************************************************************/
private static ID createQLI_OLI(ID quoteId, ID oppID, ID prodID, Id QLIID)
{

    if(QLIID == null)
    {
        SBQQ__QuoteLine__c quoteLineOD1 = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quoteId, 
            SBQQ__Product__c = prodID, 
            SBQQ__Quantity__c = 10,
            SBQQ__NetPrice__c = 200
            ,SBQQ__StartDate__c = System.Today()
            ,SBQQ__EndDate__c = System.Today().addYears(1)
            ,CurrencyIsoCode = 'USD'
            );
    insert  quoteLineOD1;       
    //System.Debug('CSABA_T CPQ QLI created Id = ' + quoteLineOD1.id);   
    system.assertEquals(quoteLineOD1.id != NULL,true,'we have a QLI'); 
    return  quoteLineOD1.id; 
    } 
 
   

     //create OppLineItems 
     /******************************************************************************************************************/
     PricebookEntry pbEntry = (PricebookEntry) TestFactory.createSObject(new PricebookEntry(Product2Id = prodID), true); 
     OpportunityLineItem oli1 = new OpportunityLineItem(
        OpportunityId = oppID,
        PricebookEntryId = pbEntry.Id,
        SBQQ__QuoteLine__c = QLIID, //quoteLineOD1.Id,
        Start_Date__c = System.Today(),
        End_Date__c = System.Today().addYears(1)
        ,Quantity = 10,TotalPrice = 200
        ); 
    insert oli1;
    system.assertEquals(oli1.id != NULL,true,'we have an OLI'); 
    return  oli1.id;         
    //******************************************************************************************************************/    
    
} 


@istest
/*****************************************
Create a couple of Prod subscription for
the same Account and call the bacth 
*****************************************/
private static void testProdonAccountBatch()
{
    ProductSubscription_POC__c refPOC =  [Select id,Account__c, Product__c, Product__r.Family from ProductSubscription_POC__c limit 1];

    ProductSubscription__c header1 = createHeaderPS(refPOC.Account__c,refPOC.Product__c);  
    ProductSubscriptionTerm__c term1 = createTerm(header1.id, 1, -1);

    Product2 testProd1 = (Product2) TestFactory.createSObject(new Product2(Name = 'Prod4PS_1',Family = 'Canvas'), true);      
    ProductSubscription__c header2 = createHeaderPS(refPOC.Account__c,testProd1.id);     
    ProductSubscriptionTerm__c term2 = createTerm(header1.id, 2, -1); 

    Test.startTest();

    batchBuildDynamicAcountPSRel obj = new batchBuildDynamicAcountPSRel(false,refPOC.Account__c);
    DataBase.executeBatch(obj,1); 

    Test.stopTest();

    Account acc = [Select id, ProductsonAccount__c  from Account where id = :refPOC.Account__c];
    System.assertEquals(acc.ProductsonAccount__c.contains('Canvas'),true,acc.ProductsonAccount__c);
}

@istest
/************************************
Create ProdSubsc and a some of Terms
Play with the CurrentTerm and Active
by simulating an out of sync status.
the  call the bacth to fix  it. EASY
************************************/
private static void testPSsyncBatch()
{
    ProductSubscription_POC__c refPOC =  [Select id,Account__c, Product__c from ProductSubscription_POC__c limit 1];

    ProductSubscription__c header1 = createHeaderPS(refPOC.Account__c,refPOC.Product__c);  
    ProductSubscriptionTerm__c term1 = createTerm(header1.id,1, -21);
    ProductSubscriptionTerm__c term2 = createTerm(header1.id,2, -11);   
    header1.CurrentSubscriptionTerm__c = term2.id;
    update header1;

    header1 = [Select id,SubscriptionStatus__c,SyncStatus__c,CurrentSubscriptionTerm__c from  ProductSubscription__c where id = :header1.id]; 
    system.assertEquals('Active', header1.SubscriptionStatus__c,header1);
    system.assertEquals('out of sync', header1.SyncStatus__c,header1);    

    Test.startTest();

    batchSynchronizeProdSubscrTerms obj = new batchSynchronizeProdSubscrTerms(header1.id);
    DataBase.executeBatch(obj,1); 

    Test.stopTest();

    header1 = [Select id,SubscriptionStatus__c,SyncStatus__c,CurrentSubscriptionTerm__c,StartDate__c,EndDate__c from  ProductSubscription__c where id = :header1.id]; 
    system.assertEquals('Expired', header1.SubscriptionStatus__c,'Synched to Expired');
}

/***********************************************************************
 create ProdSubscr to be used by other test method
 **********************************************************************/
private static ProductSubscription__c createHeaderPS(ID accId,ID prodID)
{
    ProductSubscription__c header = new ProductSubscription__c();
    header.Account__c = accId;
    header.Product__c = prodID;
    header.External_Id__c = accId + '_' + prodID;
    header.SubscriptionStatus__c = 'Active';
    //add Current term to this to make it  active
    header = (ProductSubscription__c)TestFactory.createSObject(header,true); 
    
    return header;
}

/***********************************************************************************************************
Create the Term for the Header.  helper method  which will be called from test method
***********************************************************************************************************/
private static ProductSubscriptionTerm__c createTerm(Id headerID, integer itemindex, integer startDateindex)
{
ProductSubscriptionTerm__c retval = new ProductSubscriptionTerm__c();

retval.StartDate__c = System.Date.today().addDays(startDateindex);
retval.EndDate__c = System.Date.today().addDays(startDateindex + 10);

retval.Name = 'HOMEMADE_TERM_' +  string.valueOf(itemindex);  

//set the parent too
retval.ProductSubscription__c = headerID;
insert retval;
return retval;
}  

}