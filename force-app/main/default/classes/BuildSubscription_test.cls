@istest
global class BuildSubscription_test 
{

@testsetup
private static void setup()
{
	Account theA =  new Account(Name = 'TestAcc');
	theA = (Account)TestFactory.createSObject(theA,true);

    Product2 theP = new Product2(Name = 'SubscriptionProd');
	theP = (Product2)TestFactory.createSObject(theP,true);    
    System.assertNotEquals(NULL,theP.id);

    ProductSubscription_POC__c header =  new ProductSubscription_POC__c();
    header.Account__c = theA.id;
    header.Product__c = theP.id;
 	header = (ProductSubscription_POC__c)TestFactory.createSObject(header,true);   

    System.assertNotEquals(NULL,header.id);

    //create an OOTB product Subscription to be added to POC Items
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
    
    Product_SubscriptionItem__c newpsi = createPSItem(refPOC.id,System.Date.today(),System.Date.today().addMonths(1), 100,1, 5000,'ExtID');
 
    test.startTest();
    ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
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
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(refPOC.id,System.Date.today(),System.Date.today().addMonths(1), 100,1, 5000,'ExtID_1');
    Product_SubscriptionItem__c newpsi2 = createPSItem(refPOC.id,newpsi1.End_Date__c.AddDays(1),newpsi1.End_Date__c.addMonths(1), 100,1, 5000,'ExtID_2');

    test.startTest();
    ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
    test.stopTest();    

    Product_SubscriptionItem__c consItem =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c 
                                             from Product_SubscriptionItem__c where RecordTypeid = :consRTID];
    System.assertNotEquals(NULL,consItem.id);

    System.assertEquals(newpsi1.Start_Date__c,consItem.Start_Date__c);   
    System.assertEquals(newpsi2.End_Date__c,consItem.End_Date__c);       
    System.assertEquals(newpsi1.QuoteItem_Value__c,consItem.Net_Value__c);    
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
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(refPOC.id,System.Date.today(),System.Date.today().addMonths(1), 100,1, 2000,'ExtID_1');
    Product_SubscriptionItem__c newpsi2 = createPSItem(refPOC.id,newpsi1.End_Date__c.AddDays(1),newpsi1.End_Date__c.addMonths(1), 200,1, 4000,'ExtID_2');
    Product_SubscriptionItem__c newpsi3 = createPSItem(refPOC.id,newpsi2.End_Date__c.AddDays(1),newpsi2.End_Date__c.addMonths(1), 300,1, 6000,'ExtID_3');    

    test.startTest();
    ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
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
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(refPOC.id,System.Date.today(),System.Date.today().addMonths(1), 100,1, 2000,'ExtID_1');
    Product_SubscriptionItem__c newpsi2 = createPSItem(refPOC.id,newpsi1.End_Date__c.AddDays(1),newpsi1.End_Date__c.addMonths(1), 200,1, 4000,'ExtID_2');
    Product_SubscriptionItem__c newpsi3 = createPSItem(refPOC.id,newpsi2.End_Date__c.AddDays(1),newpsi2.End_Date__c.addMonths(1), 200,1, 4000,'ExtID_3');    

    test.startTest();
    ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
    test.stopTest();    

    List<Product_SubscriptionItem__c> consItems =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c from Product_SubscriptionItem__c where RecordTypeid = :consRTID];
    System.assertEquals(2,consItems.size());

    System.assertEquals(newpsi1.Start_Date__c,consItems[0].Start_Date__c);   
    System.assertEquals(newpsi1.End_Date__c,consItems[0].End_Date__c); 

    System.assertEquals(newpsi2.Start_Date__c,consItems[1].Start_Date__c);   
    System.assertEquals(newpsi3.End_Date__c,consItems[1].End_Date__c);     

    System.assertEquals(newpsi1.QuoteItem_Value__c,consItems[0].Net_Value__c);    
    System.assertEquals(newpsi2.QuoteItem_Value__c,consItems[1].Net_Value__c);      
   
}

