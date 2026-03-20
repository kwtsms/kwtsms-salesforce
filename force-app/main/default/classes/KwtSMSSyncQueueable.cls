public with sharing class KwtSMSSyncQueueable implements Queueable, Database.AllowsCallouts {
    public void execute(QueueableContext context) {
        KwtSMS_Config__c config = KwtSMSSettingsService.getConfig();
        Map<String, String> creds = KwtSMSSettingsService.getCredentials();
        String username = creds.get('username');
        String password = creds.get('password');

        try {
            KwtSMSClient.BalanceResponse balance = KwtSMSClient.getBalance(username, password);
            if (balance.result == 'OK') {
                config.Cached_Balance__c = balance.available;
            }

            List<String> senderIds = KwtSMSClient.getSenderIds(username, password);
            if (senderIds != null && !senderIds.isEmpty()) {
                config.Cached_Sender_IDs__c = JSON.serialize(senderIds);
            }

            List<String> coverage = KwtSMSClient.getCoverage(username, password);
            if (coverage != null && !coverage.isEmpty()) {
                config.Cached_Coverage__c = JSON.serialize(coverage);
            }

            config.Last_Sync__c = Datetime.now();
            KwtSMSSettingsService.saveConfig(config);
            KwtSMSLogger.logInfo('SYNC', 'Daily sync completed successfully');
        } catch (Exception e) {
            KwtSMSLogger.logError('SYNC', 'Daily sync failed: ' + e.getMessage());
        }
        KwtSMSLogger.flush();
    }
}
