public with sharing class KwtSMSSendAction {

    public class SMSRequest {
        @InvocableVariable(label='Phone Number' required=true)
        public String phoneNumber;

        @InvocableVariable(label='Message Body' required=true)
        public String messageBody;

        @InvocableVariable(label='Sender ID' required=false)
        public String senderId;
    }

    public class SMSResult {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Message ID')
        public String messageId;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Send SMS via kwtSMS'
        description='Sends an SMS message through the kwtSMS gateway'
        category='Messaging'
        callout=true
    )
    public static List<SMSResult> sendSMS(List<SMSRequest> requests) {
        List<SMSResult> results = new List<SMSResult>();
        Integer SAFE_THRESHOLD = 90;

        List<SMSRequest> currentBatch = new List<SMSRequest>();
        List<SMSRequest> overflow = new List<SMSRequest>();

        for (Integer i = 0; i < requests.size(); i++) {
            if (i < SAFE_THRESHOLD) {
                currentBatch.add(requests[i]);
            } else {
                overflow.add(requests[i]);
            }
        }

        // Process current batch - each request individually
        for (SMSRequest req : currentBatch) {
            SMSResult res = new SMSResult();
            try {
                List<String> phones = new List<String>{ req.phoneNumber };
                KwtSMSEngine.SendResult sendResult = KwtSMSEngine.send(phones, req.messageBody, req.senderId);
                res.success = (sendResult.status == 'Sent');
                res.messageId = sendResult.msgId;
                res.errorMessage = sendResult.errorMessage;
            } catch (Exception e) {
                res.success = false;
                res.errorMessage = e.getMessage();
            }
            results.add(res);
        }

        // Enqueue overflow if any
        if (!overflow.isEmpty()) {
            List<String> overflowPhones = new List<String>();
            String overflowMessage = overflow[0].messageBody;
            String overflowSender = overflow[0].senderId;
            for (SMSRequest req : overflow) {
                overflowPhones.add(req.phoneNumber);
            }
            System.enqueueJob(new KwtSMSBulkSendQueueable(overflowPhones, overflowMessage, overflowSender, 1));
            // Placeholder results for overflow
            for (SMSRequest req : overflow) {
                SMSResult res = new SMSResult();
                res.success = true;
                res.errorMessage = 'Queued for async processing';
                results.add(res);
            }
        }

        return results;
    }
}
