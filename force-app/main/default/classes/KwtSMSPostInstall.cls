public with sharing class KwtSMSPostInstall implements InstallHandler {

    public void onInstall(InstallContext context) {
        // 1. Create default config
        KwtSMS_Config__c config = new KwtSMS_Config__c();
        config.Sender_ID__c = 'KWT-SMS';
        config.Test_Mode__c = true;
        config.Gateway_Enabled__c = false;
        config.Debug_Logging__c = true;
        config.Default_Language__c = 'en';
        config.Cached_Balance__c = 0;
        config.Cached_Coverage__c = '["965"]';
        config.Cached_Sender_IDs__c = '["KWT-SMS"]';
        config.Gateway_Connected__c = false;
        config.Default_Country_Code__c = '965';
        upsert config;

        // 2. Create default templates
        createDefaultTemplates();

        // 3. Create event configs
        createEventConfigs();

        // 4. Schedule sync job
        try {
            KwtSMSSyncJob.schedule();
        } catch (Exception e) {
            // Job may already be scheduled
        }

        // 5. Log installation
        KwtSMSLogger.logInfo('INSTALL', 'kwtSMS plugin installed successfully');
        KwtSMSLogger.flush();
    }

    private void createDefaultTemplates() {
        List<SMS_Template__c> templates = new List<SMS_Template__c>();

        // Order Created
        templates.add(buildTemplate('Order Created (EN)', 'Order_Created', 'en',
            'Hi {{customer_name}}, your order {{order_number}} has been placed successfully. Thank you for shopping with {{company_name}}.'));
        templates.add(buildTemplate('Order Created (AR)', 'Order_Created', 'ar',
            '\u0645\u0631\u062D\u0628\u0627 {{customer_name}}\u060C \u062A\u0645 \u062A\u0623\u0643\u064A\u062F \u0637\u0644\u0628\u0643 \u0631\u0642\u0645 {{order_number}} \u0628\u0646\u062C\u0627\u062D. \u0634\u0643\u0631\u0627 \u0644\u062A\u0633\u0648\u0642\u0643 \u0645\u0639 {{company_name}}.'));

        // Order Status Changed
        templates.add(buildTemplate('Order Status Changed (EN)', 'Order_Status_Changed', 'en',
            'Hi {{customer_name}}, your order {{order_number}} status has been updated to: {{order_status}}. - {{company_name}}'));
        templates.add(buildTemplate('Order Status Changed (AR)', 'Order_Status_Changed', 'ar',
            '\u0645\u0631\u062D\u0628\u0627 {{customer_name}}\u060C \u062A\u0645 \u062A\u062D\u062F\u064A\u062B \u062D\u0627\u0644\u0629 \u0637\u0644\u0628\u0643 \u0631\u0642\u0645 {{order_number}} \u0627\u0644\u0649: {{order_status}}. - {{company_name}}'));

        // Case Created
        templates.add(buildTemplate('Case Created (EN)', 'Case_Created', 'en',
            'Hi {{customer_name}}, your support case {{case_number}} has been created. We will get back to you shortly. - {{company_name}}'));
        templates.add(buildTemplate('Case Created (AR)', 'Case_Created', 'ar',
            '\u0645\u0631\u062D\u0628\u0627 {{customer_name}}\u060C \u062A\u0645 \u0641\u062A\u062D \u0637\u0644\u0628 \u0627\u0644\u062F\u0639\u0645 \u0631\u0642\u0645 {{case_number}}. \u0633\u0646\u062A\u0648\u0627\u0635\u0644 \u0645\u0639\u0643 \u0642\u0631\u064A\u0628\u0627. - {{company_name}}'));

        // Case Status Changed
        templates.add(buildTemplate('Case Status Changed (EN)', 'Case_Status_Changed', 'en',
            'Hi {{customer_name}}, your case {{case_number}} status has been updated to: {{case_status}}. - {{company_name}}'));
        templates.add(buildTemplate('Case Status Changed (AR)', 'Case_Status_Changed', 'ar',
            '\u0645\u0631\u062D\u0628\u0627 {{customer_name}}\u060C \u062A\u0645 \u062A\u062D\u062F\u064A\u062B \u062D\u0627\u0644\u0629 \u0637\u0644\u0628 \u0627\u0644\u062F\u0639\u0645 \u0631\u0642\u0645 {{case_number}} \u0627\u0644\u0649: {{case_status}}. - {{company_name}}'));

        // Admin alerts (English only)
        templates.add(buildTemplate('Admin: New Order (EN)', 'Admin_Order_Created', 'en',
            'New order {{order_number}} received from {{customer_name}}. Total: {{order_total}}. - {{company_name}}'));
        templates.add(buildTemplate('Admin: New Case (EN)', 'Admin_Case_Created', 'en',
            'New support case {{case_number}}: {{case_subject}} from {{customer_name}}. - {{company_name}}'));

        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, templates);
        insert decision.getRecords();
    }

    private void createEventConfigs() {
        List<KwtSMS_Event_Config__c> configs = new List<KwtSMS_Event_Config__c>();
        configs.add(buildEventConfig('Order_Created', 'Order Created'));
        configs.add(buildEventConfig('Order_Status_Changed', 'Order Status Changed'));
        configs.add(buildEventConfig('Case_Created', 'Case Created'));
        configs.add(buildEventConfig('Case_Status_Changed', 'Case Status Changed'));

        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, configs);
        insert decision.getRecords();
    }

    private SMS_Template__c buildTemplate(String name, String eventType, String language, String body) {
        SMS_Template__c t = new SMS_Template__c();
        t.Name = name;
        t.Event_Type__c = eventType;
        t.Language__c = language;
        t.Body__c = body;
        t.Default_Body__c = body;
        return t;
    }

    private KwtSMS_Event_Config__c buildEventConfig(String eventName, String label) {
        KwtSMS_Event_Config__c ec = new KwtSMS_Event_Config__c();
        ec.Name = eventName;
        ec.Event_Name__c = eventName;
        ec.Label__c = label;
        ec.Enabled__c = false;
        ec.Notify_Customer__c = true;
        ec.Notify_Admin__c = false;
        return ec;
    }
}
