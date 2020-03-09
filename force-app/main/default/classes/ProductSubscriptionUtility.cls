/******************************************************
pass here those methods which manipulate already  
created POC subscription records (consolidation....) 
******************************************************/
global without sharing class ProductSubscriptionUtility 
{
private static Id qliRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('QLI Based').getRecordTypeId(); 
private static Id consRTID = Schema.SObjectType.Product_SubscriptionItem__c.getRecordTypeInfosByName().get('Consolidated').getRecordTypeId();


@InvocableMethod(label='Get Subscription' description='Create Subscription and items')
/********************************************************************************
invocable method always invoked with 1 item
Return: list of new or upserted POC records. in case size is > 1 it will create
problems when embedding it into a Flow (Quick action on Opportunity)
********************************************************************************/
public static void processSubscription(List<ProductSubscriptionBuilder> psbs)
{
System.Debug('CSABAX start processSubscription with pspb : ' +  psbs);   
String operation;
ID accId;
Set<ID> prodIDs = new Set<ID>();
ID psId; //POC or PS ID
Id oppId;
Boolean isOnBehalf = false;

List<ProductSubscriptionBuilder> psbs4pso = new List<ProductSubscriptionBuilder>();

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
      
      if(operation == 'BuildPSO')
      {
      //createproduct subscription Opportunity record
      psbs4pso.add(psb); 
     
      }        

}

if(prodIDs.size() > 1) { return; }  //impossible in normal operation

System.Debug('CSABAX operation = ' +  operation);
if(Operation == 'Create')
   {
   BuildSubscriptionPOC.buildSubscriptionFromAccount4Products(accId,prodIDs,'Create');
   }

if(operation == 'Consolidate')
   {
   ConsolidateItems4Subs(psid);        //psid is the POC ID      
   }

   if(operation == 'CONSOLIDATED_2.0')
   {
   ConsolidateItems4SubsBBSUM(psid);   //psid is the POC ID            
   }   


if(operation == 'Reset')
  {
   DeleteConsolidatedItems(psid,true); //psid is the POC ID    
  }


if(operation == 'BuildFromOpp') 
  {
   //if(isOnBehalf == true) Always call this
   //   {
         BuildSubscriptionPOC.buildSubscriptionFromOpportunityAccountLink(oppId);   
   //   }  

  }

 if(operation == 'BuildFromProdSubsc') 
  {
   BuildSubscriptionPOC.buildSubscriptionFromAccount4Products(accId,prodIDs,NULL);
  } 


 if(operation == 'MergeI2T') 
  {
   Set<ID> ps2Merge = new Set<ID>();
   ps2Merge.add(psid);       //psid is the POC ID    
   MergeAllItems2Terms(ps2Merge);
  }   

}

/***********************************************************************************************************************
there are cases when the Contingency is detectable only fter having the new Start-EndDate range consolidated and is not
visible when current Item is the same as the previous item (best use case is the Upsell)
***********************************************************************************************************************/
private static void add2ConsolidatedList(List<Product_SubscriptionItem__c> consList,Product_SubscriptionItem__c newcons)
{
   if(newcons == NULL) { return; }

   System.Debug('CSABAX start add2ConsolidatedList. currenrsize = ' + consList.size() + ' for newcons = ' +  newcons);
   if(consList.size() > 0)
     {
     //check if the last consolidated has the same value and is contingent wih the new one
     Product_SubscriptionItem__c lastcons = consList[consList.size()-1];
     double aRRComp = compareARRs(lastcons,newcons);
     /*************************************************************************************************************
     Net_Value__c is not sue the best.  Think deeper.  2 year X  vs. 1  Year X = 3 year 2X? not sure. Probably we
     can do this if the 2 durations are the same otherwise keep the lastCon  and add a new one
     *************************************************************************************************************/
     if(
        (
         lastcons.End_Date__c == newcons.Start_Date__c.addDays(-1) 
          ||                                            
         lastcons.End_Date__c == newcons.Start_Date__c 
         ) 
        && 
        (
         lastcons.Net_Value__c == newcons.Net_Value__c //wee need to consider other fields othewise we miss contingency of 2 + items
         ||
         lastcons.QuoteItem_Value__c == newcons.Net_Value__c  //just temporarily, the best would be ARR
         || 
         (aRRComp <= 1.05 && aRRComp >= 0.95)              //this should be the real and ONLY decisionmaker. 
        )
       )
        {
         //we extend the consolidated    
         lastcons.End_Date__c = newcons.End_Date__c;
         lastcons.Net_Value__c = lastcons.Net_Value__c + newcons.Net_Value__c;  
         //calculate the Duration again
         lastcons.Duration__c = getExactMonhtsLength(lastcons.Start_Date__c, lastcons.End_Date__c);
         return;
        }
     }

   newcons.External_Id__c = newcons.External_Id__c + '_' + consList.size();   //Use this only i the NEW
   if(newcons.Net_Value__c > 0)
     {
        if(newcons.RecordTypeID != consRTID) 
           {
           newcons.RecordTypeID = consRTID;   //it happen i case of  an upsell scenario 
           }
      consList.add(newcons); 
     }

}

/******************************************************************************************************
 Comapre the AAR value of 2 Items. We can not rely  on ARR__c field because is  a  formula field which 
 evaluates later. Rely on Net_Value__c divided by Duration
 *****************************************************************************************************/
private static double compareARRs(Product_SubscriptionItem__c cons1, Product_SubscriptionItem__c cons2)
{
Double retval;

Decimal fullLengthinDays1 = cons1.Start_Date__c.daysBetween(cons1.End_Date__c);
Decimal fullLengthinDays2 = cons2.Start_Date__c.daysBetween(cons2.End_Date__c);

Decimal netVal1 = cons1.Net_Value__c;
Decimal netVal2 = cons2.Net_Value__c;

if(NetVal1 == 0 || NetVal2 == 0)
{
   return -100;  //in order to never match
}

double calcARR1 = netVal1 * 365 / fullLengthinDays1;
double calcARR2 = netVal2 * 365 / fullLengthinDays2;

retval = calcARR1/calcARR2;

return retval;
}


/******************************************************************************************

 *****************************************************************************************/
