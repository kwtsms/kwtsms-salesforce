@IsTest
private class KwtSMSPhoneUtilsTest {

    // -------------------------------------------------------------------------
    // normalize(String) tests
    // -------------------------------------------------------------------------

    // 2026-11-05 10:09 +03: every sample number is now in the unassigned country code 999
    // (99912345678 and neighbours). normalize(), deduplicate() and checkCoverage() are not
    // Kuwait-specific, so the same code paths run. The old samples belonged to real people.
    // The four verify() Kuwait mobile-prefix tests are parked as a TODO below, int-testnumber
    @IsTest
    static void testNormalize_stripsPlusPrefix() {
        String result = KwtSMSPhoneUtils.normalize('+99912345678');
        System.assertEquals('99912345678', result, 'Should strip leading + sign');
    }

    @IsTest
    static void testNormalize_strips00Prefix() {
        String result = KwtSMSPhoneUtils.normalize('0099912345678');
        System.assertEquals('99912345678', result, 'Should strip leading 00 prefix');
    }

    @IsTest
    static void testNormalize_stripsSpaces() {
        String result = KwtSMSPhoneUtils.normalize('999 1234 5678');
        System.assertEquals('99912345678', result, 'Should strip all spaces');
    }

    @IsTest
    static void testNormalize_stripsDashes() {
        String result = KwtSMSPhoneUtils.normalize('999-1234-5678');
        System.assertEquals('99912345678', result, 'Should strip all dashes');
    }

    @IsTest
    static void testNormalize_convertsArabicDigits() {
        // Arabic-Indic digits for 99912345678: \u0669\u0669\u0669\u0661\u0662\u0663\u0664\u0665\u0666\u0667\u0668
        String arabicInput = '\u0669\u0669\u0669\u0661\u0662\u0663\u0664\u0665\u0666\u0667\u0668';
        String result = KwtSMSPhoneUtils.normalize(arabicInput);
        System.assertEquals('99912345678', result, 'Should convert Arabic-Indic digits to Latin');
    }

    @IsTest
    static void testNormalize_alreadyClean() {
        String result = KwtSMSPhoneUtils.normalize('99912345678');
        System.assertEquals('99912345678', result, 'Already clean number should be unchanged');
    }

    @IsTest
    static void testNormalize_nullInput() {
        String result = KwtSMSPhoneUtils.normalize(null);
        System.assertEquals('', result, 'Null input should return empty string');
    }

    @IsTest
    static void testNormalize_emptyInput() {
        String result = KwtSMSPhoneUtils.normalize('');
        System.assertEquals('', result, 'Empty input should return empty string');
    }

    // -------------------------------------------------------------------------
    // normalize(String, List<String>) tests
    // -------------------------------------------------------------------------

    @IsTest
    static void testNormalize_withCoverage_stripsLocalZeroKSA() {
        // KSA local format: 9660548796547 should become 966548796547
        String result = KwtSMSPhoneUtils.normalize('9660548796547', new List<String>{'966'});
        System.assertEquals('966548796547', result, 'Should strip local zero after KSA country code 966');
    }

    @IsTest
    static void testNormalize_withCoverage_stripsLocalZeroUAE() {
        // UAE local format: 9710551234567 should become 971551234567
        String result = KwtSMSPhoneUtils.normalize('9710551234567', new List<String>{'971'});
        System.assertEquals('971551234567', result, 'Should strip local zero after UAE country code 971');
    }

    @IsTest
    static void testNormalize_withCoverage_noZeroNoChange() {
        // Already normalised number whose country code is in coverage should remain unchanged
        String result = KwtSMSPhoneUtils.normalize('99912345678', new List<String>{'999'});
        System.assertEquals('99912345678', result, 'No local zero present, number should be unchanged');
    }

    // -------------------------------------------------------------------------
    // verify(String) tests
    // -------------------------------------------------------------------------

    // TODO(int-testnumber): testVerify_validKuwait4, testVerify_validKuwait5,
    // testVerify_validKuwait6 and testVerify_validKuwait9 were removed on 2026-11-05 10:09 +03
    // because their inputs were real Kuwait mobiles. verify() accepts a 965 number only when it
    // is exactly 11 digits and the digit after 965 is 4, 5, 6 or 9, so any input that passes is
    // a real-looking mobile; no synthetic value exists. Apex cannot read environment variables.
    // Restore them once Boss decides the source of an approved test mobile per prefix (for
    // example a protected Custom Metadata record read only in tests). Assert true for each.

    @IsTest
    static void testVerify_tooShort() {
        Boolean result = KwtSMSPhoneUtils.verify('123456');
        System.assertEquals(false, result, 'Number with fewer than 8 digits should be invalid');
    }

