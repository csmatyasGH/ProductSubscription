public without sharing class BuildSubscriptionPOC 
{

private static Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
private static Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId(); 

/***********************************************************************************************
Build Subscription Header/Items for Account and all products passed as parameter.
Try to differentiate between call from Opportunity and a call from self-creation(test only).
If param3 is not null this mean is invoked from PB and we should skip header creation 
Return value is a set of ProductSubscription_POC recordIDs 
***********************************************************************************************/
public static Set<ID> buildSubscriptionFromAccount4Products(ID accId,Set<ID> prodIds,String source)
{
System.Debug('CSABAX  start buildSubscriptionFromAccount_Products for Acc: ' + accId + ' ProdCount = ' + prodIds.size());  
Set<ID> retval =  new Set<ID>();  
List<ProductSubscription_POC__c> psPOC2Upsert = new List<ProductSubscription_POC__c>();
List<Product_SubscriptionItem__c> pSIs2Upsert = new List<Product_SubscriptionItem__c>();
List<ProductSubscription__c> lstPS2Create = new List<ProductSubscription__c> ();

Set<String> dmlErrMsg =  new Set<String>();

/********************************************************************************************************************************************
collect all CPQ QuoteLinItems belonging to the Products passed as param which are part of a winning Opportunity and of a primary CPQ quote. 
Collect the OOTB Subscription and attach it to the POC Subscription item.  Handle cases when OOTB  ProductSSubscription__c is  missing  
********************************************************************************************************************************************/
List<Product2> prodswithQLI = [SELECT Id, Name,Family,Product_Sub_Family__c,Product_Type__c, 
                                               (Select ID,SBQQ__Product__c, SBQQ__StartDate__c,SBQQ__EndDate__c,SBQQ__Quote__r.SBQQ__Account__c 
                                                ,SBQQ__SegmentIndex__c,SBQQ__NetPrice__c,SBQQ__CustomerPrice__c,SBQQ__ListPrice__c,SBQQ__Quantity__c 
                                                ,Net_Total_Rounded__c,CurrencyIsoCode
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
    //Map<Date,List<Product_SubscriptionItem__c>> mapDate2Items = new Map<Date,List<Product_SubscriptionItem__c>>();              //2020.02.06. SHOULD BE REPLACED WITH BELOW   
    Map<String,List<Product_SubscriptionItem__c>> mapsDate2Items = new Map<String,List<Product_SubscriptionItem__c>>();   
    if(source == NULL)
      {//we can build the header based on prod and accId 
      ProductSubscription_POC__c newPOC = new ProductSubscription_POC__c();
      newPOC.Account__c = accId;
      newPOC.Product__c = prod.id;
      newPOC.ExternalID__c = accId + '_' + prod.id;

      if(prod.R00N70000001lXB6EAM__r == NULL)
         {
         newPOC.Number_of_Expected_Items__c = 0;
         }
      else 
         {
        newPOC.Number_of_Expected_Items__c = prod.R00N70000001lXB6EAM__r.size();
         }   

      psPOC2Upsert.add(newPOC);  
      }
  

    ID ppsID = NULL;
    List<ProductSubscription__c> pps = prod.Product_Subscriptions__r;
    if(pps.size() == 1)  
      {
      ppsID = pps[0].id;       
      }  
    else 
      {
      //we do not have yet the OOTB ProductSubscription. Create here sometime 
      ProductSubscription__c newPS = new ProductSubscription__c();
      //Set Name field, but the name is wierd for existing records
      newPS.Account__c = accID;
      newPS.Product__c = prod.id;
      newPS.External_Id__c = accId + '_' + prod.id;
      newPS.Name = 'HM-PS ' + prod.Family + ' - ' + prod.Product_Sub_Family__c + ' - ' + prod.Product_Type__c;
      //pass  the useless Prod Fam/SubFam fields
      newPS.ProductFamily__c = prod.Family;
      newPS.ProductSubFamily__c = prod.Product_Sub_Family__c;
      newPS.ProductType__c = prod.Product_Type__c;
      lstPS2Create.add(newPS);
      }   

    List<SBQQ__QuoteLine__c> qlis = prod.R00N70000001lXB6EAM__r;
    String extID4PS = accId + '_' + prod.id;
    for(SBQQ__QuoteLine__c qli :qlis)
        {
         //we can build the items ProsSubscription items here 
         ProductSubscription_POC__c refPOC = new ProductSubscription_POC__c(ExternalID__c = extID4PS);
         Product_SubscriptionItem__c newpsi = buildCPQ_PSI(qli,refPOC,NULL);
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
         String sd = String.valueOf(newpsi.Start_date__c);
         list<Product_SubscriptionItem__c> sdpsis = mapsDate2Items.get(sd);
         if(sdpsis == Null)
           {
           sdpsis = new list<Product_SubscriptionItem__c>();
           }
         sdpsis.add(newpsi);  
         mapsDate2Items.put(sd,sdpsis);
         /********************* add it to the map too *******************/            

         PSIs2Upsert.add(newpsi);          
        }

    setItemOrder(mapsDate2Items);      //we have to  reset this  for each Acc/Prod  combination
    }

List<Database.UpsertResult> durps;
System.Debug('CSABAX upsert PS_POC ' + psPOC2Upsert.size()); 

//if we do not have PSIs2Upsert DO NOT create POC
if(PSIs2Upsert.size() == 0)
   return retval;

if(PSPOC2Upsert.size() > 0)
   {
   durps = Database.upsert(PSPOC2Upsert,ProductSubscription_POC__c.ExternalID__c,false);  
   retval = ProductSubscriptionUtility.ProcessUpsertResult(durps,'ProductSubscription_POC',dmlErrMsg);
   }

if(lstPS2Create.size() > 0)
   {
   durps = Database.upsert(lstPS2Create,ProductSubscription__c.External_Id__c,false);  
   }   

//we need to handle situation when a previous  upsert  failed. !!!!!!!!!!!!!!!!!!!!!!!

System.Debug('CSABAX upsert PSIs ' + PSIs2Upsert.size());
durps = Database.upsert(PSIs2Upsert,Product_SubscriptionItem__c.External_Id__c,false); 
ProductSubscriptionUtility.ProcessUpsertResult(durps,'Product_SubscriptionItem',dmlErrMsg);

return retval; 
}  


/***********************************************************************************************************************************************************
Same as the above with the exception that it will return a list  of not-created yet Product_SubscriptionItem__c.  Will be called from within 
the buildSubscriptionFromOpportunityAccountLink to give the chance to include the on-behalf items too and Order them.  2020.02.06. OVERRULED
Add control to code from the caller. We might not need to create PS header and POC header because it were just created by the caller method.
***********************************************************************************************************************************************************/
public static Map<String,List<Product_SubscriptionItem__c>> buildSubscriptionFromAccount4ProductsOAL(ID accId,Set<ID> prodIds,String source, Id opp2Exclude)
{
System.Debug('CSABAX start buildSubscriptionFromAccount_ProductsOAL for Acc: ' + accId + ' and prodIDs: ' + prodIds);  
List<ProductSubscription_POC__c> PS_POC2Upsert = new List<ProductSubscription_POC__c>();
List<Product_SubscriptionItem__c> PSIs2Upsert = new List<Product_SubscriptionItem__c>();
List<ProductSubscription__c> lst_PS2Create = new List<ProductSubscription__c> ();

Map<String,List<Product_SubscriptionItem__c>> mapAPDate2Items = new Map<String,List<Product_SubscriptionItem__c>>();

Set<String> dmlErrMsg = new Set<String>();
/********************************************************************************************************************************************
collect all CPQ QuoteLinItems belonging to the Products passed as param which are part of a winning Opportunity and of a primary CPQ quote. 
Collect the OOTB Subscription and attach it to the POC Subscription item.  Handle cases when OOTB  ProductSSubscription__c is  missing  
********************************************************************************************************************************************/
List<Product2> ProdswithQLI = [SELECT Id, Name,Family,Product_Sub_Family__c,Product_Type__c, 
                                               (Select ID,SBQQ__Product__c, SBQQ__StartDate__c,SBQQ__EndDate__c,SBQQ__Quote__r.SBQQ__Account__c 
                                                ,SBQQ__SegmentIndex__c,SBQQ__NetPrice__c,SBQQ__CustomerPrice__c,SBQQ__ListPrice__c,SBQQ__Quantity__c 
                                                ,Net_Total_Rounded__c,CurrencyIsoCode
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
                                                and SBQQ__Quote__r.SBQQ__Opportunity2__c != :opp2Exclude
                                               ) 
                                               ,(Select id  from Product_Subscriptions__r where Account__c = :accId order by Createddate desc limit 1)     //in order to match existing
                                               ,(Select id  from ProductSubscriptions_POC__r where Account__c = :accId order by Createddate desc limit 1)  //in order to match existing
                              FROM Product2 where id in :prodIds];                                                       

for(Product2 prod :ProdswithQLI)
    {
    /***************** find the matched PS/POC  we created in the caller method  **********************************************/  
    integer matchedPOCsize = prod.ProductSubscriptions_POC__r.size();  //we must have 1  because  we just  created it in caller.
    integer matchedPSsize = prod.Product_Subscriptions__r.size();      //we must have 1  because  we just  created it in caller.
    ProductSubscription_POC__c matchedPOC = prod.ProductSubscriptions_POC__r[0]; 
    ProductSubscription__c matchedPS = prod.Product_Subscriptions__r[0];
     
    if(matchedPOC == NULL)
      {/********************** Build the Header PS POC **************************
      We can also match the existing originals based ProductSubscriptions_POC__r
      but in this case we can not set  the expected Item count ****************/
      ProductSubscription_POC__c newPOC = new ProductSubscription_POC__c();
      newPOC.Account__c = accId;
      newPOC.Product__c = prod.id;
      newPOC.ExternalID__c = accId + '_' + prod.id;

      if(prod.R00N70000001lXB6EAM__r == NULL) { newPOC.Number_of_Expected_Items__c = 0; }
      else { newPOC.Number_of_Expected_Items__c = prod.R00N70000001lXB6EAM__r.size(); }   

      PS_POC2Upsert.add(newPOC);  
      }
      /********************** Build the PS POC Header *************************/

    /******************** Build OOTB PS Header *********************/
    List<ProductSubscription__c> pps = prod.Product_Subscriptions__r;
    if(matchedPS == NULL)  
      {
      //we do not  have yet the OOTB  ProductSubscription.
      ProductSubscription__c newPS = new ProductSubscription__c();
      //Set Name field, but the name is wierd for existing records
      newPS.Name = 'HM-PS ' + prod.Family + ' - ' + prod.Product_Sub_Family__c + ' - ' + prod.Product_Type__c;
      newPS.Account__c = accID;
      newPS.Product__c = prod.id;
      newPS.External_Id__c = accId + '_' + prod.id;   
      newPS.ProductFamily__c = prod.Family;
      newPS.ProductSubFamily__c = prod.Product_Sub_Family__c;
      newPS.ProductType__c = prod.Product_Type__c;         
      lst_PS2Create.add(newPS);
      } 
    /******************** Build OOTB PS Header *********************/        

    List<SBQQ__QuoteLine__c> qlis = prod.R00N70000001lXB6EAM__r;
    System.Debug('CSABAX number of  CPQ QLItems: ' +  qlis.size());
    String extID4PS = accId + '_' + prod.id;
    for(SBQQ__QuoteLine__c qli :qlis)
        {
         //we can build the items ProsSubscription items here 
         Product_SubscriptionItem__c newpsi = buildCPQ_PSI(qli,matchedPOC,NULL); //was refPOC
         /******************************PASS THE OOTB PS lookup ***********************/
         if(matchedPS != NULL)
         {
         newpsi.Parent_PS__c = matchedPS.id;
         }
         else 
         {
         ProductSubscription__c refPS = new ProductSubscription__c(External_ID__c = extID4PS);  
         newpsi.Parent_PS__r = refPS;
         }           
         newpsi.Creation_Type__c = 'own-Deal';
         PSIs2Upsert.add(newpsi);  
         
         /****************************** SORTING  **********************************/
         String mapKey4apsd = extID4PS + '_' + newpsi.Start_Date__c;
         list<Product_SubscriptionItem__c> sdpsis = mapAPDate2Items.get(mapKey4apsd);
         if(sdpsis == Null)
           {
           sdpsis = new list<Product_SubscriptionItem__c>();
           }
         sdpsis.add(newpsi);  
         mapAPDate2Items.put(mapKey4apsd,sdpsis);
         /****************************** SORTING  *********************************/         
        }

    setItemOrder(mapAPDate2Items);      //2020.02.06. 
    }

/****************** PROBABLY NO NEED BECAUSE THE CALLER CREATED THEM. ONLY IN CASE WE HAD AOL!  **************/
/****************** FOR SURE WE DO NOT NEED IT BECAUSE WHEN NO AOL WE DO NOT CALL THISMMETHOD!  **************/
List<Database.UpsertResult> durps;
System.Debug('CSABAX upsert PS_POC / OOTB_PS' + PS_POC2Upsert.size() + ' / ' + lst_PS2Create.size()); 
if(PS_POC2Upsert.size() > 0)
   {
   durps = Database.upsert(PS_POC2Upsert,ProductSubscription_POC__c.ExternalID__c,false);  
   ProductSubscriptionUtility.ProcessUpsertResult(durps,'ProductSubscription_POC',dmlErrMsg);
   }

if(lst_PS2Create.size() > 0)
   {
   durps = Database.upsert(lst_PS2Create,ProductSubscription__c.External_Id__c,false);  
   }   
/****************** PROBABLY NO NEED BECAUSE THE CALLER CREATED THEM. ONLY IN CASE WE HAD AOL!  **************/

//we need to handle situation when a previous  upsert  failed. !!!!!!!!!!!!!!!!!!!!!!!

return mapAPDate2Items; // PSIs2Upsert;
}  


/***********************************************************************
if we want to handle the item Order here and not after creation we have
to inclue AccountID and productID and PSI item StartDate into map's key  

TRY to Build a version of this method  where we pass an Opportunity rec
this can be invoked from Batch

SUGGESTED RETURN VALUE: WE should return the POC PSs to be able to call
the Consolidation process in a way T.B.D (queueable? , Platform Event?)
***********************************************************************/
public static Set<ID> buildSubscriptionFromOpportunityAccountLink(ID oppId)
{
Set<ID> retvalPOCIDs =  new Set<ID>(); //Ids of the PS POC  records  we create or upsert
 
List<ProductSubscription_POC__c> PS_POC2Upsert = new List<ProductSubscription_POC__c>();
List<Product_SubscriptionItem__c> PSIs2Upsert = new List<Product_SubscriptionItem__c>();  
List<Product_SubscriptionItem__c> ownPSIs2Upsert = new List<Product_SubscriptionItem__c>();

List<ProductSubscription__c> lst_PS2Create = new List<ProductSubscription__c> ();

Set<String> dmlErrMsg = new set<String>(); //store the error of ProcessUpsertResult

/********** try to handle sorting here. 2020.02.03. *******/
Map<String,List<Product_SubscriptionItem__c>> mapAPDate2Items = new Map<String,List<Product_SubscriptionItem__c>>(); 

//exclue Empty Start/End Date, Filter Opp stage, Pick only OLI with QLI an think fr more folters
List<Opportunity> opps = [Select Id, Name,Source_Opportunity__c,Type,SBQQ__PrimaryQuote__c, SBQQ__PrimaryQuote__r.SBQQ__Account__c ,AccountId,CreatedDate
                         ,(Select id,Account__c,Account__r.Name, Percentage__c  from Opportunity_Account_Links__r where Percentage__c != NULL and Percentage__c != 0)
                         ,(Select ID,Product2ID,Product2.Name,Product2.Family,Product2.Product_Sub_Family__c,Product2.Product_Type__c, SBQQ__QuoteLine__c
                           ,SBQQ__QuoteLine__r.SBQQ__StartDate__c,SBQQ__QuoteLine__r.SBQQ__EndDate__c  
                           ,SBQQ__QuoteLine__r.SBQQ__NetPrice__c  ,SBQQ__QuoteLine__r.Net_Total_Rounded__c, SBQQ__QuoteLine__r.SBQQ__ListPrice__c  
                           ,SBQQ__QuoteLine__r.SBQQ__Quantity__c,SBQQ__QuoteLine__r.SBQQ__SegmentIndex__c  
                           ,SBQQ__QuoteLine__r.SBQQ__Quote__r.SBQQ__Opportunity2__c,SBQQ__QuoteLine__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.Type   //WE SHOULD USE THEOPP from the outer query!!!!      
                           ,SBQQ__QuoteLine__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.CreatedDate
                           ,SBQQ__QuoteLine__r.CurrencyIsoCode   //2020.02.12.              
                          from OpportunityLineItems 
                          where SBQQ__QuoteLine__r.SBQQ__StartDate__c != NULL
                          and SBQQ__QuoteLine__r.SBQQ__Quote__r.SBQQ__Primary__c = true //TO BE CHECKED
                          )
                          ,(Select id,Primary_Product_Subscription__c,Primary_Product_Subscription__r.Product__c  from Product_Subscription_Opportunities__r)
                          from Opportunity where id = :oppID 
                          and SBQQ__PrimaryQuote__c != NULL                             //TO BE CHECKED
                         ];

Set<ID> prodId = new Set<Id>(); 
map<Id,Set<ID>> mapAcc2Prod = new map<Id,Set<ID>>();
System.Debug('CSABAX opps impacted(hopefully 1) ' + opps.size());
/*****************************************************/
Id accId;
for(Opportunity opp :opps)
   {
   //if we do not have AOLs we use this AccountID
   Set<String> uniqueextIds = new Set<String>();
   accId = opp.SBQQ__PrimaryQuote__r.SBQQ__Account__c;
   System.Debug('CSABAX parent Account : ' + accId + ' ProdCount : ' + opp.OpportunityLineItems.size() + ' onBehalf Count:  ' + opp.Opportunity_Account_Links__r.size());
   for(OpportunityLineItem oli :opp.OpportunityLineItems)
      {
      prodId.add(oli.Product2ID); //this Set is used when no AOL and for child Accounts independent deal
      System.Debug('CSABAX build POC for Prod: ' + oli.Product2.Name);
      String ProdFam = oli.Product2.Family;
      String ProdSubFam = oli.Product2.Product_Sub_Family__c;
      String ProdType = oli.Product2.Product_Type__c; 
      /*******************************************************************
      If the Opp has OALs  we create POC/Items for each Account where the
      Percentage__c is not NULL or 0 EVEN for the Parent Account 
      *******************************************************************/
      Integer ExtIdIndex = 0;
      for(OpportunityAccountLink__c oal :opp.Opportunity_Account_Links__r)
          {
          System.Debug('CSABAX build POC  for Account: ' + oal.Account__r.Name + ' with Percentage:  ' + oal.Percentage__c + ' for Prod: ' + oli.Product2.Name );
          String extID4PS = oal.Account__c + '_' + oli.Product2ID;
          //the same product might be present twwice in OLI. Don't create PS again
          if(uniqueextIds.contains(extID4PS) == false)
            {
              //create the Header POC Prod Subscr
              ProductSubscription_POC__c refPOC = new ProductSubscription_POC__c(ExternalID__c = extID4PS);
              refPOC.Account__c = oal.Account__c;
              refPOC.Product__c =  oli.Product2ID;
              PS_POC2Upsert.add(refPOC);
    
              //create the header PS Prod Subscr
              ProductSubscription__c refPS = new ProductSubscription__c(External_ID__c = extID4PS); 
              refPS.Account__c = oal.Account__c;
              refPS.Product__c =  oli.Product2ID;
              //set Name based on convention ProdFamily - ProdSubFamily - ProdType
              refPS.Name = 'HM-PS ' + ProdFam + ' - ' + ProdSubFam + ' - ' + ProdType;
              //pass  the useless Prod Fam/SubFam fields
              refPS.ProductFamily__c = ProdFam;
              refPS.ProductSubFamily__c = ProdSubFam;
              refPS.ProductType__c = ProdType;              
              lst_PS2Create.add(refPS);  

              uniqueextIds.add(extID4PS);
            }

          //create the PSItem. mark it as being on-behalf of type
          SBQQ__QuoteLine__c qli = oli.SBQQ__QuoteLine__r;
          ProductSubscription_POC__c newPOC = new ProductSubscription_POC__c(ExternalID__c = extID4PS);
          Product_SubscriptionItem__c newpsi = buildCPQ_PSI(qli,newPOC,ExtIdIndex); //we can not use the refPOC
          newpsi.OriginOpportunity__c = opp.id;
          newpsi.OriginOpportunity__r = opp;   
          
          newpsi.AOL_Percentage__c = oal.Percentage__c;  
          newpsi.QuoteItem_Value__c = newpsi.QuoteItem_Value__c * newpsi.AOL_Percentage__c / 100;

          newpsi.Creation_Type__c = 'on-Behalf';  //2020.02.03.  we might need this info later
          newpsi.ParentAccountID__c = opp.AccountID;//2020.02.07.
          ProductSubscription__c newPS = new ProductSubscription__c(External_ID__c = extID4PS);     
          newpsi.Parent_PS__r = newPS;   //we can not use the refPS
          PSIs2Upsert.add(newpsi);

          mapAcc2Prod.put(oal.Account__c,prodId); //the prodID set in incremented outside this for loop       
          
          /*********************************** SORTING  *****************************************************/
          String mapKey4apsd = accId + '_' + oli.Product2ID + '_' + oli.SBQQ__QuoteLine__r.SBQQ__StartDate__c;
          list<Product_SubscriptionItem__c> sdpsis = mapAPDate2Items.get(mapKey4apsd);
          if(sdpsis == Null)
            {
            sdpsis = new list<Product_SubscriptionItem__c>();
            }
          sdpsis.add(newpsi);  
          mapAPDate2Items.put(mapKey4apsd,sdpsis);
          /*********************************** SORTING ******************************************************/

          ExtIdIndex++;
          }//end for AOL loop
      /****************  EN OAL handling **************/
      //if there were no OALs in this for loop  we collect only the ProdIDs for the Parent account.

      }//end for OLI

   }//end for Opp  
/******************************************************/
    
setItemOrder(mapAPDate2Items); 

List<Database.UpsertResult> durps;

if(mapAcc2Prod.size() == 0)
   {
   System.Debug('CSABAX we do not have AOLs create POC/Itemn for the main Account. ProCount = ' + prodId.size());
   retvalPOCIDs = buildSubscriptionFromAccount4Products(accId,prodId,NULL);  
   return retvalPOCIDs;  
   }
else 
   {
    /************** the below happen only if we HAD OppAccLink records *********************/
    System.Debug('CSABAX upsert PS_POC for the on-behalf  Accounts: ' + PS_POC2Upsert.size()); 
    if(PS_POC2Upsert.size() > 0)
      {
      durps = Database.upsert(PS_POC2Upsert,ProductSubscription_POC__c.ExternalID__c,false);  
      retvalPOCIDs = ProductSubscriptionUtility.ProcessUpsertResult(durps,'ProductSubscription_POC',dmlErrMsg);
      }
    System.Debug('CSABAX upsert OOTB PS for the on-behalf Accounts' + PS_POC2Upsert.size());
    if(lst_PS2Create.size() > 0)
      {
      durps = Database.upsert(lst_PS2Create,ProductSubscription__c.External_Id__c,false);  
      ProductSubscriptionUtility.ProcessUpsertResult(durps,'ProductSubscription',dmlErrMsg);      
      } 
    /************** the above happen only if we HAD OppAccLink records *********************/
    /***** Above we create the OOTB PS and the POC PS header for the on-behalf Accunts *****/ 

  for(ID acc_Id :mapAcc2Prod.keySet())
     {
     //2020.02.15 create the own deals for the on-behalf Accounts. This call will not generate new POC or PS records because those were just upserted above. 
     Map<String,List<Product_SubscriptionItem__c>> mapAPDate2ItemsOWND = buildSubscriptionFromAccount4ProductsOAL(acc_Id,mapAcc2Prod.get(acc_Id),NULL,oppId);
     for(String keyu :mapAPDate2ItemsOWND.keyset())
        {
          List<Product_SubscriptionItem__c> ownPSItems = mapAPDate2ItemsOWND.get(keyu);
          PSIs2Upsert.addAll(ownPSItems);
        }
     }   
   }//end of ELSE  
  
//sort items before Create
System.Debug('CSABAX upsert on-behalf PSIs ' + PSIs2Upsert.size());
durps = Database.upsert(PSIs2Upsert,Product_SubscriptionItem__c.External_Id__c,false); 
ProductSubscriptionUtility.ProcessUpsertResult(durps,'Product_SubscriptionItem',dmlErrMsg);    

return retvalPOCIDs;
}


/************************************************************************************************************************************
************************************************************************************************************************************/
private static Product_SubscriptionItem__c buildCPQ_PSI(SBQQ__QuoteLine__c qli,ProductSubscription_POC__c refPOC, integer ExtIdIndex)
{
    System.Debug('CSABAX buildCPQ_PSI starts for refPOC: ' + refPOC);
    Product_SubscriptionItem__c newpsi =  new Product_SubscriptionItem__c(RecordTypeID = qliRTID);   
    if(refPOC.id != NULL)
    {
      newpsi.ParentSubscription__c = refPOC.id;      
    }
    else 
    {
      newpsi.ParentSubscription__r = refPOC;     
    }
    newpsi.OriginQuote_Line__c = qli.id;
    newpsi.OriginOpportunity__c = qli.SBQQ__Quote__r.SBQQ__Opportunity2__c;
    newpsi.OriginOpportunity__r = qli.SBQQ__Quote__r.SBQQ__Opportunity2__r; //this will bring several opp fields used later 

    newpsi.Start_Date__c = qli.SBQQ__StartDate__c;
    newpsi.End_Date__c = qli.SBQQ__EndDate__c;
    //in case of on-Behalf deaals 1 QLI  generates multiple Items
    if(ExtIdIndex == NULL)
       {
        newpsi.External_Id__c = qli.id;
       }
    else 
      {
        newpsi.External_Id__c = qli.id + '_' + string.valueOf(ExtIdIndex);
      }   

    
    newpsi.Quantity__c = qli.SBQQ__Quantity__c;
    newpsi.QuoteItem_Value__c = qli.Net_Total_Rounded__c;  //the default Perentage is 100%
    newpsi.YearIndex__c = qli.SBQQ__SegmentIndex__c;
    
    newpsi.Duration__c = qli.SBQQ__StartDate__c.monthsBetween(qli.SBQQ__EndDate__c);  //NOT GOOD review and calculate based on days/30.5 and round
    if(qli.SBQQ__StartDate__c.day() < qli.SBQQ__EndDate__c.day())
       {
        newpsi.Duration__c = newpsi.Duration__c + 1;
       }

    newpsi.OppCreatedDate__c = qli.SBQQ__Quote__r.SBQQ__Opportunity2__r.Createddate;
    newpsi.OppType__c = qli.SBQQ__Quote__r.SBQQ__Opportunity2__r.Type;
    newpsi.Creation_Type__c = 'own-Deal';    
    newpsi.Deal_Currency__c = qli.CurrencyIsoCode;  //2020.02.12.
    
    return newpsi;
}


/******************************************************************************************************************************************************
 ************************************* ITEM ORDER RELATED CODE. NOT SURE STILL NEEDED IN CONSOLIDATED 2.0 *********************************************
 *****************************************************************************************************************************************************/

/********************************************************************************************
for each list inside the map try to set the ItemOrder__c field on the Item record.
The first item should be the one with the earlierst Opportunity. if there are more  then 1, 
the second should be the Deebok and the 3rd if exist the Overruled opps item To track this 
we need Opp CreationDate and Opp Name on the object. 
Deebok Opp should have the name started wirth the Name of the Deebooked opp.  
2020.02.18. With the new Consolidation 2.0 no more need for ordering. We can get rid of code. 
********************************************************************************************/
private static void setItemOrder(Map<String,List<Product_SubscriptionItem__c>> mapDate2Items)
{

for(String sd :mapDate2Items.keyset())
   {
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
    String oppName2Match = sortedPSIs[startingIndex - 1].OriginOpportunity__r.Name;  
    ID debookedOppId = sortedPSIs[startingIndex - 1].OriginOpportunity__c;    
    Product_SubscriptionItem__c item2Match = sortedPSIs[startingIndex - 1];  //2020.02.11.      
    System.Debug('CSABAX PSI OppName2Match = ' + OppName2Match);  
    integer item2MatchOrder = (Integer)sortedPSIs[startingIndex - 1].itemOrder__c; 
    for(integer i = startingIndex; i < sorteditemsize; i++)
        {
        String currentOppName = sortedPSIs[i].OriginOpportunity__r.Name;     
        
        System.Debug('CSABAX inside for. startingIndex = ' + startingIndex);  
        System.Debug('CSABAX CurrentOppName = ' + CurrentOppName + ' i = ' + i);   
        System.Debug('CSABAX current order = ' + sortedPSIs[i].itemOrder__c);      
        //try to find item which Opp is a Debook of the sortedPSIs[startingIndex - 1] if foudn call pushItemOrderRight

        if(sortedPSIs[i] != NULL && sortedPSIs[i].itemOrder__c <= startingIndex)
          {
          System.Debug('CSABAX do not check again a debook-ed  Opps psi');  
          continue;  //do not check again a debook-ed  Opp's psi  
          }

        if((CurrentOppName.startsWith(OppName2Match) == true && (CurrentOppName.Contains('Debook') 
                                                                 || 
                                                                 CurrentOppName.Contains('debook')
                                                                 || 
                                                                 CurrentOppName.Contains('DeBook')                                                                 
                                                                ) && sortedPSIs[i].OriginOpportunity__r.Source_opportunity__c == NULL) || 
           sortedPSIs[i].OriginOpportunity__r.Source_opportunity__c == debookedOppId && ( CurrentOppName.Contains('Debook') || CurrentOppName.Contains('debook') )
           ||
           item2Match.QuoteItem_Value__c == (sortedPSIs[i].QuoteItem_Value__c) * (-1) //2020.02.11. QuoteItem_NetTotal__c
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

         }//end of inner for 

    startingIndex++;         
    }//end of while

   }//end of outer for
}

/*****************************************************************************************************************************************
2020.02.18. With the new Consolidation 2.0 no more need for ordering. We can get rid of code. 
*****************************************************************************************************************************************/
private static void pushItemOrderRight(List<Product_SubscriptionItem__c> sortedPSIs, integer startIndex, integer endIndex, integer pushto)
{
for(integer i = startIndex; i < endIndex; i++)
   { 
   if(sortedPSIs[i].itemOrder__c <= startIndex)
      {
      System.Debug('CSABAX is an old debook.');  
      continue;
      }

   sortedPSIs[i].itemOrder__c = sortedPSIs[i].itemOrder__c + 1;
   }
 
sortedPSIs[endIndex].itemOrder__c = pushto + 1;   
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

  if(thePSI.OriginOpportunity__r.CreatedDate > obj2Comp.thePSI.OriginOpportunity__r.CreatedDate)   
  {
    return 1;
  }


  else if(thePSI.OriginOpportunity__r.CreatedDate == obj2Comp.thePSI.OriginOpportunity__r.CreatedDate)  
  {
    return 0;
  }


  else if(thePSI.OriginOpportunity__r.CreatedDate < obj2Comp.thePSI.OriginOpportunity__r.CreatedDate)  
  {
    return -1;
  }
 

  return 0;
  }

}//end of  inner class


/************************************************************************
collect all products from the Primary CPQ quote of the Opp and call  
buildSubscriptionFromAccount_Products to build full Subscription for 
the Account of the Opps where the Quote prodsucts are involved
param:  Opportunity ID
return: Set of  newly  created or updated ProductSubscrriptionPOC records

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

  if(psis != NULL && psis.size() == 1)
    {

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
************************************************************************/


/*********************************************************************
Collect all Products involved for this Opportiunity via its LineItems
Collect All OpportunityLineItem for the involved products and Opp Acc
OLI and QLI are linked so if we start from here we can easily switch
between OLI anf QLI                              NOT USED ***********

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
*********************************************************************/


/******************************************************************************************************************
Build PSI from OpportunityQuoteLineItems

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
    newpsi.YearIndex__c = qli.SBQQ__QuoteLine__r.SBQQ__SegmentIndex__c;

    newpsi.QuoteItem_Value__c = qli.TotalPrice;
    
    newpsi.Duration__c = qli.Start_Date__c.monthsBetween(qli.End_Date__c) + 1; //this is not accurate because truncate 
    
    return newpsi;
}
******************************************************************************************************************/

}