@istest
/********************************************
|**** X ****|
        |***** Y *****|
                |**** Z *****|
========================================
|XXXXXXX|YYYYYYY|ZZZZZZZZZZZZZZZZZZ|

********************************************/
private static void testOverLappedMixedValues()
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

    ProductSubscription_POC__c refPOC =  [Select id from ProductSubscription_POC__c limit 1];
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(refPOC.id,System.Date.today(),System.Date.today().addMonths(2), 100,1, 2000,'ExtID_1');
    Product_SubscriptionItem__c newpsi2 = createPSItem(refPOC.id,newpsi1.Start_Date__c.AddDays(31),newpsi1.End_Date__c.addMonths(2), 200,1, 3000,'ExtID_2');
    Product_SubscriptionItem__c newpsi3 = createPSItem(refPOC.id,newpsi2.Start_Date__c.AddDays(31),newpsi2.End_Date__c.addMonths(2), 200,1, 4000,'ExtID_3');    

    test.startTest();
    ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
    test.stopTest();    

    List<Product_SubscriptionItem__c> consItems =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c from Product_SubscriptionItem__c where RecordTypeid = :consRTID];
    System.assertEquals(3,consItems.size());

    System.assertEquals(newpsi1.Start_Date__c,consItems[0].Start_Date__c);   
    //System.assertEquals(newpsi1.End_Date__c,consItems[0].End_Date__c); 

    System.assertEquals(newpsi2.Start_Date__c,consItems[1].Start_Date__c);   
    System.assertEquals(newpsi3.Start_Date__c,consItems[2].Start_Date__c);     

    //System.assertEquals(newpsi1.QuoteItem_Value__c,consItems[0].Net_Value__c);    
    //System.assertEquals(newpsi2.QuoteItem_Value__c,consItems[1].Net_Value__c);      
    //System.assertEquals(newpsi3.QuoteItem_Value__c,consItems[2].Net_Value__c);       
}


@istest
/********************************************
|**** X ****|
            |***** x *****|
            |******** Y ********|
=================================
|XXXXXXXXXXX|YYYYYYYYYYYYYYYYYYY|

********************************************/
private static void testContingentOverruled()
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

    ProductSubscription_POC__c refPOC =  [Select id from ProductSubscription_POC__c limit 1];
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(refPOC.id,System.Date.today(),System.Date.today().addMonths(1), 100,1, 2000,'ExtID_1');
    Product_SubscriptionItem__c newpsi2 = createPSItem(refPOC.id,newpsi1.End_Date__c.addDays(1),newpsi1.End_Date__c.addMonths(1).addDays(1), 100,1, 2000,'ExtID_2');
    Product_SubscriptionItem__c newpsi3 = createPSItem(refPOC.id,newpsi1.End_Date__c.addDays(1),newpsi2.End_Date__c.addMonths(1), 150,1,3000,'ExtID_3');    

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
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(refPOC.id,System.Date.today(),System.Date.today().addMonths(1), 100,1, 2000,'ExtID_1');
    Product_SubscriptionItem__c newpsi2 = createPSItem(refPOC.id,newpsi1.End_Date__c.addDays(1),newpsi1.End_Date__c.addMonths(1).addDays(1), 120,1, 2500,'ExtID_2');
    Product_SubscriptionItem__c newpsi3 = createPSItem(refPOC.id,newpsi1.End_Date__c.addDays(1),newpsi2.End_Date__c.addMonths(1), 150,1,3000,'ExtID_3');    

    test.startTest();
    ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
    test.stopTest();    

    List<Product_SubscriptionItem__c> consItems =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c from Product_SubscriptionItem__c where RecordTypeid = :consRTID];
    System.assertEquals(2,consItems.size());

    System.assertEquals(newpsi1.Start_Date__c,consItems[0].Start_Date__c);   
    System.assertEquals(newpsi2.Start_Date__c,consItems[1].Start_Date__c);   
   
    System.assertEquals(consItems[1].Quantity__c,newpsi3.Quantity__c);     
    System.assertEquals(consItems[1].Net_Value__c,3000);      
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
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(refPOC.id,System.Date.today(),System.Date.today().addyears(1), 100,1, 2000,'ExtID_1');
    Product_SubscriptionItem__c newpsi2 = createPSItem(refPOC.id,newpsi1.Start_Date__c.addMonths(1),System.Date.today().addyears(1), 120,1, 2500,'ExtID_2');
    Product_SubscriptionItem__c newpsi3 = createPSItem(refPOC.id,newpsi1.Start_Date__c.addMonths(2),System.Date.today().addyears(1), 150,1,3000,'ExtID_3');    

    test.startTest();
    ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
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
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(refPOC.id,System.Date.today(),System.Date.today().addMonths(1), 100,1, 5000,'ExtID_1');
    Product_SubscriptionItem__c newpsi2 = createPSItem(refPOC.id,System.Date.today(),System.Date.today().addMonths(1), 100,1, -5000,'ExtID_2');

    test.startTest();
    ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
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
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(refPOC.id,System.Date.today(),System.Date.today().addMonths(1),100,1, 5000,'ExtID_1');
    Product_SubscriptionItem__c newpsi2 = createPSItem(refPOC.id,System.Date.today(),System.Date.today().addMonths(1),90,1, -4000,'ExtID_2');

    test.startTest();
    ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
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
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(refPOC.id,System.Date.today(),System.Date.today().addMonths(2),100,1, 5000,'ExtID_1');
    Product_SubscriptionItem__c newpsi2 = createPSItem(refPOC.id,System.Date.today().addMonths(1),System.Date.today().addMonths(3),90,1, 4000,'ExtID_2');

    test.startTest();
    ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
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
private static void testContingentWithDeok()
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

    ProductSubscription_POC__c refPOC =  [Select id from ProductSubscription_POC__c limit 1];
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(refPOC.id,System.Date.today(),System.Date.today().addMonths(1), 100,1, 2000,'ExtID_1');
    Product_SubscriptionItem__c newpsi2 = createPSItem(refPOC.id,newpsi1.End_Date__c.AddDays(1),newpsi1.End_Date__c.addMonths(1), 100,1, 2000,'ExtID_2');
    Product_SubscriptionItem__c newpsi3 = createPSItem(refPOC.id,newpsi2.End_Date__c.AddDays(1),newpsi2.End_Date__c.addMonths(1), 100,1, 2000,'ExtID_3');   
    Product_SubscriptionItem__c newpsi4 = createPSItem(refPOC.id,newpsi2.End_Date__c.AddDays(1),newpsi2.End_Date__c.addMonths(1), 100,1, -2000,'ExtID_4');      

    test.startTest();
    ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
    test.stopTest();    

    List<Product_SubscriptionItem__c> consItems =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c 
                                                    from Product_SubscriptionItem__c where RecordTypeid = :consRTID];
    System.assertEquals(1,consItems.size());

    System.assertEquals(newpsi1.Start_Date__c,consItems[0].Start_Date__c);   
    System.assertEquals(newpsi2.End_Date__c,consItems[0].End_Date__c); 

    System.assertEquals(newpsi1.QuoteItem_Value__c,consItems[0].Net_Value__c);    
    System.assertEquals(newpsi2.QuoteItem_Value__c,consItems[0].Net_Value__c);      
   
  
}

