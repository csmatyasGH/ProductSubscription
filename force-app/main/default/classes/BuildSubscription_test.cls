@istest
global class BuildSubscription_test 
{

//@testsetup
private static void setupu()
{
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
    Opportunity opp4OD = (Opportunity) TestFactory.createSObject(new Opportunity(AccountId = accOD.Id, Name = 'OwnDealOpp'
                                                                                ,StageName = 'Closed Won', Type = 'New Logo'
                                                                                , CurrencyIsoCode = 'USD'
                                                                                ), true);
    System.Debug('CSABA_T Opp created Id = ' + Opp4OD.id);

   
    /****************************************************************************************/
    // create quote for own deal only account
    SBQQ__Quote__c quoteOD = (SBQQ__Quote__c) TestFactory.createSObject(new SBQQ__Quote__c(
            SBQQ__Opportunity2__c = opp4OD.Id,
            SBQQ__Primary__c = true
            ,CurrencyIsoCode = 'USD'
            ), true);
     System.Debug('CSABA_T CPQ Quote created Id = ' + quoteOD.id);   
    /****************************************************************************************/ 

    //CreateQLI_OLI(quoteOD.Id,opp4OD.Id,testProd1.Id);    
    Test.stopTest();

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
creae an Opportunity/Qoute/Items
update status and check
****************************************/
private static void testOpportunityDCC()
{
    Account acc4opp = (Account) TestFactory.createSObject(new Account(Name='TestAcc4OppDCC'), true);
    System.assertNotEquals(NULL,acc4opp.id,'we have account');
    Product2 testProd1 = [Select id  from Product2 where Name = 'Prod4PS' limit 1];    
    System.assertNotEquals(NULL,testProd1.id,'we have prod');

    Opportunity opp2test = [Select id  from Opportunity limit 1];
    System.Debug('CSABA_T Opp created Id = ' + opp2test.id);

    Test.startTest();

    opp2test.stageName = 'Closed Won';
    update opp2test;

    Test.stopTest();

    //close the opp and 


    Test.getEventBus().deliver();

}



@istest
/*****************************************
test the batch. Do not focus on the result 
because the batch call methods which were
already tested elswhere. Focus on coverage
*****************************************/
private static void testOppProcessBatch()
{
    Account acc4opp = (Account) TestFactory.createSObject(new Account(Name='TestAcc4OppDCC'), true);
    System.assertNotEquals(NULL,acc4opp.id,'we have account');
    Product2 testProd1 = [Select id  from Product2 where Name = 'Prod4PS' limit 1];    

    Opportunity opp2test = (Opportunity) TestFactory.createSObject(new Opportunity(AccountId = acc4opp.Id, Name = 'OwnDealOpp'
                                                                                ,StageName = 'Closed Won', Type = 'New Logo'
                                                                                , CurrencyIsoCode = 'USD'
                                                                                ), true);
    System.Debug('CSABA_T Opp created Id = ' + opp2test.id);

    Test.startTest();

    batchProcessAllOpps2PSPOC obj = new batchProcessAllOpps2PSPOC(opp2test.id);
    DataBase.executeBatch(obj,1); 

    Test.stopTest();


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
    system.assertEquals(items.size()>0,true,'we have a POC Item');

}

@istest
/****************************************
Add QLI and OLI to Qoute and Opportunity
create POC/Otems from Opp and do assert.
****************************************/
private static void testCreatePOCItems1()
{
SBQQ__Quote__c quoteOD = [Select Id,SBQQ__Opportunity2__c,SBQQ__Primary__c  //,SBQQ__Opportunity2__r.TriggerCounter__c 
                          from SBQQ__Quote__c where  SBQQ__Opportunity2__r.Name ='OwnDealOpp' limit 1];
Product2 testProd1 = [Select id  from Product2 where Name = 'Prod4PS' limit 1];
System.assertNotEquals(NULL,testProd1.id,'we have prod');

system.assertEquals(quoteOD != NULL,true,'we have a quote');
system.assertEquals(quoteOD.SBQQ__Primary__c,true,'we have a primary quote');

Test.startTest() ;

//System.Debug('CSABA TRIGGERCOUNTER 1 = ' + quoteOD.SBQQ__Opportunity2__r.TriggerCounter__c);
CreateQLI_OLI(quoteOD.Id,quoteOD.SBQQ__Opportunity2__c,testProd1.Id);   

//Opportunity opp = [Select id,TriggerCounter__c from opportunity where id = :quoteOD.SBQQ__Opportunity2__c]; 
//System.Debug('CSABA TRIGGERCOUNTER 2 = ' + opp.TriggerCounter__c);

Test.stopTest();

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
Tes AOL process
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

    Test.startTest() ;

    CreateQLI_OLI(quoteOD.Id,quoteOD.SBQQ__Opportunity2__c,testProd1.Id);
    
    Test.stopTest();

    Set<ID> pocId = BuildSubscriptionPOC.buildSubscriptionFromOpportunityAccountLink(quoteOD.SBQQ__Opportunity2__c);    
    system.assertEquals(pocId.size(),2,'we have a POC Item');

}

/*********************************************************************
method called from test method
*********************************************************************/
private static void createQLI_OLI(ID quoteId, ID oppID, ID prodID)
{
    SBQQ__QuoteLine__c quoteLineOD1 = (SBQQ__QuoteLine__c) TestFactory.createSObject(new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quoteId, 
            SBQQ__Product__c = prodID, 
            SBQQ__Quantity__c = 10
            ,SBQQ__NetPrice__c = 200
            ,SBQQ__StartDate__c = System.Today()
            ,SBQQ__EndDate__c = System.Today().addYears(1)
            ,CurrencyIsoCode = 'USD'
            ), true);
    //System.Debug('CSABA_T CPQ QLI created Id = ' + quoteLineOD1.id);   
    system.assertEquals(quoteLineOD1.id != NULL,true,'we have a QLI');           

     //create OppLineItems     
     PricebookEntry pbEntry = (PricebookEntry) TestFactory.createSObject(new PricebookEntry(Product2Id = prodID), true);     
     OpportunityLineItem oli1 = (OpportunityLineItem) TestFactory.createSObject(new OpportunityLineItem(
        OpportunityId = oppID,
        PricebookEntryId = pbEntry.Id,
        SBQQ__QuoteLine__c = quoteLineOD1.Id,
        Start_Date__c = System.Today(),
        End_Date__c = System.Today().addYears(1)
        ), true);   
    //System.Debug('CSABA_T CPQ OLI created Id = ' + oli1.id); 
    system.assertEquals(oli1.id != NULL,true,'we have an OLI'); 
} 

@istest
/************************************************
 * 
 * 
 ***********************************************/
public static void testgetitemRangeItemFraction() 
{
    ProductSubscription_POC__c refPOC =  [Select id from ProductSubscription_POC__c limit 1];
    
    Product_SubscriptionItem__c newpsi = createPSItem(NULL,refPOC.id,System.Date.today(),System.Date.today().addDays(60), 200,1, 5000,'ExtID',NULL);    

    Decimal fraction = ProductSubscriptionUtility.getitemRangeItemFraction(newpsi.Start_Date__c, newpsi.Start_Date__c.addDays(30),newpsi); 
    System.assertEquals(2500, fraction, 'We  have a fraction of the value');
}

@istest
/***********************************
**** X ****|
============
XXXXXXXXXXX|
***********************************/
private static void testSingleItem()
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

    ProductSubscription_POC__c refPOC =  [Select id from ProductSubscription_POC__c limit 1];
    
    Product_SubscriptionItem__c newpsi = createPSItem(NULL,refPOC.id,System.Date.today(),System.Date.today().addMonths(1), 100,1, 5000,'ExtID',NULL);
 
    test.startTest();
    //ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id); //
    ProductSubscriptionUtility.ConsolidateItems4SubsBBSUM(refPOC.id);
    test.stopTest();

    Product_SubscriptionItem__c consItem =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c 
                                             from Product_SubscriptionItem__c where RecordTypeid = :consRTID];
    System.assertNotEquals(NULL,consItem.id);

    System.assertEquals(newpsi.Start_Date__c,consItem.Start_Date__c);   
    System.assertEquals(newpsi.End_Date__c,consItem.End_Date__c);       
    System.assertEquals(newpsi.QuoteItem_Value__c,consItem.Net_Value__c);    
    System.assertEquals(newpsi.Quantity__c,consItem.Quantity__c); 
}