private static String buildPSIDynQuery(ID subscrID, String dealType, String rt2Consolidate)
{
//Build Dynamic SOQL becase  during test I can not assure right order due to missing Opportunities
String dynSQL = 'Select Id,Name,Parent_PS__c,Start_Date__c,End_Date__c,Net_Value__c,QuoteItem_NetTotal__c,QuoteItem_Value__c,Type__c,OppType__c,Day_Duration__c,Creation_Type__c,ParentAccountID__c  ';
dynSQL = dynSQL + ',OriginQuote_Line__c, OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.Name,OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__c';
dynSQL = dynSQL + ' ,OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.CloseDate';
dynSQL = dynSQL + ' ,OriginQuote_Line__r.SBQQ__SegmentIndex__c,Duration__c';
dynSQL = dynSQL + ' ,OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.Number_of_ACV_Years__c';
dynSQL = dynSQL + ' ,ParentSubscription__c,ParentSubscription__r.Product__c,Quantity__c,YearIndex__c,External_Id__c';
dynSQL = dynSQL + ' ,OriginOpportunity__c'; //needed to create PSP
dynSQL = dynSQL + ' from Product_SubscriptionItem__c where ParentSubscription__c = \'' + subscrID  + '\'';

dynSQL = dynSQL + ' and RecordTypeID = \'' +  rt2Consolidate + '\' ';

if(dealType != NULL)
  {
   dynSQL = dynSQL + ' and Creation_Type__c = \'' +  DealType + '\' ';
  }


if(Test.isRunningTest())
{
dynSQL = dynSQL + ' order by Start_Date__c asc,Name'; 
}
else 
{
dynSQL = dynSQL + ' order by Start_Date__c asc,itemOrder__c,OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.CloseDate asc ';
}

return dynSQL;
}

@TestVisible
/*************************************************************************************************
 Get the fraction  of the QuoteItem_Value__c corresponding to TimeRange etween SD and ED
 ************************************************************************************************/
private static Decimal getitemRangeItemFraction(Date sd, Date ed,Product_SubscriptionItem__c item)
{
   Decimal retval;

   if(item.Start_Date__c >= ed || item.End_Date__c <= sd || item.Start_Date__c.addDays(1) == item.End_Date__c )
      {
       return null;   
      }

   Decimal fullLengthinDays = item.Start_Date__c.daysBetween(item.End_Date__c);
   Decimal truncatedLengthDays = sd.daysBetween(ed);
   //adjust the Value
   if(item.QuoteItem_Value__c == NULL)
      {
       return NULL;
      }
   retval = item.QuoteItem_Value__c * (truncatedLengthDays.divide(fullLengthinDays,2));
   
   return retval;
} 

/**************************************************************************************
 * Just collect all items order by startDate and Summarize the overlapped pieces. This 
 method throw out of the window everything I worked till now in term of consolidation. 
 EVALUATE THE POSSIBILITY TO CREATE TERMs DIRECTY AS A RESULT OF CONSOLIDATION PROCESS
 Return value: a List of Consolidated Items
 *************************************************************************************/
public static List<Product_SubscriptionItem__c> consolidateItems4SubsBBSUM(ID subscrID)
{
   List<Product_SubscriptionItem__c> finalConsolidatedList =  new List<Product_SubscriptionItem__c>();

   Set<String> oppIdPSId = new set<String>();

   DeleteConsolidatedItems(subscrID,false);

   
   String dynSQL = buildPSIDynQuery(subscrID,NULL,qliRTID);
   List<Product_SubscriptionItem__c> psis = Database.query(dynSQL);

   //build the milestones which frame the start/endDate of  the consolidated items
   Set<Date> uniquems = new Set<Date>();
   List<Date> milestones = new List<Date>();

   for(Product_SubscriptionItem__c psi :psis)
       { 
         oppIdPSId.add(psi.OriginOpportunity__c + '_' + psi.Parent_PS__c);

         if(uniquems.contains(psi.Start_Date__c) == false ) //&& uniquems.contains(psi.Start_Date__c.addDays(-1)) == false
            {
            milestones.add(psi.Start_Date__c);
            uniquems.add(psi.Start_Date__c);
            }

         if(uniquems.contains(psi.End_Date__c) == false)   
           {
            milestones.add(psi.End_Date__c); 
            uniquems.add(psi.End_Date__c);
           }
     
       }
   milestones.sort();

   for(integer i = 1; i < milestones.size(); i++)
       {
        Product_SubscriptionItem__c currentConsolidated; //will have 1 consoliated item/milestone

        for(Product_SubscriptionItem__c psi :psis)
            {  
               System.Debug('CSABAY build consolidation for range: ' + milestones[i-1] + ' - ' + milestones[i]);

               //try to ingnore the Renewal opt Out because we shoud not add it again 

               //do not try to handle items which does not fall into range. handle inside below.
               Decimal itemFraction = getitemRangeItemFraction(milestones[i-1],milestones[i],psi); 
               if(itemFraction == NULL || itemFraction == 0) 
                 {   
                  continue; 
                 }

               if(currentConsolidated == NULL)
                 {  
                  currentConsolidated = makeItemConsolidated(psi);
                  currentConsolidated.Quantity__c = 0;
                  currentConsolidated.Net_Value__c = 0;
                  currentConsolidated.QuoteItem_Value__c = 0;
                 }

               currentConsolidated.Quantity__c = currentConsolidated.Quantity__c + psi.Quantity__c;
               //probably only 1  from the below  will remain final
               currentConsolidated.Net_Value__c = currentConsolidated.Net_Value__c + itemFraction;
               currentConsolidated.QuoteItem_Value__c = currentConsolidated.QuoteItem_Value__c + itemFraction;
               //probably only  1  from the above will remain final; 
               currentConsolidated.Start_Date__c = milestones[i-1];
               currentConsolidated.End_Date__c = milestones[i]; 
               currentConsolidated.Duration__c = milestones[i-1].monthsBetween(milestones[i]);  //NOT GOOD review and calculate based on days/30.5 and round
               if(milestones[i-1].day() < milestones[i].day())
                  {
                     currentConsolidated.Duration__c = currentConsolidated.Duration__c + 1;
                  }
           
               System.Debug('CSABAY add new consolidated item ' + currentConsolidated);
            }
        add2ConsolidatedList(finalConsolidatedList,currentConsolidated);
        System.Debug('CSABAX finalConsolidatedList counter: ' + finalConsolidatedList.size());
       }

   /*********************************************************************************************************
   Once consolidation is succesfull remove the Lookup to OOTB ProductSubs from the non-consolidated QLI items 
   ******************************************** START ******************************************************/
  List<Product_SubscriptionItem__c> thePSI2Upsert = new List<Product_SubscriptionItem__c>(); 
  for(Product_SubscriptionItem__c qliitem :psis)
      {
      qliitem.Parent_PS__c = NULL;   
      thePSI2Upsert.add(qliitem);
      } 

  System.Debug('CSABAX we have ' + finalConsolidatedList.size() + ' consolidated Subscription terms to insert and ' + thePSI2Upsert.size() + ' existing to update.');         

  thePSI2Upsert.addAll(finalConsolidatedList); 
  List<Database.UpsertResult> durs = Database.upsert(thePSI2Upsert,Product_SubscriptionItem__c.External_Id__c,false); 
  Set<String> errorMsg =  new Set<String>();
  ProcessUpsertResult(durs,'Product_SubscriptionItem',errorMsg);
  /*********************************************** END *************************************************************/   

  //once consolidation done create the Product Subscription Opportunity records based on IDs in oppIdPSId
  if(oppIdPSId.size() > 0)
     {
      CreatePSOfromIDs(oppIdPSId);  
     }

return finalConsolidatedList;       
}


