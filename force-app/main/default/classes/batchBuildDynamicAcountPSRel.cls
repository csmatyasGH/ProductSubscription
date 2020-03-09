/**********************************************************************************************************************************
collect all PS  for a given account and Build Dymanic Accout relationship field plus a field with a comma separated list of Prods.
SELECT id, name,(Select id,Product__r.Name from Product_Subscriptions__r) FROM Account
where id in (Select Account__C  from ProductSubscription__c)
limit 200
**********************************************************************************************************************************/
global class batchBuildDynamicAcountPSRel implements Database.Batchable<sObject>, Database.Stateful, Database.RaisesPlatformEvents {
  private Boolean processAllPSs = false;
  private String prodGroupingField;
  private String accProdListField;

  private ID testAcc;

  private Batch_Job_Monitor__c theBJM;

  /**************************************************
    this batch will be invoked from the PS sync batch. 
    **************************************************/
  public batchBuildDynamicAcountPSRel(Boolean allPss) {
    processAllPSs = allPss;

    accProdListField = 'ProductsonAccount__c';

    ProductSubscriptionSettings__c myCS = ProductSubscriptionSettings__c.getInstance();
    prodGroupingField = myCS.Product_Group_Field__c;
    if (prodGroupingField == null) {
      prodGroupingField = 'Family';
    }
  }

  /************************ used during tests *******************/
  public batchBuildDynamicAcountPSRel(Boolean allPss, ID testAccID) {
    this(allPss);
    testAcc = testAccID;

  }

  /********************************************************************************************************
    param1 API name of the accutn field where we store the Product list
    param2 API name of theb Product  field we use  in the grouping of  subscriptio products (Family, Sub-Fam)
    param3 Switch to run the bacth for all products (init data load)
    param4 test Accoutn ID  used durign testing debugging 
    ********************************************************************************************************/
  public batchBuildDynamicAcountPSRel(
    String AccFieldName,
    String ProdFieldName,
    Boolean allPss,
    ID testAccID
  ) {
    processAllPSs = allPss;

    accProdListField = AccFieldName;
    prodGroupingField = ProdFieldName;

    testAcc = testAccID;
  }

  /***************************************************************
    collect all accounts and their child PSs  which has  PS modified
    yesterday. 
    ***************************************************************/
  global Database.QueryLocator start(Database.BatchableContext BC) {
    String query = 'Select id, Name,  ' + accProdListField;
    query =
      query +
      ' ,(Select Id, Name,Product__r.Name,SyncStatus__c,LastModifieddate, Product__r.' +
      prodGroupingField +
      ' from Product_Subscriptions__r where SubscriptionStatus__c = \'Active\' )';
      query = query + ' from Account ';

    if (testAcc == null)
    {
      query =
      query +
      ' where id in (Select Account__c from ProductSubscription__c ';
    }


    if (processAllPSs == false && testAcc == null) {
      query = query + ' where LastModifieddate >= yesterday ) ';
    } else if(testAcc == NULL) {
      query = query + ' ) ';
    }

    if (testAcc != null) {
      query = query + ' where ID = \'' + testAcc + '\'';
    }

    query = query + ' limit 5000000';
    System.Debug('CSABA query = ' +  query);
    return Database.getQueryLocator(query);
  }

  /*********************************************************************
     if an account has at least 1 Active PS mark it in the DymamicRel field
     if has PS but no loger Active mark it
     *********************************************************************/
  global void execute(Database.BatchableContext BC, List<Account> scope) {
    map<ID, String> mapAcc2Prods = new Map<ID, String>();
    for (Account acc : scope) {
      /***********************************************************
      for each accout collect  the ProdFamilies into a string 
      ***********************************************************/
      Set<String> proditems = new Set<String>();

      for (ProductSubscription__c ps : acc.Product_Subscriptions__r) {
        SObject prod = ps.Product__r;
        String pgf = String.valueof(prod.get(prodGroupingField));
        proditems.add(pgf);
      }
      List<String> slist = new List<String>();
      slist.addAll(proditems);
      String af = String.join(slist, ';');
      acc.put(accProdListField, af);
      acc.ProductsonAccountCount__c = slist.size();
    }

    Database.update(scope, false);
  }

  global void finish(Database.BatchableContext BC) {
  }
}