@istest
/********************************************

|**** X ****|
            |***** x *****|
            |**** -x *****|
                |**** Y ****|
=============================
|XXXXXXXXXXX|000|YYYYYYYYYYY|

********************************************/
private static void testContingentWithDeokAndNewLogo()
{
    Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

    ProductSubscription_POC__c refPOC =  [Select id from ProductSubscription_POC__c limit 1];
    
    Product_SubscriptionItem__c newpsi1 = createPSItem(refPOC.id,System.Date.today(),System.Date.today().addMonths(1), 100,1, 2000,'ExtID_1');
    Product_SubscriptionItem__c newpsi2 = createPSItem(refPOC.id,newpsi1.End_Date__c.AddDays(1),newpsi1.End_Date__c.addMonths(1), 100,1, 2000,'ExtID_2');
    Product_SubscriptionItem__c newpsi3 = createPSItem(refPOC.id,newpsi1.End_Date__c.AddDays(1),newpsi1.End_Date__c.addMonths(1), 100,1, -2000,'ExtID_3');   
    Product_SubscriptionItem__c newpsi4 = createPSItem(refPOC.id,newpsi1.End_Date__c.AddDays(10),newpsi2.End_Date__c.addMonths(2), 110,1,  2500,'ExtID_4');      

    test.startTest();
    ProductSubscriptionUtility.ConsolidateItems4Subs(refPOC.id);
    test.stopTest();    

    List<Product_SubscriptionItem__c> consItems =  [Select id,Start_Date__c,End_Date__c,QuoteItem_Value__c,Quantity__c,Net_Value__c 
                                                    from Product_SubscriptionItem__c where RecordTypeid = :consRTID
                                                    order by Start_Date__c asc];
    System.assertEquals(2,consItems.size());

    System.assertEquals(newpsi1.Start_Date__c,consItems[0].Start_Date__c);   
    System.assertEquals(newpsi1.End_Date__c,consItems[0].End_Date__c); 

    System.assertEquals(newpsi1.QuoteItem_Value__c,consItems[0].Net_Value__c);    
    System.assertEquals(newpsi4.QuoteItem_Value__c,consItems[1].Net_Value__c);      
   
}




/*************************************************************************************************************************************************
not a test method used to create data fr the test m,ethods
*************************************************************************************************************************************************/
private static Product_SubscriptionItem__c createPSItem(ID headerID,Date sD,Date eD, Integer quantity,Integer yearI, Decimal qliVal,String extID)
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

    insert newpsi; //use factory

    newpsi = [Select id,Start_Date__c,End_Date__c,Quantity__c,QuoteItem_Value__c,Net_Value__c,YearIndex__c,External_Id__c   
              from Product_SubscriptionItem__c where id = :newpsi.id];

    return newpsi;
}


}