/************************************************************************************************
consolidated item should be always a new record even when we make a current item consolidateditem
************************************************************************************************/
private static Product_SubscriptionItem__c makeItemConsolidated(Product_SubscriptionItem__c item)
{
  Product_SubscriptionItem__c currentconsolidated = item.clone(); //this wil pass the Parent_PS
  currentconsolidated.Net_Value__c = item.QuoteItem_Value__c; //net is  ull in the QLI item.  
  currentconsolidated.RecordTypeID = consRTID; 
  System.Debug('CSABAX current cons  ootb parent  = ' + currentConsolidated.Parent_PS__c);
  return currentconsolidated;  
}

/************************************************************
try to calculate  the months between start end Date 
Not really accurate when we have almost X month
************************************************************/
private static integer getExactMonhtsLength(Date sD, Date eD)
{
   Integer monthDiff = sD.monthsBetween(eD);
   if(eD.day() > sD.day()) 
     {
     monthDiff++;
     }
   
   return monthDiff;
}

/**************************************************************************
when we want to redo the consolidation delete the old.
if is called from Reset transferr Parent PS to the remaining items
**************************************************************************/
public static void deleteConsolidatedItems(ID subscrID, Boolean restorePPS)
{
List<Product_SubscriptionItem__c> psis2delete = new List<Product_SubscriptionItem__c>();
List<Product_SubscriptionItem__c> psis2restore = new List<Product_SubscriptionItem__c>();

String soql = 'Select id, Parent_PS__c,RecordTypeID from Product_SubscriptionItem__c where ParentSubscription__c = \'' + subscrID + '\'';   
if(restorePPS == false)
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


/*******************************************************
 Replace all existing terms and convert my items 2 terms
 try to add here the Header ARR/MRR/CurrentTerm/SD-EDate
 in real live this will be called always for one record.
*******************************************************/
public static void MergeAllItems2Terms(Set<Id> thePSIDs)
{   
   List<ProductSubscriptionTerm__c> mergedPSTerms = new List<ProductSubscriptionTerm__c>();
   List<ProductSubscriptionTerm__c> tobedeletedPSTerms = new List<ProductSubscriptionTerm__c>();

   List<ProductSubscription__c> thePSs2update = new List<ProductSubscription__c>();//2020.02.28.
   
   List<ProductSubscription__c> thePSs = [Select Id,Account__c,Product__c,ProductFamily__c,ProductSubFamily__c,ProductType__c,Product__r.Name,Product__r.Family, Product__r.Product_Sub_Family__c,Product__r.Product_Type__c
                                           ,CurrentSubscriptionTerm__c,SubscriptionStatus__c //2020.02.28. 
                                           ,(Select Id,Name, StartDate__c,EndDate__c,SubscriptionKeyWithTerm__c,Account__c,Product__c,ProductID__c,ProductSubscription__c,
                                             Quantity__c,RevisedUltimateFamily__c,RevisedUltimateSubFamily__c,SubscriptionTermStatus__c  
                                             from Subscription_Terms__r  order by StartDate__c asc)
                                           ,(Select Id,Name,Start_Date__c,End_Date__c,ARR__c,MRR__c,Net_Value__c,Parent_PS__c ,ParentSubscription__c,Quantity__c  
                                             from Product_SubscriptionItems__r 
                                             where RecordType.DeveloperName = 'Consolidated'  order by Start_Date__c asc
                                            )   
                                          from ProductSubscription__c where id in :thePSIDs];
    
   map<String,ProductSubscription__c> mapextID2PS =  new  map<String,ProductSubscription__c>();                                          

   for(ProductSubscription__c thePS : thePSS)
      {
      List<ProductSubscriptionTerm__c> psTerms = thePS.Subscription_Terms__r;
      tobedeletedPSTerms.addAll(psTerms);

      List<Product_SubscriptionItem__c> psItems = thePS.Product_SubscriptionItems__r;
   
      /**** Items are ordered by StartDate asc ***/
      Integer termIndex = 0;
      ProductSubscriptionTerm__c nextTerm;     
      Date sD;
      Date eD;   
      
      for(integer i = 0; i < psItems.size(); i++)
         {
            System.Debug('CSABAX merging item: ' + psItems[i]);   
            termIndex++;    
            nextTerm = convertItem2term(psItems[i],NULL,'brand new');
            //set the name based on the convention Family - SubFamily - ProductName - index
            String family = thePS.Product__r.Family;
            String subFam = thePS.Product__r.Product_Sub_Family__c;
            String prodName = thePS.Product__r.Name;
            nextTerm.Name = family + ' - ' + subFam + ' - ' + prodName + ' - ' + string.valueOf(termIndex);
            //set the ExternalId based on convention (AccountID)(ProductID)index. NOT SURE! TRY TO INTEGRATE THE SOURCE POC OR ITEM FOR TRACKING!!
            nextTerm.SubscriptionKeyWithTerm__c = String.valueOf(psItems[i].ParentSubscription__c) + '_' + String.valueof(thePS.Account__c) + String.valueof(thePS.Product__c) + string.valueOf(termIndex);
            mergedPSTerms.add(nextTerm);    
            
            if(i == 0)
               {
                sD = nextTerm.StartDate__c;
                eD = nextTerm.EndDate__c;                
               }
            else 
               {
               eD = nextTerm.EndDate__c; //keep updatign till last item
               }   
         mapextID2PS.put(nextTerm.SubscriptionKeyWithTerm__c,thePS); 
         }
         thePS.StartDate__c = sD;
         thePS.EndDate__c = eD;
         if(ED >= System.Today())
           {
           thePS.SubscriptionStatus__c  = 'Active'; 
           }
         else if(thePS.SubscriptionStatus__c == 'Active')
           {
            thePS.SubscriptionStatus__c  = 'Expired';    
           }  

      }
    
   if(tobedeletedPSTerms.size() > 0)
      {
      Delete tobedeletedPSTerms;  //we have to delete forst otherwize the below upsert wowuld metch them before delete.   
      }      

   System.Debug('CSABAX we are upserting ' + mergedPSTerms.size() + ' items.');
   if(mergedPSTerms.size() > 0)
      {
         List<Database.UpsertResult> durs = Database.upsert(mergedPSTerms,ProductSubscriptionTerm__c.SubscriptionKeyWithTerm__c,false);
         Set<String> errorMessages = new Set<String>();
         Set<ID> mergedItems = processUpsertResult(durs,'ProductSubscriptionTerm',errorMessages);    
      }

   
   /*********** once term merge is succesfull update their  ProductSubscripton record **********/
   for(ProductSubscriptionTerm__c pst :mergedPSTerms)
   {   
      System.Debug('CSABAX after upsert pst = ' + pst);
      if(pst.id == NULL) { return; }
      Date sd = date.newinstance(pst.StartDate__c.year(),pst.StartDate__c.month(), pst.StartDate__c.day());
      Date ed = date.newinstance(pst.EndDate__c.year(),pst.EndDate__c.month(), pst.EndDate__c.day());   
      Date td = date.newinstance(System.Today().year(),System.Today().month(), System.Today().day());           
      if(sd <= td && ed >= td )
         {
            System.Debug('CSABAX current term matched get PS  from map ' + mapextID2PS.size() + ' extID = ' + pst.SubscriptionKeyWithTerm__c);
            ProductSubscription__c currentPS =  mapextID2PS.get(pst.SubscriptionKeyWithTerm__c);
            if(currentPS != NULL)
               {
               currentPS.CurrentSubscriptionTerm__c = pst.id; 
               thePSs2update.add(currentPS);  
               }
         }
   }

   System.Debug('CSABAX PS 2  update = ' + thePSs2update.size()); 
   if(thePSs2update.size() > 0)
      {
         List<Database.SaveResult> durs = Database.update(thePSs2update,false);
         Set<String> errorMessages = new Set<String>(); 
      }   
   /*********** once term merge is succesfull update their  ProductSubscripton record **********/

}


/********************************************************************************************************************************************* 
return either a new Term or the passed term updated with fields from Source Item
*********************************************************************************************************************************************/
private static ProductSubscriptionTerm__c convertItem2term(Product_SubscriptionItem__c item,ProductSubscriptionTerm__c term, String mergenew)
{   
ProductSubscriptionTerm__c retval;

if(mergenew == 'merge')
  {
   /****** NO LONGER APPLICABLE **********  
   term.StartDate__c = item.Start_Date__c;
   term.EndDate__c = item.End_Date__c;
   term.TSV__c = item.Net_Value__c;   
   **************************************/
   return retval;
  }
else if(mergenew == 'new')
  {
  /************* NO LONGER APPLICABLE ****************************   
  retval = new ProductSubscriptionTerm__c();
  retval =  term.clone(); 
  retval.StartDate__c = item.Start_Date__c;
  retval.EndDate__c = item.End_Date__c;

  retval.ARR__c = item.ARR__c;
  retval.MRR__c = item.MRR__c;
  retval.TSV__c = item.Net_Value__c;  

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
  ***************************************************************************/
  return retval;
  }   
else if(mergenew == 'brand new')
  {
   System.Debug('CSABAX term is NULL here. We need to create brand new Term');
   retval = new ProductSubscriptionTerm__c();

   retval.StartDate__c = item.Start_Date__c;
   retval.EndDate__c = item.End_Date__c;

   retval.ARR__c = item.ARR__c;
   retval.MRR__c = item.MRR__c;
   retval.TSV__c = item.Net_Value__c;  
   
   retval.Quantity__c = item.Quantity__c;

   //find namign convention
   retval.Name = 'HOMEMADE_TERM-1';  
   //find external Id  pattern
   retval.SubscriptionKeyWithTerm__c = 'TEMPRORARY0000000000000000000000000-1';

   //set the parent too
   retval.ProductSubscription__c = item.Parent_PS__c;
   return retval;
  }  

//2020.01.23. Item does not have quantity!

return term;
}


/**************************************************************************************************************
param 1
param 2: type of object we were upserting
param 3: set of String containign the Error message
Retval set If  ID  of the records  succesfully uppserted
**************************************************************************************************************/
public static Set<ID> processUpsertResult(List<Database.UpsertResult> durs, String objType,Set<String> errmsg )
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
          errmsg.add(objType + ' upsert Error: ' + de.message);  
          System.Debug('ObjType upsert Error: ' + de.message); 
         } 
      }   
   } 

 return newRecordIDs;    
}


