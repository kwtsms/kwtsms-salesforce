public with sharing class KwtSMSBulkSendQueueable implements Queueable, Database.AllowsCallouts {
    private static final Integer BATCH_SIZE = 90;
    private static final Integer MAX_CHAIN_DEPTH = 5;

    private List<String> phones;
    private String message;
    private String senderId;
    private Integer chainDepth;

    public KwtSMSBulkSendQueueable(List<String> phones, String message, String senderId, Integer chainDepth) {
        this.phones = phones;
        this.message = message;
        this.senderId = senderId;
        this.chainDepth = chainDepth;
    }

    public void execute(QueueableContext context) {
        Integer endIndex = Math.min(BATCH_SIZE, phones.size());
        List<String> batch = new List<String>();
        for (Integer i = 0; i < endIndex; i++) {
            batch.add(phones[i]);
        }

        // Send this batch via engine
        KwtSMSEngine.send(batch, message, senderId);

        // Handle remaining
        if (endIndex < phones.size()) {
            List<String> remaining = new List<String>();
            for (Integer i = endIndex; i < phones.size(); i++) {
                remaining.add(phones[i]);
            }

            if (chainDepth < MAX_CHAIN_DEPTH) {
                System.enqueueJob(new KwtSMSBulkSendQueueable(remaining, message, senderId, chainDepth + 1));
            } else {
                // Log overflow as skipped
                KwtSMSLogger.logInfo('BULK_OVERFLOW', remaining.size() + ' numbers skipped, max chain depth reached');
                KwtSMSLogger.flush();
            }
        }
    }
}