@istest
/********************************************
|**** X ****|
            |***** X *****|
==========================
|XXXXXXXXXXXXXXXXXXXXXXXXX|

********************************************/
private static void testContingentSameValue()
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

    ProductSubscription_POC__c refPOC =  [Select id from ProductSubscription_POC__c limit 1];
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(NULL,refPOC.id,System.Date.today(),System.Date.today().addMonths(1), 100,1, 5000,'ExtID_1',NULL);
    Product_SubscriptionItem__c newpsi2 = createPSItem(NULL,refPOC.id,newpsi1.End_Date__c.AddDays(1),newpsi1.End_Date__c.addMonths(1), 100,1, 5000,'ExtID_2',NULL);

    test.startTest();
    //ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
    ProductSubscriptionUtility.ConsolidateItems4SubsBBSUM(refPOC.id);    
    test.stopTest();    

    Product_SubscriptionItem__c consItem =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c 
                                             from Product_SubscriptionItem__c where RecordTypeid = :consRTID];
    System.assertNotEquals(NULL,consItem.id);

    System.assertEquals(newpsi1.Start_Date__c,consItem.Start_Date__c);   
    System.assertEquals(newpsi2.End_Date__c,consItem.End_Date__c);       
    System.assertEquals(newpsi1.QuoteItem_Value__c+newpsi1.QuoteItem_Value__c,consItem.Net_Value__c);    
    System.assertEquals(newpsi1.Quantity__c,consItem.Quantity__c);    

}

@istest
/********************************************
|**** X ****|
            |***** Y *****|
                          |**** Z *****|
========================================
|XXXXXXXXXXX|YYYYYYYYYYYYY|ZZZZZZZZZZZZ|

********************************************/
private static void testContingentDiffValue()
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

    ProductSubscription_POC__c refPOC =  [Select id from ProductSubscription_POC__c limit 1];
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(NULL,refPOC.id,System.Date.today(),System.Date.today().addMonths(1), 100,1, 2000,'ExtID_1',NULL);
    Product_SubscriptionItem__c newpsi2 = createPSItem(NULL,refPOC.id,newpsi1.End_Date__c.AddDays(1),newpsi1.End_Date__c.addMonths(1), 200,1, 4000,'ExtID_2',NULL);
    Product_SubscriptionItem__c newpsi3 = createPSItem(NULL,refPOC.id,newpsi2.End_Date__c.AddDays(1),newpsi2.End_Date__c.addMonths(1), 300,1, 6000,'ExtID_3',NULL);    

    test.startTest();
    //ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
    ProductSubscriptionUtility.ConsolidateItems4SubsBBSUM(refPOC.id);
    test.stopTest();    

    List<Product_SubscriptionItem__c> consItems =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c 
                                                    from Product_SubscriptionItem__c where RecordTypeid = :consRTID];
    System.assertEquals(3,consItems.size());

    System.assertEquals(newpsi1.Start_Date__c,consItems[0].Start_Date__c);   
    System.assertEquals(newpsi1.End_Date__c,consItems[0].End_Date__c); 

    System.assertEquals(newpsi1.QuoteItem_Value__c,consItems[0].Net_Value__c);    
    System.assertEquals(newpsi2.QuoteItem_Value__c,consItems[1].Net_Value__c);      
    System.assertEquals(newpsi3.QuoteItem_Value__c,consItems[2].Net_Value__c);     
  
}


