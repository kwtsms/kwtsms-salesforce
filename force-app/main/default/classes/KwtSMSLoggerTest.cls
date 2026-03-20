@IsTest
private class KwtSMSLoggerTest {

    @TestSetup
    static void setup() {
        KwtSMS_Config__c config = new KwtSMS_Config__c();
        config.Debug_Logging__c = true;
        config.Gateway_Enabled__c = false;
        config.Test_Mode__c = true;
        insert config;
    }

    @IsTest
    static void testLogSend_addsToBuffer() {
        KwtSMSLogger.clearBuffer();
        KwtSMSLogger.logSend(
            '96598765432', 'Hello World', 'Sent',
            null, null, 'SMS_Send',
            'MSG001', 1.0, 99.0,
            null, null,
            'KWTSMS', false, '{"status":"ok"}'
        );
        System.assertEquals(1, KwtSMSLogger.getBufferSize(),
            'logSend should add 1 record to the buffer');
        KwtSMSLogger.clearBuffer();
    }

    @IsTest
    static void testLogInfo_addsToBuffer() {
        KwtSMSLogger.clearBuffer();
        KwtSMSLogger.logInfo('Login', 'User logged in successfully');
        System.assertEquals(1, KwtSMSLogger.getBufferSize(),
            'logInfo should add 1 record with INFO level to the buffer');
        KwtSMSLogger.clearBuffer();
    }

    @IsTest
    static void testLogError_addsToBuffer() {
        KwtSMSLogger.clearBuffer();
        KwtSMSLogger.logError('SMS_Send', 'Connection timeout');
        System.assertEquals(1, KwtSMSLogger.getBufferSize(),
            'logError should add 1 record with ERROR level to the buffer');
        KwtSMSLogger.clearBuffer();
    }

    @IsTest
    static void testLogDebug_addsWhenEnabled() {
        // @TestSetup inserts config with Debug_Logging__c = true
        KwtSMSLogger.clearBuffer();
        KwtSMSLogger.logDebug('Sync', 'Debug detail here');
        System.assertEquals(1, KwtSMSLogger.getBufferSize(),
            'logDebug should add to buffer when Debug_Logging__c is true');
        KwtSMSLogger.clearBuffer();
    }

    @IsTest
    static void testLogDebug_skipsWhenDisabled() {
        KwtSMS_Config__c config = KwtSMS_Config__c.getOrgDefaults();
        config.Debug_Logging__c = false;
        update config;

        KwtSMSLogger.clearBuffer();
        KwtSMSLogger.logDebug('Sync', 'Should not be added');
        System.assertEquals(0, KwtSMSLogger.getBufferSize(),
            'logDebug should NOT add to buffer when Debug_Logging__c is false');
    }

    @IsTest
    static void testFlush_insertsRecords() {
        KwtSMSLogger.clearBuffer();
        KwtSMSLogger.logInfo('Test_Event', 'Test flush insert');
        KwtSMSLogger.logError('Test_Event', 'Test flush error');

        Test.startTest();
        KwtSMSLogger.flush();
        Test.stopTest();

        List<SMS_Log__c> logs = [SELECT Id, Event_Type__c FROM SMS_Log__c WHERE Event_Type__c = 'Test_Event'];
        System.assertEquals(2, logs.size(),
            'flush() should insert all buffered records into the database');
    }

    @IsTest
    static void testFlush_clearsBuffer() {
        KwtSMSLogger.clearBuffer();
        KwtSMSLogger.logInfo('Clear_Test', 'Buffer should clear after flush');

        Test.startTest();
        KwtSMSLogger.flush();
        Test.stopTest();

        System.assertEquals(0, KwtSMSLogger.getBufferSize(),
            'Buffer should be empty after flush()');
    }

    @IsTest
    static void testFlush_emptyBufferNoOp() {
        KwtSMSLogger.clearBuffer();

        Test.startTest();
        KwtSMSLogger.flush();
        Test.stopTest();

        System.assertEquals(0, KwtSMSLogger.getBufferSize(),
            'flush() on an empty buffer should be a no-op');
        List<SMS_Log__c> logs = [SELECT Id FROM SMS_Log__c];
        System.assertEquals(0, logs.size(),
            'No records should be inserted when flush() is called with empty buffer');
    }

    @IsTest
    static void testStripCredentials_removesPassword() {
        String input = '{"username":"testuser","password":"secret123"}';
        String result = KwtSMSLogger.stripCredentials(input);
        System.assert(!result.contains('secret123'),
            'stripCredentials should mask the password value');
        System.assert(result.contains('"password":"***"'),
            'stripCredentials should replace password with ***');
    }

    @IsTest
    static void testStripCredentials_removesUsername() {
        String input = '{"username":"testuser","password":"secret123"}';
        String result = KwtSMSLogger.stripCredentials(input);
        System.assert(!result.contains('testuser'),
            'stripCredentials should mask the username value');
        System.assert(result.contains('"username":"***"'),
            'stripCredentials should replace username with ***');
    }

    @IsTest
    static void testStripCredentials_nullInput() {
        String result = KwtSMSLogger.stripCredentials(null);
        System.assertEquals(null, result,
            'stripCredentials should return null when input is null');
    }

    @IsTest
    static void testStripCredentials_noCredentials() {
        String input = '{"status":"ok","message_id":"MSG001"}';
        String result = KwtSMSLogger.stripCredentials(input);
        System.assertEquals(input, result,
            'stripCredentials should return the string unchanged when no credentials are present');
    }

    @IsTest
    static void testGetBufferSize() {
        KwtSMSLogger.clearBuffer();
        KwtSMSLogger.logInfo('Size_Test', 'First');
        KwtSMSLogger.logInfo('Size_Test', 'Second');
        KwtSMSLogger.logError('Size_Test', 'Third');
        System.assertEquals(3, KwtSMSLogger.getBufferSize(),
            'getBufferSize should return the count of records logged to the buffer');
        KwtSMSLogger.clearBuffer();
    }
}
