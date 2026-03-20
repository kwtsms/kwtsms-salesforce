@IsTest
private class KwtSMSClientTest {

    private static final String TEST_USERNAME = 'testuser';
    private static final String TEST_PASSWORD = 'testpass';
    private static final String TEST_SENDER  = 'KWT-SMS';
    private static final String TEST_MOBILE  = '96598765432';

    @IsTest
    static void testSend_success() {
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.sendSuccess());
        Test.startTest();
        KwtSMSClient.SendResponse resp = KwtSMSClient.send(
            TEST_MOBILE, 'Hello', TEST_SENDER, TEST_USERNAME, TEST_PASSWORD, false);
        Test.stopTest();

        System.assertEquals('OK', resp.result, 'Result should be OK on successful send');
        System.assertEquals('abc123def456', resp.msgId, 'msg-id should be parsed correctly');
        System.assertEquals(1, resp.numbers, 'numbers should be 1');
        System.assertEquals(1, resp.pointsCharged, 'points-charged should be 1');
        System.assertEquals(149, resp.balanceAfter, 'balance-after should be 149');
        System.assertNull(resp.errorCode, 'errorCode should be null on success');
    }

    @IsTest
    static void testSend_authError() {
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.authError());
        Test.startTest();
        KwtSMSClient.SendResponse resp = KwtSMSClient.send(
            TEST_MOBILE, 'Hello', TEST_SENDER, TEST_USERNAME, TEST_PASSWORD, false);
        Test.stopTest();

        System.assertEquals('ERROR', resp.result, 'Result should be ERROR on auth failure');
        System.assertEquals('ERR003', resp.errorCode, 'errorCode should be ERR003');
        System.assertNotNull(resp.errorDescription, 'errorDescription should not be null');
    }

    @IsTest
    static void testSend_zeroBalance() {
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.zeroBalanceError());
        Test.startTest();
        KwtSMSClient.SendResponse resp = KwtSMSClient.send(
            TEST_MOBILE, 'Hello', TEST_SENDER, TEST_USERNAME, TEST_PASSWORD, false);
        Test.stopTest();

        System.assertEquals('ERROR', resp.result, 'Result should be ERROR on zero balance');
        System.assertEquals('ERR010', resp.errorCode, 'errorCode should be ERR010');
    }

    @IsTest
    static void testGetBalance_success() {
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.balanceSuccess());
        Test.startTest();
        KwtSMSClient.BalanceResponse resp = KwtSMSClient.getBalance(TEST_USERNAME, TEST_PASSWORD);
        Test.stopTest();

        System.assertEquals('OK', resp.result, 'Result should be OK on balance success');
        System.assertEquals(150, resp.available, 'available should be 150');
        System.assertEquals(1000, resp.purchased, 'purchased should be 1000');
        System.assertNull(resp.errorCode, 'errorCode should be null on success');
    }

    @IsTest
    static void testGetBalance_authError() {
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.authError());
        Test.startTest();
        KwtSMSClient.BalanceResponse resp = KwtSMSClient.getBalance(TEST_USERNAME, TEST_PASSWORD);
        Test.stopTest();

        System.assertEquals('ERROR', resp.result, 'Result should be ERROR on auth failure');
        System.assertEquals('ERR003', resp.errorCode, 'errorCode should be ERR003');
    }

    @IsTest
    static void testGetSenderIds_success() {
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.senderIdSuccess());
        Test.startTest();
        List<String> ids = KwtSMSClient.getSenderIds(TEST_USERNAME, TEST_PASSWORD);
        Test.stopTest();

        System.assertEquals(2, ids.size(), 'Should return 2 sender IDs');
        System.assert(ids.contains('KWT-SMS'), 'List should contain KWT-SMS');
        System.assert(ids.contains('MYAPP'), 'List should contain MYAPP');
    }

    @IsTest
    static void testGetCoverage_success() {
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.coverageSuccess());
        Test.startTest();
        List<String> prefixes = KwtSMSClient.getCoverage(TEST_USERNAME, TEST_PASSWORD);
        Test.stopTest();

        System.assertEquals(5, prefixes.size(), 'Should return 5 coverage prefixes');
        System.assert(prefixes.contains('965'), 'Coverage should include 965');
        System.assert(prefixes.contains('966'), 'Coverage should include 966');
        System.assert(prefixes.contains('971'), 'Coverage should include 971');
        System.assert(prefixes.contains('20'),  'Coverage should include 20');
        System.assert(prefixes.contains('44'),  'Coverage should include 44');
    }

    @IsTest
    static void testValidateNumbers_success() {
        Test.setMock(HttpCalloutMock.class, KwtSMSCalloutMock.validateSuccess());
        Test.startTest();
        KwtSMSClient.ValidateResponse resp = KwtSMSClient.validateNumbers(
            TEST_MOBILE + ',0096598765432,966558724477', TEST_USERNAME, TEST_PASSWORD);
        Test.stopTest();

        System.assertEquals('OK', resp.result, 'Result should be OK on validate success');
        System.assertEquals(1, resp.okNumbers.size(), 'okNumbers should have 1 entry');
        System.assertEquals('96598765432', resp.okNumbers[0], 'okNumbers[0] should match valid number');
        System.assertEquals(1, resp.erNumbers.size(), 'erNumbers should have 1 entry');
        System.assertEquals('0096598765432', resp.erNumbers[0], 'erNumbers[0] should match ER number');
        System.assertEquals(1, resp.nrNumbers.size(), 'nrNumbers should have 1 entry');
        System.assertEquals('966558724477', resp.nrNumbers[0], 'nrNumbers[0] should match NR number');
    }

    @IsTest
    static void testSend_setsCorrectHeaders() {
        HeaderCaptureMock captureMock = new HeaderCaptureMock();
        Test.setMock(HttpCalloutMock.class, captureMock);
        Test.startTest();
        KwtSMSClient.send(TEST_MOBILE, 'Hello', TEST_SENDER, TEST_USERNAME, TEST_PASSWORD, false);
        Test.stopTest();

        System.assertEquals('application/json', captureMock.capturedContentType,
            'Content-Type header should be application/json');
        System.assertEquals('application/json', captureMock.capturedAccept,
            'Accept header should be application/json');
    }

    @IsTest
    static void testSend_usesPostMethod() {
        MethodCaptureMock methodMock = new MethodCaptureMock();
        Test.setMock(HttpCalloutMock.class, methodMock);
        Test.startTest();
        KwtSMSClient.send(TEST_MOBILE, 'Hello', TEST_SENDER, TEST_USERNAME, TEST_PASSWORD, false);
        Test.stopTest();

        System.assertEquals('POST', methodMock.capturedMethod,
            'HTTP method should be POST');
    }

    @IsTest
    static void testSend_includesTestFlag() {
        BodyCaptureMock bodyMock = new BodyCaptureMock();
        Test.setMock(HttpCalloutMock.class, bodyMock);
        Test.startTest();
        KwtSMSClient.send(TEST_MOBILE, 'Hello', TEST_SENDER, TEST_USERNAME, TEST_PASSWORD, true);
        Test.stopTest();

        System.assert(bodyMock.capturedBody.contains('"test":"1"'),
            'Request body should include test flag set to 1 when testMode is true');
    }

    // Helper mocks for header/method/body capture

    private class HeaderCaptureMock implements HttpCalloutMock {
        public String capturedContentType;
        public String capturedAccept;
        public HttpResponse respond(HttpRequest req) {
            this.capturedContentType = req.getHeader('Content-Type');
            this.capturedAccept      = req.getHeader('Accept');
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"result":"OK","msg-id":"abc123def456","numbers":1,"points-charged":1,"balance-after":149,"unix-timestamp":1684763355}');
            return res;
        }
    }

    private class MethodCaptureMock implements HttpCalloutMock {
        public String capturedMethod;
        public HttpResponse respond(HttpRequest req) {
            this.capturedMethod = req.getMethod();
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"result":"OK","msg-id":"abc123def456","numbers":1,"points-charged":1,"balance-after":149,"unix-timestamp":1684763355}');
            return res;
        }
    }

    private class BodyCaptureMock implements HttpCalloutMock {
        public String capturedBody;
        public HttpResponse respond(HttpRequest req) {
            this.capturedBody = req.getBody();
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"result":"OK","msg-id":"abc123def456","numbers":1,"points-charged":1,"balance-after":149,"unix-timestamp":1684763355}');
            return res;
        }
    }
}