@istest
/********************************************
|**** X ****|
            |***** Y *****|
                          |**** Y *****|
========================================
|XXXXXXXXXXX|YYYYYYYYYYYYYYYYYYYYYYYYYY|

********************************************/
private static void testContingentMixedValue()
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

    ProductSubscription_POC__c refPOC =  [Select id from ProductSubscription_POC__c limit 1];
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(NULL,refPOC.id,System.Date.today(),System.Date.today().addMonths(1), 100,1, 2000,'ExtID_1',NULL);
    Product_SubscriptionItem__c newpsi2 = createPSItem(NULL,refPOC.id,newpsi1.End_Date__c.AddDays(1),newpsi1.End_Date__c.addMonths(1), 200,1, 4000,'ExtID_2',NULL);
    Product_SubscriptionItem__c newpsi3 = createPSItem(NULL,refPOC.id,newpsi2.End_Date__c.AddDays(1),newpsi2.End_Date__c.addMonths(1), 200,1, 4000,'ExtID_3',NULL);    

    test.startTest();
    //ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
    ProductSubscriptionUtility.ConsolidateItems4SubsBBSUM(refPOC.id);
    test.stopTest();    

    List<Product_SubscriptionItem__c> consItems =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c from Product_SubscriptionItem__c where RecordTypeid = :consRTID];
    System.assertEquals(2,consItems.size());

    System.assertEquals(newpsi1.Start_Date__c,consItems[0].Start_Date__c);   
    System.assertEquals(newpsi1.End_Date__c,consItems[0].End_Date__c); 

    System.assertEquals(newpsi2.Start_Date__c,consItems[1].Start_Date__c);   
    System.assertEquals(newpsi3.End_Date__c,consItems[1].End_Date__c);     

    System.assertEquals(newpsi1.QuoteItem_Value__c,consItems[0].Net_Value__c);    
    System.assertEquals(newpsi2.QuoteItem_Value__c+newpsi3.QuoteItem_Value__c,consItems[1].Net_Value__c);  
    
    //ProductSubscriptionBuilder
   
}


@istest
/********************************************
|**** X ****|
            |***** Y *****|
                          |**** Y *****|
========================================
|XXXXXXXXXXX|YYYYYYYYYYYYYYYYYYYYYYYYYY|
********************************************/
private static void testContingentMixedValue_WithInvokable()
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

    ProductSubscription_POC__c refPOC =  [Select id, Account__c,Product__c from ProductSubscription_POC__c limit 1];
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(NULL,refPOC.id,System.Date.today(),System.Date.today().addMonths(1), 100,1, 2000,'ExtID_1',NULL);
    Product_SubscriptionItem__c newpsi2 = createPSItem(NULL,refPOC.id,newpsi1.End_Date__c.AddDays(1),newpsi1.End_Date__c.addMonths(1), 200,1, 4000,'ExtID_2',NULL);
    Product_SubscriptionItem__c newpsi3 = createPSItem(NULL,refPOC.id,newpsi2.End_Date__c.AddDays(1),newpsi2.End_Date__c.addMonths(1), 200,1, 4000,'ExtID_3',NULL);    

    ProductSubscriptionUtility.ProductSubscriptionBuilder psb =  new ProductSubscriptionUtility.ProductSubscriptionBuilder();

    test.startTest();

    //psb.operation = 'CONSOLIDATED_2.0';
    //psb.psID = refPOC.id;

    //try to update the statis  of the refPOC
    refPOC.status__c = 'CONSOLIDATED_2.0';
    update refPOC;

    refPOC.status__c = 'RESET';
    update refPOC;   
    
    refPOC.status__c = 'CONSOLODATED';
    update refPOC;    

    test.stopTest();    

    

    
    //if(operation == 'BuildFromOpp')
    //if(operation == 'BuildFromProdSubsc')
    //if(operation == 'CONSOLIDATED_2.0')

   
}

@istest
/********************************************
|**** X ****|
        |***** Y *****|
                |**** Z *****|
========================================
|XXXXXXX|YYYYYYY|ZZZZZZZZZZZZ|

********************************************/
private static void testOverLappedMixedValues_V1()
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

    ProductSubscription_POC__c refPOC =  [Select id from ProductSubscription_POC__c limit 1];
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(NULL,refPOC.id,System.Date.today(),System.Date.today().addMonths(2), 100,1, 2000,'ExtID_1',NULL);
    Product_SubscriptionItem__c newpsi2 = createPSItem(NULL,refPOC.id,newpsi1.Start_Date__c.AddDays(31),newpsi1.End_Date__c.addMonths(2), 200,1, 3000,'ExtID_2',NULL);
    Product_SubscriptionItem__c newpsi3 = createPSItem(NULL,refPOC.id,newpsi2.Start_Date__c.AddDays(31),newpsi2.End_Date__c.addMonths(2), 200,1, 4000,'ExtID_3',NULL);    

    test.startTest();

    ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
    test.stopTest();    

    List<Product_SubscriptionItem__c> consItems =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c from Product_SubscriptionItem__c where RecordTypeid = :consRTID];
    System.assertEquals(3,consItems.size());

    System.assertEquals(newpsi1.Start_Date__c,consItems[0].Start_Date__c);   
    //System.assertEquals(newpsi1.End_Date__c,consItems[0].End_Date__c); 

    System.assertEquals(newpsi2.Start_Date__c,consItems[1].Start_Date__c);   
    System.assertEquals(newpsi3.Start_Date__c,consItems[2].Start_Date__c);        
}