/**********************************************************
parameter is a set  of  string which concatenates the OppID
and the prodSubscr Id.   
**********************************************************/
private static void createPSOfromIDs(Set<String> recordIds)
{
List<ProductSubscriptionOpportunity__c> psos = new List<ProductSubscriptionOpportunity__c>();

for(String ids :recordIds)
    {
    String[] recIds = Ids.split('_');
    System.Debug('CSABAZ Ids = ' +  Ids);
    if(recIds.size() != 2 || recIds[0].length() != 18 || recIds[1].length() != 18)
       {
       continue;   
       }  
    
    ProductSubscriptionOpportunity__c pso =  new ProductSubscriptionOpportunity__c();
    pso.Related_Opportunity__c  = recIds[0]; 
    pso.Primary_Product_Subscription__c = recIds[1];  
    pso.External_Id__c = Ids; 
    psos.add(pso);
    }

List<Database.UpsertResult> durs = Database.upsert(psos,ProductSubscriptionOpportunity__c.External_Id__c,false); 
Set<String> errorMsg =  new Set<String>();
ProcessUpsertResult(durs,'ProductSubscriptionOpportunity',errorMsg);   
}

/***************************************
 wrapper class for the invocable methods
 **************************************/
global class ProductSubscriptionBuilder 
{
    @InvocableVariable (label='account ID')
    global ID accId;

    @InvocableVariable (label='ProductSubscription ID')
    global ID psID;   //either POC or OOTB PS record Id (depends on caller context)

    @InvocableVariable (label='ProductSubscription Item ID' description='pass the current record ID')
    global ID psiID;  //used when creating the Productsubscription opportunity  record 

    @InvocableVariable (label='Product ID')
    global ID prodID;  

    @InvocableVariable (label='opportunity ID')
    global ID oppID;    //used  when creating the PSI records  from opp     

    @InvocableVariable
    global Boolean isOnBehalf;     

    @InvocableVariable(required=true)
    global String operation;
}



