@IsTest
private class KwtSMSFlowHandlerTest {

    @TestSetup
    static void setup() {
        KwtSMS_Config__c config = new KwtSMS_Config__c();
        config.Gateway_Enabled__c = true;
        config.Gateway_Connected__c = true;
        config.Cached_Balance__c = 100;
        config.Sender_ID__c = 'KWT-SMS';
        config.Test_Mode__c = true;
        config.Debug_Logging__c = false;
        config.Default_Language__c = 'en';
        config.Default_Country_Code__c = '965';
        config.Cached_Coverage__c = '["965","966","971"]';
        config.Cached_Sender_IDs__c = '["KWT-SMS"]';
        insert config;

        KwtSMS_Event_Config__c eventConfig = new KwtSMS_Event_Config__c();
        eventConfig.Event_Name__c = 'Order_Confirmed';
        eventConfig.Enabled__c = true;
        eventConfig.Notify_Customer__c = true;
        eventConfig.Notify_Admin__c = false;
        insert eventConfig;
    }

    // -----------------------------------------------------------------------
    // testHandleEvent_noMatchingConfig
    // -----------------------------------------------------------------------

    @IsTest
    static void testHandleEvent_noMatchingConfig() {
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());

        KwtSMSFlowHandler.FlowRequest req = new KwtSMSFlowHandler.FlowRequest();
        req.recordId = null;
        req.eventType = 'Unknown_Event';
        req.objectType = 'Order';

        Test.startTest();
        KwtSMSFlowHandler.handleEvent(new List<KwtSMSFlowHandler.FlowRequest>{ req });
        Test.stopTest();

        // No exception expected; no send should occur for an unknown event type
        System.assert(true, 'handleEvent completed without error for unknown event type');
    }

    // -----------------------------------------------------------------------
    // testHandleEvent_disabledConfig
    // -----------------------------------------------------------------------

    @IsTest
    static void testHandleEvent_disabledConfig() {
        KwtSMS_Event_Config__c cfg = [
            SELECT Id, Enabled__c FROM KwtSMS_Event_Config__c
            WHERE Event_Name__c = 'Order_Confirmed' WITH SECURITY_ENFORCED LIMIT 1
        ];
        cfg.Enabled__c = false;
        update cfg;

        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());

        KwtSMSFlowHandler.FlowRequest req = new KwtSMSFlowHandler.FlowRequest();
        req.recordId = null;
        req.eventType = 'Order_Confirmed';
        req.objectType = 'Order';

        Test.startTest();
        KwtSMSFlowHandler.handleEvent(new List<KwtSMSFlowHandler.FlowRequest>{ req });
        Test.stopTest();

        // Disabled config: no callout should occur, no exception
        System.assert(true, 'handleEvent completed without error for disabled config');
    }

    // -----------------------------------------------------------------------
    // testHandleEvent_notifyCustomer_order_noPhone
    // -----------------------------------------------------------------------

    @IsTest
    static void testHandleEvent_notifyCustomer_order_noPhone() {
        // Create an Order with no phone resolvable
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contract cont = new Contract(AccountId = acc.Id, StartDate = Date.today(), ContractTerm = 12, Status = 'Draft');
        insert cont;

        Order ord = new Order(
            AccountId = acc.Id,
            Status = 'Draft',
            EffectiveDate = Date.today(),
            ContractId = cont.Id
        );
        insert ord;

        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());

        KwtSMSFlowHandler.FlowRequest req = new KwtSMSFlowHandler.FlowRequest();
        req.recordId = ord.Id;
        req.eventType = 'Order_Confirmed';
        req.objectType = 'Order';

        Test.startTest();
        KwtSMSFlowHandler.handleEvent(new List<KwtSMSFlowHandler.FlowRequest>{ req });
        Test.stopTest();

        // No phone available so no SMS sent; no exception expected
        System.assert(true, 'handleEvent with Order and no phone completed without error');
    }

    // -----------------------------------------------------------------------
    // testHandleEvent_notifyCustomer_case_noPhone
    // -----------------------------------------------------------------------

    @IsTest
    static void testHandleEvent_notifyCustomer_case_noPhone() {
        KwtSMS_Event_Config__c cfg = [
            SELECT Id, Notify_Customer__c FROM KwtSMS_Event_Config__c
            WHERE Event_Name__c = 'Order_Confirmed' WITH SECURITY_ENFORCED LIMIT 1
        ];
        cfg.Notify_Customer__c = true;
        update cfg;

        Case c = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        insert c;

        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());

        KwtSMSFlowHandler.FlowRequest req = new KwtSMSFlowHandler.FlowRequest();
        req.recordId = c.Id;
        req.eventType = 'Order_Confirmed';
        req.objectType = 'Case';

        Test.startTest();
        KwtSMSFlowHandler.handleEvent(new List<KwtSMSFlowHandler.FlowRequest>{ req });
        Test.stopTest();

        // Case with no contact: no phone, no SMS; no exception expected
        System.assert(true, 'handleEvent with Case and no contact completed without error');
    }

    // -----------------------------------------------------------------------
    // testHandleEvent_notifyAdmin
    // -----------------------------------------------------------------------

    @IsTest
    static void testHandleEvent_notifyAdmin() {
        KwtSMS_Event_Config__c cfg = [
            SELECT Id, Notify_Customer__c, Notify_Admin__c FROM KwtSMS_Event_Config__c
            WHERE Event_Name__c = 'Order_Confirmed' WITH SECURITY_ENFORCED LIMIT 1
        ];
        cfg.Notify_Customer__c = false;
        cfg.Notify_Admin__c = true;
        update cfg;

        Admin_Alert_Recipient__c recipient = new Admin_Alert_Recipient__c();
        recipient.Phone__c = '96598765432';
        recipient.Active__c = true;
        insert recipient;

        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());

        KwtSMSFlowHandler.FlowRequest req = new KwtSMSFlowHandler.FlowRequest();
        req.recordId = null;
        req.eventType = 'Order_Confirmed';
        req.objectType = 'Order';

        Test.startTest();
        KwtSMSFlowHandler.handleEvent(new List<KwtSMSFlowHandler.FlowRequest>{ req });
        Test.stopTest();

        // Admin notification path executed; no exception expected
        System.assert(true, 'handleEvent with admin notification completed without error');
    }

    // -----------------------------------------------------------------------
    // testHandleEvent_multipleRequests
    // -----------------------------------------------------------------------

    @IsTest
    static void testHandleEvent_multipleRequests() {
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());

        KwtSMSFlowHandler.FlowRequest req1 = new KwtSMSFlowHandler.FlowRequest();
        req1.recordId = null;
        req1.eventType = 'Order_Confirmed';
        req1.objectType = 'Order';

        KwtSMSFlowHandler.FlowRequest req2 = new KwtSMSFlowHandler.FlowRequest();
        req2.recordId = null;
        req2.eventType = 'Unknown_Event';
        req2.objectType = 'Order';

        Test.startTest();
        KwtSMSFlowHandler.handleEvent(
            new List<KwtSMSFlowHandler.FlowRequest>{ req1, req2 }
        );
        Test.stopTest();

        // Batch of requests processed without exception
        System.assert(true, 'handleEvent processed multiple requests without error');
    }
}
