public with sharing class KwtSMSPhoneUtils {

    /**
     * Normalize a phone number: convert Arabic-Indic digits, strip non-digits,
     * strip leading zeros.
     */
    public static String normalize(String phone) {
        if (phone == null) {
            return '';
        }

        // Convert Arabic-Indic digits (U+0660-U+0669) to Latin
        String result = '';
        for (Integer i = 0; i < phone.length(); i++) {
            Integer cp = phone.charAt(i);
            if (cp >= 0x0660 && cp <= 0x0669) {
                result += String.valueOf(cp - 0x0660);
            } else if (cp >= 0x06F0 && cp <= 0x06F9) {
                result += String.valueOf(cp - 0x06F0);
            } else {
                result += phone.substring(i, i + 1);
            }
        }

        // Strip all non-digit characters
        result = result.replaceAll('[^0-9]', '');

        // Strip leading zeros
        result = result.replaceFirst('^0+', '');

        return result;
    }

    /**
     * Normalize a phone number with coverage-aware local zero stripping.
     * If the cleaned number starts with a known country prefix and the digit
     * immediately after the prefix is 0, that zero is removed.
     */
    public static String normalize(String phone, List<String> coverage) {
        String cleaned = normalize(phone);

        if (coverage != null && !cleaned.equals('')) {
            for (String prefix : coverage) {
                if (cleaned.startsWith(prefix) && cleaned.length() > prefix.length()) {
                    String afterPrefix = cleaned.substring(prefix.length());
                    if (afterPrefix.startsWith('0')) {
                        cleaned = prefix + afterPrefix.substring(1);
                    }
                    break;
                }
            }
        }

        return cleaned;
    }

    /**
     * Verify whether a phone number is valid for sending SMS.
     * Performs length, all-same-digit, and Kuwait-specific prefix checks.
     */
    public static Boolean verify(String phone) {
        if (phone == null || phone.trim().equals('')) {
            return false;
        }

        // Length check: 8-15 digits
        Integer len = phone.length();
        if (len < 8 || len > 15) {
            return false;
        }

        // All-same-digit check
        Boolean allSame = true;
        String firstChar = phone.substring(0, 1);
        for (Integer i = 1; i < phone.length(); i++) {
            if (!phone.substring(i, i + 1).equals(firstChar)) {
                allSame = false;
                break;
            }
        }
        if (allSame) {
            return false;
        }

        // Kuwait-specific validation: 965 + 8 digits = 11 digits total
        // Mobile prefixes after 965: 4, 5, 6, 9
        if (phone.startsWith('965')) {
            if (phone.length() != 11) {
                return false;
            }
            String mobilePrefixChar = phone.substring(3, 4);
            Set<String> kuwaitMobilePrefixes = new Set<String>{'4', '5', '6', '9'};
            if (!kuwaitMobilePrefixes.contains(mobilePrefixChar)) {
                return false;
            }
        }

        return true;
    }

    /**
     * Remove duplicate phone numbers while preserving insertion order.
     */
    public static List<String> deduplicate(List<String> phones) {
        List<String> result = new List<String>();
        if (phones == null || phones.isEmpty()) {
            return result;
        }

        Set<String> seen = new Set<String>();
        for (String phone : phones) {
            if (!seen.contains(phone)) {
                seen.add(phone);
                result.add(phone);
            }
        }

        return result;
    }

    /**
     * Split a list of phone numbers into covered and uncovered buckets
     * based on a list of country-code prefixes.
     */
    public static Map<String, List<String>> checkCoverage(List<String> phones, List<String> coverage) {
        List<String> covered = new List<String>();
        List<String> uncovered = new List<String>();

        if (phones != null) {
            for (String phone : phones) {
                Boolean matched = false;
                if (coverage != null) {
                    for (String prefix : coverage) {
                        if (phone != null && phone.startsWith(prefix)) {
                            matched = true;
                            break;
                        }
                    }
                }
                if (matched) {
                    covered.add(phone);
                } else {
                    uncovered.add(phone);
                }
            }
        }

        Map<String, List<String>> result = new Map<String, List<String>>();
        result.put('covered', covered);
        result.put('uncovered', uncovered);
        return result;
    }
}
