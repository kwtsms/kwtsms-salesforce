@IsTest
private class KwtSMSSyncJobTest {

    /**
     * Multi-endpoint mock: returns appropriate JSON based on the request URL.
     */
    private class SyncMultiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            String endpoint = req.getEndpoint();
            if (endpoint.contains('balance/')) {
                res.setBody('{"result":"OK","available":150,"purchased":1000}');
            } else if (endpoint.contains('senderid/')) {
                res.setBody('{"result":"OK","senderid":["KWT-SMS","MYAPP"]}');
            } else if (endpoint.contains('coverage/')) {
                res.setBody('{"result":"OK","coverage":["965","966","971","20","44"]}');
            } else {
                res.setBody('{"result":"OK"}');
            }
            return res;
        }
    }

    @TestSetup
    static void makeData() {
        KwtSMS_Config__c config = new KwtSMS_Config__c();
        config.Gateway_Connected__c = true;
        config.Cached_Balance__c = 100;
        upsert config;
    }

    @IsTest
    static void testExecute_enqueuesQueueable() {
        Test.setMock(HttpCalloutMock.class, new SyncMultiMock());

        KwtSMS_Config__c config = KwtSMS_Config__c.getOrgDefaults();
        config.Gateway_Connected__c = true;
        upsert config;

        Test.startTest();
        KwtSMSSyncJob job = new KwtSMSSyncJob();
        job.execute(null);
        Test.stopTest();

        // After stopTest, async jobs (Queueable) have run.
        // Verify the sync result: Last_Sync__c should be set.
        KwtSMS_Config__c updated = KwtSMS_Config__c.getOrgDefaults();
        System.assertNotEquals(null, updated.Last_Sync__c,
            'Last_Sync__c should be set after Queueable runs');
    }

    @IsTest
    static void testExecute_skipsWhenNotConnected() {
        KwtSMS_Config__c config = KwtSMS_Config__c.getOrgDefaults();
        config.Gateway_Connected__c = false;
        upsert config;

        Test.startTest();
        KwtSMSSyncJob job = new KwtSMSSyncJob();
        job.execute(null);
        Test.stopTest();

        // Last_Sync__c should remain null since we skipped.
        KwtSMS_Config__c updated = KwtSMS_Config__c.getOrgDefaults();
        System.assertEquals(null, updated.Last_Sync__c,
            'Last_Sync__c should not be set when gateway is not connected');
    }

    @IsTest
    static void testSyncQueueable_updatesBalance() {
        Test.setMock(HttpCalloutMock.class, new SyncMultiMock());

        Test.startTest();
        System.enqueueJob(new KwtSMSSyncQueueable());
        Test.stopTest();

        KwtSMS_Config__c updated = KwtSMS_Config__c.getOrgDefaults();
        System.assertEquals(150, updated.Cached_Balance__c,
            'Cached balance should be updated to 150');
    }

    @IsTest
    static void testSyncQueueable_updatesSenderIds() {
        Test.setMock(HttpCalloutMock.class, new SyncMultiMock());

        Test.startTest();
        System.enqueueJob(new KwtSMSSyncQueueable());
        Test.stopTest();

        KwtSMS_Config__c updated = KwtSMS_Config__c.getOrgDefaults();
        System.assertNotEquals(null, updated.Cached_Sender_IDs__c,
            'Cached sender IDs should be set');
        List<String> ids = (List<String>) JSON.deserialize(
            updated.Cached_Sender_IDs__c, List<String>.class);
        System.assert(ids.contains('KWT-SMS'), 'KWT-SMS should be in sender IDs');
        System.assert(ids.contains('MYAPP'), 'MYAPP should be in sender IDs');
    }

    @IsTest
    static void testSyncQueueable_updatesLastSync() {
        Test.setMock(HttpCalloutMock.class, new SyncMultiMock());

        Datetime beforeSync = Datetime.now();

        Test.startTest();
        System.enqueueJob(new KwtSMSSyncQueueable());
        Test.stopTest();

        KwtSMS_Config__c updated = KwtSMS_Config__c.getOrgDefaults();
        System.assertNotEquals(null, updated.Last_Sync__c,
            'Last_Sync__c should be set after sync');
        System.assert(updated.Last_Sync__c >= beforeSync,
            'Last_Sync__c should be at or after the sync start time');
    }

    @IsTest
    static void testSchedule_returnsJobId() {
        Test.startTest();
        Id jobId = KwtSMSSyncJob.schedule();
        Test.stopTest();

        System.assertNotEquals(null, jobId,
            'schedule() should return a non-null job ID');

        // Clean up the scheduled job
        List<CronTrigger> jobs = [
            SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = :KwtSMSSyncJob.JOB_NAME
        ];
        if (!jobs.isEmpty()) {
            System.abortJob(jobs[0].Id);
        }
    }
}
