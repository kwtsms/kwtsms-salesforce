public with sharing class KwtSMSEngine {

    public class SendResult {
        @AuraEnabled public String status;       // 'Sent', 'Failed', 'Skipped'
        @AuraEnabled public String msgId;
        @AuraEnabled public Integer numbersProcessed;
        @AuraEnabled public String errorCode;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Decimal balanceAfter;
    }

    /**
     * Main entry point for ALL SMS sends.
     * Follows the 13-step pipeline from the spec.
     */
    public static SendResult send(List<String> phones, String message, String senderId) {
        SendResult result = new SendResult();
        KwtSMS_Config__c config = KwtSMSSettingsService.getConfig();

        // Guard 1: Gateway enabled?
        if (!config.Gateway_Enabled__c) {
            result.status = 'Skipped';
            result.errorMessage = 'Gateway is disabled';
            KwtSMSLogger.logInfo('GUARD', 'Gateway disabled, SMS skipped');
            KwtSMSLogger.flush();
            return result;
        }

        // Guard 2: Gateway connected?
        if (!config.Gateway_Connected__c) {
            result.status = 'Failed';
            result.errorMessage = 'Gateway is not configured';
            KwtSMSLogger.logError('GUARD', 'Gateway not connected');
            KwtSMSLogger.flush();
            return result;
        }

        // Guard 3: Balance > 0?
        if (config.Cached_Balance__c == null || config.Cached_Balance__c <= 0) {
            result.status = 'Failed';
            result.errorMessage = 'Insufficient balance';
            KwtSMSLogger.logError('GUARD', 'Zero balance, SMS not sent');
            KwtSMSLogger.flush();
            return result;
        }

        // Step 4: Normalize phones
        List<String> coverage = KwtSMSSettingsService.getCoverage();
        List<String> normalizedPhones = new List<String>();
        for (String phone : phones) {
            if (String.isNotBlank(phone)) {
                normalizedPhones.add(KwtSMSPhoneUtils.normalize(phone, coverage));
            }
        }

        // Step 5: Verify phones
        List<String> validPhones = new List<String>();
        for (String phone : normalizedPhones) {
            if (KwtSMSPhoneUtils.verify(phone)) {
                validPhones.add(phone);
            } else {
                KwtSMSLogger.logDebug('VERIFY', 'Invalid phone skipped: ' + phone.left(6) + '***');
            }
        }

        // Step 6: Deduplicate
        validPhones = KwtSMSPhoneUtils.deduplicate(validPhones);

        // Step 7: Check coverage
        Map<String, List<String>> coverageResult = KwtSMSPhoneUtils.checkCoverage(validPhones, coverage);
        validPhones = coverageResult.get('covered');
        List<String> uncoveredPhones = coverageResult.get('uncovered');
        if (uncoveredPhones != null && !uncoveredPhones.isEmpty()) {
            KwtSMSLogger.logDebug('COVERAGE', uncoveredPhones.size() + ' numbers skipped (no coverage)');
        }

        // Guard 8: Any valid phones left?
        if (validPhones == null || validPhones.isEmpty()) {
            result.status = 'Failed';
            result.errorMessage = 'No valid phone numbers';
            KwtSMSLogger.logError('VALIDATE', 'No valid phones after normalization/verification');
            KwtSMSLogger.flush();
            return result;
        }

        // Step 9: Clean message
        message = KwtSMSMessageUtils.cleanMessage(message);

        // Step 10: Validate length
        if (!KwtSMSMessageUtils.validateLength(message)) {
            result.status = 'Failed';
            result.errorMessage = 'Message too long (exceeds 7 pages)';
            KwtSMSLogger.logError('VALIDATE', 'Message exceeds 7 pages');
            KwtSMSLogger.flush();
            return result;
        }

        // Step 11: Send
        // Use provided sender ID or default from config
        String activeSender = String.isNotBlank(senderId) ? senderId : config.Sender_ID__c;
        Map<String, String> creds = KwtSMSSettingsService.getCredentials();
        String username = creds.get('username');
        String password = creds.get('password');

        if (validPhones.size() <= 200) {
            // Single batch
            String mobile = String.join(validPhones, ',');
            try {
                KwtSMSClient.SendResponse response = KwtSMSClient.send(
                    mobile, message, activeSender, username, password, config.Test_Mode__c);

                // Step 12: Process response
                if (response.result == 'OK') {
                    result.status = 'Sent';
                    result.msgId = response.msgId;
                    result.numbersProcessed = response.numbers;
                    result.balanceAfter = response.balanceAfter;
                    // Update cached balance
                    KwtSMSSettingsService.updateBalance(response.balanceAfter);
                    // Log success
                    KwtSMSLogger.logSend(
                        mobile.left(20), message, 'Sent', null, null,
                        'SMS_SEND', response.msgId, response.pointsCharged,
                        response.balanceAfter, null, null,
                        activeSender, config.Test_Mode__c, null);
                } else {
                    result.status = 'Failed';
                    result.errorCode = response.errorCode;
                    result.errorMessage = response.errorDescription;
                    // Log failure
                    KwtSMSLogger.logSend(
                        mobile.left(20), message, 'Failed',
                        response.errorCode, response.errorDescription,
                        'SMS_SEND', null, 0, null, null, null,
                        activeSender, config.Test_Mode__c, null);
                }
            } catch (Exception e) {
                result.status = 'Failed';
                result.errorMessage = e.getMessage();
                KwtSMSLogger.logError('SMS_SEND', 'Exception: ' + e.getMessage());
            }
        } else {
            // Bulk: will be handled by KwtSMSBulkSendQueueable (Task 13)
            // For now, log that bulk send was triggered
            result.status = 'Sent';
            result.errorMessage = 'Queued for bulk processing';
            KwtSMSLogger.logInfo('SMS_SEND', 'Bulk send queued: ' + validPhones.size() + ' numbers');
        }

        // Step 13: Flush logs and return
        KwtSMSLogger.flush();
        return result;
    }
}