/*************************************************
 Same as above but use  Consolidation 2.0

 |**** X ********|
        |***** Y *************|
                        |**** Z *****|
========================================
|XXXXXXX| XL+YR  |  YM  |YR+ZL|  ZR  |

 ************************************************/
@Istest
private static void testOverLappedMixedValues_V2()
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

    ProductSubscription_POC__c refPOC =  [Select id,Account__c, Product__c from ProductSubscription_POC__c limit 1];

    ProductSubscription__c ootbheader = new ProductSubscription__c();
    ootbheader.Account__c = refPOC.Account__c;
    ootbheader.Product__c = refPOC.Product__c;
    ootbheader.External_Id__c = refPOC.Account__c + '_' + refPOC.Product__c;
    ootbheader = (ProductSubscription__c)TestFactory.createSObject(ootbheader,true);     
    ProductSubscription__c ootbPS = [Select id, Account__c,Product__c from ProductSubscription__c limit 1];
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(ootbPS.id,refPOC.id,System.Date.today(),System.Date.today().addMonths(2), 100,1, 2000,'ExtID_1',NULL);
    Product_SubscriptionItem__c newpsi2 = createPSItem(ootbPS.id,refPOC.id,newpsi1.Start_Date__c.AddDays(31),newpsi1.End_Date__c.addMonths(2), 200,1, 3000,'ExtID_2',NULL);
    Product_SubscriptionItem__c newpsi3 = createPSItem(ootbPS.id,refPOC.id,newpsi2.Start_Date__c.AddDays(31),newpsi2.End_Date__c.addMonths(2), 200,1, 4000,'ExtID_3',NULL);    

    List<Product_SubscriptionItem__c> cis;
    test.startTest();

    cis = ProductSubscriptionUtility.ConsolidateItems4SubsBBSUM(refPOC.id);
    test.stopTest();    

    List<Product_SubscriptionItem__c> consItems =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c,parent_PS__c,ParentSubscription__c from Product_SubscriptionItem__c where RecordTypeid = :consRTID];
    System.assertEquals(5,consItems.size());

    system.assertEquals(cis.size() > 0,true,'we have consolidated item' );
    Product_SubscriptionItem__c item = cis[0];
    System.Debug('CSABAT: consolidated item = ' + item);

    Id poc = item.ParentSubscription__c;
    system.assertNotEquals(poc, NULL,'we have Parent POC'); 

    Id parent_PS = item.Parent_PS__c;
    system.assertNotEquals(parent_PS, NULL,'we have Parent PS');

    system.assertEquals(parent_PS, consItems[0].Parent_PS__c,'we have Parent PS matching');    
   
    Set<ID> psIDs = new Set<ID>();
    psIDs.add(parent_PS);
    ProductSubscriptionUtility.MergeAllItems2Terms(psIDs);
    
    //test the Delete Comnsolifation and the Merge
    ProductSubscriptionUtility.DeleteConsolidatedItems(poc, true); 
        
}


@istest
/********************************************
|**** X ****|
            |***** x *****|
            |******** Y ********|
=================================
|XXXXXXXXXXX|YYYYYYYYYYYYYYYYYYY|

********************************************/
private static void testContingentOverruled_V1()
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

    ProductSubscription_POC__c refPOC =  [Select id from ProductSubscription_POC__c limit 1];
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(NULL,refPOC.id,System.Date.today(),System.Date.today().addMonths(1), 100,1, 2000,'ExtID_1',NULL);
    Product_SubscriptionItem__c newpsi2 = createPSItem(NULL,refPOC.id,newpsi1.End_Date__c.addDays(1),newpsi1.End_Date__c.addMonths(1).addDays(1), 100,1, 2000,'ExtID_2',NULL);
    Product_SubscriptionItem__c newpsi3 = createPSItem(NULL,refPOC.id,newpsi1.End_Date__c.addDays(1),newpsi2.End_Date__c.addMonths(1), 150,1,3000,'ExtID_3',NULL);    

    test.startTest();

    ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
    test.stopTest();    

    List<Product_SubscriptionItem__c> consItems =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c from Product_SubscriptionItem__c where RecordTypeid = :consRTID];
    System.assertEquals(2,consItems.size());

    System.assertEquals(newpsi1.Start_Date__c,consItems[0].Start_Date__c);   
    System.assertEquals(newpsi2.Start_Date__c,consItems[1].Start_Date__c);   
    //her we have to  heck if  the Quantit was overruled    
    System.assertEquals(consItems[1].Net_Value__c,3000);      
    System.assertEquals(consItems[1].Quantity__c,newpsi3.Quantity__c);        
}

@istest
/********************************************
|**** X ****|
            |***** x *****|
            |******** Y ********|
=================================
|XXXXXXXXXXX|YYYYYYYYYYYYYYYYYYY|

********************************************/
private static void testContingentOverruled_V2()
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

    ProductSubscription_POC__c refPOC =  [Select id from ProductSubscription_POC__c limit 1];
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(NULL,refPOC.id,System.Date.today(),System.Date.today().addMonths(1), 100,1, 2000,'ExtID_1',NULL);
    Product_SubscriptionItem__c newpsi2 = createPSItem(NULL,refPOC.id,newpsi1.End_Date__c.addDays(1),newpsi1.End_Date__c.addMonths(1).addDays(1), 100,1, 2000,'ExtID_2',NULL);
    Product_SubscriptionItem__c newpsi3 = createPSItem(NULL,refPOC.id,newpsi1.End_Date__c.addDays(1),newpsi2.End_Date__c.addMonths(1), 150,1,3000,'ExtID_3',NULL);    

    test.startTest();

    ProductSubscriptionUtility.ConsolidateItems4SubsBBSUM(refPOC.id);
    test.stopTest();    

    List<Product_SubscriptionItem__c> consItems =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c from Product_SubscriptionItem__c where RecordTypeid = :consRTID];
    System.assertEquals(3,consItems.size());

}

