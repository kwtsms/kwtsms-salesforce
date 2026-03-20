@IsTest
public class KwtSMSCalloutMock implements HttpCalloutMock {
    private String responseBody;
    private Integer statusCode;

    public KwtSMSCalloutMock(String responseBody, Integer statusCode) {
        this.responseBody = responseBody;
        this.statusCode = statusCode;
    }

    public HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setBody(this.responseBody);
        res.setStatusCode(this.statusCode);
        res.setHeader('Content-Type', 'application/json');
        return res;
    }

    public static KwtSMSCalloutMock sendSuccess() {
        return new KwtSMSCalloutMock(
            '{"result":"OK","msg-id":"abc123def456","numbers":1,"points-charged":1,"balance-after":149,"unix-timestamp":1684763355}',
            200);
    }

    public static KwtSMSCalloutMock balanceSuccess() {
        return new KwtSMSCalloutMock(
            '{"result":"OK","available":150,"purchased":1000}', 200);
    }

    public static KwtSMSCalloutMock senderIdSuccess() {
        return new KwtSMSCalloutMock(
            '{"result":"OK","senderid":["KWT-SMS","MYAPP"]}', 200);
    }

    public static KwtSMSCalloutMock coverageSuccess() {
        return new KwtSMSCalloutMock(
            '{"result":"OK","coverage":["965","966","971","20","44"]}', 200);
    }

    public static KwtSMSCalloutMock validateSuccess() {
        return new KwtSMSCalloutMock(
            '{"result":"OK","mobile":{"OK":["96598765432"],"ER":["0096598765432"],"NR":["966558724477"]}}', 200);
    }

    public static KwtSMSCalloutMock authError() {
        return new KwtSMSCalloutMock(
            '{"result":"ERROR","code":"ERR003","description":"Authentication error, username or password are not correct."}',
            200);
    }

    public static KwtSMSCalloutMock zeroBalanceError() {
        return new KwtSMSCalloutMock(
            '{"result":"ERROR","code":"ERR010","description":"Zero balance."}', 200);
    }
}