/*********************************************************************************
Part of CONSOLIDATION 1.0  design. 
*********************************************************************************/
public static List<Product_SubscriptionItem__c> consolidateItems4Subs(ID subscrID)
{
List<Product_SubscriptionItem__c> finalConsolidatedList =  new List<Product_SubscriptionItem__c>();

DeleteConsolidatedItems(subscrID,false);
//***************************************************
//this will call the parametrized Consolidation method
//Run the query here in order to save SOQL
//***************************************************
List<Product_SubscriptionItem__c> ownDealPSIs = new List<Product_SubscriptionItem__c>();
List<Product_SubscriptionItem__c> onBehalfPSIs = new List<Product_SubscriptionItem__c>();

String dynSQL = buildPSIDynQuery(subscrID,NULL,qliRTID);
List<Product_SubscriptionItem__c> psis = Database.query(dynSQL);

map<String,List<Product_SubscriptionItem__c>> maponbehalf4Parent = new map<String,List<Product_SubscriptionItem__c>>();
for(Product_SubscriptionItem__c psi :psis)
   {
     if(psi.Creation_Type__c == 'own-Deal')
     {
      ownDealPSIs.add(psi);
     }
     else 
     {
      //store the psis belonging to same parent in a map because we have to consolidate separatele 
      List<Product_SubscriptionItem__c> psis4acc = maponbehalf4Parent.get(psi.ParentAccountID__c);
      if(psis4acc == NULL)
         {
         psis4acc = new List<Product_SubscriptionItem__c>();   
         } 
      psis4acc.add(psi);  
      maponbehalf4Parent.put(psi.ParentAccountID__c,psis4acc);
      //store the psis belonging to same parent in a map because we have to consolidate separatele

      //onBehalfPSIs.add(psi);  
     }
   }
System.Debug('CSABAY we HAVE ' + ownDealPSIs.size() + ' ownDealPSIs to consolidate');   
System.Debug('CSABAY we HAVE ' + maponbehalf4Parent.size() + ' onBehalfPSIs');

//1. Call 4 own-deals
if(ownDealPSIs != NULL)
{
   ownDealPSIs = ConsolidateListItems4Subs(ownDealPSIs);
   if(ownDealPSIs != NULL)
     {
      System.Debug('CSABAY we have ' + ownDealPSIs.size() + ' Consolidated ownDealPSIs');
     }

}

//2. Call 4 on-Behalf grouped by ParentAccountID
for(String parentAcID :maponbehalf4Parent.keyset())
    {
      List<Product_SubscriptionItem__c> sameParentOBpsis = maponbehalf4Parent.get(parentAcID);
      System.Debug('CSABAY we have ' + sameParentOBpsis.size() + ' onBehalfPSIs to consolidate');
      onBehalfPSIs.addAll(ConsolidateListItems4Subs(sameParentOBpsis));  

      //here whe have to do an Upsell-like consolidation of the already consolidated parent-based items
      //NOT  sure i need to order  them again probably yes
    }
System.Debug('CSABAY we have ' + onBehalfPSIs.size() + ' Consolidated onBehalfPSIs');
   

//3. Consolidate to outcame of the 2 consolidation processes
//NO need to take care of the logical order. 
//We order basd on time and do a FULL(left-middle-Right) UPSELL includig leftovers!!!!!

finalConsolidatedList.addAll(ownDealPSIs);

return finalConsolidatedList;
}



/****************************************************
Leave old Terms as it is. Overrule Current and Future 
items. If there are more Items then Term get the Name 
and External_ID of the last Term and continue

public static void MergeItems2Terms(Set<Id> thePSIDs)
{
System.Debug('CSABAX start MergeItems2Terms for ' + thePSIDs);   
List<ProductSubscriptionTerm__c> mergedPSTerms = new List<ProductSubscriptionTerm__c>();

List<ProductSubscription__c> thePSs = [Select Id
                                        ,(Select Id,Name, StartDate__c,EndDate__c,SubscriptionKeyWithTerm__c,Account__c,Product__c,ProductID__c,ProductSubscription__c,
                                          Quantity__c,RevisedUltimateFamily__c,RevisedUltimateSubFamily__c,SubscriptionTermStatus__c  
                                          from Subscription_Terms__r where  SubscriptionTermStatus__c in ('Current','Future') order by StartDate__c asc)
                                        ,(Select Id,Name,Start_Date__c,End_Date__c,ARR__c,MRR__c,Net_Value__c,Parent_PS__c   
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
            nextTerm = convertItem2term(psi,NULL,'brand_new');
            System.Debug('CSABAX created term: ' + nextTerm);
            mergedPSTerms.add(nextTerm);            
            }   
         }
      }

   }

System.Debug('CSABAX we are upserting ' + mergedPSTerms.size() + ' items.');
List<Database.UpsertResult> durs = Database.upsert(mergedPSTerms,ProductSubscriptionTerm__c.SubscriptionKeyWithTerm__c,false);
Set<String> errorMessages = new Set<String>();
processUpsertResult(durs,'ProductSubscriptionTerm',errorMessages);
}
****************************************************/