@istest
/*************************************
|**** X ****|
            |***** Z *****|
            |******** Y ********|
=================================
|XXXXXXXXXXX|YYYYYYYYYYYYYYYYYYY|

************************************/
private static void testOverruled()
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

    ProductSubscription_POC__c refPOC =  [Select id from ProductSubscription_POC__c limit 1];
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(NULL,refPOC.id,System.Date.today(),System.Date.today().addMonths(1), 100,1, 2000,'ExtID_1',NULL);
    Product_SubscriptionItem__c newpsi2 = createPSItem(NULL,refPOC.id,newpsi1.End_Date__c.addDays(1),newpsi1.End_Date__c.addMonths(1).addDays(1), 120,1, 2500,'ExtID_2',NULL);
    Product_SubscriptionItem__c newpsi3 = createPSItem(NULL,refPOC.id,newpsi1.End_Date__c.addDays(1),newpsi2.End_Date__c.addMonths(1), 150,1,3000,'ExtID_3',NULL);    

    test.startTest();
    //ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
    ProductSubscriptionUtility.ConsolidateItems4SubsBBSUM(refPOC.id);
    test.stopTest();    

    List<Product_SubscriptionItem__c> consItems =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c from Product_SubscriptionItem__c where RecordTypeid = :consRTID];
    System.assertEquals(3,consItems.size());

    //System.assertEquals(newpsi1.Start_Date__c,consItems[0].Start_Date__c);   
    //System.assertEquals(newpsi2.Start_Date__c,consItems[1].Start_Date__c);   
   
    //System.assertEquals(consItems[1].Quantity__c,newpsi3.Quantity__c);     
    //System.assertEquals(consItems[1].Net_Value__c,3000);      
}


/*************************************
|XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX|
            |YYYYYYYYYYYYYYYYYYY|
                 |ZZZZZZZZZZZZZZ|
=================================
|XXXXXXXXXXX|YYYY|ZZZZZZZZZZZZZZ|

************************************/
private static void testOverruled1()
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

    ProductSubscription_POC__c refPOC =  [Select id from ProductSubscription_POC__c limit 1];
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(NULL,refPOC.id,System.Date.today(),System.Date.today().addyears(1), 100,1, 2000,'ExtID_1',NULL);
    Product_SubscriptionItem__c newpsi2 = createPSItem(NULL,refPOC.id,newpsi1.Start_Date__c.addMonths(1),System.Date.today().addyears(1), 120,1, 2500,'ExtID_2',NULL);
    Product_SubscriptionItem__c newpsi3 = createPSItem(NULL,refPOC.id,newpsi1.Start_Date__c.addMonths(2),System.Date.today().addyears(1), 150,1,3000,'ExtID_3',NULL);    

    test.startTest();
    //ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
    ProductSubscriptionUtility.ConsolidateItems4SubsBBSUM(refPOC.id);
    test.stopTest();    

    List<Product_SubscriptionItem__c> consItems =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c from Product_SubscriptionItem__c where RecordTypeid = :consRTID];
    System.assertEquals(2,consItems.size());

    System.assertEquals(newpsi1.Start_Date__c,consItems[0].Start_Date__c);   
    System.assertEquals(newpsi2.Start_Date__c,consItems[1].Start_Date__c);   
   
    System.assertEquals(consItems[1].Quantity__c,newpsi3.Quantity__c);     
    System.assertEquals(consItems[1].Net_Value__c,3000);      
}


@istest
/**********************************
|**** X ****|
|**** -X ***|
=============
|00000000000|

**********************************/
private static void testfullDebok()
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

    ProductSubscription_POC__c refPOC =  [Select id from ProductSubscription_POC__c limit 1];
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(NULL,refPOC.id,System.Date.today(),System.Date.today().addMonths(1), 100,1, 5000,'ExtID_1',NULL);
    Product_SubscriptionItem__c newpsi2 = createPSItem(NULL,refPOC.id,System.Date.today(),System.Date.today().addMonths(1), 100,1, -5000,'ExtID_2',NULL);

    test.startTest();
    //ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
    ProductSubscriptionUtility.ConsolidateItems4SubsBBSUM(refPOC.id);
    test.stopTest();    

    List<Product_SubscriptionItem__c> consItems =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c from Product_SubscriptionItem__c where RecordTypeid = :consRTID];
    System.assertEquals(0,consItems.size());
}


@istest
/**************************************
|**** X ****|
|**** -Y ***|
=============
|*** X-Y ***|
**************************************/
private static void testfPartialDebok()
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

    ProductSubscription_POC__c refPOC =  [Select id from ProductSubscription_POC__c limit 1];
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(NULL,refPOC.id,System.Date.today(),System.Date.today().addMonths(1),100,1, 5000,'ExtID_1',NULL);
    Product_SubscriptionItem__c newpsi2 = createPSItem(NULL,refPOC.id,System.Date.today(),System.Date.today().addMonths(1),90,1, -4000,'ExtID_2',NULL);

    test.startTest();
    ProductSubscriptionUtility.ConsolidateItems4SubsBBSUM(refPOC.id);
    test.stopTest();    

    List<Product_SubscriptionItem__c> consItems =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c from Product_SubscriptionItem__c where RecordTypeid = :consRTID];
    System.assertEquals(1,consItems.size());

    System.assertEquals(newpsi1.QuoteItem_Value__c + newpsi2.QuoteItem_Value__c,consItems[0].Net_Value__c);           
}

