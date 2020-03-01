/***********************************************************************
this is a queueable clas which call itself several times and consolidate
yhe POC PS passed as first parameter in the constructor 
 **********************************************************************/
public with sharing class queueableConsolidatePSIs  implements Queueable
{

    List<ID> pocPSIDs = new List<ID>();
    integer pocPSCounter;

    /****************************************************************************
    when this constructor is caller recursivelly pass always the same list of IDs
    but increment the counter till reach the list size()-1
    ****************************************************************************/
    public queueableConsolidatePSIs(List<ID> pocPSs2Consolidate, Integer counter) 
    {
        System.Debug('CSABAZ start queuable for ' + pocPSs2Consolidate.size() + ' items at item: ' + counter);
        pocPSIDs = pocPSs2Consolidate;
        pocPSCounter = counter;
    }    


    public void execute(QueueableContext context) 
    {
     if(pocPSIDs == NULL || pocPSCounter >= pocPSIDs.size())
        {
        return;
        }

    ID currentPOCPS = pocPSIDs.get(pocPSCounter);
    List<Product_SubscriptionItem__c> finalConsolidatedList = ProductSubscriptionUtility.ConsolidateItems4SubsBBSUM(currentPOCPS);

    integer nrofitems = finalConsolidatedList.size(); 
    System.Debug('CSABAZ current POC: ' + currentPOCPS + ' generated ' + nrofitems + ' consolidated items');

    Set<ID> prodSubscr2Merge = new set<ID>(); //we will have always 1 item
    if(finalConsolidatedList != NULL && finalConsolidatedList.size() > 0)
       {
        Product_SubscriptionItem__c consolidatedpsi = finalConsolidatedList[0];
        if(consolidatedpsi.Parent_PS__c == NULL) { return; }

        prodSubscr2Merge.add(consolidatedpsi.Parent_PS__c); 
        ProductSubscriptionUtility.MergeAllItems2Terms(prodSubscr2Merge);    
 
        ProductSubscription_POC__c poc2c =  new ProductSubscription_POC__c(Id = currentPOCPS); 
        poc2c.status__c = 'CONSOLIDATED_2.0';
        update poc2c;
       }         

    //once this is done enqueu the new queueable for the next POC 
    if(pocPSCounter < pocPSIDs.size() -1)
       {
        System.enqueueJob(new queueableConsolidatePSIs(pocPSIDs,++pocPSCounter));  
       }

    }
    
    
}