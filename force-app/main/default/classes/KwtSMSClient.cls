public with sharing class KwtSMSClient {
    private static final String BASE_URL = 'https://www.kwtsms.com/API/';
    private static final Integer TIMEOUT_MS = 30000;

    // Response wrapper classes
    public class SendResponse {
        public String result;
        public String msgId;
        public Integer numbers;
        public Integer pointsCharged;
        public Decimal balanceAfter;
        public String errorCode;
        public String errorDescription;
    }

    public class BalanceResponse {
        public String result;
        public Decimal available;
        public Decimal purchased;
        public String errorCode;
        public String errorDescription;
    }

    public class ValidateResponse {
        public String result;
        public List<String> okNumbers;
        public List<String> erNumbers;
        public List<String> nrNumbers;
    }

    /**
     * Send SMS to one or more numbers (comma-separated, max 200).
     */
    public static SendResponse send(String mobile, String message,
            String sender, String username, String password, Boolean testMode) {
        Map<String, Object> body = new Map<String, Object>{
            'username' => username,
            'password' => password,
            'sender' => sender,
            'mobile' => mobile,
            'message' => message,
            'test' => testMode ? '1' : '0'
        };
        String responseBody = doPost('send/', body);
        return parseSendResponse(responseBody);
    }

    /**
     * Get account balance.
     */
    public static BalanceResponse getBalance(String username, String password) {
        Map<String, Object> body = new Map<String, Object>{
            'username' => username,
            'password' => password
        };
        String responseBody = doPost('balance/', body);
        return parseBalanceResponse(responseBody);
    }

    /**
     * Get available sender IDs.
     */
    public static List<String> getSenderIds(String username, String password) {
        Map<String, Object> body = new Map<String, Object>{
            'username' => username,
            'password' => password
        };
        String responseBody = doPost('senderid/', body);
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        if (parsed.get('result') == 'OK' && parsed.containsKey('senderid')) {
            List<Object> ids = (List<Object>) parsed.get('senderid');
            List<String> result = new List<String>();
            for (Object id : ids) {
                result.add(String.valueOf(id));
            }
            return result;
        }
        return new List<String>();
    }

    /**
     * Get active country coverage prefixes.
     */
    public static List<String> getCoverage(String username, String password) {
        Map<String, Object> body = new Map<String, Object>{
            'username' => username,
            'password' => password
        };
        String responseBody = doPost('coverage/', body);
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        if (parsed.get('result') == 'OK' && parsed.containsKey('coverage')) {
            List<Object> prefixes = (List<Object>) parsed.get('coverage');
            List<String> result = new List<String>();
            for (Object p : prefixes) {
                result.add(String.valueOf(p));
            }
            return result;
        }
        return new List<String>();
    }

    /**
     * Validate phone numbers.
     */
    public static ValidateResponse validateNumbers(String mobile,
            String username, String password) {
        Map<String, Object> body = new Map<String, Object>{
            'username' => username,
            'password' => password,
            'mobile' => mobile
        };
        String responseBody = doPost('validate/', body);
        return parseValidateResponse(responseBody);
    }

    // Core HTTP POST
    private static String doPost(String endpoint, Map<String, Object> body) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(TIMEOUT_MS);
        req.setBody(JSON.serialize(body));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new CalloutException('HTTP ' + res.getStatusCode() + ': ' + res.getStatus());
        }
        return res.getBody();
    }

    private static SendResponse parseSendResponse(String body) {
        SendResponse resp = new SendResponse();
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
        resp.result = (String) parsed.get('result');
        if (resp.result == 'OK') {
            resp.msgId = (String) parsed.get('msg-id');
            resp.numbers = parsed.get('numbers') != null ? Integer.valueOf(parsed.get('numbers')) : 0;
            resp.pointsCharged = parsed.get('points-charged') != null ? Integer.valueOf(parsed.get('points-charged')) : 0;
            resp.balanceAfter = parsed.get('balance-after') != null ? Decimal.valueOf(String.valueOf(parsed.get('balance-after'))) : 0;
        } else {
            resp.errorCode = (String) parsed.get('code');
            resp.errorDescription = (String) parsed.get('description');
        }
        return resp;
    }

    private static BalanceResponse parseBalanceResponse(String body) {
        BalanceResponse resp = new BalanceResponse();
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
        resp.result = (String) parsed.get('result');
        if (resp.result == 'OK') {
            resp.available = parsed.get('available') != null ? Decimal.valueOf(String.valueOf(parsed.get('available'))) : 0;
            resp.purchased = parsed.get('purchased') != null ? Decimal.valueOf(String.valueOf(parsed.get('purchased'))) : 0;
        } else {
            resp.errorCode = (String) parsed.get('code');
            resp.errorDescription = (String) parsed.get('description');
        }
        return resp;
    }

    private static ValidateResponse parseValidateResponse(String body) {
        ValidateResponse resp = new ValidateResponse();
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
        resp.result = (String) parsed.get('result');
        resp.okNumbers = new List<String>();
        resp.erNumbers = new List<String>();
        resp.nrNumbers = new List<String>();
        if (resp.result == 'OK' && parsed.containsKey('mobile')) {
            Map<String, Object> mobile = (Map<String, Object>) parsed.get('mobile');
            if (mobile.containsKey('OK')) {
                for (Object n : (List<Object>) mobile.get('OK')) {
                    resp.okNumbers.add(String.valueOf(n));
                }
            }
            if (mobile.containsKey('ER')) {
                for (Object n : (List<Object>) mobile.get('ER')) {
                    resp.erNumbers.add(String.valueOf(n));
                }
            }
            if (mobile.containsKey('NR')) {
                for (Object n : (List<Object>) mobile.get('NR')) {
                    resp.nrNumbers.add(String.valueOf(n));
                }
            }
        }
        return resp;
    }
}