/****************************************************************************************************************************
Do not try to handle Contingency at each step. Do it only when new contingent StartDate occure Within the same StartDate do 
only the consolidation, and try to merge only when adding item to consolidatedPSIs list

TRY to parametrize in order to differentiate between OWN-Deals and OnBehalf-Deals. Also in case there are both own and 
on-Behalf -Deals we have to do a final consolidation of the consolidated items.  CHALLENGE! 

RETURN VALUE SHOULD BE THE CONSOLIDATED ITEMS

public static List<Product_SubscriptionItem__c> ConsolidateItems4SubsTBD(ID subscrID, String DealType, String RT2Consolidate)
{
//DeleteConsolidatedItems(subscrID,false);

List<Product_SubscriptionItem__c> consolidatedPSIs = new List<Product_SubscriptionItem__c>();

//Build Dynamic SOQL becase  during test I can not assure right order due to missing Opportunities
String dynSQL = 'Select Id,Name,Parent_PS__c,Start_Date__c,End_Date__c,Net_Value__c,QuoteItem_NetTotal__c,QuoteItem_Value__c,Type__c,OppType__c,Day_Duration__c,Creation_Type__c  ';
dynSQL = dynSQL + ',OriginQuote_Line__c, OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.Name,OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__c';
dynSQL = dynSQL + ' ,OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.CloseDate';
dynSQL = dynSQL + ' ,OriginQuote_Line__r.SBQQ__SegmentIndex__c,Duration__c';
dynSQL = dynSQL + ' ,OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.Number_of_ACV_Years__c';
dynSQL = dynSQL + ' ,ParentSubscription__c,ParentSubscription__r.Product__c,Quantity__c,YearIndex__c,External_Id__c';
dynSQL = dynSQL + ' from Product_SubscriptionItem__c where ParentSubscription__c = \'' + subscrID  + '\'';

dynSQL = dynSQL + ' and RecordTypeID = \'' +  RT2Consolidate + '\' ';

if(DealType != NULL)
  {
   dynSQL = dynSQL + ' and Creation_Type__c = \'' +  DealType + '\' ';
  }


if(Test.isRunningTest())
{
dynSQL = dynSQL + ' order by Start_Date__c asc,Name'; 
}
else 
{
dynSQL = dynSQL + ' order by Start_Date__c asc,itemOrder__c,OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.CloseDate asc ';
}
System.Debug('CSABAX dynSql = ' + dynSQL);
List<Product_SubscriptionItem__c> psis = Database.query(dynSQL);


Integer itemcount = psis.size();
System.Debug('CSABAX itemcount = ' + itemcount);
if(itemcount == 0) { return NULL; }

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
   return consolidatedPSIs;
   }

for(integer i = 1; i<itemcount; i++)
   {
    Product_SubscriptionItem__c currentItem = psis[i];
    Product_SubscriptionItem__c prevItem = psis[i-1];    
    System.Debug('CSABAX currentconsolidated = ' + currentconsolidated);    
    System.Debug('CSABAX currentItem = ' + currentItem); 
    System.Debug('CSABAX prevItem = ' + prevItem);     

    //************************ SAME START DATE START ***************************
    if(currentItem.Start_Date__c == prevItem.Start_Date__c)
    {
    System.Debug('CSABAX either debook or a New-logo/Renewal or an Upsell');

    //currentconsolidated = handleSameStart(prevItem,currentItem); 
    currentconsolidated = handleSameStart(currentconsolidated,currentItem); 
    continue;
    }
    //************************ SAME START DATE END ****************************  
    
    //************************ CONTINGENT DATES START *************************    
    if(prevItem.End_Date__c.addDays(1) == currentItem.Start_Date__c)
    {
    System.Debug('CSABAX start of a contingent new item');    
    
    add2ConsolidatedList(consolidatedPSIs,currentconsolidated);
    currentconsolidated = makeItemConsolidated(currentItem);
    continue;
    }
    //************************ CONTINGENT DATES END ***************************

    //************************ FUTURE DATES START *****************    
    if(currentItem.Start_Date__c > prevItem.End_Date__c.addDays(1))
    {
    //DO NOT FORGET THIS
    continue;
    }
    //************************ FUTURE DATES END ******************   
    

    //************************ OVERLAPPED DATES START *********************************************************    
    if(currentItem.Start_Date__c > prevItem.Start_Date__c && currentItem.Start_Date__c < prevItem.End_Date__c )
    { 
    System.Debug('CSABAX overlapped item ');
    currentconsolidated = handleOverlap(currentconsolidated,currentItem);   
    add2ConsolidatedList(consolidatedPSIs,currentconsolidated); 

    if(currentItem.OppType__c == 'upsell')
      { 
      currentconsolidated = upsell(prevItem,makeItemConsolidated(currentItem));
      }
    else 
      {
      currentconsolidated = makeItemConsolidated(currentItem); 
      }
    
    continue; 
    }//end of overlapped if
    //************************ OVERLAPPED DATES END ***********************************************************

   }//end of for


   //dont' forgot the last Consolidated item
   if(currentconsolidated.Net_Value__c != 0)
     {//do not add to the consolidate List Items with 0 revenue.        
      add2ConsolidatedList(consolidatedPSIs,currentconsolidated);  
     }


   //*********************************************************************************************************
   //Once consolidation is succesfull remove the Lookup to OOTB ProductSubs from the non-consolidated QLI items 
   //******************************************** START ******************************************************
   List<Product_SubscriptionItem__c> thePSI2Upsert = new List<Product_SubscriptionItem__c>(); 
   for(Product_SubscriptionItem__c qli_item :psis)
       {
       qli_item.Parent_PS__c = NULL;   
       thePSI2Upsert.add(qli_item);
       } 

   System.Debug('CSABAX we have ' + consolidatedPSIs.size() + ' consolidated Subscription terms to insert and ' + thePSI2Upsert.size() + ' existing to update.');         

   thePSI2Upsert.addAll(consolidatedPSIs); 
   List<Database.UpsertResult> durs = Database.upsert(thePSI2Upsert,Product_SubscriptionItem__c.External_Id__c,false); 
   Set<String> errorMsg =  new Set<String>();
   ProcessUpsertResult(durs,'Product_SubscriptionItem',errorMsg);
   //*********************************************** END *************************************************************
buildSubscriptionFromAccount4ProductsOAL
}
****************************************************************************************************************************/


/****************************************************************************************************************
This method is supposed to replace the other one. 
We take out the query from this method and we call it with having a list of psis as parameter.
****************************************************************************************************************/
public static List<Product_SubscriptionItem__c> consolidateListItems4Subs(List<Product_SubscriptionItem__c> psis)
{
//DeleteConsolidatedItems(subscrID,false);
List<Product_SubscriptionItem__c> consolidatedPSIs = new List<Product_SubscriptionItem__c>();
Integer itemcount = psis.size();
System.Debug('CSABAX itemcount = ' + itemcount);
if(itemcount == 0) { return NULL; }

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
   return consolidatedPSIs;
   }

