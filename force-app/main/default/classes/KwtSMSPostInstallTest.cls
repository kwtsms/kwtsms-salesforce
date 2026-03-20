@IsTest
private class KwtSMSPostInstallTest {

    @IsTest
    static void testOnInstall_createsDefaultConfig() {
        Test.startTest();
        new KwtSMSPostInstall().onInstall(null);
        Test.stopTest();

        List<KwtSMS_Config__c> configs = [
            SELECT Sender_ID__c, Test_Mode__c, Gateway_Enabled__c,
                   Debug_Logging__c, Default_Language__c, Cached_Balance__c,
                   Cached_Coverage__c, Cached_Sender_IDs__c,
                   Gateway_Connected__c, Default_Country_Code__c
            FROM KwtSMS_Config__c
        ];

        System.assertEquals(1, configs.size(), 'Expected exactly one KwtSMS_Config__c record');

        KwtSMS_Config__c cfg = configs[0];
        System.assertEquals('KWT-SMS', cfg.Sender_ID__c, 'Sender_ID__c mismatch');
        System.assertEquals(true, cfg.Test_Mode__c, 'Test_Mode__c mismatch');
        System.assertEquals(false, cfg.Gateway_Enabled__c, 'Gateway_Enabled__c mismatch');
        System.assertEquals(true, cfg.Debug_Logging__c, 'Debug_Logging__c mismatch');
        System.assertEquals('en', cfg.Default_Language__c, 'Default_Language__c mismatch');
        System.assertEquals(0, cfg.Cached_Balance__c, 'Cached_Balance__c mismatch');
        System.assertEquals('["965"]', cfg.Cached_Coverage__c, 'Cached_Coverage__c mismatch');
        System.assertEquals('["KWT-SMS"]', cfg.Cached_Sender_IDs__c, 'Cached_Sender_IDs__c mismatch');
        System.assertEquals(false, cfg.Gateway_Connected__c, 'Gateway_Connected__c mismatch');
        System.assertEquals('965', cfg.Default_Country_Code__c, 'Default_Country_Code__c mismatch');
    }

    @IsTest
    static void testOnInstall_createsTemplates() {
        Test.startTest();
        new KwtSMSPostInstall().onInstall(null);
        Test.stopTest();

        List<SMS_Template__c> templates = [
            SELECT Id, Name, Event_Type__c, Language__c
            FROM SMS_Template__c
        ];

        System.assertEquals(10, templates.size(), 'Expected 10 SMS templates');

        // Verify each event type has the expected templates
        Map<String, List<SMS_Template__c>> byEvent = new Map<String, List<SMS_Template__c>>();
        for (SMS_Template__c t : templates) {
            if (!byEvent.containsKey(t.Event_Type__c)) {
                byEvent.put(t.Event_Type__c, new List<SMS_Template__c>());
            }
            byEvent.get(t.Event_Type__c).add(t);
        }

        System.assertEquals(2, byEvent.get('Order_Created').size(), 'Order_Created should have 2 templates');
        System.assertEquals(2, byEvent.get('Order_Status_Changed').size(), 'Order_Status_Changed should have 2 templates');
        System.assertEquals(2, byEvent.get('Case_Created').size(), 'Case_Created should have 2 templates');
        System.assertEquals(2, byEvent.get('Case_Status_Changed').size(), 'Case_Status_Changed should have 2 templates');
        System.assertEquals(1, byEvent.get('Admin_Order_Created').size(), 'Admin_Order_Created should have 1 template');
        System.assertEquals(1, byEvent.get('Admin_Case_Created').size(), 'Admin_Case_Created should have 1 template');
    }

    @IsTest
    static void testOnInstall_createsEventConfigs() {
        Test.startTest();
        new KwtSMSPostInstall().onInstall(null);
        Test.stopTest();

        List<KwtSMS_Event_Config__c> configs = [
            SELECT Event_Name__c, Enabled__c, Notify_Customer__c, Notify_Admin__c
            FROM KwtSMS_Event_Config__c
        ];

        System.assertEquals(4, configs.size(), 'Expected 4 event configs');

        Set<String> expectedEvents = new Set<String>{
            'Order_Created', 'Order_Status_Changed', 'Case_Created', 'Case_Status_Changed'
        };

        for (KwtSMS_Event_Config__c ec : configs) {
            System.assert(expectedEvents.contains(ec.Event_Name__c), 'Unexpected event name: ' + ec.Event_Name__c);
            System.assertEquals(false, ec.Enabled__c, 'Event config should be disabled by default');
            System.assertEquals(true, ec.Notify_Customer__c, 'Notify_Customer__c should be true');
            System.assertEquals(false, ec.Notify_Admin__c, 'Notify_Admin__c should be false');
        }
    }

    @IsTest
    static void testOnInstall_schedulesSync() {
        Test.startTest();
        new KwtSMSPostInstall().onInstall(null);
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'kwtSMS Daily Sync'
        ];

        System.assertEquals(1, jobs.size(), 'Expected scheduled job named kwtSMS Daily Sync');
    }
}
