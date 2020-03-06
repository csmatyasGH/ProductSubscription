/***************************************************
 this class is intended to support Batch Job Monitor
 to store statistics and error from bach job run.
 **************************************************/
public without sharing class batchJobMonitorUtility 
{

    public static Batch_Job_Monitor__c createBatchMonitor(
        Id batchJobID,
        String batchClassName,
        Integer success,
        Integer failure,
        String theComment
      ) {
        List<Batch_Job_Monitor__c> parentBJMs = [
          SELECT Id, Log_Level__c
          FROM Batch_Job_Monitor__c
          WHERE
            BatchClassName__c = :BatchClassName
            AND Parent_BatchMonitor__c = null
            AND Active__c = true
          LIMIT 1
        ];
    
        if (parentBJMs.size() == 0) {
          return null;
        }
    
        Batch_Job_Monitor__c thenewBJM = new Batch_Job_Monitor__c(
          Parent_BatchMonitor__c = parentBJMs[0].id,
          BatchClassName__c = batchClassName
        );
        thenewBJM.comment__c = theComment;
        thenewBJM.BatchJobID__c = batchJobID;
        thenewBJM.nrofSuccess__c = success;
        thenewBJM.NrofFailures__c = failure;
        //insert thenewBJM;
        Database.upsertresult durs = Database.upsert(
          thenewBJM,
          Batch_Job_Monitor__c.BatchJobID__c,
          false
        );
        thenewBJM.comment__c = parentBJMs[0].Log_Level__c; //just to pass the loglevel back to caller
        return thenewBJM;
      }
    
         /**************************************************************
          * 
    
         **************************************************************/
         public static Batch_Job_Monitor_Item__c createBatchMonitorItem(
          ID bjmID,
          String themsg,
          String thePhase,
          String item
        ) {
          Batch_Job_Monitor_Item__c bjmi = new Batch_Job_Monitor_Item__c();
          bjmi.Parent_Job_Monitor__c = bjmID;
          bjmi.Message__c = themsg;
          bjmi.Error_Phase__c = thePhase;
          bjmi.Affected_record__c = item;
      
          return bjmi;
        }  
}
