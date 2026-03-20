@IsTest
private class KwtSMSControllerTest {

    // =========================================================
    // Multi-response mock: routes responses by endpoint URL
    // =========================================================
    private class MultiMock implements HttpCalloutMock {
        private Map<String, HttpCalloutMock> mocks = new Map<String, HttpCalloutMock>();

        public MultiMock add(String urlFragment, HttpCalloutMock mock) {
            mocks.put(urlFragment, mock);
            return this;
        }

        public HTTPResponse respond(HTTPRequest req) {
            String url = req.getEndpoint();
            for (String fragment : mocks.keySet()) {
                if (url.contains(fragment)) {
                    return mocks.get(fragment).respond(req);
                }
            }
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setBody('{"result":"ERROR","code":"NOT_FOUND","description":"No mock for: ' + url + '"}');
            return res;
        }
    }

    private class SimpleMock implements HttpCalloutMock {
        private String body;
        private Integer statusCode;

        public SimpleMock(String body, Integer statusCode) {
            this.body = body;
            this.statusCode = statusCode;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    // Canned JSON responses
    private static final String BALANCE_OK   = '{"result":"OK","available":100,"purchased":200}';
    private static final String SENDER_OK    = '{"result":"OK","senderid":["KWT-SMS"]}';
    private static final String COVERAGE_OK  = '{"result":"OK","coverage":["965"]}';
    private static final String SEND_OK      = '{"result":"OK","msg-id":"MSG001","numbers":1,"points-charged":1,"balance-after":99}';
    private static final String AUTH_ERROR   = '{"result":"ERROR","code":"AUTH_FAILED","description":"Invalid credentials"}';

    // =========================================================
    // @TestSetup
    // =========================================================
    @TestSetup
    static void makeData() {
        // Custom Setting
        KwtSMS_Config__c config = new KwtSMS_Config__c();
        config.Gateway_Enabled__c = true;
        config.Gateway_Connected__c = true;
        config.Cached_Balance__c = 100;
        config.Sender_ID__c = 'KWT-SMS';
        config.Test_Mode__c = false;
        config.Debug_Logging__c = false;
        config.Default_Country_Code__c = '965';
        config.Default_Language__c = 'en';
        config.Cached_Sender_IDs__c = '["KWT-SMS"]';
        config.Cached_Coverage__c = '["965"]';
        upsert config;

        // Event configs
        List<KwtSMS_Event_Config__c> events = new List<KwtSMS_Event_Config__c>{
            new KwtSMS_Event_Config__c(
                Event_Name__c = 'OrderConfirmed',
                Label__c = 'Order Confirmed',
                Enabled__c = true,
                Notify_Customer__c = true,
                Notify_Admin__c = false
            ),
            new KwtSMS_Event_Config__c(
                Event_Name__c = 'CaseCreated',
                Label__c = 'Case Created',
                Enabled__c = false,
                Notify_Customer__c = false,
                Notify_Admin__c = true
            )
        };
        insert events;

        // Templates
        List<SMS_Template__c> templates = new List<SMS_Template__c>{
            new SMS_Template__c(
                Name = 'OrderConfirmed_en',
                Event_Type__c = 'OrderConfirmed',
                Language__c = 'en',
                Body__c = 'Your order {{order_number}} is confirmed.',
                Default_Body__c = 'Your order {{order_number}} is confirmed.'
            ),
            new SMS_Template__c(
                Name = 'OrderConfirmed_ar',
                Event_Type__c = 'OrderConfirmed',
                Language__c = 'ar',
                Body__c = 'تم تاكيد طلبك رقم {{order_number}}.',
                Default_Body__c = 'تم تاكيد طلبك رقم {{order_number}}.'
            )
        };
        insert templates;

        // Admin recipients
        Admin_Alert_Recipient__c recipient = new Admin_Alert_Recipient__c(
            Name = 'Test Admin',
            Phone__c = '96598765432',
            Active__c = true
        );
        insert recipient;
    }

    // =========================================================
    // Dashboard
    // =========================================================
    @IsTest
    static void testGetDashboardData() {
        Test.startTest();
        Map<String, Object> data = KwtSMSController.getDashboardData();
        Test.stopTest();

        System.assertNotEquals(null, data, 'Dashboard data should not be null');
        System.assert(data.containsKey('balance'), 'balance key missing');
        System.assert(data.containsKey('senderId'), 'senderId key missing');
        System.assert(data.containsKey('testMode'), 'testMode key missing');
        System.assert(data.containsKey('gatewayConnected'), 'gatewayConnected key missing');
        System.assert(data.containsKey('gatewayEnabled'), 'gatewayEnabled key missing');
        System.assert(data.containsKey('lastSync'), 'lastSync key missing');
        System.assert(data.containsKey('sentToday'), 'sentToday key missing');
        System.assert(data.containsKey('failedToday'), 'failedToday key missing');
        System.assert(data.containsKey('skippedToday'), 'skippedToday key missing');
        System.assert(data.containsKey('sentWeek'), 'sentWeek key missing');
        System.assert(data.containsKey('failedWeek'), 'failedWeek key missing');
        System.assert(data.containsKey('skippedWeek'), 'skippedWeek key missing');
        System.assert(data.containsKey('eventConfigs'), 'eventConfigs key missing');
        System.assert(data.containsKey('adminRecipients'), 'adminRecipients key missing');
        System.assert(data.containsKey('recentLogs'), 'recentLogs key missing');
    }

    // =========================================================
    // Gateway Config
    // =========================================================
    @IsTest
    static void testGetGatewayConfig() {
        Test.startTest();
        Map<String, Object> data = KwtSMSController.getGatewayConfig();
        Test.stopTest();

        System.assertNotEquals(null, data, 'Gateway config should not be null');
        System.assertEquals(true, data.get('gatewayConnected'), 'gatewayConnected should be true');
        System.assertEquals(100.0, data.get('balance'), 'balance should be 100');
        System.assertEquals('KWT-SMS', data.get('senderId'), 'senderId mismatch');
        System.assertEquals(false, data.get('testMode'), 'testMode should be false');
        System.assertEquals('965', data.get('defaultCountryCode'), 'defaultCountryCode mismatch');
        System.assertEquals(true, data.get('gatewayEnabled'), 'gatewayEnabled should be true');
        System.assertEquals('en', data.get('defaultLanguage'), 'defaultLanguage should be en');
        System.assertNotEquals(null, data.get('senderIds'), 'senderIds should not be null');
        System.assertNotEquals(null, data.get('coverage'), 'coverage should not be null');
    }

    // =========================================================
    // Login - success
    // =========================================================
    @IsTest
    static void testLogin_success() {
        MultiMock mock = new MultiMock()
            .add('balance/', new SimpleMock(BALANCE_OK, 200))
            .add('senderid/', new SimpleMock(SENDER_OK, 200))
            .add('coverage/', new SimpleMock(COVERAGE_OK, 200));
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        Map<String, Object> result = KwtSMSController.login('testuser', 'testpass');
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Login should succeed');
        System.assertEquals(100.0, result.get('balance'), 'Balance mismatch');
        System.assertNotEquals(null, result.get('senderIds'), 'senderIds should not be null');
        System.assertNotEquals(null, result.get('coverage'), 'coverage should not be null');
    }

    // =========================================================
    // Login - failure
    // =========================================================
    @IsTest
    static void testLogin_failure() {
        MultiMock mock = new MultiMock()
            .add('balance/', new SimpleMock(AUTH_ERROR, 200));
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        Map<String, Object> result = KwtSMSController.login('baduser', 'badpass');
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Login should fail');
        System.assertNotEquals(null, result.get('error'), 'Error message should be present');
    }

    // =========================================================
    // Logout
    // =========================================================
    @IsTest
    static void testLogout() {
        Test.startTest();
        KwtSMSController.logout();
        Test.stopTest();

        KwtSMS_Config__c config = KwtSMSSettingsService.getConfig();
        System.assertEquals(false, config.Gateway_Connected__c, 'Gateway should be disconnected after logout');
        System.assertEquals(0, config.Cached_Balance__c, 'Balance should be 0 after logout');
    }

    // =========================================================
    // Reload
    // =========================================================
    @IsTest
    static void testReload() {
        MultiMock mock = new MultiMock()
            .add('balance/', new SimpleMock(BALANCE_OK, 200))
            .add('senderid/', new SimpleMock(SENDER_OK, 200))
            .add('coverage/', new SimpleMock(COVERAGE_OK, 200));
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        Map<String, Object> result = KwtSMSController.reload();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(100.0, result.get('balance'), 'Balance should be updated to 100');
        System.assertNotEquals(null, result.get('lastSync'), 'lastSync should be set');
    }

    // =========================================================
    // saveGatewaySettings
    // =========================================================
    @IsTest
    static void testSaveGatewaySettings() {
        Test.startTest();
        KwtSMSController.saveGatewaySettings('MY-SENDER', true, true, '966');
        Test.stopTest();

        KwtSMS_Config__c config = KwtSMSSettingsService.getConfig();
        System.assertEquals('MY-SENDER', config.Sender_ID__c, 'Sender ID mismatch');
        System.assertEquals(true, config.Test_Mode__c, 'Test mode mismatch');
        System.assertEquals(true, config.Debug_Logging__c, 'Debug logging mismatch');
        System.assertEquals('966', config.Default_Country_Code__c, 'Country code mismatch');
    }

    // =========================================================
    // saveGlobalSettings
    // =========================================================
    @IsTest
    static void testSaveGlobalSettings() {
        Test.startTest();
        KwtSMSController.saveGlobalSettings(false, 'ar');
        Test.stopTest();

        KwtSMS_Config__c config = KwtSMSSettingsService.getConfig();
        System.assertEquals(false, config.Gateway_Enabled__c, 'Gateway should be disabled');
        System.assertEquals('ar', config.Default_Language__c, 'Default language should be ar');
    }

    // =========================================================
    // getEventConfigs
    // =========================================================
    @IsTest
    static void testGetEventConfigs() {
        Test.startTest();
        List<KwtSMS_Event_Config__c> configs = KwtSMSController.getEventConfigs();
        Test.stopTest();

        System.assertNotEquals(null, configs, 'Event configs should not be null');
        System.assertEquals(2, configs.size(), 'Should have 2 event configs');
    }

    // =========================================================
    // saveEventConfig
    // =========================================================
    @IsTest
    static void testSaveEventConfig() {
        KwtSMS_Event_Config__c ec = [SELECT Id, Enabled__c FROM KwtSMS_Event_Config__c WHERE Event_Name__c = 'OrderConfirmed' LIMIT 1];
        System.assertEquals(true, ec.Enabled__c, 'Should start enabled');

        Test.startTest();
        KwtSMSController.saveEventConfig(ec.Id, false, false, true);
        Test.stopTest();

        KwtSMS_Event_Config__c updated = [SELECT Enabled__c, Notify_Customer__c, Notify_Admin__c FROM KwtSMS_Event_Config__c WHERE Id = :ec.Id];
        System.assertEquals(false, updated.Enabled__c, 'Should now be disabled');
        System.assertEquals(false, updated.Notify_Customer__c, 'Notify Customer mismatch');
        System.assertEquals(true, updated.Notify_Admin__c, 'Notify Admin mismatch');
    }

    // =========================================================
    // getTemplatesForEvent
    // =========================================================
    @IsTest
    static void testGetTemplatesForEvent() {
        Test.startTest();
        List<SMS_Template__c> templates = KwtSMSController.getTemplatesForEvent('OrderConfirmed');
        Test.stopTest();

        System.assertNotEquals(null, templates, 'Templates should not be null');
        System.assertEquals(2, templates.size(), 'Should have 2 templates for OrderConfirmed');
    }

    // =========================================================
    // saveTemplate
    // =========================================================
    @IsTest
    static void testSaveTemplate() {
        SMS_Template__c t = [SELECT Id, Body__c FROM SMS_Template__c WHERE Language__c = 'en' LIMIT 1];
        String newBody = 'Updated body text.';

        Test.startTest();
        KwtSMSController.saveTemplate(t.Id, newBody);
        Test.stopTest();

        SMS_Template__c updated = [SELECT Body__c FROM SMS_Template__c WHERE Id = :t.Id];
        System.assertEquals(newBody, updated.Body__c, 'Body should be updated');
    }

    // =========================================================
    // resetTemplate
    // =========================================================
    @IsTest
    static void testResetTemplate() {
        SMS_Template__c t = [SELECT Id, Default_Body__c FROM SMS_Template__c WHERE Language__c = 'en' LIMIT 1];
        // First modify the body
        t.Body__c = 'Temporary modified body.';
        update t;

        Test.startTest();
        KwtSMSController.resetTemplate(t.Id);
        Test.stopTest();

        SMS_Template__c reset = [SELECT Body__c, Default_Body__c FROM SMS_Template__c WHERE Id = :t.Id];
        System.assertEquals(reset.Default_Body__c, reset.Body__c, 'Body should match Default_Body after reset');
    }

    // =========================================================
    // getAdminRecipients
    // =========================================================
    @IsTest
    static void testGetAdminRecipients() {
        Test.startTest();
        List<Admin_Alert_Recipient__c> recipients = KwtSMSController.getAdminRecipients();
        Test.stopTest();

        System.assertNotEquals(null, recipients, 'Recipients should not be null');
        System.assertEquals(1, recipients.size(), 'Should have 1 recipient');
        System.assertEquals('96598765432', recipients[0].Phone__c, 'Phone number mismatch');
    }

    // =========================================================
    // addAdminRecipient
    // =========================================================
    @IsTest
    static void testAddAdminRecipient() {
        Test.startTest();
        // 96596543210 is a valid Kuwait mobile: 965 + 9 prefix (valid) = 11 digits
        Admin_Alert_Recipient__c newRecipient = KwtSMSController.addAdminRecipient('New Admin', '96596543210');
        Test.stopTest();

        System.assertNotEquals(null, newRecipient, 'New recipient should not be null');
        System.assertNotEquals(null, newRecipient.Id, 'New recipient should have an Id');
        System.assertEquals('96596543210', newRecipient.Phone__c, 'Phone number mismatch');
    }

    // =========================================================
    // addAdminRecipient - duplicate
    // =========================================================
    @IsTest
    static void testAddAdminRecipient_duplicate() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            KwtSMSController.addAdminRecipient('Dup Admin', '96598765432');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw AuraHandledException for duplicate phone');
    }

