public with sharing class KwtSMSController {

    // === Dashboard ===
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDashboardData() {
        Map<String, Object> data = new Map<String, Object>();
        KwtSMS_Config__c config = KwtSMSSettingsService.getConfig();

        data.put('balance', config.Cached_Balance__c);
        data.put('senderId', config.Sender_ID__c);
        data.put('testMode', config.Test_Mode__c);
        data.put('gatewayConnected', config.Gateway_Connected__c);
        data.put('gatewayEnabled', config.Gateway_Enabled__c);
        data.put('lastSync', config.Last_Sync__c);

        // CRUD check before aggregate queries
        if (Schema.sObjectType.SMS_Log__c.isAccessible()) {
            data.put('sentToday', [SELECT COUNT() FROM SMS_Log__c WHERE Status__c = 'Sent' AND CreatedDate = TODAY]);
            data.put('failedToday', [SELECT COUNT() FROM SMS_Log__c WHERE Status__c = 'Failed' AND CreatedDate = TODAY]);
            data.put('skippedToday', [SELECT COUNT() FROM SMS_Log__c WHERE Status__c = 'Skipped' AND CreatedDate = TODAY]);
            Date weekStart = Date.today().toStartOfWeek();
            data.put('sentWeek', [SELECT COUNT() FROM SMS_Log__c WHERE Status__c = 'Sent' AND CreatedDate >= :weekStart]);
            data.put('failedWeek', [SELECT COUNT() FROM SMS_Log__c WHERE Status__c = 'Failed' AND CreatedDate >= :weekStart]);
            data.put('skippedWeek', [SELECT COUNT() FROM SMS_Log__c WHERE Status__c = 'Skipped' AND CreatedDate >= :weekStart]);
        }

        data.put('eventConfigs', [SELECT Event_Name__c, Label__c, Enabled__c, Notify_Customer__c, Notify_Admin__c FROM KwtSMS_Event_Config__c WITH SECURITY_ENFORCED ORDER BY Event_Name__c]);
        data.put('adminRecipients', [SELECT Name, Phone__c, Active__c FROM Admin_Alert_Recipient__c WITH SECURITY_ENFORCED]);
        data.put('recentLogs', [SELECT CreatedDate, Phone__c, Message__c, Points_Charged__c, Error_Message__c, Event_Type__c, Status__c FROM SMS_Log__c WITH SECURITY_ENFORCED ORDER BY CreatedDate DESC LIMIT 10]);

        return data;
    }

    // === Gateway ===
    @AuraEnabled
    public static Map<String, Object> login(String username, String password) {
        Map<String, Object> result = new Map<String, Object>();
        try {
            // Validate credentials by calling balance
            KwtSMSClient.BalanceResponse balance = KwtSMSClient.getBalance(username, password);
            if (balance.result != 'OK') {
                result.put('success', false);
                result.put('error', 'Login failed. Please check your username and password.');
                return result;
            }

            // Save credentials via Metadata API (async)
            KwtSMSSettingsService.saveCredentials(username, password);

            // Update config
            KwtSMS_Config__c config = KwtSMSSettingsService.getConfig();
            config.Cached_Balance__c = balance.available;
            config.Gateway_Connected__c = true;

            // Fetch sender IDs
            List<String> senderIds = KwtSMSClient.getSenderIds(username, password);
            config.Cached_Sender_IDs__c = JSON.serialize(senderIds);

            // Fetch coverage
            List<String> coverage = KwtSMSClient.getCoverage(username, password);
            config.Cached_Coverage__c = JSON.serialize(coverage);

            config.Last_Sync__c = Datetime.now();
            KwtSMSSettingsService.saveConfig(config);

            result.put('success', true);
            result.put('balance', balance.available);
            result.put('senderIds', senderIds);
            result.put('coverage', coverage);

            KwtSMSLogger.logInfo('LOGIN', 'Gateway login successful');
            KwtSMSLogger.flush();
        } catch (Exception e) {
            result.put('success', false);
            result.put('error', 'Login failed. Please check your username and password.');
            KwtSMSLogger.logError('LOGIN', 'Login failed: ' + e.getMessage());
            KwtSMSLogger.flush();
        }
        return result;
    }

    @AuraEnabled
    public static void logout() {
        KwtSMSSettingsService.clearCredentials();
        KwtSMS_Config__c config = KwtSMSSettingsService.getConfig();
        config.Gateway_Connected__c = false;
        config.Cached_Balance__c = 0;
        config.Cached_Sender_IDs__c = '["KWT-SMS"]';
        config.Cached_Coverage__c = '["965"]';
        config.Last_Sync__c = null;
        KwtSMSSettingsService.saveConfig(config);
        KwtSMSLogger.logInfo('LOGOUT', 'Gateway logout');
        KwtSMSLogger.flush();
    }

    @AuraEnabled
    public static Map<String, Object> reload() {
        Map<String, Object> result = new Map<String, Object>();
        Map<String, String> creds = KwtSMSSettingsService.getCredentials();
        String username = creds.get('username');
        String password = creds.get('password');

        KwtSMS_Config__c config = KwtSMSSettingsService.getConfig();

        KwtSMSClient.BalanceResponse balance = KwtSMSClient.getBalance(username, password);
        if (balance.result == 'OK') {
            config.Cached_Balance__c = balance.available;
        }
        List<String> senderIds = KwtSMSClient.getSenderIds(username, password);
        if (!senderIds.isEmpty()) config.Cached_Sender_IDs__c = JSON.serialize(senderIds);
        List<String> coverage = KwtSMSClient.getCoverage(username, password);
        if (!coverage.isEmpty()) config.Cached_Coverage__c = JSON.serialize(coverage);

        config.Last_Sync__c = Datetime.now();
        KwtSMSSettingsService.saveConfig(config);

        result.put('balance', config.Cached_Balance__c);
        result.put('senderIds', senderIds);
        result.put('coverage', coverage);
        result.put('lastSync', config.Last_Sync__c);
        return result;
    }

    @AuraEnabled
    public static void saveGatewaySettings(String senderId, Boolean testMode, Boolean debugLogging, String defaultCountryCode) {
        KwtSMS_Config__c config = KwtSMSSettingsService.getConfig();
        config.Sender_ID__c = senderId;
        config.Test_Mode__c = testMode;
        config.Debug_Logging__c = debugLogging;
        config.Default_Country_Code__c = defaultCountryCode;
        KwtSMSSettingsService.saveConfig(config);
    }

    @AuraEnabled
    public static Map<String, Object> sendTestSMS(String phone, String message) {
        Map<String, Object> result = new Map<String, Object>();
        KwtSMSEngine.SendResult sendResult = KwtSMSEngine.send(new List<String>{phone}, message, null);
        result.put('success', sendResult.status == 'Sent');
        result.put('status', sendResult.status);
        result.put('msgId', sendResult.msgId);
        result.put('errorMessage', sendResult.errorMessage);
        return result;
    }

    // === Settings ===
    @AuraEnabled
    public static void saveGlobalSettings(Boolean gatewayEnabled, String defaultLanguage) {
        KwtSMS_Config__c config = KwtSMSSettingsService.getConfig();
        config.Gateway_Enabled__c = gatewayEnabled;
        config.Default_Language__c = defaultLanguage;
        KwtSMSSettingsService.saveConfig(config);
    }

    @AuraEnabled(cacheable=true)
    public static List<KwtSMS_Event_Config__c> getEventConfigs() {
        return [SELECT Id, Event_Name__c, Label__c, Enabled__c, Notify_Customer__c, Notify_Admin__c FROM KwtSMS_Event_Config__c WITH SECURITY_ENFORCED ORDER BY Event_Name__c];
    }

    @AuraEnabled
    public static void saveEventConfig(Id configId, Boolean enabled, Boolean notifyCustomer, Boolean notifyAdmin) {
        KwtSMS_Event_Config__c ec = [SELECT Id FROM KwtSMS_Event_Config__c WHERE Id = :configId WITH SECURITY_ENFORCED LIMIT 1];
        ec.Enabled__c = enabled;
        ec.Notify_Customer__c = notifyCustomer;
        ec.Notify_Admin__c = notifyAdmin;
        update ec;
    }

    // === Templates ===
    @AuraEnabled
    public static List<SMS_Template__c> getTemplatesForEvent(String eventType) {
        return [SELECT Id, Name, Event_Type__c, Language__c, Body__c, Default_Body__c FROM SMS_Template__c WHERE Event_Type__c = :eventType WITH SECURITY_ENFORCED ORDER BY Language__c];
    }

    @AuraEnabled
    public static void saveTemplate(Id templateId, String body) {
        SMS_Template__c t = [SELECT Id FROM SMS_Template__c WHERE Id = :templateId WITH SECURITY_ENFORCED LIMIT 1];
        t.Body__c = body;
        update t;
    }

    @AuraEnabled
    public static void resetTemplate(Id templateId) {
        SMS_Template__c t = [SELECT Id, Default_Body__c FROM SMS_Template__c WHERE Id = :templateId WITH SECURITY_ENFORCED LIMIT 1];
        t.Body__c = t.Default_Body__c;
        update t;
    }

    // === Admin Recipients ===
    @AuraEnabled
    public static List<Admin_Alert_Recipient__c> getAdminRecipients() {
        return [SELECT Id, Name, Phone__c, Active__c FROM Admin_Alert_Recipient__c WITH SECURITY_ENFORCED ORDER BY Name];
    }

    @AuraEnabled
    public static Admin_Alert_Recipient__c addAdminRecipient(String recipientName, String phone) {
        // Normalize phone
        String normalizedPhone = KwtSMSPhoneUtils.normalize(phone);
        if (!KwtSMSPhoneUtils.verify(normalizedPhone)) {
            throw new AuraHandledException('Invalid phone number format.');
        }
        // Check duplicate
        List<Admin_Alert_Recipient__c> existing = [SELECT Id FROM Admin_Alert_Recipient__c WHERE Phone__c = :normalizedPhone WITH SECURITY_ENFORCED LIMIT 1];
        if (!existing.isEmpty()) {
            throw new AuraHandledException('This phone number already exists.');
        }
        Admin_Alert_Recipient__c recipient = new Admin_Alert_Recipient__c();
        recipient.Name = recipientName;
        recipient.Phone__c = normalizedPhone;
        recipient.Active__c = true;
        insert recipient;
        return recipient;
    }

    @AuraEnabled
    public static void deleteAdminRecipient(Id recipientId) {
        Admin_Alert_Recipient__c r = [SELECT Id FROM Admin_Alert_Recipient__c WHERE Id = :recipientId WITH SECURITY_ENFORCED LIMIT 1];
        delete r;
    }

    @AuraEnabled
    public static void toggleAdminRecipient(Id recipientId, Boolean active) {
        Admin_Alert_Recipient__c r = [SELECT Id FROM Admin_Alert_Recipient__c WHERE Id = :recipientId WITH SECURITY_ENFORCED LIMIT 1];
        r.Active__c = active;
        update r;
    }

    // === Logs ===
    @AuraEnabled
    public static List<SMS_Log__c> getLogs(String statusFilter, String eventFilter, String logLevelFilter, String searchTerm, Integer limitCount, Integer offsetCount) {
        String query = 'SELECT CreatedDate, Phone__c, Message__c, Points_Charged__c, Error_Code__c, Error_Message__c, Event_Type__c, Status__c, Log_Level__c, Message_ID__c, Sender_ID__c, Test_Mode__c, API_Response__c, Balance_After__c, Related_Record_ID__c, Related_Object_Type__c FROM SMS_Log__c';
        List<String> conditions = new List<String>();

        if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
            conditions.add('Status__c = \'' + String.escapeSingleQuotes(statusFilter) + '\'');
        }
        if (String.isNotBlank(eventFilter) && eventFilter != 'All') {
            conditions.add('Event_Type__c = \'' + String.escapeSingleQuotes(eventFilter) + '\'');
        }
        if (String.isNotBlank(logLevelFilter) && logLevelFilter != 'All') {
            conditions.add('Log_Level__c = \'' + String.escapeSingleQuotes(logLevelFilter) + '\'');
        }
        if (String.isNotBlank(searchTerm)) {
            String safeSearch = '%' + String.escapeSingleQuotes(searchTerm) + '%';
            conditions.add('(Phone__c LIKE \'' + safeSearch + '\' OR Message_ID__c LIKE \'' + safeSearch + '\')');
        }

        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }
        query += ' WITH SECURITY_ENFORCED ORDER BY CreatedDate DESC';

        Integer safeLimit = (limitCount != null && limitCount > 0) ? limitCount : 50;
        query += ' LIMIT ' + safeLimit;

        if (offsetCount != null && offsetCount > 0) {
            query += ' OFFSET ' + offsetCount;
        }

        return Database.query(query);
    }

    @AuraEnabled
    public static void clearLogs() {
        List<SMS_Log__c> logsToDelete = [SELECT Id FROM SMS_Log__c WITH SECURITY_ENFORCED LIMIT 10000];
        while (!logsToDelete.isEmpty()) {
            delete logsToDelete;
            logsToDelete = [SELECT Id FROM SMS_Log__c WITH SECURITY_ENFORCED LIMIT 10000];
        }
    }

    // === Utility ===
    @AuraEnabled
    public static KwtSMSMessageUtils.PageInfo calculatePages(String message) {
        return KwtSMSMessageUtils.calculatePages(message);
    }

    @AuraEnabled
    public static List<String> getPlaceholdersForEvent(String eventType) {
        return KwtSMSTemplateEngine.getPlaceholdersForEvent(eventType);
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getGatewayConfig() {
        Map<String, Object> data = new Map<String, Object>();
        KwtSMS_Config__c config = KwtSMSSettingsService.getConfig();
        data.put('gatewayConnected', config.Gateway_Connected__c);
        data.put('balance', config.Cached_Balance__c);
        data.put('senderId', config.Sender_ID__c);
        data.put('testMode', config.Test_Mode__c);
        data.put('debugLogging', config.Debug_Logging__c);
        data.put('defaultCountryCode', config.Default_Country_Code__c);
        data.put('lastSync', config.Last_Sync__c);
        data.put('senderIds', KwtSMSSettingsService.getSenderIds());
        data.put('coverage', KwtSMSSettingsService.getCoverage());
        data.put('gatewayEnabled', config.Gateway_Enabled__c);
        data.put('defaultLanguage', config.Default_Language__c);
        return data;
    }
}
