public with sharing class KwtSMSSyncJob implements Schedulable {
    public static final String CRON_EXPRESSION = '0 0 7 * * ?';
    public static final String JOB_NAME = 'kwtSMS Daily Sync';

    public void execute(SchedulableContext sc) {
        KwtSMS_Config__c config = KwtSMSSettingsService.getConfig();
        if (!config.Gateway_Connected__c) {
            KwtSMSLogger.logInfo('SYNC', 'Skipped: gateway not connected');
            KwtSMSLogger.flush();
            return;
        }
        System.enqueueJob(new KwtSMSSyncQueueable());
    }

    public static Id schedule() {
        return System.schedule(JOB_NAME, CRON_EXPRESSION, new KwtSMSSyncJob());
    }
}