    // =========================================================
    // deleteAdminRecipient
    // =========================================================
    @IsTest
    static void testDeleteAdminRecipient() {
        Admin_Alert_Recipient__c r = [SELECT Id FROM Admin_Alert_Recipient__c WHERE Phone__c = '96598765432' LIMIT 1];

        Test.startTest();
        KwtSMSController.deleteAdminRecipient(r.Id);
        Test.stopTest();

        List<Admin_Alert_Recipient__c> remaining = [SELECT Id FROM Admin_Alert_Recipient__c WHERE Id = :r.Id];
        System.assertEquals(0, remaining.size(), 'Recipient should be deleted');
    }

    // =========================================================
    // toggleAdminRecipient
    // =========================================================
    @IsTest
    static void testToggleAdminRecipient() {
        Admin_Alert_Recipient__c r = [SELECT Id, Active__c FROM Admin_Alert_Recipient__c WHERE Phone__c = '96598765432' LIMIT 1];
        System.assertEquals(true, r.Active__c, 'Should start active');

        Test.startTest();
        KwtSMSController.toggleAdminRecipient(r.Id, false);
        Test.stopTest();

        Admin_Alert_Recipient__c updated = [SELECT Active__c FROM Admin_Alert_Recipient__c WHERE Id = :r.Id];
        System.assertEquals(false, updated.Active__c, 'Should now be inactive');
    }

