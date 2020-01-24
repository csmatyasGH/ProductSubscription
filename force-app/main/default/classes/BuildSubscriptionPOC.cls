public without sharing class BuildSubscriptionPOC 
{

public BuildSubscriptionPOC() 
{

} 

private static Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
private static Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 


/***********************************************************************************************
Build Subscription Header/Items for Account and all products passed as parameter.
Try to differentiate between call from Opportunity and a call from self-creation.
If param3 is not null this mean is invoked from PB and we should skip header creation 
***********************************************************************************************/
public static Set<ID> buildSubscriptionFromAccount_Products(ID accId,Set<ID> prodIds,String source)
{
Set<ID> retval =  new Set<ID>();  
List<ProductSubscription_POC__c> PS_POC2Upsert = new List<ProductSubscription_POC__c>();
List<Product_SubscriptionItem__c> PSIs2Upsert = new List<Product_SubscriptionItem__c>();
List<ProductSubscription__c> lst_PS2Create = new List<ProductSubscription__c> ();

/********************************************************************************************************************************************
collect all CPQ QuoteLinItems belonging to the Products passed as param which are part of a winning Opportunity and of a primary CPQ quote. 
Collect the OOTB Subscription and attach it to the POC Subscription item.  Handle cases when OOTB  ProductSSubscription__c is  missing  
********************************************************************************************************************************************/
List<Product2> ProdswithQLI = [SELECT Id, Name, 
                                               (Select ID,SBQQ__Product__c, SBQQ__StartDate__c,SBQQ__EndDate__c,SBQQ__Quote__r.SBQQ__Account__c 
                                                ,SBQQ__SegmentIndex__c,SBQQ__NetPrice__c,SBQQ__CustomerPrice__c,SBQQ__ListPrice__c,SBQQ__Quantity__c 
                                                ,Net_Total_Rounded__c
                                                ,SBQQ__Quote__r.SBQQ__StartDate__c,SBQQ__Quote__r.SBQQ__EndDate__c,SBQQ__Quote__r.Number_of_Years__c
                                                ,SBQQ__Quote__r.SBQQ__Opportunity2__r.Type,SBQQ__Quote__r.SBQQ__Opportunity2__r.Name
                                                ,SBQQ__Quote__r.SBQQ__Opportunity2__r.Number_of_ACV_Years__c,SBQQ__Quote__r.SBQQ__Opportunity2__r.CreatedDate
                                                ,SBQQ__Quote__r.SBQQ__Opportunity2__r.Source_Opportunity__c
                                                from R00N70000001lXB6EAM__r                     //Related List for the Products CPQ quoteLineItem
                                                where SBQQ__Quote__r.SBQQ__Account__c = :accId  //Quote Account is not the same as the Accoutn of the Quotes Opp
                                                and SBQQ__Quote__r.SBQQ__Primary__c = true
                                                and SBQQ__Quote__r.SBQQ__Opportunity2__r.iswon = true
                                                and SBQQ__StartDate__c != NULL
                                                and SBQQ__Quote__r.SBQQ__Opportunity2__r.StageName in ('Closed DeBook Non-Quota','Closed DeBook Quota','Closed Won')
                                               ) 
                                               ,(Select id  from Product_Subscriptions__r where Account__c = :accId order by Createddate desc limit 1) //normally should be only 1
                              FROM Product2 where id in :prodIds];                                                       

for(Product2 prod :ProdswithQLI)
    {
Map<Date,List<Product_SubscriptionItem__c>> mapDate2Items = new Map<Date,List<Product_SubscriptionItem__c>>();  //2019.01.08.        
    if(source == NULL)
      {//we can build the header based on prod and accId 
      ProductSubscription_POC__c newPOC = new ProductSubscription_POC__c();
      newPOC.Account__c = accId;
      newPOC.Product__c = prod.id;
      newPOC.ExternalID__c = accId + '_' + prod.id;
      PS_POC2Upsert.add(newPOC);  
      }
  

    ID ppsID = NULL;
    List<ProductSubscription__c> pps = prod.Product_Subscriptions__r;
    if(pps.size() == 1)  
      {
      ppsID = pps[0].id;       
      }  
    else 
      {
      //we do not  have yet the OOTB  ProductSubscription.  Create here sometime 
      ProductSubscription__c newPS = new ProductSubscription__c();
      //Set Name field, but the name is wierd for existing records
      newPS.Account__c = accID;
      newPS.Product__c = prod.id;
      newPS.External_Id__c = accId + '_' + prod.id;
      lst_PS2Create.add(newPS);
      }   

    List<SBQQ__QuoteLine__c> qlis = prod.R00N70000001lXB6EAM__r;
    String extID4PS = accId + '_' + prod.id;
    for(SBQQ__QuoteLine__c qli :qlis)
        {
         //we can build the items ProsSubscription items here 
         ProductSubscription_POC__c refPOC = new ProductSubscription_POC__c(ExternalID__c = extID4PS);
         Product_SubscriptionItem__c newpsi = buildCPQ_PSI(qli,refPOC);
         if(ppsID != NULL)
         {
         newpsi.Parent_PS__c = ppsID;
         }
         else 
         {
         ProductSubscription__c refPS = new ProductSubscription__c(External_ID__c = extID4PS);  
         newpsi.Parent_PS__r = refPS;
         }

         /********************* add it to the map too *******************/
         Date sd = newpsi.Start_date__c;
         list<Product_SubscriptionItem__c> sdpsis = mapDate2Items.get(sd);
         if(sdpsis == Null)
           {
           sdpsis = new list<Product_SubscriptionItem__c>();
           }
         sdpsis.add(newpsi);  
         mapDate2Items.put(sd,sdpsis);
         /********************* add it to the map too *******************/            

         PSIs2Upsert.add(newpsi);          
        }

    setItemOrder(mapDate2Items);      //we have to  reset this  for each Acc/Prod  combination
    }

List<Database.UpsertResult> durps;
System.Debug('CSABAX upsert PS_POC ' + PS_POC2Upsert.size()); 
if(PS_POC2Upsert.size() > 0)
   {
   durps = Database.upsert(PS_POC2Upsert,ProductSubscription_POC__c.ExternalID__c,false);  
   retval = ProductSubscriptionUtility.ProcessUpsertResult(durps);
   }

if(lst_PS2Create.size() > 0)
   {
   durps = Database.upsert(lst_PS2Create,ProductSubscription__c.External_Id__c,false);  
   }   

//we need to handle situation when a previous  upsert  failed. !!!!!!!!!!!!!!!!!!!!!!!

//TRY TO BUILD HTHE RIGT ORDER OF THE Items. special Care for items with Same StatDate
//setItemOrder(mapDate2Items);

System.Debug('CSABAX upsert PSIs ' + PSIs2Upsert.size());
durps = Database.upsert(PSIs2Upsert,Product_SubscriptionItem__c.External_Id__c,false); 
ProductSubscriptionUtility.ProcessUpsertResult(durps);

return retval; 
}  


/*******************************************************************************************************************************
Same as the above with the exception that it will return a list  of not-created yet Product_SubscriptionItem__c.  Will be called
from within the buildSubscriptionFromOpportunityAccountLink to give the chance to include the on-behalf items too and Order them
*******************************************************************************************************************************/
public static List<Product_SubscriptionItem__c> buildSubscriptionFromAccount_ProductsOAL(ID accId,Set<ID> prodIds,String source)
{
List<ProductSubscription_POC__c> PS_POC2Upsert = new List<ProductSubscription_POC__c>();
List<Product_SubscriptionItem__c> PSIs2Upsert = new List<Product_SubscriptionItem__c>();
List<ProductSubscription__c> lst_PS2Create = new List<ProductSubscription__c> ();

/********************************************************************************************************************************************
collect all CPQ QuoteLinItems belonging to the Products passed as param which are part of a winning Opportunity and of a primary CPQ quote. 
Collect the OOTB Subscription and attach it to the POC Subscription item.  Handle cases when OOTB  ProductSSubscription__c is  missing  
********************************************************************************************************************************************/
List<Product2> ProdswithQLI = [SELECT Id, Name, 
                                               (Select ID,SBQQ__Product__c, SBQQ__StartDate__c,SBQQ__EndDate__c,SBQQ__Quote__r.SBQQ__Account__c 
                                                ,SBQQ__SegmentIndex__c,SBQQ__NetPrice__c,SBQQ__CustomerPrice__c,SBQQ__ListPrice__c,SBQQ__Quantity__c 
                                                ,Net_Total_Rounded__c
                                                ,SBQQ__Quote__r.SBQQ__StartDate__c,SBQQ__Quote__r.SBQQ__EndDate__c,SBQQ__Quote__r.Number_of_Years__c
                                                ,SBQQ__Quote__r.SBQQ__Opportunity2__r.Type,SBQQ__Quote__r.SBQQ__Opportunity2__r.Name
                                                ,SBQQ__Quote__r.SBQQ__Opportunity2__r.Number_of_ACV_Years__c,SBQQ__Quote__r.SBQQ__Opportunity2__r.CreatedDate
                                                ,SBQQ__Quote__r.SBQQ__Opportunity2__r.Source_Opportunity__c
                                                from R00N70000001lXB6EAM__r                     //Related List for the Products CPQ quoteLineItem
                                                where SBQQ__Quote__r.SBQQ__Account__c = :accId  //Quote Account is not the same as the Accoutn of the Quotes Opp
                                                and SBQQ__Quote__r.SBQQ__Primary__c = true
                                                and SBQQ__Quote__r.SBQQ__Opportunity2__r.iswon = true
                                                and SBQQ__StartDate__c != NULL
                                                and SBQQ__Quote__r.SBQQ__Opportunity2__r.StageName in ('Closed DeBook Non-Quota','Closed DeBook Quota','Closed Won')
                                               ) 
                                               ,(Select id  from Product_Subscriptions__r where Account__c = :accId order by Createddate desc limit 1) //normally should be only 1
                              FROM Product2 where id in :prodIds];                                                       

for(Product2 prod :ProdswithQLI)
    {
Map<Date,List<Product_SubscriptionItem__c>> mapDate2Items = new Map<Date,List<Product_SubscriptionItem__c>>();  //2019.01.08.        
    if(source == NULL)
      {//we can build the header based on prod and accId 
      ProductSubscription_POC__c newPOC = new ProductSubscription_POC__c();
      newPOC.Account__c = accId;
      newPOC.Product__c = prod.id;
      newPOC.ExternalID__c = accId + '_' + prod.id;
      PS_POC2Upsert.add(newPOC);  
      }
  

    ID ppsID = NULL;
    List<ProductSubscription__c> pps = prod.Product_Subscriptions__r;
    if(pps.size() == 1)  
      {
      ppsID = pps[0].id;       
      }  
    else 
      {
      //we do not  have yet the OOTB  ProductSubscription.  Create here sometime 
      ProductSubscription__c newPS = new ProductSubscription__c();
      //Set Name field, but the name is wierd for existing records
      newPS.Account__c = accID;
      newPS.Product__c = prod.id;
      newPS.External_Id__c = accId + '_' + prod.id;
      lst_PS2Create.add(newPS);
      }   

    List<SBQQ__QuoteLine__c> qlis = prod.R00N70000001lXB6EAM__r;
    String extID4PS = accId + '_' + prod.id;
    for(SBQQ__QuoteLine__c qli :qlis)
        {
         //we can build the items ProsSubscription items here 
         ProductSubscription_POC__c refPOC = new ProductSubscription_POC__c(ExternalID__c = extID4PS);
         Product_SubscriptionItem__c newpsi = buildCPQ_PSI(qli,refPOC);
         if(ppsID != NULL)
         {
         newpsi.Parent_PS__c = ppsID;
         }
         else 
         {
         ProductSubscription__c refPS = new ProductSubscription__c(External_ID__c = extID4PS);  
         newpsi.Parent_PS__r = refPS;
         }

         /********************* add it to the map too *******************/
         Date sd = newpsi.Start_date__c;
         list<Product_SubscriptionItem__c> sdpsis = mapDate2Items.get(sd);
         if(sdpsis == Null)
           {
           sdpsis = new list<Product_SubscriptionItem__c>();
           }
         sdpsis.add(newpsi);  
         mapDate2Items.put(sd,sdpsis);
         /********************* add it to the map too *******************/            

         PSIs2Upsert.add(newpsi);          
        }

    setItemOrder(mapDate2Items);      //we have to  reset this  for each Acc/Prod  combination
    }

List<Database.UpsertResult> durps;
System.Debug('CSABAX upsert PS_POC ' + PS_POC2Upsert.size()); 
if(PS_POC2Upsert.size() > 0)
   {
   durps = Database.upsert(PS_POC2Upsert,ProductSubscription_POC__c.ExternalID__c,false);  
   ProductSubscriptionUtility.ProcessUpsertResult(durps);
   }

if(lst_PS2Create.size() > 0)
   {
   durps = Database.upsert(lst_PS2Create,ProductSubscription__c.External_Id__c,false);  
   }   

//we need to handle situation when a previous  upsert  failed. !!!!!!!!!!!!!!!!!!!!!!!

//TRY TO BUILD HTHE RIGT ORDER OF THE Items. special Care for items with Same StatDate
//setItemOrder(mapDate2Items);

return PSIs2Upsert;
}  

/***********************************************************************************
for each list inside the map try to set the ItemOrder__c field on the Item record.
The first item should be the one with the earlierst Opportunity. if there are more 
then 1, the second should be the Deebok and the 3rd if exist the Overruled opps item
To track this we need Opp CreationDate and Opp Name on the object. Deebok Opp should
have the name started wirth the Name of the Deebooked opp.  
***********************************************************************************/
private static void setItemOrder(Map<Date,List<Product_SubscriptionItem__c>> mapDate2Items)
{

for(Date sd :mapDate2Items.keyset())
   {
   System.Debug('CSABAX sd = ' +  sd);  
   //1 order the items based on Opp Created Date asc  
   //2 iterate again starting from 2 and look for Debook
   //3 iterate again starting from 3 and look for Same Name Start
   List<Product_SubscriptionItem__c> sortedPSIs = OrderPIsByOppCreatedDate(mapDate2Items.get(sd)) ;
   //return;
   Integer sorteditemsize = sortedPSIs.size();
   Integer startingIndex = 1; 
   while (startingIndex < sorteditemsize)
    {
    System.Debug('CSABAX  inside WHILE: startIndex/sorteditemSize = ' + startingIndex + '/' + sorteditemsize);  
    String OppName2Match = sortedPSIs[startingIndex - 1].OriginOpportunity__r.Name;  
    ID debookedOppId = sortedPSIs[startingIndex - 1].OriginOpportunity__c;          
   System.Debug('CSABAX PSI OppName2Match = ' + OppName2Match);  
   integer item2MatchOrder = (Integer)sortedPSIs[startingIndex - 1].itemOrder__c; 
    for(integer i = startingIndex; i < sorteditemsize; i++)
        {
        String CurrentOppName = sortedPSIs[i].OriginOpportunity__r.Name;     

        System.Debug('CSABAX inside for. startingIndex = ' + startingIndex);  
        System.Debug('CSABAX CurrentOppName = ' + CurrentOppName + ' i = ' + i);   
        System.Debug('CSABAX current order = ' + sortedPSIs[i].itemOrder__c);     
        //try to find item which Opp is a Debook of the sortedPSIs[startingIndex - 1] if foudn call pushItemOrderRight

        if(sortedPSIs[i].itemOrder__c <= startingIndex)
        {
        System.Debug('CSABAX do not check again a debook-ed  Opps psi');  
        continue;  //do not check again a debook-ed  Opp's psi  
        }

        if((CurrentOppName.startsWith(OppName2Match) == true && (CurrentOppName.Contains('Debook') || CurrentOppName.Contains('debook')) && sortedPSIs[i].OriginOpportunity__r.Source_opportunity__c == NULL) || 
           sortedPSIs[i].OriginOpportunity__r.Source_opportunity__c == debookedOppId && ( CurrentOppName.Contains('Debook') || CurrentOppName.Contains('debook') )
          ) 
           {
           System.Debug('CSABAX debook matched: ');  
           if(i == startingIndex) 
             {
             break; 
             }
           else 
             {
             pushItemOrderRight(sortedPSIs, startingIndex,i,item2MatchOrder);
             break;
             }  
           }
        }//end of for 

    startingIndex++;         
    }//end of while


   }

}

/*****************************************************************************************************************************************

*****************************************************************************************************************************************/
private static void pushItemOrderRight(List<Product_SubscriptionItem__c> sortedPSIs, integer startIndex, integer endIndex, integer pushto)
{
System.Debug('CSABAX start pushItemOrderRight. start/end = ' + startIndex + '/' + endIndex);  
for(integer i = startIndex; i < endIndex; i++)
   { 
   System.Debug('CSABAX si/ei/i = ' + startIndex + '/' + endIndex + '/' + i); 
   System.Debug('CSABAX  item: ' + sortedPSIs[i].OriginOpportunity__r.Name);
   if(sortedPSIs[i].itemOrder__c <= startIndex)
      {
      System.Debug('CSABAX is an old debook.');  
      continue;
      }

   System.Debug('CSABAX pushing item: ' + sortedPSIs[i].OriginOpportunity__r.Name);
   sortedPSIs[i].itemOrder__c = sortedPSIs[i].itemOrder__c + 1;
   }
System.Debug('CSABAX settign the Deebok: ' + sortedPSIs[endIndex].OriginOpportunity__r.Name); 
System.Debug('CSABA current order = ' + sortedPSIs[endIndex].itemOrder__c);  
sortedPSIs[endIndex].itemOrder__c = pushto + 1;   
System.Debug('CSABA next order = ' + sortedPSIs[endIndex].itemOrder__c); 
}


/************************************************************************
collect all products from the Primary CPQ quote of the Opp and call  
buildSubscriptionFromAccount_Products to build full Subscription for 
the Account of the Opps where the Quote prodsucts are involved
param:  Opportunity ID
return: Set of  newly  created or updated ProductSubscrriptionPOC records
************************************************************************/
public static Set<ID> buildSubscriptionFromOpportunity4AppProds(ID oppId)
{
Set<ID> retval = new set<ID>();

List<SBQQ__QuoteLine__c> qlis = [Select SBQQ__Quote__r.SBQQ__Account__c,SBQQ__Product__c
                                ,(Select id from Product_SubscriptionItems__r)
                                 from SBQQ__QuoteLine__c
                                 where SBQQ__Quote__r.SBQQ__Opportunity2__c = :oppId
                                 and SBQQ__Quote__r.SBQQ__Opportunity2__r.iswon = true
                                 and SBQQ__Quote__r.SBQQ__Primary__c = true
                                 and SBQQ__StartDate__c != NULL
                                 and SBQQ__Quote__r.SBQQ__Opportunity2__r.StageName in ('Closed DeBook Non-Quota','Closed DeBook Quota','Closed Won')
                                ];
System.Debug('CSABAX Opp has QLI  count = ' + qlis.size());                                
ID accId;
Set<ID> prodIDs =  new Set<ID>();

for(SBQQ__QuoteLine__c qli :qlis)
  {
  List<Product_SubscriptionItem__c> psis = qli.Product_SubscriptionItems__r;
  //if we have psis child record this mean we already created the PS for this QLI we can skip
  if(psis != NULL && psis.size() == 1)
    {
      //System.Debug('CSABAX this QLI already has subscription item'); 
      //continue;   
    }
  
  accId =  qli.SBQQ__Quote__r.SBQQ__Account__c;
  prodIDs.add(qli.SBQQ__Product__c);  
  }

  if(prodIDs.size() > 0)
    {
    System.Debug('CSABAX build POC for acc: ' + accID + ' and prods: ' + prodIDs);       
    retval = buildSubscriptionFromAccount_Products(accId,prodIDs,NULL);
    }
  else 
    {
    System.Debug('CSABAX  no new item 2  create');  
    }   

return retval;
}


/***********************************************************************

***********************************************************************/
public static void buildSubscriptionFromOpportunityAccountLink(ID oppId)
{
List<ProductSubscription_POC__c> PS_POC2Upsert = new List<ProductSubscription_POC__c>();
List<Product_SubscriptionItem__c> PSIs2Upsert = new List<Product_SubscriptionItem__c>();
List<ProductSubscription__c> lst_PS2Create = new List<ProductSubscription__c> ();

//exclue Empty Start/End Date, Filter Opp stage, Pick only OLI with QLI an think fr more folters
List<Opportunity> opps = [Select Id, Name,Source_Opportunity__c,Type,SBQQ__PrimaryQuote__c, SBQQ__PrimaryQuote__r.SBQQ__Account__c 
                         ,(Select id,Account__c,Percentage__c  from Opportunity_Account_Links__r where Percentage__c != NULL and Percentage__c != 0)
                         ,(Select ID,Product2ID, SBQQ__QuoteLine__c
                           ,SBQQ__QuoteLine__r.SBQQ__StartDate__c,SBQQ__QuoteLine__r.SBQQ__EndDate__c  
                           ,SBQQ__QuoteLine__r.SBQQ__NetPrice__c  ,SBQQ__QuoteLine__r.Net_Total_Rounded__c, SBQQ__QuoteLine__r.SBQQ__ListPrice__c  
                           ,SBQQ__QuoteLine__r.SBQQ__Quantity__c,SBQQ__QuoteLine__r.SBQQ__SegmentIndex__c                       
                          from OpportunityLineItems)
                          ,(Select id,Primary_Product_Subscription__c,Primary_Product_Subscription__r.Product__c  from Product_Subscription_Opportunities__r)
                          from Opportunity where id = :oppID];

Set<ID> prodId = new Set<Id>(); 
map<Id,Set<ID>> mapAcc2Prod = new map<Id,Set<ID>>();
/*****************************************************/
Id accId;
for(Opportunity opp :opps)
   {
   //if we do not have AOLs we use this AccountID
   accId = opp.SBQQ__PrimaryQuote__r.SBQQ__Account__c;
   for(OpportunityLineItem oli :opp.OpportunityLineItems)
      {
      prodId.add(oli.Product2ID); //this Set is used when no AOL and for child Accounts independent deal
      for(OpportunityAccountLink__c oal :opp.Opportunity_Account_Links__r)
          {

          String extID4PS = oal.Account__c + '_' + oli.Product2ID;
          ProductSubscription_POC__c refPOC = new ProductSubscription_POC__c(ExternalID__c = extID4PS);
          refPOC.Account__c = oal.Account__c;
          refPOC.Product__c =  oli.Product2ID;
          PS_POC2Upsert.add(refPOC);

          //create the header PS POC
          ProductSubscription__c refPS = new ProductSubscription__c(External_ID__c = extID4PS); 
          refPS.Account__c = oal.Account__c;
          refPS.Product__c =  oli.Product2ID;
          lst_PS2Create.add(refPS);          

          //create the PSItem
          SBQQ__QuoteLine__c qli = oli.SBQQ__QuoteLine__r;
          Product_SubscriptionItem__c newpsi = buildCPQ_PSI(qli,refPOC);
          newpsi.OriginOpportunity__c = opp.id;
          newpsi.OriginOpportunity__r = opp;   
          newpsi.AOL_Percentage__c = oal.Percentage__c;       
          newpsi.Parent_PS__r = refPS;
          PSIs2Upsert.add(newpsi);

          mapAcc2Prod.put(oal.Account__c,prodId); //the prodID set  in incremented outside this for loop          
          }
      }
   }  

/******************************************************/


List<Database.UpsertResult> durps;
System.Debug('CSABAX upsert PS_POC ' + PS_POC2Upsert.size()); 
if(PS_POC2Upsert.size() > 0)
   {
   durps = Database.upsert(PS_POC2Upsert,ProductSubscription_POC__c.ExternalID__c,false);  
   ProductSubscriptionUtility.ProcessUpsertResult(durps);
   }

if(lst_PS2Create.size() > 0)
   {
   durps = Database.upsert(lst_PS2Create,ProductSubscription__c.External_Id__c,false);  
   }   

if(mapAcc2Prod.size() == 0)
   {
   //we do not have AOLs create POC/Itesm for the main Account
    buildSubscriptionFromAccount_Products(accId,prodId,NULL);  
    return;  
   }
else 
   {
  //for each Account create the "own" POC/Items
  for(ID acc_Id :mapAcc2Prod.keySet())
     {
     PSIs2Upsert.addAll(buildSubscriptionFromAccount_ProductsOAL(acc_Id,mapAcc2Prod.get(accId),NULL));  
     }   
   }
  
//sort items before Create
System.Debug('CSABAX upsert PSIs ' + PSIs2Upsert.size());
durps = Database.upsert(PSIs2Upsert,Product_SubscriptionItem__c.External_Id__c,false); 
ProductSubscriptionUtility.ProcessUpsertResult(durps);                      
}

/*********************************************************************
Collect all Products involved for this Opp via its OpportunityLineItems
Collect All OpportunityLineItem for the involved products and Opp Acc.
OLI and QLI are linked so if we start from here we can easily switch
between OLI anf QLI
*********************************************************************/
public static void buildSubscriptionFromOpportunityLineItems(ID oppId)
{
   List<OpportunityLineItem> olis = [Select id, Product2ID from OpportunityLineItem where OpportunityID = :oppId];

   Set<ID> prodIds = new Set<ID>();

   for(OpportunityLineItem oli :olis)
       {
       prodIds.add(oli.product2ID);
       }    

   olis = [Select id, Product2ID, Product2.Name,Consortium_Child_Account__c,Package__c,Product_for_Calc__c,
           TotalPrice,Quantity
           ,SBQQ__QuoteLine__c,SBQQ__QuoteLine__r.SBQQ__NetTotal__c,SBQQ__QuoteLine__r.SBQQ__SegmentIndex__c,
           OpportunityID,Opportunity.AccountID
           ,SBQQ__QuoteLine__r.SBQQ__Quote__c,Opportunity.SBQQ__PrimaryQuote__c
           ,Start_Date__c,End_Date__c   //there are yearly Start/End  dates. Might be useful
           from OpportunityLineItem 
           where product2ID in :prodIds
           and SBQQ__QuoteLine__c != Null 
           and Start_Date__c != NULL and End_Date__c != NULL
           and Opportunity.iswon = true
         ];   

   List<ProductSubscription__c> PS_2Upsert = new List<ProductSubscription__c>(); //does not have external ID!!!!
   List<ProductSubscription_POC__c> PS_POC2Upsert = new List<ProductSubscription_POC__c>();
   List<Product_SubscriptionItem__c> PSIs2Upsert = new List<Product_SubscriptionItem__c>();             

   //create the Header SUbscr POC
   for(OpportunityLineItem oli :olis)
   {
    ProductSubscription_POC__c newPOC = new ProductSubscription_POC__c();
    newPOC.Account__c = oli.Opportunity.AccountID;
    newPOC.Product__c = oli.Product2ID;
    newPOC.ExternalID__c = newPOC.Account__c  + '_' + newPOC.Product__c;
    PS_POC2Upsert.add(newPOC); 

    //upsert the standard ProductSubscription
    //ProductSubscription__c ps = new ProductSubscription__c();
   }   

   for(OpportunityLineItem oli :olis)
   {
   //we can build the items ProsSubscription items here 
   ProductSubscription_POC__c refPOC = new ProductSubscription_POC__c(ExternalID__c = oli.Opportunity.AccountID + '_' + oli.Product2ID);
   Product_SubscriptionItem__c newpsi = buildQLI_PSI(oli,refPOC);
   //newpsi.Parent_PS__c = ppsID;
   PSIs2Upsert.add(newpsi);        
   }

}


/*****************************************************************************************************************
*****************************************************************************************************************/
private static Product_SubscriptionItem__c buildCPQ_PSI(SBQQ__QuoteLine__c qli,ProductSubscription_POC__c refPOC )
{
    Product_SubscriptionItem__c newpsi =  new Product_SubscriptionItem__c(RecordTypeID = qliRTID);    
    newpsi.ParentSubscription__r = refPOC;
    newpsi.OriginQuote_Line__c = qli.id;
    newpsi.OriginOpportunity__c = qli.SBQQ__Quote__r.SBQQ__Opportunity2__c;
    newpsi.OriginOpportunity__r = qli.SBQQ__Quote__r.SBQQ__Opportunity2__r; //this will bring several opp fields used later 

    newpsi.Start_Date__c = qli.SBQQ__StartDate__c;
    newpsi.End_Date__c = qli.SBQQ__EndDate__c;
    newpsi.External_Id__c = qli.id;
    
    newpsi.Quantity__c = qli.SBQQ__Quantity__c;
    newpsi.QuoteItem_Value__c = qli.Net_Total_Rounded__c;
    newpsi.YearIndex__c = qli.SBQQ__SegmentIndex__c;
    //calculate MRR and TSV (and if possible take care of the Conversion too)
    
    newpsi.Duration__c = qli.SBQQ__StartDate__c.monthsBetween(qli.SBQQ__EndDate__c) + 1;  //NOT GOOD review and calculate based on days/30.5 and round

    newpsi.OppCreatedDate__c = qli.SBQQ__Quote__r.SBQQ__Opportunity2__r.Createddate;
    
    return newpsi;
}

/******************************************************************************************************************
Build PSI from OpportunityQuoteLineItems
******************************************************************************************************************/
private static Product_SubscriptionItem__c buildQLI_PSI(OpportunityLineItem qli,ProductSubscription_POC__c refPOC )
{
    Product_SubscriptionItem__c newpsi =  new Product_SubscriptionItem__c(RecordTypeID = qliRTID);    
    newpsi.ParentSubscription__r = refPOC;
    newpsi.OriginQuote_Line__c = qli.id;
    newpsi.OriginOpportunity__c = qli.OpportunityID;
    newpsi.Start_Date__c = qli.Start_Date__c;
    newpsi.End_Date__c = qli.End_Date__c;
    newpsi.External_Id__c = qli.id;
    
    newpsi.Quantity__c = qli.Quantity;
    newpsi.QuoteItem_Value__c = qli.TotalPrice;
    newpsi.YearIndex__c = qli.SBQQ__QuoteLine__r.SBQQ__SegmentIndex__c;
    //calculate MRR and TSV (and if possible take care of the Conversion too)
    
    newpsi.Duration__c = qli.Start_Date__c.monthsBetween(qli.End_Date__c) + 1; 
    
    return newpsi;
}



/*****************************************************************************************************************
pass the items to a wrapper list, order it and set ItemOrder and return an ordered list of Product Subscr. Items 
*****************************************************************************************************************/
private static List<Product_SubscriptionItem__c>  OrderPIsByOppCreatedDate(List<Product_SubscriptionItem__c> psis)
{
List<Product_SubscriptionItem__c> orderedPSIs = new List<Product_SubscriptionItem__c>();

List<ProdSubscrItemWrapper> wrapperList = new List<ProdSubscrItemWrapper>();
for(Product_SubscriptionItem__c psi :psis)
  {
  ProdSubscrItemWrapper wi = new ProdSubscrItemWrapper(psi);
  wrapperList.add(wi);
  }

wrapperList.sort();
Integer sortOrder = 0;
for(ProdSubscrItemWrapper wi : wrapperList)
   {
    sortOrder++; 
    wi.thePSI.itemOrder__c = sortOrder; 
    orderedPSIs.add(wi.thePSI);
   }  

return orderedPSIs;
}

/*******************************************************

*******************************************************/
public class ProdSubscrItemWrapper implements Comparable 
{
public Product_SubscriptionItem__c thePSI;

public ProdSubscrItemWrapper(Product_SubscriptionItem__c psi)
{
  thePSI = psi;
}

public Integer compareTo(Object obj)
  {
  ProdSubscrItemWrapper obj2Comp = (ProdSubscrItemWrapper)obj;

  //if(thePSI.OppCreatedDate__c > obj2Comp.thePSI.OppCreatedDate__c) //newpsi.OriginOpportunity__r
  if(thePSI.OriginOpportunity__r.CreatedDate > obj2Comp.thePSI.OriginOpportunity__r.CreatedDate)   
    return 1;

  //else if(thePSI.OppCreatedDate__c == obj2Comp.thePSI.OppCreatedDate__c)
  else if(thePSI.OriginOpportunity__r.CreatedDate == obj2Comp.thePSI.OriginOpportunity__r.CreatedDate)  
    return 0;

  //else if(thePSI.OppCreatedDate__c < obj2Comp.thePSI.OppCreatedDate__c)
  else if(thePSI.OriginOpportunity__r.CreatedDate < obj2Comp.thePSI.OriginOpportunity__r.CreatedDate)  
    return -1;

  return 0;
  }

}//end of  inner class


}