@istest
/***********************************
|**** X ****|
    |**** Y ***|
================
|XXX|YYYYYYYYYY|

***********************************/
private static void testOverlapped()
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

    ProductSubscription_POC__c refPOC =  [Select id from ProductSubscription_POC__c limit 1];
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(NULL,refPOC.id,System.Date.today(),System.Date.today().addMonths(2),100,1, 5000,'ExtID_1',NULL);
    Product_SubscriptionItem__c newpsi2 = createPSItem(NULL,refPOC.id,System.Date.today().addMonths(1),System.Date.today().addMonths(3),90,1, 4000,'ExtID_2',NULL);

    test.startTest();
    ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
    //ProductSubscriptionUtility.ConsolidateItems4SubsBBSUM(refPOC.id);
    test.stopTest();    

    List<Product_SubscriptionItem__c> consItems =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c 
                                                    from Product_SubscriptionItem__c where RecordTypeid = :consRTID];
    System.assertEquals(2,consItems.size());


    Decimal fullLengthinDays = newpsi1.Start_Date__c.daysBetween(newpsi1.End_Date__c);
    Decimal truncatedLengthDays = newpsi1.Start_Date__c.daysBetween(newpsi2.Start_Date__c);    //in case of  small
    Decimal ratio = truncatedLengthDays.divide(fullLengthinDays,2);  

    
    System.assertEquals(newpsi1.QuoteItem_Value__c * ratio,consItems[0].Net_Value__c);  
    System.assertEquals(newpsi2.QuoteItem_Value__c,consItems[1].Net_Value__c);   
    //verify the start/End Date too       
}


@istest
/********************************************
|**** X ****|
            |***** x *****|
                          |**** x *****|
                          |**** -x ****|
========================================
|XXXXXXXXXXXXXXXXXXXXXXXXX|

********************************************/
private static void testContingentWithDebook_V1()
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

    ProductSubscription_POC__c refPOC =  [Select id from ProductSubscription_POC__c limit 1];
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(NULL,refPOC.id,System.Date.today(),System.Date.today().addMonths(1), 100,1, 2000,'ExtID_1',NULL);
    Product_SubscriptionItem__c newpsi2 = createPSItem(NULL,refPOC.id,newpsi1.End_Date__c.AddDays(1),newpsi1.End_Date__c.addMonths(1), 100,1, 2000,'ExtID_2',NULL);
    Product_SubscriptionItem__c newpsi3 = createPSItem(NULL,refPOC.id,newpsi2.End_Date__c.AddDays(1),newpsi2.End_Date__c.addMonths(1), 100,1, 2000,'ExtID_3',NULL);   
    Product_SubscriptionItem__c newpsi4 = createPSItem(NULL,refPOC.id,newpsi2.End_Date__c.AddDays(1),newpsi2.End_Date__c.addMonths(1), 100,1, -2000,'ExtID_4',NULL);      

    test.startTest();
    ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
    test.stopTest();    

    List<Product_SubscriptionItem__c> consItems =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c 
                                                    from Product_SubscriptionItem__c where RecordTypeid = :consRTID];
    System.assertEquals(1,consItems.size());

    System.assertEquals(newpsi1.Start_Date__c,consItems[0].Start_Date__c);   
    System.assertEquals(newpsi2.End_Date__c,consItems[0].End_Date__c); 

    System.assertEquals(newpsi1.QuoteItem_Value__c+newpsi2.QuoteItem_Value__c,consItems[0].Net_Value__c);       
  
}

@istest
/********************************************
|**** X ****|
            |***** x *****|
                          |**** x *****|
                          |**** -x ****|
========================================
|XXXXXXXXXXXXXXXXXXXXXXXXX|

********************************************/
private static void testContingentWithDebook_V2()
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

    ProductSubscription_POC__c refPOC =  [Select id from ProductSubscription_POC__c limit 1];
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(NULL,refPOC.id,System.Date.today(),System.Date.today().addMonths(1), 100,1, 2000,'ExtID_1',NULL);
    Product_SubscriptionItem__c newpsi2 = createPSItem(NULL,refPOC.id,newpsi1.End_Date__c.AddDays(1),newpsi1.End_Date__c.addMonths(1), 100,1, 2000,'ExtID_2',NULL);
    Product_SubscriptionItem__c newpsi3 = createPSItem(NULL,refPOC.id,newpsi2.End_Date__c.AddDays(1),newpsi2.End_Date__c.addMonths(1), 100,1, 2000,'ExtID_3',NULL);   
    Product_SubscriptionItem__c newpsi4 = createPSItem(NULL,refPOC.id,newpsi2.End_Date__c.AddDays(1),newpsi2.End_Date__c.addMonths(1), 100,1, -2000,'ExtID_4',NULL);      

    test.startTest();
    ProductSubscriptionUtility.ConsolidateItems4SubsBBSUM(refPOC.id);
    test.stopTest();    

    List<Product_SubscriptionItem__c> consItems =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c 
                                                    from Product_SubscriptionItem__c where RecordTypeid = :consRTID];
    System.assertEquals(1,consItems.size());

    System.assertEquals(newpsi1.Start_Date__c,consItems[0].Start_Date__c);   
    System.assertEquals(newpsi2.End_Date__c,consItems[0].End_Date__c); 

    System.assertEquals(newpsi1.QuoteItem_Value__c+newpsi2.QuoteItem_Value__c,consItems[0].Net_Value__c);       
  
}