    // =========================================================
    // sendTestSMS
    // =========================================================
    @IsTest
    static void testSendTestSMS() {
        MultiMock mock = new MultiMock()
            .add('send/', new SimpleMock(SEND_OK, 200))
            .add('balance/', new SimpleMock(BALANCE_OK, 200))
            .add('senderid/', new SimpleMock(SENDER_OK, 200))
            .add('coverage/', new SimpleMock(COVERAGE_OK, 200));
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        Map<String, Object> result = KwtSMSController.sendTestSMS('96598765432', 'Test message');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(true, result.get('success'), 'Send should succeed');
        System.assertEquals('Sent', result.get('status'), 'Status should be Sent');
    }

    // =========================================================
    // getLogs
    // =========================================================
    @IsTest
    static void testGetLogs() {
        // Insert a log record
        SMS_Log__c log = new SMS_Log__c(
            Phone__c = '96598765432',
            Message__c = 'Test log',
            Status__c = 'Sent',
            Event_Type__c = 'OrderConfirmed',
            Log_Level__c = 'INFO'
        );
        insert log;

        Test.startTest();
        List<SMS_Log__c> logs = KwtSMSController.getLogs('Sent', 'OrderConfirmed', 'INFO', null, 10, 0);
        Test.stopTest();

        System.assertNotEquals(null, logs, 'Logs should not be null');
        System.assert(logs.size() >= 1, 'Should have at least 1 log');
    }

