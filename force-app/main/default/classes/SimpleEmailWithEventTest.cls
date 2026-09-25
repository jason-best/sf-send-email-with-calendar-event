@IsTest
private class SimpleEmailWithEventTest {

    @IsTest
    static void testUtcInviteContainsRequestMetadata() {
        SimpleEmailWithEvent.SimpleEmailWithEventInput input = baseInput();
        input.eventStart = Datetime.newInstanceGmt(2026, 9, 25, 16, 0, 0);
        input.eventEnd = Datetime.newInstanceGmt(2026, 9, 25, 17, 30, 0);
        input.subject = 'Design review';
        input.body = 'Bring the mockups';
        input.eventLocation = 'Room A, Floor 2';
        input.eventUrl = 'https://example.com/meet';
        input.organizerEmail = 'owner@example.com';
        input.organizerName = 'Event Owner';
        input.eventUid = 'stable-uid@threelevers.com';
        input.eventSequence = 2;
        input.eventReminderMinutes = 15;
        input.eventMethod = 'Request';

        String ics = SimpleEmailWithEvent.previewIcs(input);

        System.assert(ics.contains('METHOD:REQUEST'));
        System.assert(ics.contains('UID:stable-uid@threelevers.com'));
        System.assert(ics.contains('DTSTART:20260925T160000Z'));
        System.assert(ics.contains('DTEND:20260925T173000Z'));
        System.assert(ics.contains('SUMMARY:Design review'));
        System.assert(ics.contains('DESCRIPTION:Bring the mockups'));
        System.assert(ics.contains('LOCATION:Room A\\, Floor 2'));
        System.assert(ics.contains('URL:https://example.com/meet'));
        System.assert(ics.contains('ORGANIZER;CN="Event Owner":mailto:owner@example.com'));
        System.assert(ics.contains('ATTENDEE;PARTSTAT=NEEDS-ACTION;RSVP=TRUE:mailto:guest@example.com'));
        System.assert(ics.contains('SEQUENCE:2'));
        System.assert(ics.contains('STATUS:CONFIRMED'));
        System.assert(ics.contains('TRIGGER:-PT15M'));
        System.assert(ics.contains('\r\n'));
    }

    @IsTest
    static void testNamedTimeZoneAllDayAndCancel() {
        SimpleEmailWithEvent.SimpleEmailWithEventInput timed = baseInput();
        timed.eventStart = Datetime.newInstanceGmt(2026, 7, 15, 16, 0, 0);
        timed.eventEnd = Datetime.newInstanceGmt(2026, 7, 15, 17, 0, 0);
        timed.eventTimeZone = 'America/Los_Angeles';
        timed.subject = 'Morning meeting';
        timed.body = 'Line one';

        String zoned = SimpleEmailWithEvent.previewIcs(timed);
        System.assert(zoned.contains('METHOD:PUBLISH'));
        System.assert(!zoned.contains('ATTENDEE'));
        System.assert(!zoned.contains('BEGIN:VTIMEZONE'));
        System.assert(zoned.contains('DTSTART:20260715T160000Z'));
        System.assert(zoned.contains('DTEND:20260715T170000Z'));

        SimpleEmailWithEvent.SimpleEmailWithEventInput allDay = baseInput();
        allDay.eventAllDay = true;
        allDay.eventStart = Datetime.newInstanceGmt(2026, 9, 25, 0, 0, 0);
        allDay.eventEnd = Datetime.newInstanceGmt(2026, 9, 26, 0, 0, 0);
        allDay.subject = 'Offsite';
        allDay.body = 'Two days';
        String dates = SimpleEmailWithEvent.previewIcs(allDay);
        System.assert(dates.contains('DTSTART;VALUE=DATE:20260925'));
        System.assert(dates.contains('DTEND;VALUE=DATE:20260927'));

        SimpleEmailWithEvent.SimpleEmailWithEventInput cancel = baseInput();
        cancel.eventMethod = 'Cancel';
        cancel.eventUid = 'existing@threelevers.com';
        cancel.eventSequence = 3;
        cancel.subject = 'Canceled';
        cancel.body = 'No longer happening';
        String canceled = SimpleEmailWithEvent.previewIcs(cancel);
        System.assert(canceled.contains('METHOD:CANCEL'));
        System.assert(canceled.contains('STATUS:CANCELLED'));
        System.assert(canceled.contains('UID:existing@threelevers.com'));
        System.assert(canceled.contains('SEQUENCE:3'));
        System.assert(!canceled.contains('ATTENDEE'));
        System.assert(!canceled.contains('BEGIN:VALARM'));
    }

