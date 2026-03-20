public with sharing class KwtSMSMessageUtils {

    public class PageInfo {
        @AuraEnabled public String encoding;
        @AuraEnabled public Integer charCount;
        @AuraEnabled public Integer pageCount;
        @AuraEnabled public Integer charsRemaining;
    }

    public static String cleanMessage(String message) {
        if (message == null || String.isBlank(message)) {
            return '';
        }

        // Strip HTML tags
        message = message.replaceAll('<[^>]+>', '');

        // Strip emoji - common Unicode ranges
        message = message.replaceAll('[\\x{1F600}-\\x{1F64F}]', ''); // Emoticons
        message = message.replaceAll('[\\x{1F300}-\\x{1F5FF}]', ''); // Misc Symbols and Pictographs
        message = message.replaceAll('[\\x{1F680}-\\x{1F6FF}]', ''); // Transport and Map Symbols
        message = message.replaceAll('[\\x{1F900}-\\x{1F9FF}]', ''); // Supplemental Symbols and Pictographs
        message = message.replaceAll('[\\x{2600}-\\x{26FF}]', '');   // Miscellaneous Symbols
        message = message.replaceAll('[\\x{2700}-\\x{27BF}]', '');   // Dingbats

        // Strip hidden control characters
        message = message.replaceAll('[\\x{200B}-\\x{200F}\\x{FEFF}\\x{00AD}]', '');

        // Convert Arabic-Indic digits (U+0660-U+0669) and Extended Arabic-Indic (U+06F0-U+06F9) to Latin digits
        for (Integer i = 0; i < 10; i++) {
            message = message.replace(String.fromCharArray(new List<Integer>{0x0660 + i}), String.valueOf(i));
            message = message.replace(String.fromCharArray(new List<Integer>{0x06F0 + i}), String.valueOf(i));
        }

        // Trim whitespace
        message = message.trim();

        return message;
    }

    public static Boolean isArabic(String message) {
        if (message == null || String.isBlank(message)) {
            return false;
        }
        Pattern arabicPattern = Pattern.compile('[\\x{0600}-\\x{06FF}]');
        return arabicPattern.matcher(message).find();
    }

    public static PageInfo calculatePages(String message) {
        PageInfo info = new PageInfo();

        if (message == null || String.isBlank(message)) {
            info.encoding = 'English';
            info.charCount = 0;
            info.pageCount = 0;
            info.charsRemaining = 0;
            return info;
        }

        info.charCount = message.length();

        if (isArabic(message)) {
            info.encoding = 'Arabic';
            Integer firstPage = 70;
            Integer subsequent = 67;

            if (info.charCount <= firstPage) {
                info.pageCount = 1;
                info.charsRemaining = firstPage - info.charCount;
            } else {
                Integer extra = info.charCount - firstPage;
                // Integer ceiling division: (extra + subsequent - 1) / subsequent
                Integer extraPages = (extra + subsequent - 1) / subsequent;
                info.pageCount = 1 + extraPages;
                Integer usedInLastPage = extra - ((extraPages - 1) * subsequent);
                info.charsRemaining = subsequent - usedInLastPage;
            }
        } else {
            info.encoding = 'English';
            Integer firstPage = 160;
            Integer subsequent = 153;

            if (info.charCount <= firstPage) {
                info.pageCount = 1;
                info.charsRemaining = firstPage - info.charCount;
            } else {
                Integer extra = info.charCount - firstPage;
                Integer extraPages = (extra + subsequent - 1) / subsequent;
                info.pageCount = 1 + extraPages;
                Integer usedInLastPage = extra - ((extraPages - 1) * subsequent);
                info.charsRemaining = subsequent - usedInLastPage;
            }
        }

        return info;
    }

    public static Boolean validateLength(String message) {
        PageInfo info = calculatePages(message);
        return info.pageCount <= 7;
    }
}
