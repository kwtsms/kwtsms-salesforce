@IsTest
private class KwtSMSSendActionTest {

    @TestSetup
    static void setup() {
        KwtSMS_Config__c config = new KwtSMS_Config__c();
        config.Gateway_Enabled__c = true;
        config.Gateway_Connected__c = true;
        config.Cached_Balance__c = 100;
        config.Sender_ID__c = 'KWT-SMS';
        config.Test_Mode__c = true;
        config.Debug_Logging__c = true;
        config.Default_Language__c = 'en';
        config.Default_Country_Code__c = '965';
        config.Cached_Coverage__c = '["965","966","971"]';
        config.Cached_Sender_IDs__c = '["KWT-SMS"]';
        insert config;
    }

    // Helper: update config fields on the org-defaults record
    private static void updateConfig(Map<String, Object> fields) {
        KwtSMS_Config__c config = KwtSMS_Config__c.getOrgDefaults();
        for (String field : fields.keySet()) {
            config.put(field, fields.get(field));
        }
        upsert config;
    }

    // -----------------------------------------------------------------------
    // testSendSMS_singleRequest
    // -----------------------------------------------------------------------

    @IsTest
    static void testSendSMS_singleRequest() {
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());

        KwtSMSSendAction.SMSRequest req = new KwtSMSSendAction.SMSRequest();
        req.phoneNumber = '96598765432';
        req.messageBody = 'Hello from Flow';
        req.senderId = 'KWT-SMS';

        Test.startTest();
        List<KwtSMSSendAction.SMSResult> results = KwtSMSSendAction.sendSMS(
            new List<KwtSMSSendAction.SMSRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected exactly 1 result');
        System.assertEquals(true, results[0].success, 'Expected success=true for valid send');
        System.assertNotEquals(null, results[0].messageId, 'Expected messageId to be populated');
        System.assertEquals('abc123def456', results[0].messageId, 'Expected msgId from mock');
    }

    // -----------------------------------------------------------------------
    // testSendSMS_multipleRequests
    // -----------------------------------------------------------------------

    @IsTest
    static void testSendSMS_multipleRequests() {
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());

        KwtSMSSendAction.SMSRequest req1 = new KwtSMSSendAction.SMSRequest();
        req1.phoneNumber = '96598765432';
        req1.messageBody = 'Message 1';

        KwtSMSSendAction.SMSRequest req2 = new KwtSMSSendAction.SMSRequest();
        req2.phoneNumber = '96658765432';
        req2.messageBody = 'Message 2';

        KwtSMSSendAction.SMSRequest req3 = new KwtSMSSendAction.SMSRequest();
        req3.phoneNumber = '97158765432';
        req3.messageBody = 'Message 3';

        Test.startTest();
        List<KwtSMSSendAction.SMSResult> results = KwtSMSSendAction.sendSMS(
            new List<KwtSMSSendAction.SMSRequest>{ req1, req2, req3 }
        );
        Test.stopTest();

        System.assertEquals(3, results.size(), 'Expected 3 results for 3 requests');
    }

    // -----------------------------------------------------------------------
    // testSendSMS_returnsOutputVariables
    // -----------------------------------------------------------------------

    @IsTest
    static void testSendSMS_returnsOutputVariables() {
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());

        KwtSMSSendAction.SMSRequest req = new KwtSMSSendAction.SMSRequest();
        req.phoneNumber = '96598765432';
        req.messageBody = 'Test output variables';
        req.senderId = null;

        Test.startTest();
        List<KwtSMSSendAction.SMSResult> results = KwtSMSSendAction.sendSMS(
            new List<KwtSMSSendAction.SMSRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected 1 result');
        KwtSMSSendAction.SMSResult result = results[0];

        // All three output variables must be set
        System.assertNotEquals(null, result.success, 'success field must be populated');
        System.assertEquals(true, result.success, 'Expected success=true on mock success');
        System.assertNotEquals(null, result.messageId, 'messageId field must be populated');
        System.assertEquals('abc123def456', result.messageId, 'Expected messageId from mock');
        // errorMessage is null on success - verify the field exists by checking it is accessible
        // (a null errorMessage on success is correct behaviour)
        System.assertEquals(null, result.errorMessage,
            'errorMessage should be null on successful send');
    }

    // -----------------------------------------------------------------------
    // testSendSMS_gatewayDisabled
    // -----------------------------------------------------------------------

    @IsTest
    static void testSendSMS_gatewayDisabled() {
        updateConfig(new Map<String, Object>{ 'Gateway_Enabled__c' => false });
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());

        KwtSMSSendAction.SMSRequest req = new KwtSMSSendAction.SMSRequest();
        req.phoneNumber = '96598765432';
        req.messageBody = 'Should not be sent';
        req.senderId = null;

        Test.startTest();
        List<KwtSMSSendAction.SMSResult> results = KwtSMSSendAction.sendSMS(
            new List<KwtSMSSendAction.SMSRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected 1 result');
        System.assertEquals(false, results[0].success,
            'Expected success=false when gateway is disabled');
        System.assertNotEquals(null, results[0].errorMessage,
            'Expected errorMessage to be populated when gateway is disabled');
    }
}
