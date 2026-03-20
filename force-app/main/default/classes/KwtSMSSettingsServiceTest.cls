@IsTest
private class KwtSMSSettingsServiceTest {

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
        config.Cached_Sender_IDs__c = '["KWT-SMS","TEST-ID"]';
        config.Cached_Coverage__c = '["965","966","971"]';
        insert config;
    }

    @IsTest
    static void testGetConfig_returnsOrgDefaults() {
        KwtSMS_Config__c config = KwtSMSSettingsService.getConfig();
        System.assertNotEquals(null, config, 'Config should not be null');
        System.assertEquals(true, config.Gateway_Enabled__c, 'Gateway_Enabled__c should be true');
        System.assertEquals(true, config.Gateway_Connected__c, 'Gateway_Connected__c should be true');
        System.assertEquals(100, config.Cached_Balance__c, 'Cached_Balance__c should be 100');
        System.assertEquals('KWT-SMS', config.Sender_ID__c, 'Sender_ID__c should be KWT-SMS');
        System.assertEquals('965', config.Default_Country_Code__c, 'Default_Country_Code__c should be 965');
    }

    @IsTest
    static void testSaveConfig_updatesValues() {
        KwtSMS_Config__c config = KwtSMSSettingsService.getConfig();
        config.Sender_ID__c = 'UPDATED-ID';
        KwtSMSSettingsService.saveConfig(config);

        KwtSMS_Config__c reread = KwtSMSSettingsService.getConfig();
        System.assertEquals('UPDATED-ID', reread.Sender_ID__c, 'Sender_ID__c should be updated');
    }

    @IsTest
    static void testIsGatewayReady_allTrue() {
        Boolean result = KwtSMSSettingsService.isGatewayReady();
        System.assertEquals(true, result, 'Gateway should be ready when all conditions pass');
    }

    @IsTest
    static void testIsGatewayReady_notEnabled() {
        KwtSMS_Config__c config = KwtSMSSettingsService.getConfig();
        config.Gateway_Enabled__c = false;
        KwtSMSSettingsService.saveConfig(config);

        Boolean result = KwtSMSSettingsService.isGatewayReady();
        System.assertEquals(false, result, 'Gateway should not be ready when not enabled');
    }

    @IsTest
    static void testIsGatewayReady_notConnected() {
        KwtSMS_Config__c config = KwtSMSSettingsService.getConfig();
        config.Gateway_Connected__c = false;
        KwtSMSSettingsService.saveConfig(config);

        Boolean result = KwtSMSSettingsService.isGatewayReady();
        System.assertEquals(false, result, 'Gateway should not be ready when not connected');
    }

    @IsTest
    static void testIsGatewayReady_zeroBalance() {
        KwtSMS_Config__c config = KwtSMSSettingsService.getConfig();
        config.Cached_Balance__c = 0;
        KwtSMSSettingsService.saveConfig(config);

        Boolean result = KwtSMSSettingsService.isGatewayReady();
        System.assertEquals(false, result, 'Gateway should not be ready when balance is zero');
    }

    @IsTest
    static void testIsGatewayReady_nullBalance() {
        KwtSMS_Config__c config = KwtSMSSettingsService.getConfig();
        config.Cached_Balance__c = null;
        KwtSMSSettingsService.saveConfig(config);

        Boolean result = KwtSMSSettingsService.isGatewayReady();
        System.assertEquals(false, result, 'Gateway should not be ready when balance is null');
    }

    @IsTest
    static void testGetCredentials_returnsCMDT() {
        Map<String, String> creds = KwtSMSSettingsService.getCredentials();
        System.assertNotEquals(null, creds, 'Credentials map should not be null');
        // CMDT records are not queryable without SeeAllData=true in test context,
        // so we only verify the method does not throw and returns a valid map.
    }

    @IsTest
    static void testGetSenderIds_parsesCachedJSON() {
        List<String> senderIds = KwtSMSSettingsService.getSenderIds();
        System.assertEquals(2, senderIds.size(), 'Should return 2 sender IDs');
        System.assertEquals('KWT-SMS', senderIds[0], 'First sender ID should be KWT-SMS');
        System.assertEquals('TEST-ID', senderIds[1], 'Second sender ID should be TEST-ID');
    }

    @IsTest
    static void testGetSenderIds_emptyReturnsDefault() {
        KwtSMS_Config__c config = KwtSMSSettingsService.getConfig();
        config.Cached_Sender_IDs__c = null;
        KwtSMSSettingsService.saveConfig(config);

        List<String> senderIds = KwtSMSSettingsService.getSenderIds();
        System.assertEquals(1, senderIds.size(), 'Should return 1 default sender ID');
        System.assertEquals('KWT-SMS', senderIds[0], 'Default sender ID should be KWT-SMS');
    }

    @IsTest
    static void testGetCoverage_parsesCachedJSON() {
        List<String> coverage = KwtSMSSettingsService.getCoverage();
        System.assertEquals(3, coverage.size(), 'Should return 3 coverage codes');
        System.assertEquals('965', coverage[0], 'First code should be 965');
        System.assertEquals('966', coverage[1], 'Second code should be 966');
        System.assertEquals('971', coverage[2], 'Third code should be 971');
    }

    @IsTest
    static void testGetCoverage_emptyReturnsDefault() {
        KwtSMS_Config__c config = KwtSMSSettingsService.getConfig();
        config.Cached_Coverage__c = null;
        KwtSMSSettingsService.saveConfig(config);

        List<String> coverage = KwtSMSSettingsService.getCoverage();
        System.assertEquals(1, coverage.size(), 'Should return 1 default coverage code');
        System.assertEquals('965', coverage[0], 'Default coverage code should be 965');
    }

    @IsTest
    static void testUpdateBalance_savesValue() {
        KwtSMSSettingsService.updateBalance(50);

        KwtSMS_Config__c config = KwtSMSSettingsService.getConfig();
        System.assertEquals(50, config.Cached_Balance__c, 'Balance should be updated to 50');
    }

    @IsTest
    static void testSaveCredentials_enqueuesDeployment() {
        Test.startTest();
        Id jobId = KwtSMSSettingsService.saveCredentials('testuser', 'testpass');
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'saveCredentials should return a non-null job ID');
    }

    @IsTest
    static void testClearCredentials_enqueuesDeployment() {
        Test.startTest();
        Id jobId = KwtSMSSettingsService.clearCredentials();
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'clearCredentials should return a non-null job ID');
    }
}