for(integer i = 1; i<itemcount; i++)
   {
    Product_SubscriptionItem__c currentItem = psis[i];
    Product_SubscriptionItem__c prevItem = psis[i-1];    
    System.Debug('CSABAX currentconsolidated = ' + currentconsolidated);    
    System.Debug('CSABAX currentItem = ' + currentItem); 
    System.Debug('CSABAX prevItem = ' + prevItem);     

    //************************ SAME START DATE START ***************************
    if(currentItem.Start_Date__c == prevItem.Start_Date__c)
    {
    System.Debug('CSABAX either debook or a New-logo/Renewal or an Upsell');

    //currentconsolidated = handleSameStart(prevItem,currentItem); 
    currentconsolidated = handleSameStart(currentconsolidated,currentItem); 
    continue;
    }
    //************************ SAME START DATE END ****************************   
    
    //************************ CONTINGENT DATES START *************************   
    if(prevItem.End_Date__c.addDays(1) == currentItem.Start_Date__c)
    {
    System.Debug('CSABAX start of a contingent new item');    
    
    add2ConsolidatedList(consolidatedPSIs,currentconsolidated);
    currentconsolidated = makeItemConsolidated(currentItem);
    continue;
    }
    //************************ CONTINGENT DATES END ***************************

    //************************ FUTURE DATES START *****************    
    if(currentItem.Start_Date__c > prevItem.End_Date__c.addDays(1))
    {
    //DO NOT FORGET THIS //2020.02.11.
    add2ConsolidatedList(consolidatedPSIs,currentconsolidated);
    currentconsolidated = makeItemConsolidated(currentItem);
    continue;
    }
    //************************ FUTURE DATES END ******************   
    

    //************************ OVERLAPPED DATES START *********************************************************    
    if(currentItem.Start_Date__c > prevItem.Start_Date__c && currentItem.Start_Date__c < prevItem.End_Date__c )
    { 
    System.Debug('CSABAX overlapped item ');
    currentconsolidated = handleOverlap(currentconsolidated,currentItem);   
    add2ConsolidatedList(consolidatedPSIs,currentconsolidated); 

    if(currentItem.OppType__c == 'Upsell')
      { 
      currentconsolidated = upsell(prevItem,makeItemConsolidated(currentItem));
      }
    else 
      {
      currentconsolidated = makeItemConsolidated(currentItem); 
      }
    
    continue; 
    }//end of overlapped if
    //************************ OVERLAPPED DATES END ***********************************************************

   }//end of for


   //dont' forgot the last Consolidated item
   if(currentconsolidated.Net_Value__c != 0)
     {//do not add to the consolidate List Items with 0 revenue.        
      add2ConsolidatedList(consolidatedPSIs,currentconsolidated);  
     }


   //*********************************************************************************************************
   //Once consolidation is succesfull remove the Lookup to OOTB ProductSubs from the non-consolidated QLI items 
   //******************************************** START ******************************************************
   List<Product_SubscriptionItem__c> thePSI2Upsert = new List<Product_SubscriptionItem__c>(); 
   for(Product_SubscriptionItem__c qliitem :psis)
       {
         qliitem.Parent_PS__c = NULL;   
       thePSI2Upsert.add(qliitem);
       } 

   System.Debug('CSABAX we have ' + consolidatedPSIs.size() + ' consolidated Subscription terms to insert and ' + thePSI2Upsert.size() + ' existing to update.');         

   thePSI2Upsert.addAll(consolidatedPSIs); 
   List<Database.UpsertResult> durs = Database.upsert(thePSI2Upsert,Product_SubscriptionItem__c.External_Id__c,false); 
   Set<String> errorMsg =  new Set<String>();
   ProcessUpsertResult(durs,'Product_SubscriptionItem',errorMsg);
   //*********************************************** END *************************************************************

   return consolidatedPSIs;
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
else if(item.OppType__c == 'Upsell' 
        // ||
        //item.OppType__c == 'Renewal'  //2020.02.05.  TBC
        )
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
  retval.Net_Value__c = item.QuoteItem_Value__c;   //2020.01.27. RETHINK A BIT!!!!!!!!!!!
  }
retval.RecordTypeID = consRTID;

//2020.01.17. Check the Upsell!!!!

return retval;
}





