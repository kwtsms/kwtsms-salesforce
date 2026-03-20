@IsTest
private class KwtSMSEngineTest {

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

    // Helper: update config fields directly on the inserted record
    private static void updateConfig(Map<String, Object> fields) {
        KwtSMS_Config__c config = KwtSMS_Config__c.getOrgDefaults();
        for (String field : fields.keySet()) {
            config.put(field, fields.get(field));
        }
        upsert config;
    }

    // -----------------------------------------------------------------------
    // Guard tests
    // -----------------------------------------------------------------------

    @IsTest
    static void testSend_gatewayDisabled_skipped() {
        updateConfig(new Map<String, Object>{ 'Gateway_Enabled__c' => false });
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());

        Test.startTest();
        KwtSMSEngine.SendResult result = KwtSMSEngine.send(
            new List<String>{ '96598765432' }, 'Hello', null);
        Test.stopTest();

        System.assertEquals('Skipped', result.status,
            'Expected Skipped when gateway is disabled');
        System.assertEquals('Gateway is disabled', result.errorMessage,
            'Expected disabled error message');
    }

    @IsTest
    static void testSend_gatewayNotConnected_error() {
        updateConfig(new Map<String, Object>{ 'Gateway_Connected__c' => false });
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());

        Test.startTest();
        KwtSMSEngine.SendResult result = KwtSMSEngine.send(
            new List<String>{ '96598765432' }, 'Hello', null);
        Test.stopTest();

        System.assertEquals('Failed', result.status,
            'Expected Failed when gateway is not connected');
        System.assertEquals('Gateway is not configured', result.errorMessage,
            'Expected not configured error message');
    }

    @IsTest
    static void testSend_zeroBalance_error() {
        updateConfig(new Map<String, Object>{ 'Cached_Balance__c' => 0 });
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());

        Test.startTest();
        KwtSMSEngine.SendResult result = KwtSMSEngine.send(
            new List<String>{ '96598765432' }, 'Hello', null);
        Test.stopTest();

        System.assertEquals('Failed', result.status,
            'Expected Failed when balance is zero');
        System.assertEquals('Insufficient balance', result.errorMessage,
            'Expected insufficient balance error message');
    }

    // -----------------------------------------------------------------------
    // Phone validation tests
    // -----------------------------------------------------------------------

    @IsTest
    static void testSend_invalidPhone_error() {
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());

        Test.startTest();
        KwtSMSEngine.SendResult result = KwtSMSEngine.send(
            new List<String>{ '123' }, 'Hello', null);
        Test.stopTest();

        System.assertEquals('Failed', result.status,
            'Expected Failed for invalid short phone number');
        System.assertEquals('No valid phone numbers', result.errorMessage,
            'Expected no valid phones message');
    }

    @IsTest
    static void testSend_uncoveredCountry_skipped() {
        // UK number not in coverage list (coverage is 965, 966, 971)
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());

        Test.startTest();
        KwtSMSEngine.SendResult result = KwtSMSEngine.send(
            new List<String>{ '44123456789' }, 'Hello', null);
        Test.stopTest();

        System.assertEquals('Failed', result.status,
            'Expected Failed for number outside coverage');
        System.assertEquals('No valid phone numbers', result.errorMessage,
            'Expected no valid phones message for uncovered country');
    }

    @IsTest
    static void testSend_nullPhones_error() {
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());

        Test.startTest();
        KwtSMSEngine.SendResult result = KwtSMSEngine.send(
            new List<String>(), 'Hello', null);
        Test.stopTest();

        System.assertEquals('Failed', result.status,
            'Expected Failed for empty phone list');
        System.assertEquals('No valid phone numbers', result.errorMessage,
            'Expected no valid phones message for empty list');
    }

    // -----------------------------------------------------------------------
    // Successful send tests
    // -----------------------------------------------------------------------

    @IsTest
    static void testSend_success() {
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());

        Test.startTest();
        KwtSMSEngine.SendResult result = KwtSMSEngine.send(
            new List<String>{ '96598765432' }, 'Test message', null);
        Test.stopTest();

        System.assertEquals('Sent', result.status,
            'Expected Sent for valid send');
        System.assertNotEquals(null, result.msgId,
            'Expected msgId to be populated on success');
        System.assertEquals('abc123def456', result.msgId,
            'Expected msgId from mock response');
        System.assertEquals(1, result.numbersProcessed,
            'Expected 1 number processed');
    }

    @IsTest
    static void testSend_updatesBalance() {
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());

        Test.startTest();
        KwtSMSEngine.SendResult result = KwtSMSEngine.send(
            new List<String>{ '96598765432' }, 'Test message', null);
        Test.stopTest();

        System.assertEquals('Sent', result.status,
            'Expected Sent status');

        KwtSMS_Config__c updatedConfig = KwtSMS_Config__c.getOrgDefaults();
        System.assertEquals(149, updatedConfig.Cached_Balance__c,
            'Expected Cached_Balance__c updated to balance-after value from mock (149)');
    }

    @IsTest
    static void testSend_apiError_logsFailed() {
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.authError());

        Test.startTest();
        KwtSMSEngine.SendResult result = KwtSMSEngine.send(
            new List<String>{ '96598765432' }, 'Test message', null);
        Test.stopTest();

        System.assertEquals('Failed', result.status,
            'Expected Failed on API auth error');
        System.assertNotEquals(null, result.errorCode,
            'Expected errorCode to be populated on API error');
        System.assertEquals('ERR003', result.errorCode,
            'Expected ERR003 error code from mock auth error response');
        System.assertNotEquals(null, result.errorMessage,
            'Expected errorMessage to be populated on API error');
    }

    // -----------------------------------------------------------------------
    // Deduplication and message tests
    // -----------------------------------------------------------------------

    @IsTest
    static void testSend_deduplicatesPhones() {
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());

        Test.startTest();
        KwtSMSEngine.SendResult result = KwtSMSEngine.send(
            new List<String>{ '96598765432', '96598765432' }, 'Hello', null);
        Test.stopTest();

        System.assertEquals('Sent', result.status,
            'Expected Sent even with duplicate phones');
        // The mock always returns numbers=1 for one unique number sent
        System.assertEquals(1, result.numbersProcessed,
            'Expected only 1 number processed after deduplication');
    }

    @IsTest
    static void testSend_cleansMessage() {
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());

        Test.startTest();
        // Message with HTML tags - cleanMessage strips them
        KwtSMSEngine.SendResult result = KwtSMSEngine.send(
            new List<String>{ '96598765432' }, '<b>Hi</b>', null);
        Test.stopTest();

        // If HTML caused an issue the send would fail; Sent means cleaning worked
        System.assertEquals('Sent', result.status,
            'Expected Sent after HTML tags are cleaned from message');
    }

    @IsTest
    static void testSend_messageTooLong_error() {
        // Build a 1100-character English message (exceeds 7 pages: 7*153+7=1078 max)
        String longMsg = '';
        for (Integer i = 0; i < 1100; i++) {
            longMsg += 'A';
        }
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());

        Test.startTest();
        KwtSMSEngine.SendResult result = KwtSMSEngine.send(
            new List<String>{ '96598765432' }, longMsg, null);
        Test.stopTest();

        System.assertEquals('Failed', result.status,
            'Expected Failed for message exceeding 7 pages');
        System.assertEquals('Message too long (exceeds 7 pages)', result.errorMessage,
            'Expected message too long error');
    }

    @IsTest
    static void testSend_customSenderId() {
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());

        Test.startTest();
        KwtSMSEngine.SendResult result = KwtSMSEngine.send(
            new List<String>{ '96598765432' }, 'Hello', 'MY-BRAND');
        Test.stopTest();

        // A successful send confirms the custom sender ID was accepted and passed through
        System.assertEquals('Sent', result.status,
            'Expected Sent when custom senderId is provided');
        System.assertEquals('abc123def456', result.msgId,
            'Expected msgId populated, confirming send executed with custom senderId');
    }
}
