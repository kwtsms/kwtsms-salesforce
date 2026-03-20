public with sharing class KwtSMSLogger {
    private static List<SMS_Log__c> buffer = new List<SMS_Log__c>();

    /**
     * Log a full SMS send attempt with all fields.
     */
    public static void logSend(String phone, String message, String status,
            String errorCode, String errorMessage, String eventType,
            String msgId, Decimal pointsCharged, Decimal balanceAfter,
            String relatedRecordId, String relatedObjectType,
            String senderId, Boolean testMode, String apiResponse) {
        if (!shouldLog('INFO')) return;
        SMS_Log__c logRecord = new SMS_Log__c();
        logRecord.Phone__c = phone;
        logRecord.Message__c = message != null ? message.left(1000) : null;
        logRecord.Status__c = status;
        logRecord.Error_Code__c = errorCode;
        logRecord.Error_Message__c = errorMessage != null ? errorMessage.left(255) : null;
        logRecord.Event_Type__c = eventType;
        logRecord.Message_ID__c = msgId;
        logRecord.Points_Charged__c = pointsCharged;
        logRecord.Balance_After__c = balanceAfter;
        logRecord.Related_Record_ID__c = relatedRecordId;
        logRecord.Related_Object_Type__c = relatedObjectType;
        logRecord.Sender_ID__c = senderId;
        logRecord.Test_Mode__c = testMode != null ? testMode : false;
        logRecord.API_Response__c = stripCredentials(apiResponse);
        logRecord.Log_Level__c = status == 'Failed' ? 'ERROR' : 'INFO';
        buffer.add(logRecord);
    }

    /**
     * Log an informational message (non-send events like login, sync, guards).
     */
    public static void logInfo(String eventType, String detail) {
        logSimple('INFO', eventType, detail);
    }

    /**
     * Log an error.
     */
    public static void logError(String eventType, String detail) {
        logSimple('ERROR', eventType, detail);
    }

    /**
     * Log a debug message (only when Debug Logging is ON).
     */
    public static void logDebug(String eventType, String detail) {
        logSimple('DEBUG', eventType, detail);
    }

    private static void logSimple(String level, String eventType, String detail) {
        if (!shouldLog(level)) return;
        SMS_Log__c logRecord = new SMS_Log__c();
        logRecord.Event_Type__c = eventType;
        logRecord.Message__c = detail != null ? detail.left(1000) : null;
        logRecord.Log_Level__c = level;
        logRecord.Status__c = level == 'ERROR' ? 'Failed' : 'Sent';
        buffer.add(logRecord);
    }

    /**
     * Flush all buffered log records to the database.
     * Call this at the end of every transaction.
     * Uses Security.stripInaccessible for CRUD/FLS compliance.
     */
    public static void flush() {
        if (!buffer.isEmpty()) {
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.CREATABLE, buffer);
            insert decision.getRecords();
            buffer.clear();
        }
    }

    /**
     * Check if a log level should be recorded.
     * ERROR, WARN, INFO are always logged.
     * DEBUG is only logged when Debug_Logging__c is ON.
     */
    @TestVisible
    private static Boolean shouldLog(String level) {
        if (level == 'ERROR' || level == 'WARN' || level == 'INFO') {
            return true;
        }
        if (level == 'DEBUG') {
            KwtSMS_Config__c config = KwtSMS_Config__c.getOrgDefaults();
            return config != null && config.Debug_Logging__c;
        }
        return false;
    }

    /**
     * Strip username and password from API response JSON before logging.
     */
    @TestVisible
    private static String stripCredentials(String apiResponse) {
        if (String.isBlank(apiResponse)) return apiResponse;
        apiResponse = apiResponse.replaceAll('"username"\\s*:\\s*"[^"]*"', '"username":"***"');
        apiResponse = apiResponse.replaceAll('"password"\\s*:\\s*"[^"]*"', '"password":"***"');
        return apiResponse;
    }

    /**
     * Get buffer size for testing.
     */
    @TestVisible
    private static Integer getBufferSize() {
        return buffer.size();
    }

    /**
     * Clear buffer without flushing (for testing).
     */
    @TestVisible
    private static void clearBuffer() {
        buffer.clear();
    }
}