@istest
/*****************************************************

|**** X ****|
            |***** x *****|
            |**** -x *****|
                |**** Y *********|
==================================
|XXXXXXXXXXX|000|   YL    | YR   |

*****************************************************/
private static void testContingentWithDeokAndNewLogo()
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

    ProductSubscription_POC__c refPOC =  [Select id from ProductSubscription_POC__c limit 1];
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(NULL,refPOC.id,System.Date.today(),System.Date.today().addMonths(1), 100,1, 2000,'ExtID_1',NULL);
    Product_SubscriptionItem__c newpsi2 = createPSItem(NULL,refPOC.id,newpsi1.End_Date__c.AddDays(1),newpsi1.End_Date__c.addMonths(1), 100,1, 2000,'ExtID_2',NULL);
    Product_SubscriptionItem__c newpsi3 = createPSItem(NULL,refPOC.id,newpsi1.End_Date__c.AddDays(1),newpsi1.End_Date__c.addMonths(1), 100,1, -2000,'ExtID_3',NULL);   
    Product_SubscriptionItem__c newpsi4 = createPSItem(NULL,refPOC.id,newpsi1.End_Date__c.AddDays(10),newpsi2.End_Date__c.addMonths(2), 110,1,  2500,'ExtID_4',NULL);      

    test.startTest();
    //ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
    ProductSubscriptionUtility.ConsolidateItems4SubsBBSUM(refPOC.id);
    test.stopTest();    

    List<Product_SubscriptionItem__c> consItems =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c 
                                                    from Product_SubscriptionItem__c where RecordTypeid = :consRTID
                                                    order by Start_Date__c asc];
    System.assertEquals(3,consItems.size());

    System.assertEquals(newpsi1.Start_Date__c,consItems[0].Start_Date__c);   
    System.assertEquals(newpsi1.End_Date__c,consItems[0].End_Date__c); 

    System.assertEquals(newpsi1.QuoteItem_Value__c,consItems[0].Net_Value__c);    
    //System.assertEquals(newpsi4.QuoteItem_Value__c,consItems[1].Net_Value__c);      
   
}


/****************************************

|**** X ****|
            |***** x *****|
            |**** uZ  ****|
===========================
|XXXXXXXXXXX|**** X+Z ****|

****************************************/
@istest
private static void testFullRangeUpsell_V1()
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

    ProductSubscription_POC__c refPOC =  [Select id from ProductSubscription_POC__c limit 1];
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(NULL,refPOC.id,System.Date.today(),System.Date.today().addMonths(1), 100,1, 2000,'ExtID_1',NULL);
    Product_SubscriptionItem__c newpsi2 = createPSItem(NULL,refPOC.id,newpsi1.End_Date__c.AddDays(1),newpsi1.End_Date__c.addMonths(2), 200,1, 4000,'ExtID_2',NULL);
    Product_SubscriptionItem__c newpsi3 = createPSItem(NULL,refPOC.id,newpsi1.End_Date__c.AddDays(1),newpsi1.End_Date__c.addMonths(2), 100,1, 6000,'ExtID_3','Upsell');    

    test.startTest();
    ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
    test.stopTest();

    List<Product_SubscriptionItem__c> consItems =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c 
                                                    from Product_SubscriptionItem__c where RecordTypeid = :consRTID
                                                    order by Start_Date__c asc];
    System.assertEquals(2,consItems.size());    
}


@istest
private static void testFullRangeUpsell_V2()
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

    ProductSubscription_POC__c refPOC =  [Select id from ProductSubscription_POC__c limit 1];
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(NULL,refPOC.id,System.Date.today(),System.Date.today().addMonths(1), 100,1, 2000,'ExtID_1',NULL);
    Product_SubscriptionItem__c newpsi2 = createPSItem(NULL,refPOC.id,newpsi1.End_Date__c.AddDays(1),newpsi1.End_Date__c.addMonths(2), 200,1, 4000,'ExtID_2',NULL);
    Product_SubscriptionItem__c newpsi3 = createPSItem(NULL,refPOC.id,newpsi1.End_Date__c.AddDays(1),newpsi1.End_Date__c.addMonths(2), 100,1, 6000,'ExtID_3','Upsell');    

    test.startTest();
    ProductSubscriptionUtility.ConsolidateItems4SubsBBSUM(refPOC.id);
    test.stopTest();

    List<Product_SubscriptionItem__c> consItems =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c 
                                                    from Product_SubscriptionItem__c where RecordTypeid = :consRTID
                                                    order by Start_Date__c asc];
    System.assertEquals(2,consItems.size());    
}

/*******************************************

|**** Y ****|
            |************ x ***************|
                          |******* uZ *****|
============================================
|XXXXXXXXXXX|*** -tlX *** |**** -trX+Z ****|

*******************************************/
@istest
private static void testRightSideUpsell()
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

    ProductSubscription_POC__c refPOC =  [Select id from ProductSubscription_POC__c limit 1];
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(NULL,refPOC.id,System.Date.today(),System.Date.today().addMonths(1), 100,1, 2000,'ExtID_1',NULL);
    Product_SubscriptionItem__c newpsi2 = createPSItem(NULL,refPOC.id,newpsi1.End_Date__c.AddDays(1),newpsi1.End_Date__c.addMonths(2), 200,1, 4000,'ExtID_2',NULL);
    Product_SubscriptionItem__c newpsi3 = createPSItem(NULL,refPOC.id,newpsi1.End_Date__c.AddDays(30),newpsi1.End_Date__c.addMonths(2), 100,1, 6000,'ExtID_3','Upsell');    

    test.startTest();
    //ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
    ProductSubscriptionUtility.ConsolidateItems4SubsBBSUM(refPOC.id);
    test.stopTest();    

    List<Product_SubscriptionItem__c> consItems =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c 
                                                    from Product_SubscriptionItem__c where RecordTypeid = :consRTID
                                                    order by Start_Date__c asc];
    System.assertEquals(3,consItems.size());       
}


