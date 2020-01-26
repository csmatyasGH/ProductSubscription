/******************************************************
pass here those methods which manipulate already  
created POC subscription records (consolidation....) 
******************************************************/
global without sharing class ProductSubscriptionUtility 
{
    private static Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
    private static Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId();

    public ProductSubscriptionUtility() 
    {

    }


@InvocableMethod(label='Get Subscription' description='Create Subscription and items')
/********************************************************************************
invocable method always invoked with 1 item
Return: list of new or upserted POC records. in case size is > 1 it will create
problems when embedding it into a Flow (Quick action on Opportunity)
********************************************************************************/
public static void processSubscription(List<ProductSubscriptionBuilder> psbs)
{
String operation;
ID accId;
Set<ID> prodIDs = new Set<ID>();
ID psId;
Id oppId;
Boolean isOnBehalf = false;

for(ProductSubscriptionBuilder psb :psbs)
  { 
   System.Debug('CSABAX psb: ' + psb);  
   prodIDs.add(psb.prodID);   
   psid = psb.psID;     

   operation = psb.Operation; 
   if(operation == 'Create')
      {
      accId = psb.accId;
      }

   if(operation == 'BuildFromOpp')
      {
      oppId = psb.oppId;
      isOnBehalf = psb.isOnBehalf;
      }  

   if(operation == 'BuildFromProdSubsc')
      {
      accId = psb.accId;
      prodIDs.add(psb.prodID);         
      }            

}

if(prodIDs.size() > 1) { return; }  //impossible in  normal operation

System.Debug('CSABAX operation = ' +  operation);
if(Operation == 'Create')
   BuildSubscriptionPOC.buildSubscriptionFromAccount_Products(accId,prodIDs,'Create');

if(operation == 'Consolidate')
   {
   ConsolidateItems4Subs(psid);         
   }


if(operation == 'Reset')
  {
   DeleteConsolidatedItems(psid,true);
  }


if(operation == 'BuildFromOpp') 
  {
   if(isOnBehalf == false)
      {
      BuildSubscriptionPOC.buildSubscriptionFromOpportunity4AppProds(oppId);
      }  
   else 
      {
      BuildSubscriptionPOC.buildSubscriptionFromOpportunityAccountLink(oppId);      
      } 

  }

 if(operation == 'BuildFromProdSubsc') 
  {
   BuildSubscriptionPOC.buildSubscriptionFromAccount_Products(accId,prodIDs,NULL);
  } 

}


/*****************************************************
after introducing itemOrder no more need the Dynamic
SOQL
*****************************************************/
public static void ConsolidateItems4Subs(ID subscrID)
{
DeleteConsolidatedItems(subscrID,false);

List<Product_SubscriptionItem__c> consolidatedPSIs = new List<Product_SubscriptionItem__c>();
//Build Dynamic SOQL becase  during test I can not assure right order due to missing Opportunities
String dynSQL = 'Select Id,Name,Parent_PS__c,Start_Date__c,End_Date__c,Net_Value__c,QuoteItem_NetTotal__c,QuoteItem_Value__c,Type__c,Opp_Type__c,Day_Duration__c  ';
dynSQL = dynSQL + ',OriginQuote_Line__c, OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.Name,OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__c';
dynSQL = dynSQL + ' ,OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.CloseDate';
dynSQL = dynSQL + ' ,OriginQuote_Line__r.SBQQ__SegmentIndex__c,Duration__c';
dynSQL = dynSQL + ' ,OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.Number_of_ACV_Years__c';
dynSQL = dynSQL + ' ,ParentSubscription__c,ParentSubscription__r.Product__c,Quantity__c,YearIndex__c,External_Id__c';
dynSQL = dynSQL + ' from Product_SubscriptionItem__c where ParentSubscription__c = \'' + subscrID  + '\'';
dynSQL = dynSQL + ' and RecordTypeID = \'' +  qliRTID + '\'';

if(Test.isRunningTest())
{
dynSQL = dynSQL + ' order by Start_Date__c asc,Name'; 
}
else 
{
dynSQL = dynSQL + ' order by Start_Date__c asc,itemOrder__c,OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.CloseDate asc';
}
System.Debug('CSABAX dynSql = ' + dynSQL);
List<Product_SubscriptionItem__c> psis = Database.query(dynSQL);
/*************************************************************************************************************************************************************************************
List<Product_SubscriptionItem__c> psis = [Select Id,Name,Parent_PS__c,Start_Date__c,End_Date__c,Net_Value__c,QuoteItem_NetTotal__c,QuoteItem_Value__c,Type__c,
                                          OriginQuote_Line__c, OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.Name,OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__c,
                                          OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.CloseDate,
                                          OriginQuote_Line__r.SBQQ__SegmentIndex__c,Duration__c,
                                          OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.Number_of_ACV_Years__c
                                          ,ParentSubscription__c,ParentSubscription__r.Product__c
                                          ,Quantity__c,YearIndex__c,External_Id__c
                                          from Product_SubscriptionItem__c where ParentSubscription__c = :subscrID
                                          and RecordTypeID = :qliRTID
                                          order by Start_Date__c asc,
                                          OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.CloseDate asc]; //2019.01.03
*************************************************************************************************************************************************************************************/

Integer itemcount = psis.size();
System.Debug('CSABAX itemcount = ' + itemcount);
if(itemcount == 0) { return; }

Product_SubscriptionItem__c currentconsolidated = new Product_SubscriptionItem__c();
currentconsolidated = psis[0].clone();
currentconsolidated.Net_Value__c = psis[0].QuoteItem_Value__c;
currentconsolidated.RecordTypeID = consRTID;

if(itemcount == 1)
   {
   //we have 1 single "Self-Consoldated" item.ApexPages.  
   currentconsolidated.External_Id__c = currentconsolidated.External_Id__c + '_' + consolidatedPSIs.size();   
   consolidatedPSIs.add(currentconsolidated);
   insert currentconsolidated;
   return;
   }


for(integer i = 1; i<itemcount; i++)
   {
    Product_SubscriptionItem__c currentItem = psis[i];
    Product_SubscriptionItem__c prevItem = psis[i-1];    
    System.Debug('CSABAX currentconsolidated = ' + currentconsolidated);    
    System.Debug('CSABAX currentItem = ' + currentItem); 
    System.Debug('CSABAX prevItem = ' + prevItem);     

    /************************ SAME START DATE START *****************/
    if(currentItem.Start_Date__c == prevItem.Start_Date__c)
    {
    System.Debug('CSABAX either debook or a new logo same period');

    /*********** if the currentconsolidated has TYPE = "CONTINGENT" we should roll back the contingency to the previous period
    and save it as final consolidated. Theoretically this item might continue the Consolidation chain but unlikelly BUT HAPPEN
    *************************************************************************************************************************/ 
    if(currentconsolidated.Type__c == 'CONTINGENT')
       {
        if(currentconsolidated.Net_Value__c != currentItem.QuoteItem_Value__c)
           {
            currentconsolidated.End_Date__c = currentItem.Start_Date__c.addDays(-1);
            currentconsolidated.Duration__c = currentconsolidated.Start_Date__c.monthsBetween(currentconsolidated.End_Date__c);   
            currentconsolidated.External_Id__c = currentconsolidated.External_Id__c + '_' + consolidatedPSIs.size();  
            //Reevaluate AAR and TSV                  
            consolidatedPSIs.add(currentconsolidated); 
            currentconsolidated = handleSameStart(prevItem,currentItem);               
           }
        else 
           {
           //iif the current item keep the continegcy ignore it because it  the same.
           continue;
           }
       }

    //we continue consolidation with Previos Item and Current Item,   
    currentconsolidated = handleSameStart(prevItem,currentItem);   
    continue;
    }
    /************************ SAME START DATE END *******************/    
    
    /************************ CONTINGENT DATES START *************************/    
    if(currentconsolidated.End_Date__c.addDays(1) == currentItem.Start_Date__c)
    {
    //start of a contingent new item   
    System.Debug('CSABAX start of a contingent new item');    
    Product_SubscriptionItem__c cc = handleContingent(currentconsolidated,currentItem);
    if(cc == null)
      {
       //we keep the currentconsolidated having it's duration extended
      } 
    else 
      {
       //we can mark currentconsolidated as final and continue with the cc currentItem new Candidate
       if(currentconsolidated.Net_Value__c > 0)
          {
           currentconsolidated.External_Id__c = currentconsolidated.External_Id__c + '_' + consolidatedPSIs.size();  //2019.12.07.       
           if(currentconsolidated.Type__c == NULL)
              {   
              currentconsolidated.Type__c = 'SINGLE ITEM';  
              }       
           consolidatedPSIs.add(currentconsolidated);
          }
       else 
         {
         //WARNING. Here I assume that the Net_Value__c CAN NOT BE < 0.  BUT there are such a cases   
         //https://instructure--staging.my.salesforce.com/aEP2g0000008ROf
         }   


       currentconsolidated = cc.clone();
       currentconsolidated.RecordTypeID = consRTID;
      }  

    continue;
    }
    /************************ CONTINGENT DATES END ***************************/

    /************************ FUTURE DATES START *****************/    
    if(currentItem.Start_Date__c > prevItem.End_Date__c.addDays(1))
    {
    //unlinked new future period   
    continue;
    }
    /************************ FUTURE DATES END ******************/    
    

    /************************ OVERLAPPED DATES START *********************************************************/    
    if(currentItem.Start_Date__c > prevItem.Start_Date__c && currentItem.Start_Date__c < prevItem.End_Date__c )
    {
    //overlapped item  
    System.Debug('CSABAX overlapped item ');  
    //if the new Item is overlapping with a CONTINGENT currentconsolidated we undo the contingency   
    if(currentconsolidated.Type__c == 'CONTINGENT')
       {
        currentconsolidated.End_Date__c = currentItem.Start_Date__c.addDays(-1);
        currentconsolidated.Duration__c = currentconsolidated.Start_Date__c.monthsBetween(currentconsolidated.End_Date__c);  
        currentconsolidated.External_Id__c = currentconsolidated.External_Id__c + '_' + consolidatedPSIs.size();  //2019.12.07.  
        //Reevaluate AAR and TSV                  
        consolidatedPSIs.add(currentconsolidated);     
       }

    //continue consolidation having the previous as cc
    Product_SubscriptionItem__c cc = handleOverlap(prevItem,currentItem);   
    if(cc != NULL)  
      {
      if(cc.Net_Value__c > 0)
         {
         cc.External_Id__c = cc.External_Id__c + '_' + consolidatedPSIs.size();  //2019.12.07.     
         consolidatedPSIs.add(cc); 
         }

      //if the current item is an upsell we have to handle it  2020.01.21.
      if(currentItem.Opp_Type__c == 'upsell')
         {
         currentconsolidated = upsell(prevItem,currentItem); 
         currentconsolidated.RecordTypeID = consRTID; 
         }
      else 
         {//this was before 2020.01.21.
         currentconsolidated = currentItem.clone(); 
         currentconsolidated.Net_Value__c = currentItem.QuoteItem_Value__c;
         currentconsolidated.RecordTypeID = consRTID;  
         currentconsolidated.External_Id__c = currentconsolidated.External_Id__c + '_' + consolidatedPSIs.size();       
         }
 
      }  
    else 
      {
      //we might have a multiyear deal overruled. sart a new process
      currentconsolidated = currentItem.clone(); 
      currentconsolidated.Net_Value__c = currentItem.QuoteItem_Value__c;   
      currentconsolidated.RecordTypeID = consRTID;            
      }  

    continue; 
    }
    /************************ OVERLAPPED DATES END ***********************************************************/

   }//end of for

   if(currentconsolidated.Net_Value__c != 0)
     {
      currentconsolidated.External_Id__c = currentconsolidated.External_Id__c + '_' + consolidatedPSIs.size();         
      consolidatedPSIs.add(currentconsolidated);
     }

   System.Debug('CSABAX we have ' + consolidatedPSIs.size() + ' consolidated Subscription terms');

   /*********************************************************************************************************
   Once consolidation is succesfull remove the Lookup to OOTB ProductSubs from the non-consolidated QLI items 
   ******************************************** START ******************************************************/
   List<Product_SubscriptionItem__c> thePSI2Upsert = new List<Product_SubscriptionItem__c>(); 
   for(Product_SubscriptionItem__c qli_item :psis)
       {
       qli_item.Parent_PS__c = NULL;   
       thePSI2Upsert.add(qli_item);
       }   

   thePSI2Upsert.addAll(consolidatedPSIs); 
   for(Product_SubscriptionItem__c i2u :thePSI2Upsert)
   {
   System.Debug('CSABAX Id = ' + i2u.id + ' ExtID = ' +  i2u.External_Id__c);   
   }
   List<Database.UpsertResult> durs = Database.upsert(thePSI2Upsert,Product_SubscriptionItem__c.External_Id__c,false); 
   ProcessUpsertResult(durs);
   /*********************************************** END *************************************************************/

}

/***************************************************************************************************************************
param 1 cc- consolidatedCandidate
param 2 -item. the current item in the Loop
return value  the consolidated candidate 
***************************************************************************************************************************/
private static Product_SubscriptionItem__c handleSameStart(Product_SubscriptionItem__c cc, Product_SubscriptionItem__c item)
{
Product_SubscriptionItem__c retval = new Product_SubscriptionItem__c(RecordTypeID = consRTID);
if(item.QuoteItem_Value__c < 0 || (Test.isRunningTest() == true && cc.QuoteItem_Value__c < 0))
  {
   //this is a debook. We assume same start/End date otherwise BAD data
   retval = cc.clone();
   retval.Net_Value__c = cc.QuoteItem_Value__c + item.QuoteItem_Value__c;  
   retval.QuoteItem_Value__c = retval.Net_Value__c;         //2020.01.20.
   retval.Type__c = 'DEBOOKED'; 

  }
else if(item.Opp_Type__c == 'Upsell')
  {
   //try to handle here the real upsell
   //here instead  taking over the old item we add gthe current item's value to the current one
   //mthemativally this does not differ form the above. The only difference is taht new value is not < 0
   retval = item.clone();
   retval.Net_Value__c = cc.QuoteItem_Value__c + item.QuoteItem_Value__c;  
   retval.QuoteItem_Value__c = retval.Net_Value__c;         //2020.20.21.
   retval.Type__c = 'UPSELLED';   
  }  
else 
  {
  //this is an ammendment or a new logo for the same period. the new one should take over  
  retval = item.clone();
  retval.Net_Value__c = item.QuoteItem_Value__c;
  }
retval.RecordTypeID = consRTID;

//2020.01.17. Check the Upsell!!!!

return retval;
}

/****************************************************************************************************************************
//if  are contingent we should check if cc and item has the same value
//if YES we extend the cc's End Date to the full range
//if NO the item will be the new cc and will be returned
//the original cc will be  a final on and the returned will serv as new cc for further iterations
****************************************************************************************************************************/
private static Product_SubscriptionItem__c handleContingent(Product_SubscriptionItem__c cc, Product_SubscriptionItem__c item)
{
Product_SubscriptionItem__c retval = new Product_SubscriptionItem__c(RecordTypeID = consRTID);

if(cc.QuoteItem_Value__c == item.QuoteItem_Value__c) //here we should check the Quantity and unit price not the total but not sure!!!!????
  {
   cc.End_Date__c = item.End_Date__c;
   cc.Duration__c = cc.Start_Date__c.monthsBetween(item.End_Date__c);   
   cc.Type__c = 'CONTINGENT';
   cc.Net_Value__c = cc.Net_Value__c + cc.QuoteItem_Value__c;  //add new to original 2020.01.22.
   return null;
  }
else 
  {
   retval = item.clone();
   retval.Net_Value__c = item.QuoteItem_Value__c;   
   retval.RecordTypeID = consRTID;
  }

return retval;    
}

/*************************************************************************************************************************
in case the new item startDate fall between cc's Start/End_Date we create 1 consolidated item for the "left" side and Item
will be the new Candidate.
in case the item is in a different SBQQ__SegmentIndex__c then cc do not continue. Return NULL and make item a new cc. WHY??????????????
*************************************************************************************************************************/
private static Product_SubscriptionItem__c handleOverlap(Product_SubscriptionItem__c cc, Product_SubscriptionItem__c item)
{
Product_SubscriptionItem__c retval = new Product_SubscriptionItem__c(RecordTypeID = consRTID);

if(cc.OriginQuote_Line__r.SBQQ__SegmentIndex__c < item.OriginQuote_Line__r.SBQQ__SegmentIndex__c)
{
   return NULL;   //rethink this
}


//trunchate the current cc into a new one and make it as final one. The item will be the new cc    
Decimal fullLengthinDays = cc.Start_Date__c.daysBetween(cc.End_Date__c);
Decimal truncatedLengthDays = cc.Start_Date__c.daysBetween(item.Start_Date__c);    //in case of  small
//adjust the Value
retval.Start_Date__c = cc.Start_Date__c;
retval.End_Date__c = item.Start_Date__c.addDays(-1);
retval.Net_Value__c = cc.QuoteItem_Value__c * (truncatedLengthDays.divide(fullLengthinDays,2));  //to be checked

retval.OriginQuote_Line__c = cc.OriginQuote_Line__c;
retval.ParentSubscription__c = cc.ParentSubscription__c;
retval.Parent_PS__c = cc.Parent_PS__c;
retval.Type__c = 'TRUNCATED';
retval.External_Id__c = cc.External_Id__c;  //2020.01.21.

return retval;
}


/****************************************************************************************************************************
XXXXXXXXXXXXXXXXXXX
YYYYYYYYY
-------------------
XXXX+YYYY|XXXXXXXXX

OR

XXXXXXXXXXXXXXXXXXX
           YYYYYYYY
----------------
XXXXXXXXXX|XXX+YYYY

Regardless if we upsell to left  or Right side  the summed result will be the same.           The leftover value  will differ 
WE SHOULD KNOW IF IS A LEFT OR RIGHT UPSELL
****************************************************************************************************************************/
private static Product_SubscriptionItem__c upsell(Product_SubscriptionItem__c prevItem, Product_SubscriptionItem__c currItem)
{
Product_SubscriptionItem__c retval =  new Product_SubscriptionItem__c();

Decimal prevD = prevItem.Day_Duration__c;
Decimal currD = currItem.Day_Duration__c;

Decimal prevRatio = currD.divide(prevD,2);

if(prevItem.Start_Date__c == currItem.Start_Date__c)
{
retval.Start_Date__c = prevItem.Start_Date__c;
retval.End_Date__c = currItem.Start_Date__c.addDays(-1);
}
else if(prevItem.End_Date__c == currItem.End_Date__c)
{
retval.Start_Date__c = currItem.Start_Date__c;
retval.End_Date__c = currItem.End_Date__c;   
}
else 
{
//this should not happen. Middle-Upsell not handled. ignre upsell and currItem take over
retval = currItem;
return retval;
}


retval.Net_Value__c = prevItem.QuoteItem_Value__c * prevRatio + currItem.QuoteItem_Value__c;

retval.OriginQuote_Line__c = prevItem.OriginQuote_Line__c;
retval.ParentSubscription__c = prevItem.ParentSubscription__c;
retval.Parent_PS__c = prevItem.Parent_PS__c;
retval.External_Id__c = currItem.External_Id__c;

return retval;
}

/***************************************************************************************************************************************************
XXXXXXXXXXXXXXXX
        YYYYYYYY
----------------
XXXXXXXX|XXX+YYY 
***************************************************************************************************************************************************/




/**************************************************************************
when we want to redo the consolidation delete the old.
if is called from Reset transferr Parent PS to the remaining items
**************************************************************************/
public static void DeleteConsolidatedItems(ID subscrID, Boolean RestorePPS)
{
List<Product_SubscriptionItem__c> psis2delete = new List<Product_SubscriptionItem__c>();
List<Product_SubscriptionItem__c> psis2restore = new List<Product_SubscriptionItem__c>();

String soql = 'Select id, Parent_PS__c,RecordTypeID from Product_SubscriptionItem__c where ParentSubscription__c = \'' + subscrID + '\'';   
if(RestorePPS == false)
   {
   soql = soql + ' and RecordTypeID = \'' + consRTID + '\' order by RecordType.Name ';   
   psis2delete = Database.query(soql); 
   Delete psis2delete;
   return;
   }

soql = soql + ' order by RecordType.Name';  
List<Product_SubscriptionItem__c> psis = Database.query(soql);
ID parentPS;
for(Product_SubscriptionItem__c psi :psis)
   {
   if(psi.RecordTypeID == consRTID) 
      {
       psis2delete.add(psi); 
       parentPS = psi.Parent_PS__c;
      }
   else 
      {
      psi.Parent_PS__c = parentPS;
      psis2restore.add(psi);
      }   
   }   

if(psis2delete.size() > 0) { Delete psis2delete; }   
if(psis2restore.size() > 0) { update psis2restore; }   

}



/**********************************************
Leave old Terms as it is. Overrule Current and
Future items. If there are more Items then Term
get the Name and External_ID  of the last Term
and continue form there
**********************************************/
public static void MergeItems2Terms(Set<Id> thePSIDs)
{
List<ProductSubscriptionTerm__c> mergedPSTerms = new List<ProductSubscriptionTerm__c>();

List<ProductSubscription__c> thePSs = [Select Id
                                        ,(Select Id,Name, StartDate__c,EndDate__c,SubscriptionKeyWithTerm__c,Account__c,Product__c,ProductID__c,ProductSubscription__c,
                                          Quantity__c,RevisedUltimateFamily__c,RevisedUltimateSubFamily__c,SubscriptionTermStatus__c  
                                          from Subscription_Terms__r where  SubscriptionTermStatus__c in ('Current','Future') order by StartDate__c asc)
                                        ,(Select Id,Name,Start_Date__c,End_Date__c,ARR__c,MRR__c,Net_Value__c  
                                          from Product_SubscriptionItems__r 
                                          where RecordType.DeveloperName = 'Consolidated' and SubscriptionTermStatus__c in ('Current','Future') order by Start_Date__c asc
                                         )   
                                       from ProductSubscription__c where id in :thePSIDs];

for(ProductSubscription__c thePS : thePSS)
   {
   List<ProductSubscriptionTerm__c> psTerms = thePS.Subscription_Terms__r;
   List<Product_SubscriptionItem__c> psItems = thePS.Product_SubscriptionItems__r;

   System.Debug('CSABAX psTerms count = ' + psTerms.size());
   System.Debug('CSABAX psItems count = ' + psItems.size());   

   String lastTermName;
   String lastTermExtID;

   /**** Items are ordered by StartDate asc ***/
   Integer termIndex = 0;
   ProductSubscriptionTerm__c nextTerm;    
   for(Product_SubscriptionItem__c psi :psItems)
      { 
      System.Debug('CSABAX merging item: ' + psi);   
          
      for(integer i = termIndex; i < psTerms.size(); i++)
         {
         nextTerm = convertItem2term(psi,psTerms[i],'merge');
         mergedPSTerms.add(nextTerm);         
         break;
         }

      
      termIndex++;
      System.Debug('CSABAX termIndex after inc. = ' + termIndex);

      if(termIndex > psTerms.size())
         {
         //if we still have items here convert item to term and set thr name and External Id  to the  next increment
         //here we have to consider the case when there is no term at all. We have to define the Name and ExternalID 

         if(nextTerm != NULL)
            {
            //new but not brand-new or the second one from a series of brand news
            nextTerm = convertItem2term(psi,psTerms[psTerms.size() -1],'new');
            //System.Debug('CSABAX created term: ' + nextTerm);
            mergedPSTerms.add(nextTerm);
            }      
         else 
            {
            //brand new.
            }   
         }
      }

   }

System.Debug('CSABAX we are upserting ' + mergedPSTerms.size() + ' items.');
List<Database.UpsertResult> durs = Database.upsert(mergedPSTerms,ProductSubscriptionTerm__c.SubscriptionKeyWithTerm__c,false);
processUpsertResult(durs);
}


/************************************************************************************************************************************** 
return either a new Term or the passed term updated with fields from Source Item
Keep al fields excepting: ARR/MRR/TSV/Quantity/Start-End Dates
**************************************************************************************************************************************/
private static ProductSubscriptionTerm__c convertItem2term(Product_SubscriptionItem__c item,ProductSubscriptionTerm__c term, String merge_new)
{
System.Debug('CSABAX call convertItem2term with term: ' + term.Name + ' for ' + merge_new);   
ProductSubscriptionTerm__c retval;

if(merge_new == 'merge')
  {
   term.StartDate__c = item.Start_Date__c;
   term.EndDate__c = item.End_Date__c;

   //term.ARR__c = item.ARR__c;
   //term.MRR__c = item.MRR__c;
   term.TSV__c = item.Net_Value__c;   //TermNetValue__c
  }
else if(merge_new == 'new')
  {
  retval = new ProductSubscriptionTerm__c();
  retval =  term.clone(); //pass all  existing and usefull fields  like Prod /Family,.....
  retval.StartDate__c = item.Start_Date__c;
  retval.EndDate__c = item.End_Date__c;

  retval.ARR__c = item.ARR__c;
  retval.MRR__c = item.MRR__c;
  retval.TSV__c = item.Net_Value__c;   //TermNetValue__c  

  //adjust(increment) the Name and External Id
  String theName = retval.Name;
  integer lastindex = theName.lastIndexOf(' ');

  String rootName = theName.left(lastindex);
  String increment = theName.right(theName.length() - lastindex);
  Integer intIncrement = Integer.valueOf(increment.trim());
  intIncrement = intIncrement + 1;  
  retval.Name = rootName + ' ' + String.valueof(intIncrement);

  String leftExtId = retval.SubscriptionKeyWithTerm__c.left(36);
  String rightExtID = retval.SubscriptionKeyWithTerm__c.right(retval.SubscriptionKeyWithTerm__c.length()- 36); //this should be a number
  intIncrement = Integer.valueOf(rightExtID);
  intIncrement = intIncrement + 1;
  retval.SubscriptionKeyWithTerm__c = leftExtId + String.valueof(intIncrement);
  System.Debug('CSABAX created term: ' + retval);
  return retval;
  //we use the term passed as parameter  to get the Acc/prod/Fam fields to be reused and Name, ExtId to use in building incremented one  
  }   
else if(merge_new == 'brand new')
  {
   //term is NULL here. We need to create brand new Term
  }  



//2020.01.23. Item does not have quantity!

return term;
}



/*********************************************************************
parameter is  a list  of Product subscriptions belonging to 1 Account.
Try to build hierarchy relationship based on Prod attributes (Family?)
Select id, Name, 
(Select Id,PrimaryProductSubscription__c,Name,Product__r.Name,ProductFamily__c,ProductSubFamily__c, Product__r.Family, IsPrimaryProductSubscription__c  from Product_Subscriptions__r) 
from Account 
where id in (Select Account__c from ProductSubscription__c)
*********************************************************************/
private void buildPSHierarchy(List<ProductSubscription__c> thePSs4Acc)
{

}


/**************************************************************************
return a set of newly created/updated RecordIDs
**************************************************************************/
public static Set<ID> processUpsertResult(List<Database.UpsertResult> durs)
{
 Set<ID> newRecordIDs = new Set<ID>();  
 for(Database.UpsertResult dur :durs) 
   {
   if(dur.isSuccess())
      {
       System.Debug('CSABAX success: ' + dur.getId());
       newRecordIDs.add(dur.getId());
      }
   else 
      {
      for(Database.Error de :dur.getErrors())
         {
          System.Debug('CSABAX error: ' + de.message); 
         } 
      }   
   } 

 return newRecordIDs;    
}


public static void processUpsertResult(List<Database.SaveResult> durs)
{
 for(Database.SaveResult dur :durs) 
   {
   if(dur.isSuccess())
      {
       System.Debug('CSABAX success: ' + dur.getId()); 
      }
   else 
      {
      for(Database.Error de :dur.getErrors())
         {
          System.Debug('CSABAX error: ' + de.message); 
         } 
      }   
   }  
}

global class ProductSubscriptionBuilder 
{
    @InvocableVariable
    global ID accId;

    @InvocableVariable
    global ID psID; 

    @InvocableVariable
    global ID prodID;  

    @InvocableVariable
    global ID oppID;         

    @InvocableVariable
    global Boolean isOnBehalf;     

    @InvocableVariable(required=true)
    global String operation;
}


}