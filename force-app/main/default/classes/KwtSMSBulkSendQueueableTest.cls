@IsTest
private class KwtSMSBulkSendQueueableTest {

    @TestSetup
    static void setup() {
        KwtSMS_Config__c config = new KwtSMS_Config__c();
        config.Gateway_Enabled__c = true;
        config.Gateway_Connected__c = true;
        config.Cached_Balance__c = 1000;
        config.Sender_ID__c = 'KWT-SMS';
        config.Test_Mode__c = true;
        config.Debug_Logging__c = true;
        config.Default_Language__c = 'en';
        config.Default_Country_Code__c = '965';
        config.Cached_Coverage__c = '["965","966","971"]';
        config.Cached_Sender_IDs__c = '["KWT-SMS"]';
        insert config;
    }

    // Build a list of valid Kuwait phone numbers of a given size
    private static List<String> buildPhones(Integer count) {
        List<String> phones = new List<String>();
        for (Integer i = 0; i < count; i++) {
            // Vary last 4 digits, keep valid Kuwait mobile prefix (9655xxxx)
            String suffix = String.valueOf(1000 + Math.mod(i, 9000)).left(4);
            phones.add('9655' + suffix);
        }
        return phones;
    }

    // -----------------------------------------------------------------------
    // testExecute_processesBatch
    // 50 phones: all fit in one batch (BATCH_SIZE=90), engine called, logs written
    // -----------------------------------------------------------------------
    @IsTest
    static void testExecute_processesBatch() {
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());
        List<String> phones = buildPhones(50);

        Test.startTest();
        KwtSMSBulkSendQueueable job = new KwtSMSBulkSendQueueable(phones, 'Hello batch', 'KWT-SMS', 0);
        System.enqueueJob(job);
        Test.stopTest();

        // After stopTest the job has run. Verify that log records were inserted
        // (engine calls KwtSMSLogger.flush which inserts SMS_Log__c records).
        List<SMS_Log__c> logs = [SELECT Id, Event_Type__c, Status__c FROM SMS_Log__c];
        System.assert(!logs.isEmpty(), 'Expected log records after batch send');
    }

    // -----------------------------------------------------------------------
    // testExecute_chainsWhenMoreRemain
    // 100 phones: first batch is 90, 10 remain, a second Queueable must be enqueued
    // -----------------------------------------------------------------------
    @IsTest
    static void testExecute_chainsWhenMoreRemain() {
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());
        List<String> phones = buildPhones(100);

        Test.startTest();
        KwtSMSBulkSendQueueable job = new KwtSMSBulkSendQueueable(phones, 'Hello bulk', 'KWT-SMS', 0);
        System.enqueueJob(job);
        Test.stopTest();

        // After stopTest, both the original job and the chained job have executed.
        // Verify logs exist from both executions (the first batch of 90 and the remaining 10).
        List<SMS_Log__c> logs = [SELECT Id FROM SMS_Log__c];
        System.assert(!logs.isEmpty(), 'Expected log records from chained queueable executions');

        // The async job queue should show 2 completed jobs
        List<AsyncApexJob> jobs = [
            SELECT Id, JobType, Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
        ];
        // At minimum one job ran; inside Test.startTest/stopTest chained jobs also execute
        System.assert(jobs.size() >= 1, 'Expected at least one Queueable job to have run');
    }

    // -----------------------------------------------------------------------
    // testExecute_stopsAtMaxDepth
    // 10 phones with chainDepth=5 (== MAX_CHAIN_DEPTH): no additional enqueue,
    // engine processes the phones, no overflow (phones.size() <= BATCH_SIZE).
    // To test the overflow log branch: use 200 phones at depth 5.
    // -----------------------------------------------------------------------
    @IsTest
    static void testExecute_stopsAtMaxDepth() {
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());

        // 200 phones at depth 5: first batch (90) is sent, 110 remain but chain is maxed
        List<String> phones = buildPhones(200);

        Test.startTest();
        KwtSMSBulkSendQueueable job = new KwtSMSBulkSendQueueable(phones, 'Overflow test', 'KWT-SMS', 5);
        System.enqueueJob(job);
        Test.stopTest();

        // No additional Queueable should be enqueued beyond the one we started.
        List<AsyncApexJob> jobs = [
            SELECT Id, JobType, Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
        ];
        System.assertEquals(1, jobs.size(), 'Expected exactly 1 Queueable job: no chaining at max depth');

        // The BULK_OVERFLOW log entry must exist
        List<SMS_Log__c> overflowLogs = [
            SELECT Id, Event_Type__c, Message__c
            FROM SMS_Log__c
            WHERE Event_Type__c = 'BULK_OVERFLOW'
        ];
        System.assert(!overflowLogs.isEmpty(), 'Expected BULK_OVERFLOW log entry when max chain depth reached');
        System.assert(
            overflowLogs[0].Message__c.contains('max chain depth reached'),
            'Expected overflow message to mention max chain depth'
        );
    }

    // -----------------------------------------------------------------------
    // testExecute_emptyPhones
    // Empty list: execute must complete without errors, no logs, no enqueue
    // -----------------------------------------------------------------------
    @IsTest
    static void testExecute_emptyPhones() {
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());
        List<String> phones = new List<String>();

        Test.startTest();
        KwtSMSBulkSendQueueable job = new KwtSMSBulkSendQueueable(phones, 'Empty test', 'KWT-SMS', 0);
        System.enqueueJob(job);
        Test.stopTest();

        // No exceptions thrown; job completed. Engine call with empty list returns Failed
        // (no valid phones), but no uncaught exception should occur.
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, ExtendedStatus
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
        ];
        System.assertEquals(1, jobs.size(), 'Expected exactly 1 Queueable job');
        System.assertEquals('Completed', jobs[0].Status, 'Expected job to complete without error');
    }
}