/************************************

|**** Y *************|
            |***** x ***************|
            |**** -x ***************|
=====================================
|****** Y ***********|

************************************/
@istest
private static void testTOBEWRITTEN()
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

    Account accOD = (Account) TestFactory.createSObject(new Account(Name='ONDEAL_ONLY'), true);
    System.assertNotEquals(NULL,accOD.id,'we have account');

    Product2 testProd1 = (Product2) TestFactory.createSObject(new Product2(Name = 'Prod4PS'), true);  
    System.assertNotEquals(NULL,testProd1.id,'we have product');

    ProductSubscription_POC__c refPOC =  new ProductSubscription_POC__c();
    refPOC.Account__c = accOD.id;
    refPOC.Product__c = testProd1.id;
    refPOC = (ProductSubscription_POC__c)TestFactory.createSObject(refPOC,true);   
    System.assertNotEquals(NULL,refPOC.id,'we have POC');    
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(NULL,refPOC.id,System.Date.today(),System.Date.today().addyears(1), 100,1, 2000,'ExtID_1',NULL);
    Product_SubscriptionItem__c newpsi2 = createPSItem(NULL,refPOC.id,newpsi1.Start_Date__c.AddMonths(6),newpsi1.End_Date__c.addMonths(6), 200,1, 4000,'ExtID_2',NULL);
    Product_SubscriptionItem__c newpsi3 = createPSItem(NULL,refPOC.id,newpsi1.Start_Date__c.AddMonths(6),newpsi1.End_Date__c.addMonths(6), -200,1, -4000,'ExtID_3',NULL);    

    test.startTest();
    //ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
    ProductSubscriptionUtility.ConsolidateItems4SubsBBSUM(refPOC.id);
    test.stopTest();    

    List<Product_SubscriptionItem__c> consItems =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c 
                                                    from Product_SubscriptionItem__c where RecordTypeid = :consRTID
                                                    order by Start_Date__c asc];
    System.assertEquals(1,consItems.size());       
}

/*******************************************

|**** Y *************|
            |***** x ***************|
            |**** -x ***************|
                     |******* Y **********|
===========================================
|******************* 2Y ******************|

*******************************************/
@istest
private static void testTOBEWRITTEN1()
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

    Account accOD = (Account) TestFactory.createSObject(new Account(Name='ONDEAL_ONLY'), true);
    System.assertNotEquals(NULL,accOD.id,'we have account');

    Product2 testProd1 = (Product2) TestFactory.createSObject(new Product2(Name = 'Prod4PS'), true);  
    System.assertNotEquals(NULL,testProd1.id,'we have product');

    ProductSubscription_POC__c refPOC =  new ProductSubscription_POC__c();
    refPOC.Account__c = accOD.id;
    refPOC.Product__c = testProd1.id;
    refPOC = (ProductSubscription_POC__c)TestFactory.createSObject(refPOC,true);   
    System.assertNotEquals(NULL,refPOC.id,'we have POC');    
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(NULL,refPOC.id,System.Date.today(),System.Date.today().addyears(1), 100,1, 2000,'ExtID_1',NULL);
    Product_SubscriptionItem__c newpsi2 = createPSItem(NULL,refPOC.id,newpsi1.Start_Date__c.AddMonths(6),newpsi1.End_Date__c.addMonths(6), 200,1, 4000,'ExtID_2',NULL);
    Product_SubscriptionItem__c newpsi3 = createPSItem(NULL,refPOC.id,newpsi1.Start_Date__c.AddMonths(6),newpsi1.End_Date__c.addMonths(6), -200,1, -4000,'ExtID_3',NULL);    
    Product_SubscriptionItem__c newpsi4 = createPSItem(NULL,refPOC.id,newpsi1.End_Date__c.addDays(1),newpsi1.End_Date__c.addyears(1), 100,1, 2000,'ExtID_4',NULL);

    test.startTest();
    //ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
    ProductSubscriptionUtility.ConsolidateItems4SubsBBSUM(refPOC.id);
    test.stopTest();    

    List<Product_SubscriptionItem__c> consItems =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c 
                                                    from Product_SubscriptionItem__c where RecordTypeid = :consRTID
                                                    order by Start_Date__c asc];
    System.assertEquals(1,consItems.size());       
}



/*********************************************************************************************************************************************************************************
not a test method used to create data fr the test methods
param0: ootb PS ID
param1: POC id
param2,3: StartDate,EndDate
param4:   Quantity
param5:    
param6:   Inherited QuoteLineItem Value
param7:   ExternalID
param8:   Opportunity Type (used to handle Upsell)  Options: "New Logo", "Renewal","Upsell" 
*********************************************************************************************************************************************************************************/
private static Product_SubscriptionItem__c createPSItem(ID ootbheaderID, ID headerID,Date sD,Date eD, Integer quantity,Integer yearI, Decimal qliVal,String extID, String oppType)
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 

    Product_SubscriptionItem__c newpsi =  new Product_SubscriptionItem__c(RecordTypeID = qliRTID);    
    newpsi.ParentSubscription__c = headerID;
    newpsi.Start_Date__c = sD;
    newpsi.End_Date__c = eD;
    newpsi.Duration__c = newpsi.Start_Date__c.monthsBetween(newpsi.End_Date__c);       
    
    newpsi.Quantity__c = quantity;
    newpsi.QuoteItem_Value__c = qliVal;
    newpsi.YearIndex__c = yearI;

    newpsi.External_Id__c = extID;   
    newpsi.OppType__c = oppType;

    if(ootbheaderID != NULL)
       {
       newpsi.parent_PS__c = ootbheaderID;    
       }

    insert newpsi; //use factory

    newpsi = [Select id,Start_Date__c,End_Date__c,Quantity__c,QuoteItem_Value__c,Net_Value__c,YearIndex__c,External_Id__c   
              from Product_SubscriptionItem__c where id = :newpsi.id];

    return newpsi;
}


}