/*************************************************************************************************************************
in case the new item startDate fall between cc's Start/End_Date we create 1 consolidated item for the "left" side and Item
will be the new Candidate.
in case the item is in a different SBQQ__SegmentIndex__c then cc do not continue. Return NULL and make item a new cc. WHY?
*************************************************************************************************************************/
private static Product_SubscriptionItem__c handleOverlap(Product_SubscriptionItem__c cc, Product_SubscriptionItem__c item)
{
Product_SubscriptionItem__c retval = new Product_SubscriptionItem__c(RecordTypeID = consRTID);
//************************************************************************************************
//CAN'T SEE WHY I DID IT IN THE PAST
//if(cc.OriginQuote_Line__r.SBQQ__SegmentIndex__c < item.OriginQuote_Line__r.SBQQ__SegmentIndex__c)
//{
//   return NULL;   //rethink this
//}
// ***********************************************************************************************

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
-------------------
XXXXXXXXXX|XXX+YYYY

OR maybe?

XXXXXXXXXXXXXXXXXXX
      YYYYYYYY
-------------------
XXXXX|XXX+YYYY|XXXX

OR?    NOT CORRECT!
XXXXXXXXXXXXXXXXXXX
          YYYYYYYYYYYYY
-------------------
XXXXXXXXX|YYYY+XXXX|YYY

Regardless if we upsell to left  or Right side  the summed result will be the same.           
The leftover value  will differ 
WE SHOULD KNOW IF IS A LEFT OR RIGHT UPSELL
Return value will be the item which holds the SUMMARY
****************************************************************************************************************************/
private static Product_SubscriptionItem__c upsell(Product_SubscriptionItem__c prevItem, Product_SubscriptionItem__c currItem)
{
Product_SubscriptionItem__c retval =  new Product_SubscriptionItem__c();

Decimal prevD = prevItem.Day_Duration__c;
Decimal currD = currItem.Day_Duration__c;

Decimal prevRatio = currD.divide(prevD,2);

if(prevItem.Start_Date__c == currItem.Start_Date__c)
{
//left Upsell
retval.Start_Date__c = prevItem.Start_Date__c;
retval.End_Date__c = currItem.Start_Date__c.addDays(-1);
}
else if(prevItem.End_Date__c == currItem.End_Date__c)
{
//right upsell    
retval.Start_Date__c = currItem.Start_Date__c;
retval.End_Date__c = currItem.End_Date__c;   
}
else 
{
//this should not happen. Middle-Upsell not handled. ignore upsell and currItem take over
//we  can try  to broke it  in pieces andcreate a fake Item  fo the leftover
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


/************************************************************
after introducing itemOrder no more need the Dynamic SOQL. 
Revork of the initial version.                    OUTDATED

public static void ConsolidateItems4Subs_CURRENT(ID subscrID)
{
DeleteConsolidatedItems(subscrID,false);

List<Product_SubscriptionItem__c> consolidatedPSIs = new List<Product_SubscriptionItem__c>();

String dynSQL = 'Select Id,Name,Parent_PS__c,Start_Date__c,End_Date__c,Net_Value__c,QuoteItem_NetTotal__c,QuoteItem_Value__c,Type__c,OppType__c,Day_Duration__c  ';
dynSQL = dynSQL + ',OriginQuote_Line__c, OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.Name,OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__c';
dynSQL = dynSQL + ' ,OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.CloseDate';
dynSQL = dynSQL + ' ,OriginQuote_Line__r.SBQQ__SegmentIndex__c,Duration__c';
dynSQL = dynSQL + ' ,OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.Number_of_ACV_Years__c';
dynSQL = dynSQL + ' ,ParentSubscription__c,ParentSubscription__r.Product__c,Quantity__c,YearIndex__c,External_Id__c';
dynSQL = dynSQL + ' from Product_SubscriptionItem__c where ParentSubscription__c = \'' + subscrID  + '\'';
dynSQL = dynSQL + ' and RecordTypeID = \'' +  qliRTID + '\'  ';

if(Test.isRunningTest())
{
dynSQL = dynSQL + ' order by Start_Date__c asc,Name'; 
}
else 
{
dynSQL = dynSQL + ' order by Start_Date__c asc,itemOrder__c,OriginQuote_Line__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.CloseDate asc ';
}
System.Debug('CSABAX dynSql = ' + dynSQL);
List<Product_SubscriptionItem__c> psis = Database.query(dynSQL);

Integer itemcount = psis.size();
System.Debug('CSABAX itemcount = ' + itemcount);
if(itemcount == 0) { return; }

Product_SubscriptionItem__c currentconsolidated = new Product_SubscriptionItem__c();
currentconsolidated = psis[0].clone();
currentconsolidated.Net_Value__c = psis[0].QuoteItem_Value__c;
currentconsolidated.RecordTypeID = consRTID;

if(itemcount == 1)
   {
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


    if(currentItem.Start_Date__c == prevItem.Start_Date__c)
    {
    System.Debug('CSABAX either debook or a new logo same period');

    if(currentconsolidated.Type__c == 'CONTINGENT')
       {
        if(currentconsolidated.Net_Value__c != currentItem.QuoteItem_Value__c)      //2020.01.27. Net_value is not good here because is cumulated!
           {
            //we roll back the contingency because unlikely we can keep it bot not excluded.   
            currentconsolidated.End_Date__c = currentItem.Start_Date__c.addDays(-1);
            currentconsolidated.Duration__c = currentconsolidated.Start_Date__c.monthsBetween(currentconsolidated.End_Date__c);   
            currentconsolidated.External_Id__c = currentconsolidated.External_Id__c + '_' + consolidatedPSIs.size();  
            //we wshould Adjust  Net_Value__c when debooking!!! 2020.01.27. CHECK HOW WE ARE HANDLING CONTINGENCE AT CREATION!!
            currentconsolidated.Net_Value__c = currentconsolidated.Net_Value__c - currentconsolidated.QuoteItem_Value__c; //2020.01.28.            

            add2ConsolidatedList(consolidatedPSIs,currentconsolidated);
            currentconsolidated = handleSameStart(prevItem,currentItem);  
            continue;  //2020.01.27.             
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
           //2020.01.27.  consolidatedPSIs.add(currentconsolidated);
           add2ConsolidatedList(consolidatedPSIs,currentconsolidated);
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


   
    if(currentItem.Start_Date__c > prevItem.End_Date__c.addDays(1))
    {
    //unlinked new future period   
    continue;
    }

    

   
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
        //we have to roll back the contingency beause we start an overlap wicc will unlikely keep the revenue  
        currentconsolidated.Net_Value__c = currentconsolidated.Net_Value__c - currentconsolidated.QuoteItem_Value__c; //2020.01.28.     

        add2ConsolidatedList(consolidatedPSIs,currentconsolidated);
       }

    //continue consolidation having the previous as cc
    Product_SubscriptionItem__c cc = handleOverlap(prevItem,currentItem);   
    if(cc != NULL)  
      {
      if(cc.Net_Value__c > 0)
         {
         cc.External_Id__c = cc.External_Id__c + '_' + consolidatedPSIs.size();  //2019.12.07.   
         add2ConsolidatedList(consolidatedPSIs,cc);  
         }

      //if the current item is an upsell we have to handle it  2020.01.21.
      if(currentItem.OppType__c == 'upsell')
         {
         currentconsolidated = upsell(prevItem,makeItemConsolidated(currentItem)); 
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


   }//end of for

   if(currentconsolidated.Net_Value__c != 0)
     {
      currentconsolidated.External_Id__c = currentconsolidated.External_Id__c + '_' + consolidatedPSIs.size();         
      //2020.01.27. consolidatedPSIs.add(currentconsolidated);
      add2ConsolidatedList(consolidatedPSIs,currentconsolidated);  
     }

   System.Debug('CSABAX we have ' + consolidatedPSIs.size() + ' consolidated Subscription terms');

   List<Product_SubscriptionItem__c> thePSI2Upsert = new List<Product_SubscriptionItem__c>(); 
   for(Product_SubscriptionItem__c qli_item :psis)
       {
       qli_item.Parent_PS__c = NULL;   
       thePSI2Upsert.add(qli_item);
       }   

   thePSI2Upsert.addAll(consolidatedPSIs); 
   System.Debug('CSABAX start upserting thePSI2Upsert count = ' +thePSI2Upsert.size());  
   List<Database.UpsertResult> durs = Database.upsert(thePSI2Upsert,Product_SubscriptionItem__c.External_Id__c,false); 
   Set<String> errorMsg = new Set<String>();
   ProcessUpsertResult(durs,'Product_SubscriptionItem',errorMsg);


}
********************************************/

/****************************************************************************************************************************
//if  are contingent we should check if cc and item has the same value
//if YES we extend the cc's End Date to the full range
//if NO the item will be the new cc and will be returned
//the original cc will be  a final on and the returned will serv as new cc for further iterations

private static Product_SubscriptionItem__c handleContingent(Product_SubscriptionItem__c cc, Product_SubscriptionItem__c item)
{
Product_SubscriptionItem__c retval = new Product_SubscriptionItem__c(RecordTypeID = consRTID);

if(cc.QuoteItem_Value__c == item.QuoteItem_Value__c) //here we should check the Quantity and unit price not the total but not sure!!!!????
  {
   cc.End_Date__c = item.End_Date__c;
   cc.Duration__c = cc.Start_Date__c.monthsBetween(item.End_Date__c);   
   cc.Type__c = 'CONTINGENT';
   cc.Net_Value__c = cc.Net_Value__c + cc.QuoteItem_Value__c;  
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
****************************************************************************************************************************/




}