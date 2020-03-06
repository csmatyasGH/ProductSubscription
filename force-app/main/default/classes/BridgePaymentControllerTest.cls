@isTest
private class BridgePaymentControllerTest {

	@testSetup
    private static void setup() {
        //Setup test data
        Account acc = (Account) TestFactory.createSObject(new Account(), true);
        Contact con = (Contact) TestFactory.createSObject(new Contact(), true);
        Opportunity opp = (Opportunity) TestFactory.createSObject(new Opportunity(
            AccountId = acc.Id, 
            RecordTypeId = RecordTypeUtil.getRecordTypeIdByDeveloperName(Opportunity.SObjectType, 'Bridge_For_Teams'),
            StageName = 'Attempting',
            Subdomain__c = 'test'
            ), true);
        SBQQ__Quote__c quote = (SBQQ__Quote__c) TestFactory.createSObject(new SBQQ__Quote__c(
            SBQQ__Opportunity2__c = opp.Id,
            SBQQ__Primary__c = true,
            BillingFrequency2__c = 'Annual',
            Accounting_Contact__c = con.Id
            ), true);
        Product2 testProd = (Product2) TestFactory.createSObject(new Product2(
        	Product_Type__c = 'Cloud SaaS Subscription'
        	), true);
        SBQQ__QuoteLine__c quoteLine = (SBQQ__QuoteLine__c) TestFactory.createSObject(new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id, 
            SBQQ__Product__c = testProd.Id, 
            SBQQ__Quantity__c = 10,
            SBQQ__CustomerPrice__c = 10,
            SBQQ__OptionLevel__c = 1,
            sbqqat__TaxAmount__c = 0,
            SBQQ__SegmentIndex__c = 1), true);
        PricebookEntry pbEntry = (PricebookEntry) TestFactory.createSObject(new PricebookEntry(
            Product2Id = testProd.Id), true);
        OpportunityLineItem oli = (OpportunityLineItem) TestFactory.createSObject(new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbEntry.Id,
            SBQQ__QuoteLine__c = quoteLine.Id), true);
        ChargentBase__Gateway__c gateway = (ChargentBase__Gateway__c) TestFactory.createSObject(new ChargentBase__Gateway__c(), true);
        SBQQ__QuoteTerm__c terms = (SBQQ__QuoteTerm__c) TestFactory.createSObject(new SBQQ__QuoteTerm__c(
        	SBQQ__Body__c = 'Blah',
        	SBExternalID__c = 'BridgeForTeams',
        	SBQQ__PrintOrder__c = 1
        	), true);
    }
	
	@isTest static void testController() {
		SBQQ__Quote__c qt = [Select Id from SBQQ__Quote__c limit 1];
		ChargentOrders__ChargentOrder__c order = ChargentOrderUtility.createOrderFromQuote(qt); 
		
		ChargentOrders__Payment_Request__c payRequest = [Select Id, RequestId__c from ChargentOrders__Payment_Request__c];

		Test.setCurrentPageReference(Page.BridgePayment); 
		System.currentPageReference().getParameters().put('req', EncodingUtil.urlDecode(payRequest.RequestId__c, 'UTF-8'));
		System.currentPageReference().getHeaders().put('X-Forwarded-For', '1.1.1.1');
		System.currentPageReference().getHeaders().put('User-Agent', 'browser');
		BridgePaymentController ctrl = new BridgePaymentController();
		System.assertEquals(payRequest.RequestId__c, ctrl.RequestId);
		System.assert(ctrl.QuoteRecord != null);
		System.assert(ctrl.SubscriptionLine != null);
		System.assert(ctrl.isValidRequest);

		System.assertEquals('Blah', ctrl.quoteTerms);
		System.assertEquals('$', ctrl.currencySymbol);

		ctrl.acceptTerms();
		order = [Select AcceptedTerms__c, AcceptedTermsIP__c, AcceptedTermsUserAgent__c from ChargentOrders__ChargentOrder__c where id = :order.id];
		System.assertEquals('1.1.1.1', order.AcceptedTermsIP__c);
		System.assertEquals('Blah', order.AcceptedTerms__c);
		System.assertEquals('browser', order.AcceptedTermsUserAgent__c);

		System.assertEquals(null, ctrl.routeRequest());
	}

	@isTest static void testInvalidRequest() {
		Test.setCurrentPageReference(Page.BridgePayment); 
		BridgePaymentController ctrl = new BridgePaymentController();

		System.assert(!ctrl.isValidRequest);
		System.assertNotEquals(null, ctrl.routeRequest());
	}
}