    // =========================================================
    // clearLogs
    // =========================================================
    @IsTest
    static void testClearLogs() {
        // Insert log records
        List<SMS_Log__c> logsToInsert = new List<SMS_Log__c>();
        for (Integer i = 0; i < 5; i++) {
            logsToInsert.add(new SMS_Log__c(
                Phone__c = '96598765432',
                Message__c = 'Log ' + i,
                Status__c = 'Sent',
                Log_Level__c = 'INFO'
            ));
        }
        insert logsToInsert;

        Test.startTest();
        KwtSMSController.clearLogs();
        Test.stopTest();

        Integer remaining = [SELECT COUNT() FROM SMS_Log__c];
        System.assertEquals(0, remaining, 'All logs should be cleared');
    }

    // =========================================================
    // calculatePages
    // =========================================================
    @IsTest
    static void testCalculatePages() {
        Test.startTest();
        KwtSMSMessageUtils.PageInfo info = KwtSMSController.calculatePages('Hello world');
        Test.stopTest();

        System.assertNotEquals(null, info, 'PageInfo should not be null');
        System.assertEquals('English', info.encoding, 'Should be English encoding');
        System.assertEquals(11, info.charCount, 'Char count mismatch');
        System.assertEquals(1, info.pageCount, 'Should be 1 page');
    }

    // =========================================================
    // getPlaceholdersForEvent
    // =========================================================
    @IsTest
    static void testGetPlaceholdersForEvent() {
        Test.startTest();
        List<String> placeholders = KwtSMSController.getPlaceholdersForEvent('OrderConfirmed');
        Test.stopTest();

        System.assertNotEquals(null, placeholders, 'Placeholders should not be null');
        System.assert(placeholders.size() > 0, 'Should have at least one placeholder');
        System.assert(placeholders.contains('{{company_name}}'), '{{company_name}} should always be present');
    }
}
