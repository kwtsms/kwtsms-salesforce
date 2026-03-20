@IsTest
private class KwtSMSMessageUtilsTest {

    // -------------------------------------------------------
    // cleanMessage tests
    // -------------------------------------------------------

    @IsTest
    static void testCleanMessage_stripsHTML() {
        String result = KwtSMSMessageUtils.cleanMessage('<b>Hello</b>');
        System.assertEquals('Hello', result, 'HTML tags should be stripped');
    }

    @IsTest
    static void testCleanMessage_stripsScriptTag() {
        String result = KwtSMSMessageUtils.cleanMessage('<script>alert(1)</script>');
        System.assertEquals('alert(1)', result, 'Script tags should be stripped, inner text preserved');
    }

    @IsTest
    static void testCleanMessage_stripsHiddenChars() {
        // Build a string with zero-width space (U+200B) and zero-width joiner (U+200D)
        String zwsp = String.fromCharArray(new List<Integer>{ 0x200B });
        String zwj  = String.fromCharArray(new List<Integer>{ 0x200D });
        String input = 'Hello' + zwsp + zwj + 'World';
        String result = KwtSMSMessageUtils.cleanMessage(input);
        System.assertEquals('HelloWorld', result, 'Zero-width characters should be stripped');
    }

    @IsTest
    static void testCleanMessage_convertsArabicNumerals() {
        // Arabic-Indic digits U+0660-U+0669: 1, 2, 3
        String one   = String.fromCharArray(new List<Integer>{ 0x0661 });
        String two   = String.fromCharArray(new List<Integer>{ 0x0662 });
        String three = String.fromCharArray(new List<Integer>{ 0x0663 });
        String input = one + two + three;
        String result = KwtSMSMessageUtils.cleanMessage(input);
        System.assertEquals('123', result, 'Arabic-Indic digits should be converted to Latin digits');
    }

    @IsTest
    static void testCleanMessage_trimsWhitespace() {
        String result = KwtSMSMessageUtils.cleanMessage('  hello  ');
        System.assertEquals('hello', result, 'Leading and trailing whitespace should be trimmed');
    }

    @IsTest
    static void testCleanMessage_preservesArabicText() {
        String arabic = '\u0645\u0631\u062D\u0628\u0627'; // مرحبا
        String result = KwtSMSMessageUtils.cleanMessage(arabic);
        System.assertEquals(arabic, result, 'Arabic text should be preserved as-is');
    }

    @IsTest
    static void testCleanMessage_preservesNewlines() {
        String input = 'line1\nline2';
        String result = KwtSMSMessageUtils.cleanMessage(input);
        System.assertEquals('line1\nline2', result, 'Newlines should be preserved');
    }

    @IsTest
    static void testCleanMessage_nullReturnsEmpty() {
        String result = KwtSMSMessageUtils.cleanMessage(null);
        System.assertEquals('', result, 'Null input should return empty string');
    }

    @IsTest
    static void testCleanMessage_emptyReturnsEmpty() {
        String result = KwtSMSMessageUtils.cleanMessage('');
        System.assertEquals('', result, 'Empty input should return empty string');
    }

    // -------------------------------------------------------
    // isArabic tests
    // -------------------------------------------------------

    @IsTest
    static void testIsArabic_withArabic() {
        Boolean result = KwtSMSMessageUtils.isArabic('\u0645\u0631\u062D\u0628\u0627'); // مرحبا
        System.assertEquals(true, result, 'Arabic text should be detected as Arabic');
    }

    @IsTest
    static void testIsArabic_withEnglish() {
        Boolean result = KwtSMSMessageUtils.isArabic('Hello');
        System.assertEquals(false, result, 'English text should not be detected as Arabic');
    }

    @IsTest
    static void testIsArabic_withMixed() {
        Boolean result = KwtSMSMessageUtils.isArabic('Hello \u0645\u0631\u062D\u0628\u0627');
        System.assertEquals(true, result, 'Mixed text containing Arabic should be detected as Arabic');
    }

    @IsTest
    static void testIsArabic_empty() {
        Boolean result = KwtSMSMessageUtils.isArabic('');
        System.assertEquals(false, result, 'Empty string should not be detected as Arabic');
    }

    // -------------------------------------------------------
    // calculatePages tests
    // -------------------------------------------------------