    @IsTest
    static void testVerify_tooLong() {
        Boolean result = KwtSMSPhoneUtils.verify('1234567890123456');
        System.assertEquals(false, result, 'Number with more than 15 digits should be invalid');
    }

    @IsTest
    static void testVerify_allSameDigits() {
        Boolean result = KwtSMSPhoneUtils.verify('99999999999');
        System.assertEquals(false, result, 'Number with all identical digits should be invalid');
    }

    @IsTest
    static void testVerify_kuwaitLandline() {
        // 965 + prefix 2 is a landline, not a mobile prefix
        Boolean result = KwtSMSPhoneUtils.verify('96522334455');
        System.assertEquals(false, result, 'Kuwait landline prefix 2 should be invalid for SMS');
    }

    @IsTest
    static void testVerify_nullInput() {
        Boolean result = KwtSMSPhoneUtils.verify(null);
        System.assertEquals(false, result, 'Null input should return false');
    }

    @IsTest
    static void testVerify_international() {
        // UAE mobile: 11 digits, non-Kuwait, valid length
        Boolean result = KwtSMSPhoneUtils.verify('971501234567');
        System.assertEquals(true, result, 'Valid international number should return true');
    }

    // -------------------------------------------------------------------------
    // deduplicate(List<String>) tests
    // -------------------------------------------------------------------------

    @IsTest
    static void testDeduplicate_removesDupes() {
        List<String> input = new List<String>{'a', 'b', 'a', 'c'};
        List<String> result = KwtSMSPhoneUtils.deduplicate(input);
        System.assertEquals(3, result.size(), 'Duplicate entry should be removed, resulting in 3 items');
        System.assertEquals('a', result[0], 'First element should be a');
        System.assertEquals('b', result[1], 'Second element should be b');
        System.assertEquals('c', result[2], 'Third element should be c');
    }

    @IsTest
    static void testDeduplicate_preservesOrder() {
        List<String> input = new List<String>{'99912345678', '99912345679', '99912345670', '99912345678'};
        List<String> result = KwtSMSPhoneUtils.deduplicate(input);
        System.assertEquals(3, result.size(), 'Should have 3 unique numbers');
        System.assertEquals('99912345678', result[0], 'First number should be preserved in order');
        System.assertEquals('99912345679', result[1], 'Second number should be preserved in order');
        System.assertEquals('99912345670', result[2], 'Third number should be preserved in order');
    }

    @IsTest
    static void testDeduplicate_noDupes() {
        List<String> input = new List<String>{'99912345678', '99912345679'};
        List<String> result = KwtSMSPhoneUtils.deduplicate(input);
        System.assertEquals(2, result.size(), 'No duplicates present, list should be unchanged in size');
    }

    @IsTest
    static void testDeduplicate_emptyList() {
        List<String> result = KwtSMSPhoneUtils.deduplicate(new List<String>());
        System.assertEquals(0, result.size(), 'Empty input should return empty list');
    }

    // -------------------------------------------------------------------------
    // checkCoverage(List<String>, List<String>) tests
    // -------------------------------------------------------------------------

    @IsTest
    static void testCheckCoverage_allCovered() {
        List<String> phones = new List<String>{'99912345678', '99912345679'};
        List<String> coverage = new List<String>{'999', '966'};
        Map<String, List<String>> result = KwtSMSPhoneUtils.checkCoverage(phones, coverage);
        System.assertEquals(2, result.get('covered').size(), 'Both covered-prefix numbers should be covered');
        System.assertEquals(0, result.get('uncovered').size(), 'No numbers should be uncovered');
    }

    @IsTest
    static void testCheckCoverage_someUncovered() {
        List<String> phones = new List<String>{'99912345678', '12025550123'};
        List<String> coverage = new List<String>{'999'};
        Map<String, List<String>> result = KwtSMSPhoneUtils.checkCoverage(phones, coverage);
        System.assertEquals(1, result.get('covered').size(), 'One covered-prefix number should be covered');
        System.assertEquals(1, result.get('uncovered').size(), 'One US number should be uncovered');
        System.assertEquals('99912345678', result.get('covered')[0], 'Covered number should be the 999 number');
        System.assertEquals('12025550123', result.get('uncovered')[0], 'Uncovered number should be the US number');
    }

    @IsTest
    static void testCheckCoverage_noneCovered() {
        List<String> phones = new List<String>{'12025550123', '447911123456'};
        List<String> coverage = new List<String>{'965'};
        Map<String, List<String>> result = KwtSMSPhoneUtils.checkCoverage(phones, coverage);
        System.assertEquals(0, result.get('covered').size(), 'No numbers should be covered');
        System.assertEquals(2, result.get('uncovered').size(), 'Both numbers should be uncovered');
    }
}