    @IsTest
    static void testRichTextLineBreaksAndCollectionRecipients() {
        SimpleEmailWithEvent.SimpleEmailWithEventInput input = baseInput();
        input.recipientAddressList = null;
        input.recipientAddressCollection = new List<String>{ 'one@example.com', 'two@example.com' };
        input.ccRecipientAddressList = 'cc@example.com';
        input.richTextFormattedBody = true;
        input.useLineBreaks = true;
        input.body = 'Hello\nthere';
        input.subject = 'Rich';
        input.eventShowAsBusy = false;

        String ics = SimpleEmailWithEvent.previewIcs(input);
        System.assert(ics.contains('DESCRIPTION:Hello\\nthere'));
        System.assert(ics.contains('X-ALT-DESC;FMTTYPE=text/html:Hello<br>there'));
        System.assert(ics.contains('METHOD:PUBLISH'));
        System.assert(!ics.contains('ATTENDEE'));
        System.assert(ics.contains('TRANSP:TRANSPARENT'));
        System.assert(ics.contains('X-MICROSOFT-CDO-BUSYSTATUS:FREE'));
    }

    @IsTest
    static void testInviteToOrganizerIsPublished() {
        SimpleEmailWithEvent.SimpleEmailWithEventInput input = baseInput();
        input.organizerEmail = 'guest@example.com';
        input.subject = 'Solo';
        input.body = 'Just me';

        String ics = SimpleEmailWithEvent.previewIcs(input);

        System.assert(ics.contains('METHOD:PUBLISH'));
        System.assert(ics.contains('ORGANIZER:mailto:guest@example.com'));
        System.assert(!ics.contains('ATTENDEE'));
        System.assert(!ics.contains('BEGIN:VTIMEZONE'));
    }

    @IsTest
    static void testSendAndValidationErrors() {
        Contact contact = new Contact(LastName = 'Invitee', Email = 'person@example.com');
        insert contact;

        SimpleEmailWithEvent.SimpleEmailWithEventInput good = baseInput();
        good.recipientAddressList = null;
        good.recipientId = contact.Id;
        good.logEmailOnSend = true;

        SimpleEmailWithEvent.SimpleEmailWithEventInput missingRecipient = baseInput();
        missingRecipient.recipientAddressList = null;

        SimpleEmailWithEvent.SimpleEmailWithEventInput missingStart = baseInput();
        missingStart.eventStart = null;

        SimpleEmailWithEvent.SimpleEmailWithEventInput badZone = baseInput();
        badZone.eventTimeZone = 'Not/A Zone';

        SimpleEmailWithEvent.SimpleEmailWithEventInput workflowUser = baseInput();
        workflowUser.senderType = 'DefaultWorkflowUser';

        Test.startTest();
        List<SimpleEmailWithEvent.SimpleEmailWithEventOutput> results = SimpleEmailWithEvent.sendEmail(
            new List<SimpleEmailWithEvent.SimpleEmailWithEventInput>{
                good,
                missingRecipient,
                missingStart,
                badZone,
                workflowUser
            }
        );
        Test.stopTest();

        System.assertEquals(5, results.size());
        System.assertEquals(true, results[0].success, results[0].errorMessage == null ? 'send failed' : results[0].errorMessage);
        System.assert(results[0].eventUid.endsWith('@threelevers.com'));
        System.assertEquals(false, results[1].success);
        System.assert(results[1].errorMessage.contains('Recipient'));
        System.assert(results[2].errorMessage.contains('Event Start'));
        System.assert(results[3].errorMessage.contains('Event Time Zone'));
        System.assert(results[4].errorMessage.contains('DefaultWorkflowUser'));
    }

    @IsTest
    static void testContentAttachmentAndUnknownOrgWideAddress() {
        ContentVersion version = new ContentVersion(
            Title = 'Agenda',
            PathOnClient = 'Agenda.txt',
            VersionData = Blob.valueOf('topics')
        );
        insert version;

        SimpleEmailWithEvent.SimpleEmailWithEventInput withFile = baseInput();
        withFile.attachmentId = version.Id;

        SimpleEmailWithEvent.SimpleEmailWithEventInput missingOrgWide = baseInput();
        missingOrgWide.senderType = 'OrgWideEmailAddress';
        missingOrgWide.senderEmailAddress = 'missing-owea@example.com';

        Test.startTest();
        List<SimpleEmailWithEvent.SimpleEmailWithEventOutput> results = SimpleEmailWithEvent.sendEmail(
            new List<SimpleEmailWithEvent.SimpleEmailWithEventInput>{ withFile, missingOrgWide }
        );
        Test.stopTest();

        System.assertEquals(true, results[0].success, results[0].errorMessage == null ? 'send failed' : results[0].errorMessage);
        System.assertEquals(false, results[1].success);
        System.assert(results[1].errorMessage.contains('missing-owea@example.com'));
    }

    private static SimpleEmailWithEvent.SimpleEmailWithEventInput baseInput() {
        SimpleEmailWithEvent.SimpleEmailWithEventInput input = new SimpleEmailWithEvent.SimpleEmailWithEventInput();
        input.recipientAddressList = 'guest@example.com';
        input.subject = 'Subject';
        input.body = 'Body';
        input.eventStart = Datetime.newInstanceGmt(2026, 9, 25, 16, 0, 0);
        input.eventEnd = Datetime.newInstanceGmt(2026, 9, 25, 17, 0, 0);
        return input;
    }
}
