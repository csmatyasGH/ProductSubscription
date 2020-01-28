global class batchReplicateProductSubscriptionPOC implements Database.Batchable<AggregateResult> {
 
    global Iterable<AggregateResult> start(Database.batchableContext info)
    {
        // just instantiate the new iterable here and return
        return new AggregateResultIterable();
    }
 
    global void execute(Database.BatchableContext BC, List<AggregateResult> scope)
    {
        Set<ID> newPSPOCs = new Set<ID>();
        System.debug('CSABAX SCOPE size = ' + scope.size());
        for(AggregateResult ar : scope)
            { 
            System.debug('CSABAX s = ' + ar); 
            String oppId = String.valueof(ar.get('Related_Opportunity__c'));
            newPSPOCs = BuildSubscriptionPOC.buildSubscriptionFromOpportunity4AppProds(oppId);
            } 

        for(ID subscrID :newPSPOCs)
            {
            ProductSubscriptionUtility.DeleteConsolidatedItems(subscrID,false);    
            }
    }
 
    /***********************************************
    
    ***********************************************/ 
    global void finish(Database.BatchableContext BC)
    {
        
    }   
 
    /*************************************************************************
    
    *************************************************************************/
    global class AggregateResultIterable implements Iterable<AggregateResult> {
        global Iterator<AggregateResult> Iterator(){
            return new AggregateResultIterator();
       }
    }
 
    /************************************************************************
    
    ************************************************************************/ 
    global class AggregateResultIterator implements Iterator<AggregateResult> {
        AggregateResult [] results {get;set;}
        Integer index {get; set;} 
 
        global AggregateResultIterator() {
            index = 0;
            String query = 'SELECT Related_Opportunity__c, count(ID)  FROM ProductSubscriptionOpportunity__c where Related_Opportunity__r.SBQQ__PrimaryQuote__c != NULL ';
            query = query + ' and Related_Opportunity__r.StageName in (\'Closed DeBook Non-Quota\',\'Closed DeBook Quota\',\'Closed Won\') ';
            query = query + ' group by Related_Opportunity__c order by Related_Opportunity__c  desc limit 5000';
            results = Database.query(query);            
        } 
 
        global boolean hasNext(){ 
           return results != null && !results.isEmpty() && index < results.size(); 
        }    
 
        global AggregateResult next(){ 
            return results[index++];            
        }       
    }    
 
}