    @IsTest
    static void testCalculatePages_english1Page() {
        String msg = 'a'.repeat(160);
        KwtSMSMessageUtils.PageInfo info = KwtSMSMessageUtils.calculatePages(msg);
        System.assertEquals('English', info.encoding, 'Should be English encoding');
        System.assertEquals(1, info.pageCount, '160 chars should fit in 1 page');
        System.assertEquals(0, info.charsRemaining, '0 chars remaining at exactly 160');
    }

    @IsTest
    static void testCalculatePages_english2Pages() {
        String msg = 'a'.repeat(161);
        KwtSMSMessageUtils.PageInfo info = KwtSMSMessageUtils.calculatePages(msg);
        System.assertEquals('English', info.encoding, 'Should be English encoding');
        System.assertEquals(2, info.pageCount, '161 chars should require 2 pages');
        System.assertEquals(152, info.charsRemaining, '152 chars remaining in second page');
    }

    @IsTest
    static void testCalculatePages_english3Pages() {
        // 160 + 153 + 1 = 314 chars -> 3 pages
        String msg = 'a'.repeat(314);
        KwtSMSMessageUtils.PageInfo info = KwtSMSMessageUtils.calculatePages(msg);
        System.assertEquals('English', info.encoding, 'Should be English encoding');
        System.assertEquals(3, info.pageCount, '314 chars should require 3 pages');
        System.assertEquals(152, info.charsRemaining, '152 chars remaining in third page');
    }

    @IsTest
    static void testCalculatePages_arabic1Page() {
        // Build a 70-char Arabic string
        String arabicChar = '\u0645'; // م
        String msg = arabicChar.repeat(70);
        KwtSMSMessageUtils.PageInfo info = KwtSMSMessageUtils.calculatePages(msg);
        System.assertEquals('Arabic', info.encoding, 'Should be Arabic encoding');
        System.assertEquals(1, info.pageCount, '70 Arabic chars should fit in 1 page');
        System.assertEquals(0, info.charsRemaining, '0 chars remaining at exactly 70');
    }

    @IsTest
    static void testCalculatePages_arabic2Pages() {
        String arabicChar = '\u0645'; // م
        String msg = arabicChar.repeat(71);
        KwtSMSMessageUtils.PageInfo info = KwtSMSMessageUtils.calculatePages(msg);
        System.assertEquals('Arabic', info.encoding, 'Should be Arabic encoding');
        System.assertEquals(2, info.pageCount, '71 Arabic chars should require 2 pages');
        System.assertEquals(66, info.charsRemaining, '66 chars remaining in second page');
    }

    @IsTest
    static void testCalculatePages_mixedIsArabic() {
        String msg = 'Hello \u0645\u0631\u062D\u0628\u0627'; // Hello مرحبا
        KwtSMSMessageUtils.PageInfo info = KwtSMSMessageUtils.calculatePages(msg);
        System.assertEquals('Arabic', info.encoding, 'Mixed text with Arabic should use Arabic encoding');
    }

    @IsTest
    static void testCalculatePages_emptyMessage() {
        KwtSMSMessageUtils.PageInfo info = KwtSMSMessageUtils.calculatePages('');
        System.assertEquals('English', info.encoding, 'Empty message should default to English encoding');
        System.assertEquals(0, info.pageCount, 'Empty message should have 0 pages');
        System.assertEquals(0, info.charCount, 'Empty message should have 0 chars');
        System.assertEquals(0, info.charsRemaining, 'Empty message should have 0 remaining');
    }

    // -------------------------------------------------------
    // validateLength tests
    // -------------------------------------------------------

    @IsTest
    static void testValidateLength_under7Pages() {
        // 6 pages of English: 160 + 5*153 = 160 + 765 = 925 chars
        String msg = 'a'.repeat(925);
        Boolean result = KwtSMSMessageUtils.validateLength(msg);
        System.assertEquals(true, result, 'Message fitting in 6 pages should be valid');
    }

    @IsTest
    static void testValidateLength_exactly7Pages() {
        // Exactly 7 pages of English: 160 + 6*153 = 160 + 918 = 1078 chars
        String msg = 'a'.repeat(1078);
        Boolean result = KwtSMSMessageUtils.validateLength(msg);
        System.assertEquals(true, result, 'Message fitting in exactly 7 pages should be valid');
    }

    @IsTest
    static void testValidateLength_over7Pages() {
        // 8 pages of English: 160 + 7*153 = 160 + 1071 = 1231 chars
        String msg = 'a'.repeat(1231);
        Boolean result = KwtSMSMessageUtils.validateLength(msg);
        System.assertEquals(false, result, 'Message requiring 8 pages should be invalid');
    }
}
