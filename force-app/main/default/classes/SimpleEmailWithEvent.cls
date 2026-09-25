/**
 * Invocable action: send an email the way Flow's Send Email action does, and attach
 * a calendar event so clients can add it to a calendar.
 *
 * The calendar part is Content-Type text/calendar with a method parameter that
 * matches METHOD inside the file. Apex cannot set the message root content type.
 *
 * Publish (the default) has no attendees: it is an event, not a meeting invite.
 * Cancel reuses Event UID with a higher Event Sequence to remove that event.
 * Request sends a meeting invite. Gmail does not load a request in the organizer's
 * mailbox, so the organizer receives a separate published copy.
 */
global with sharing class SimpleEmailWithEvent {

    private static final String PRODID = '-//Three Levers//SimpleEmailWithEvent//EN';
    private static final Integer DEFAULT_DURATION_MINUTES = 60;

    global class SimpleEmailWithEventInput {
        @InvocableVariable(label='Recipient Address List' description='Comma-separated To addresses.')
        global String recipientAddressList;

        @InvocableVariable(label='Recipient Address Collection' description='Text collection of To addresses.')
        global List<String> recipientAddressCollection;

        @InvocableVariable(label='CC Recipient Address List' description='Comma-separated CC addresses.')
        global String ccRecipientAddressList;

        @InvocableVariable(label='CC Recipient Address Collection' description='Text collection of CC addresses.')
        global List<String> ccRecipientAddressCollection;

        @InvocableVariable(label='BCC Recipient Address List' description='Comma-separated BCC addresses.')
        global String bccRecipientAddressList;

        @InvocableVariable(label='BCC Recipient Address Collection' description='Text collection of BCC addresses.')
        global List<String> bccRecipientAddressCollection;

        @InvocableVariable(label='Recipient ID' description='Contact, Lead, User, or Person Account. Required when using an email template, and required to log the email.')
        global Id recipientId;

        @InvocableVariable(label='Related Record ID' description='Record used for template merge fields and activity logging. Cannot be combined with a Lead Recipient ID.')
        global Id relatedRecordId;

        @InvocableVariable(label='Sender Type' description='CurrentUser (default), OrgWideEmailAddress, or DefaultWorkflowUser. Apex cannot send as the Default Workflow User; use an org-wide address instead.')
        global String senderType;

        @InvocableVariable(label='Sender Email Address' description='Verified organization-wide email address. Required when Sender Type is OrgWideEmailAddress. Also used as the calendar organizer when Organizer Email is blank.')
        global String senderEmailAddress;

        @InvocableVariable(label='Email Template ID' description='Classic or Lightning email template Id. Subject and body come from the template.')
        global Id emailTemplateId;

        @InvocableVariable(label='Subject' description='Email subject. Required when no email template is set. Also the event title when Event Summary is blank.')
        global String subject;

        @InvocableVariable(label='Body' description='Email body. Plain text unless Rich-Text-Formatted Body is true. Required when no email template is set.')
        global String body;

        @InvocableVariable(label='Rich-Text-Formatted Body' description='When true, Body is sent as HTML.')
        global Boolean richTextFormattedBody;

        @InvocableVariable(label='Use Line Breaks' description='When true, line breaks in a rich-text Body become HTML line breaks.')
        global Boolean useLineBreaks;

        @InvocableVariable(label='Attachment ID' description='Comma-separated ContentVersion (068) or ContentDocument (069) Ids.')
        global String attachmentId;

        @InvocableVariable(label='Attachment ID Collection' description='Text collection of ContentVersion or ContentDocument Ids.')
        global List<String> attachmentIdCollection;

        @InvocableVariable(label='Log Email on Send' description='When true, logs the email to the Recipient ID activity timeline. A Contact, Lead, or Person Account Recipient ID is required.')
        global Boolean logEmailOnSend;

        @InvocableVariable(label='Add Threading Token to Subject' description='Appends an Email-to-Case threading token to the subject. Related Record ID is required.')
        global Boolean addThreadingTokenToSubject;

        @InvocableVariable(label='Add Threading Token to Body' description='Appends an Email-to-Case threading token to the body. Related Record ID is required.')
        global Boolean addThreadingTokenToBody;

        @InvocableVariable(required=true label='Event Start' description='Event start. Timed events are written in UTC so calendar apps show the event in the recipient local time.')
        global Datetime eventStart;

        @InvocableVariable(label='Event End' description='Event end. When blank, the event lasts one hour. For an all-day event this is the last day, and a blank end means that day only.')
        global Datetime eventEnd;

        @InvocableVariable(label='Event All Day' description='When true, the invite uses calendar dates instead of times.')
        global Boolean eventAllDay;

        @InvocableVariable(label='Event Time Zone' description='Named time zone such as America/Los_Angeles. Used for all-day events so the calendar date is that zone. Timed events are sent as UTC.')
        global String eventTimeZone;

        @InvocableVariable(label='Event Summary' description='Calendar title. Blank uses Subject.')
        global String eventSummary;

        @InvocableVariable(label='Event Description' description='Calendar description. Blank uses the plain-text email body.')
        global String eventDescription;

        @InvocableVariable(label='Event Location')
        global String eventLocation;

        @InvocableVariable(label='Event URL' description='Meeting or other URL stored on the calendar event.')
        global String eventUrl;

        @InvocableVariable(label='Organizer Name' description='Calendar organizer display name. Blank uses the sending address display name when available.')
        global String organizerName;

        @InvocableVariable(label='Organizer Email' description='Calendar organizer address. Blank uses Sender Email Address, then the running user email.')
        global String organizerEmail;

        @InvocableVariable(label='Event Attendee Address List' description='Comma-separated attendee addresses. Used only when Event Method is Request. Blank uses the To recipients.')
        global String eventAttendeeAddressList;

        @InvocableVariable(label='Event Attendee Address Collection' description='Text collection of attendee addresses. Used only when Event Method is Request, together with Event Attendee Address List.')
        global List<String> eventAttendeeAddressCollection;

        @InvocableVariable(label='Event UID' description='Stable calendar id. Store the output and reuse it, with a higher Event Sequence, to cancel the same event. A new id is created when blank.')
        global String eventUid;

        @InvocableVariable(label='Event Sequence' description='0 for a new event. Increase it when canceling or replacing an existing Event UID.')
        global Integer eventSequence;

        @InvocableVariable(label='Event Method' description='Publish (default), Cancel, or Request. Publish sends an event with no participants. Cancel removes an event when you reuse Event UID and a higher Event Sequence. Request sends a meeting invite.')
        global String eventMethod;

        @InvocableVariable(label='Event Reminder Minutes' description='Minutes before start to show a reminder in the calendar invite. Blank sends no reminder.')
        global Integer eventReminderMinutes;

        @InvocableVariable(label='Event Show As Busy' description='When true (default), the event blocks time as busy. When false, it is free.')
        global Boolean eventShowAsBusy;
    }

    global class SimpleEmailWithEventOutput {
        @InvocableVariable(label='Success')
        global Boolean success;

        @InvocableVariable(label='Error Message')
        global String errorMessage;

        @InvocableVariable(label='Event UID' description='UID written into the calendar file. Store it to cancel the same event later.')
        global String eventUid;
    }

    private class PreparedEmail {
        public List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
        public String errorMessage;
        public String eventUid;
    }

    private class SenderContext {
        public Map<String, OrgWideEmailAddress> orgWideByAddress = new Map<String, OrgWideEmailAddress>();
        public Map<Id, String> emailByRecipientId = new Map<Id, String>();
        public Map<Id, Id> contactIdByPersonAccountId = new Map<Id, Id>();
        public Map<Id, ContentVersion> versionById = new Map<Id, ContentVersion>();
        public Set<Id> templateIds = new Set<Id>();
        public User runningUser;
    }

    @InvocableMethod(
        label='Send Email with Calendar Event'
        description='Sends an email with the same recipient, sender, and content inputs as the Send Email action, plus an iCalendar invite clients can add automatically.'
        category='Email'
    )
    global static List<SimpleEmailWithEventOutput> sendEmail(List<SimpleEmailWithEventInput> inputs) {
        List<SimpleEmailWithEventOutput> outputs = new List<SimpleEmailWithEventOutput>();
        if (inputs == null || inputs.isEmpty()) {
            return outputs;
        }

        SenderContext context = loadContext(inputs);
        List<PreparedEmail> prepared = new List<PreparedEmail>();
        List<Messaging.SingleEmailMessage> toSend = new List<Messaging.SingleEmailMessage>();
        List<Integer> sendIndexes = new List<Integer>();

        for (SimpleEmailWithEventInput input : inputs) {
            PreparedEmail email = prepare(input, context);
            prepared.add(email);
            for (Messaging.SingleEmailMessage message : email.messages) {
                toSend.add(message);
                sendIndexes.add(prepared.size() - 1);
            }
        }

        if (!toSend.isEmpty()) {
            List<Messaging.SendEmailResult> results = Messaging.sendEmail(toSend, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    continue;
                }
                PreparedEmail email = prepared[sendIndexes[i]];
                email.messages.clear();
                email.errorMessage = sendError(results[i]);
            }
        }

        for (PreparedEmail email : prepared) {
            SimpleEmailWithEventOutput output = new SimpleEmailWithEventOutput();
            output.success = !email.messages.isEmpty() && String.isBlank(email.errorMessage);
            output.errorMessage = output.success ? null : email.errorMessage;
            output.eventUid = email.eventUid;
            outputs.add(output);
        }
        return outputs;
    }

    private static SenderContext loadContext(List<SimpleEmailWithEventInput> inputs) {
        SenderContext context = new SenderContext();
        context.runningUser = [SELECT Id, Name, Email FROM User WHERE Id = :UserInfo.getUserId()];

        Set<String> orgWideAddresses = new Set<String>();
        Set<Id> recipientIds = new Set<Id>();
        Set<Id> contentIds = new Set<Id>();
        Set<Id> templateIds = new Set<Id>();

        for (SimpleEmailWithEventInput input : inputs) {
            if (input == null) {
                continue;
            }
            if (!String.isBlank(input.senderEmailAddress)) {
                orgWideAddresses.add(input.senderEmailAddress.trim());
            }
            if (input.recipientId != null) {
                recipientIds.add(input.recipientId);
            }
            if (input.emailTemplateId != null) {
                templateIds.add(input.emailTemplateId);
            }
            contentIds.addAll(parseIds(joinLists(input.attachmentId, input.attachmentIdCollection)));
        }

        if (!orgWideAddresses.isEmpty()) {
            for (OrgWideEmailAddress owea : [
                SELECT Id, Address, DisplayName
                FROM OrgWideEmailAddress
                WHERE Address IN :orgWideAddresses
            ]) {
                context.orgWideByAddress.put(owea.Address.toLowerCase(), owea);
            }
        }
        if (!templateIds.isEmpty()) {
            for (EmailTemplate template : [SELECT Id FROM EmailTemplate WHERE Id IN :templateIds]) {
                context.templateIds.add(template.Id);
            }
        }
        context.emailByRecipientId.putAll(emailsForRecipients(recipientIds, context));
        context.versionById.putAll(versionsFor(contentIds));
        return context;
    }

    private static Map<Id, String> emailsForRecipients(Set<Id> recipientIds, SenderContext context) {
        Map<Id, String> emails = new Map<Id, String>();
        Set<Id> contactIds = new Set<Id>();
        Set<Id> leadIds = new Set<Id>();
        Set<Id> userIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
        for (Id recipientId : recipientIds) {
            Schema.SObjectType type = recipientId.getSObjectType();
            if (type == Contact.SObjectType) {
                contactIds.add(recipientId);
            } else if (type == Lead.SObjectType) {
                leadIds.add(recipientId);
            } else if (type == User.SObjectType) {
                userIds.add(recipientId);
            } else if (type == Account.SObjectType) {
                accountIds.add(recipientId);
            }
        }
        if (!contactIds.isEmpty()) {
            for (Contact contact : [SELECT Id, Email FROM Contact WHERE Id IN :contactIds]) {
                emails.put(contact.Id, contact.Email);
            }
        }
        if (!leadIds.isEmpty()) {
            for (Lead lead : [SELECT Id, Email FROM Lead WHERE Id IN :leadIds]) {
                emails.put(lead.Id, lead.Email);
            }
        }
        if (!userIds.isEmpty()) {
            for (User user : [SELECT Id, Email FROM User WHERE Id IN :userIds]) {
                emails.put(user.Id, user.Email);
            }
        }
        if (!accountIds.isEmpty()) {
            context.contactIdByPersonAccountId.putAll(personContacts(accountIds));
            Set<Id> personContactIds = new Set<Id>(context.contactIdByPersonAccountId.values());
            if (!personContactIds.isEmpty()) {
                for (Contact contact : [SELECT Id, Email FROM Contact WHERE Id IN :personContactIds]) {
                    emails.put(contact.Id, contact.Email);
                }
            }
        }
        return emails;
    }

    private static Map<Id, Id> personContacts(Set<Id> accountIds) {
        Map<Id, Id> contactByAccount = new Map<Id, Id>();
        Map<String, Schema.SObjectField> fields = Account.SObjectType.getDescribe().fields.getMap();
        if (!fields.containsKey('PersonContactId') || !fields.containsKey('IsPersonAccount')) {
            return contactByAccount;
        }
        for (SObject row : Database.query(
            'SELECT Id, PersonContactId FROM Account WHERE Id IN :accountIds AND IsPersonAccount = true'
        )) {
            if (row.get('PersonContactId') != null) {
                contactByAccount.put((Id) row.get('Id'), (Id) row.get('PersonContactId'));
            }
        }
        return contactByAccount;
    }

    private static Map<Id, ContentVersion> versionsFor(Set<Id> contentIds) {
        Map<Id, ContentVersion> versions = new Map<Id, ContentVersion>();
        if (contentIds.isEmpty()) {
            return versions;
        }
        Set<Id> versionIds = new Set<Id>();
        Set<Id> documentIds = new Set<Id>();
        for (Id contentId : contentIds) {
            Schema.SObjectType type = contentId.getSObjectType();
            if (type == ContentVersion.SObjectType) {
                versionIds.add(contentId);
            } else if (type == ContentDocument.SObjectType) {
                documentIds.add(contentId);
            }
        }
        if (!versionIds.isEmpty()) {
            for (ContentVersion version : [
                SELECT Id, Title, FileExtension, VersionData, ContentDocumentId
                FROM ContentVersion
                WHERE Id IN :versionIds
            ]) {
                versions.put(version.Id, version);
            }
        }
        if (!documentIds.isEmpty()) {
            for (ContentVersion version : [
                SELECT Id, Title, FileExtension, VersionData, ContentDocumentId
                FROM ContentVersion
                WHERE ContentDocumentId IN :documentIds AND IsLatest = true
            ]) {
                versions.put(version.ContentDocumentId, version);
            }
        }
        return versions;
    }

    private static PreparedEmail prepare(SimpleEmailWithEventInput input, SenderContext context) {
        PreparedEmail prepared = new PreparedEmail();
        if (input == null) {
            prepared.errorMessage = 'An email input is required.';
            return prepared;
        }
        try {
            Id targetId = resolveRecipientTarget(input, context);
            List<String> toAddresses = addresses(input.recipientAddressList, input.recipientAddressCollection);
            List<String> ccAddresses = addresses(input.ccRecipientAddressList, input.ccRecipientAddressCollection);
            List<String> bccAddresses = addresses(input.bccRecipientAddressList, input.bccRecipientAddressCollection);
            if (targetId == null && toAddresses.isEmpty()) {
                prepared.errorMessage = 'Provide a Recipient ID or at least one recipient email address.';
                return prepared;
            }
            if (input.emailTemplateId == null && String.isBlank(input.subject)) {
                prepared.errorMessage = 'Subject is required when no Email Template ID is set.';
                return prepared;
            }
            if (input.emailTemplateId == null && String.isBlank(input.body)) {
                prepared.errorMessage = 'Body is required when no Email Template ID is set.';
                return prepared;
            }
            if (input.emailTemplateId != null && !context.templateIds.contains(input.emailTemplateId)) {
                prepared.errorMessage = 'Email Template ID was not found.';
                return prepared;
            }
            if (input.emailTemplateId != null && targetId == null) {
                prepared.errorMessage = 'Recipient ID is required when an Email Template ID is set.';
                return prepared;
            }
            if (targetId != null && targetId.getSObjectType() == Lead.SObjectType && input.relatedRecordId != null) {
                prepared.errorMessage = 'Related Record ID cannot be used when Recipient ID is a Lead.';
                return prepared;
            }
            if (input.eventStart == null) {
                prepared.errorMessage = 'Event Start is required.';
                return prepared;
            }
            Boolean logEmail = input.logEmailOnSend == true;
            if (logEmail && !canLogActivity(targetId)) {
                prepared.errorMessage = 'Log Email on Send requires a Contact, Lead, or Person Account Recipient ID.';
                return prepared;
            }
            Boolean threadSubject = input.addThreadingTokenToSubject == true;
            Boolean threadBody = input.addThreadingTokenToBody == true;
            if ((threadSubject || threadBody) && input.relatedRecordId == null) {
                prepared.errorMessage = 'Related Record ID is required to add a threading token.';
                return prepared;
            }

            String requestedMethod = normalizeMethod(input.eventMethod);
            String organizer = organizerEmail(input, context);
            List<String> guests = excludingAddress(attendeeEmails(input, context), organizer);

            String subject = input.subject;
            String plainBody = plainBody(input);
            String htmlBody = htmlBody(input);
            if (threadSubject || threadBody) {
                String token = EmailMessages.getFormattedThreadingToken(input.relatedRecordId);
                if (threadSubject) {
                    subject = joinToken(subject, token);
                }
                if (threadBody) {
                    plainBody = joinToken(plainBody, token);
                    htmlBody = joinToken(htmlBody, token);
                }
            }

            List<EventDraft> events = calendarEvents(input, plainBody, htmlBody);
            prepared.eventUid = events[0].uid;

            String targetAddress = targetEmail(targetId, context);
            Boolean organizerTarget = sameEmail(targetAddress, organizer);
            Boolean organizerListed = organizerTarget
                || containsEmail(toAddresses, organizer)
                || containsEmail(ccAddresses, organizer)
                || containsEmail(bccAddresses, organizer);
            Boolean separateOrganizerCopy = requestedMethod == 'REQUEST' && !guests.isEmpty() && organizerListed;

            String guestMethod = requestedMethod == 'REQUEST' && guests.isEmpty() ? 'PUBLISH' : requestedMethod;
            List<String> guestAttendees = guestMethod == 'REQUEST' ? guests : new List<String>();
            Id guestTarget = separateOrganizerCopy && organizerTarget ? null : targetId;
            List<String> guestTo = separateOrganizerCopy ? excludingAddress(toAddresses, organizer) : toAddresses;
            List<String> guestCc = separateOrganizerCopy ? excludingAddress(ccAddresses, organizer) : ccAddresses;
            List<String> guestBcc = separateOrganizerCopy ? excludingAddress(bccAddresses, organizer) : bccAddresses;
            if (guestTarget != null || !guestTo.isEmpty() || !guestCc.isEmpty() || !guestBcc.isEmpty()) {
                prepared.messages.add(buildMessage(
                    input, context, guestTo, guestCc, guestBcc, guestTarget,
                    logEmail, subject, plainBody, htmlBody, guestMethod, guestAttendees, events
                ));
            }
            if (separateOrganizerCopy) {
                prepared.messages.add(buildMessage(
                    input, context, new List<String>{ organizer }, new List<String>(), new List<String>(),
                    organizerTarget ? targetId : null, false, subject, plainBody, htmlBody,
                    'PUBLISH', new List<String>(), events
                ));
            }
            if (prepared.messages.isEmpty()) {
                prepared.errorMessage = 'Provide a Recipient ID or at least one recipient email address.';
            }
            return prepared;
        } catch (Exception e) {
            prepared.errorMessage = e.getMessage();
            return prepared;
        }
    }

    private static Messaging.SingleEmailMessage buildMessage(
        SimpleEmailWithEventInput input,
        SenderContext context,
        List<String> toAddresses,
        List<String> ccAddresses,
        List<String> bccAddresses,
        Id targetId,
        Boolean logEmail,
        String subject,
        String plainBody,
        String htmlBody,
        String method,
        List<String> attendees,
        List<EventDraft> events
    ) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        applySender(mail, input, context);
        if (!toAddresses.isEmpty()) {
            mail.setToAddresses(toAddresses);
        }
        if (!ccAddresses.isEmpty()) {
            mail.setCcAddresses(ccAddresses);
        }
        if (!bccAddresses.isEmpty()) {
            mail.setBccAddresses(bccAddresses);
        }
        if (targetId != null) {
            mail.setTargetObjectId(targetId);
            mail.setTreatTargetObjectAsRecipient(true);
        }
        mail.setSaveAsActivity(logEmail == true && canLogActivity(targetId));
        if (input.relatedRecordId != null && (targetId == null || targetId.getSObjectType() != Lead.SObjectType)) {
            mail.setWhatId(input.relatedRecordId);
        }
        mail.setCharset('UTF-8');
        if (input.emailTemplateId != null && targetId != null) {
            mail.setTemplateId(input.emailTemplateId);
        } else {
            mail.setSubject(String.isBlank(subject) ? firstNonBlank(input.eventSummary, 'Event') : subject);
            if (htmlBody != null) {
                mail.setHtmlBody(htmlBody);
            }
            if (plainBody != null) {
                mail.setPlainTextBody(plainBody);
            }
        }
        List<Messaging.EmailFileAttachment> files = fileAttachments(input, context);
        files.add(calendarAttachment(input, context, method, attendees, events));
        mail.setFileAttachments(files);
        return mail;
    }

    private static Id resolveRecipientTarget(SimpleEmailWithEventInput input, SenderContext context) {
        if (input.recipientId == null) {
            return null;
        }
        Schema.SObjectType type = input.recipientId.getSObjectType();
        if (type == Contact.SObjectType || type == Lead.SObjectType || type == User.SObjectType) {
            return input.recipientId;
        }
        if (type == Account.SObjectType && context.contactIdByPersonAccountId.containsKey(input.recipientId)) {
            return context.contactIdByPersonAccountId.get(input.recipientId);
        }
        throw new SimpleEmailWithEventException(
            'Recipient ID must be a Contact, Lead, User, or Person Account.'
        );
    }

    private static Boolean canLogActivity(Id targetId) {
        if (targetId == null) {
            return false;
        }
        Schema.SObjectType type = targetId.getSObjectType();
        return type == Contact.SObjectType || type == Lead.SObjectType;
    }

    private static void applySender(Messaging.SingleEmailMessage mail, SimpleEmailWithEventInput input, SenderContext context) {
        String type = String.isBlank(input.senderType) ? 'CurrentUser' : input.senderType.trim();
        if (type.equalsIgnoreCase('CurrentUser')) {
            return;
        }
        if (type.equalsIgnoreCase('DefaultWorkflowUser')) {
            throw new SimpleEmailWithEventException(
                'Sender Type DefaultWorkflowUser cannot be set from Apex. Use CurrentUser, or OrgWideEmailAddress with a verified organization-wide email address.'
            );
        }
        if (!type.equalsIgnoreCase('OrgWideEmailAddress')) {
            throw new SimpleEmailWithEventException(
                'Sender Type "' + input.senderType + '" is not recognized. Use CurrentUser, DefaultWorkflowUser, or OrgWideEmailAddress.'
            );
        }
        if (String.isBlank(input.senderEmailAddress)) {
            throw new SimpleEmailWithEventException('Sender Email Address is required when Sender Type is OrgWideEmailAddress.');
        }
        OrgWideEmailAddress owea = context.orgWideByAddress.get(input.senderEmailAddress.trim().toLowerCase());
        if (owea == null) {
            throw new SimpleEmailWithEventException(
                'Organization-wide email address "' + input.senderEmailAddress.trim() + '" was not found.'
            );
        }
        mail.setOrgWideEmailAddressId(owea.Id);
    }

    private static List<Messaging.EmailFileAttachment> fileAttachments(SimpleEmailWithEventInput input, SenderContext context) {
        List<Messaging.EmailFileAttachment> files = new List<Messaging.EmailFileAttachment>();
        for (Id contentId : parseIds(joinLists(input.attachmentId, input.attachmentIdCollection))) {
            ContentVersion version = context.versionById.get(contentId);
            if (version == null) {
                throw new SimpleEmailWithEventException('Attachment "' + contentId + '" was not found.');
            }
            Messaging.EmailFileAttachment file = new Messaging.EmailFileAttachment();
            file.setFileName(fileName(version));
            file.setBody(version.VersionData);
            files.add(file);
        }
        return files;
    }

    private static Messaging.EmailFileAttachment calendarAttachment(
        SimpleEmailWithEventInput input,
        SenderContext context,
        String method,
        List<String> attendees,
        List<EventDraft> events
    ) {
        String ics = buildIcs(input, context, method, attendees, events);
        Messaging.EmailFileAttachment invite = new Messaging.EmailFileAttachment();
        String fileName = method == 'CANCEL' ? 'cancel.ics' : (method == 'REQUEST' ? 'invite.ics' : 'event.ics');
        invite.setFileName(fileName);
        invite.setBody(Blob.valueOf(ics));
        invite.setContentType('text/calendar; charset=utf-8; method=' + method);
        invite.setInline(false);
        return invite;
    }

    @TestVisible
    private static String previewIcs(SimpleEmailWithEventInput input) {
        SenderContext context = loadContext(new List<SimpleEmailWithEventInput>{ input });
        String method = normalizeMethod(input.eventMethod);
        String organizer = organizerEmail(input, context);
        List<String> guests = excludingAddress(attendeeEmails(input, context), organizer);
        if (method == 'REQUEST' && guests.isEmpty()) {
            method = 'PUBLISH';
        }
        List<String> attendees = method == 'REQUEST' ? guests : new List<String>();
        List<EventDraft> events = calendarEvents(input, plainBody(input), htmlBody(input));
        return buildIcs(input, context, method, attendees, events);
    }

    @TestVisible
    private static String buildIcs(
        SimpleEmailWithEventInput input,
        SenderContext context,
        String method,
        List<String> attendees,
        List<EventDraft> events
    ) {
        String organizerAddress = organizerEmail(input, context);
        String organizerName = firstNonBlank(input.organizerName, organizerDisplayName(input, context, organizerAddress));
        String stamp = formatUtc(Datetime.now());

        List<String> lines = new List<String>();
        lines.add('BEGIN:VCALENDAR');
        lines.add('PRODID:' + PRODID);
        lines.add('VERSION:2.0');
        lines.add('CALSCALE:GREGORIAN');
        lines.add('METHOD:' + method);
        for (EventDraft event : events) {
            lines.add('BEGIN:VEVENT');
            lines.add('UID:' + event.uid);
            lines.add('DTSTAMP:' + stamp);
            lines.add(dtProperty('DTSTART', event.startTime, event.allDay, event.timeZoneId));
            lines.add(dtProperty('DTEND', event.endTime, event.allDay, event.timeZoneId));
            lines.add('SUMMARY:' + escapeText(event.summary));
            if (!String.isBlank(event.description)) {
                lines.add('DESCRIPTION:' + escapeText(event.description));
            }
            if (!String.isBlank(event.htmlDescription)) {
                lines.add('X-ALT-DESC;FMTTYPE=text/html:' + escapeText(event.htmlDescription));
            }
            if (!String.isBlank(event.location)) {
                lines.add('LOCATION:' + escapeText(event.location));
            }
            if (!String.isBlank(event.url)) {
                lines.add('URL:' + escapeText(event.url));
            }
            if (!String.isBlank(organizerAddress)) {
                lines.add('ORGANIZER' + cnParam(organizerName) + ':mailto:' + organizerAddress);
            }
            for (String attendee : attendees) {
                lines.add('ATTENDEE;PARTSTAT=NEEDS-ACTION;RSVP=TRUE:mailto:' + attendee);
            }
            lines.add('STATUS:' + (method == 'CANCEL' ? 'CANCELLED' : 'CONFIRMED'));
            lines.add('SEQUENCE:' + String.valueOf(event.sequence));
            lines.add('TRANSP:' + (event.busy ? 'OPAQUE' : 'TRANSPARENT'));
            lines.add('X-MICROSOFT-CDO-BUSYSTATUS:' + (event.busy ? 'BUSY' : 'FREE'));
            if (event.reminderMinutes != null && method != 'CANCEL') {
                lines.add('BEGIN:VALARM');
                lines.add('TRIGGER:-PT' + String.valueOf(event.reminderMinutes) + 'M');
                lines.add('ACTION:DISPLAY');
                lines.add('DESCRIPTION:' + escapeText(event.summary));
                lines.add('END:VALARM');
            }
            lines.add('END:VEVENT');
        }
        lines.add('END:VCALENDAR');
        return foldLines(lines);
    }

    private class EventDraft {
        public Datetime startTime;
        public Datetime endTime;
        public Boolean allDay;
        public String timeZoneId;
        public String summary;
        public String description;
        public String htmlDescription;
        public String location;
        public String url;
        public String uid;
        public Integer sequence;
        public Integer reminderMinutes;
        public Boolean busy;
    }

    private static List<EventDraft> calendarEvents(SimpleEmailWithEventInput input, String plainBody, String htmlBody) {
        EventDraft single = new EventDraft();
        Boolean allDay = input.eventAllDay == true;
        single.startTime = input.eventStart;
        single.endTime = eventEnd(input.eventStart, input.eventEnd, allDay);
        single.allDay = allDay;
        single.timeZoneId = normalizedTimeZone(input.eventTimeZone);
        single.summary = firstNonBlank(input.eventSummary, input.subject, 'Event');
        single.description = firstNonBlank(input.eventDescription, plainBody);
        single.htmlDescription = htmlBody;
        single.location = input.eventLocation;
        single.url = input.eventUrl;
        single.uid = String.isBlank(input.eventUid)
            ? EncodingUtil.convertToHex(Crypto.generateAesKey(128)) + '@threelevers.com'
            : input.eventUid.trim();
        single.sequence = input.eventSequence == null ? 0 : input.eventSequence;
        single.reminderMinutes = input.eventReminderMinutes;
        single.busy = input.eventShowAsBusy != false;
        return new List<EventDraft>{ single };
    }

    private static String dtProperty(String name, Datetime value, Boolean allDay, String timeZoneId) {
        if (allDay) {
            String day = timeZoneId == null ? value.formatGmt('yyyyMMdd') : value.format('yyyyMMdd', timeZoneId);
            return name + ';VALUE=DATE:' + day;
        }
        return name + ':' + formatUtc(value);
    }

    private static Datetime eventEnd(Datetime startTime, Datetime endTime, Boolean allDay) {
        if (endTime != null) {
            if (allDay) {
                return endTime.addDays(1);
            }
            return endTime;
        }
        if (allDay) {
            return startTime.addDays(1);
        }
        return startTime.addMinutes(DEFAULT_DURATION_MINUTES);
    }

    private static String organizerEmail(SimpleEmailWithEventInput input, SenderContext context) {
        if (!String.isBlank(input.organizerEmail)) {
            return input.organizerEmail.trim();
        }
        if (!String.isBlank(input.senderEmailAddress)) {
            return input.senderEmailAddress.trim();
        }
        return context.runningUser.Email;
    }

    private static String organizerDisplayName(SimpleEmailWithEventInput input, SenderContext context, String organizerEmail) {
        if (!String.isBlank(input.senderEmailAddress)) {
            OrgWideEmailAddress owea = context.orgWideByAddress.get(input.senderEmailAddress.trim().toLowerCase());
            if (owea != null && !String.isBlank(owea.DisplayName)) {
                return owea.DisplayName;
            }
        }
        if (context.runningUser.Email == organizerEmail && !String.isBlank(context.runningUser.Name)) {
            return context.runningUser.Name;
        }
        return null;
    }

    private static List<String> attendeeEmails(SimpleEmailWithEventInput input, SenderContext context) {
        List<String> explicit = addresses(input.eventAttendeeAddressList, input.eventAttendeeAddressCollection);
        if (!explicit.isEmpty()) {
            return explicit;
        }
        List<String> fromRecipients = addresses(input.recipientAddressList, input.recipientAddressCollection);
        if (input.recipientId != null) {
            Id targetId = input.recipientId;
            if (context.contactIdByPersonAccountId.containsKey(input.recipientId)) {
                targetId = context.contactIdByPersonAccountId.get(input.recipientId);
            }
            String recipientEmail = context.emailByRecipientId.get(targetId);
            if (!String.isBlank(recipientEmail)) {
                fromRecipients.add(recipientEmail.trim());
            }
        }
        return fromRecipients;
    }

    private static String targetEmail(Id targetId, SenderContext context) {
        if (targetId == null) {
            return null;
        }
        return context.emailByRecipientId.get(targetId);
    }

    private static List<String> excludingAddress(List<String> emails, String address) {
        List<String> rest = new List<String>();
        for (String email : emails) {
            if (!sameEmail(email, address)) {
                rest.add(email);
            }
        }
        return rest;
    }

    private static Boolean containsEmail(List<String> emails, String address) {
        for (String email : emails) {
            if (sameEmail(email, address)) {
                return true;
            }
        }
        return false;
    }

    private static Boolean sameEmail(String left, String right) {
        return !String.isBlank(left) && !String.isBlank(right) && left.trim().equalsIgnoreCase(right.trim());
    }

    private static String htmlBody(SimpleEmailWithEventInput input) {
        if (input.emailTemplateId != null || input.richTextFormattedBody != true) {
            return null;
        }
        String html = input.body;
        if (input.useLineBreaks == true && html != null) {
            html = html.replace('\r\n', '\n').replace('\n', '<br>');
        }
        return html;
    }

    private static String plainBody(SimpleEmailWithEventInput input) {
        if (input.emailTemplateId != null || input.body == null) {
            return null;
        }
        if (input.richTextFormattedBody == true) {
            return stripHtml(input.body);
        }
        return input.body;
    }

    private static String stripHtml(String value) {
        if (value == null) {
            return null;
        }
        String text = value.replaceAll('(?i)<br\\s*/?>', '\n');
        text = text.replaceAll('(?i)</p>', '\n');
        text = text.replaceAll('<[^>]+>', '');
        text = text.replace('&nbsp;', ' ').replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>');
        return text.trim();
    }

    private static String normalizedTimeZone(String eventTimeZone) {
        if (String.isBlank(eventTimeZone)) {
            return null;
        }
        String trimmed = eventTimeZone.trim();
        TimeZone zone = TimeZone.getTimeZone(trimmed);
        if (zone.getID() == 'GMT' && trimmed.toUpperCase() != 'GMT' && trimmed.toUpperCase() != 'UTC') {
            throw new SimpleEmailWithEventException(
                'Event Time Zone "' + trimmed + '" is not recognized. Use a time zone ID such as America/Los_Angeles, or leave it blank to send the event in UTC.'
            );
        }
        return zone.getID();
    }

    private static String normalizeMethod(String eventMethod) {
        if (String.isBlank(eventMethod) || eventMethod.trim().equalsIgnoreCase('Publish')) {
            return 'PUBLISH';
        }
        if (eventMethod.trim().equalsIgnoreCase('Request')) {
            return 'REQUEST';
        }
        if (eventMethod.trim().equalsIgnoreCase('Cancel')) {
            return 'CANCEL';
        }
        throw new SimpleEmailWithEventException(
            'Event Method "' + eventMethod + '" is not recognized. Use Publish, Cancel, or Request.'
        );
    }

    private static List<String> addresses(String commaList, List<String> collection) {
        List<String> values = new List<String>();
        Set<String> seen = new Set<String>();
        addAddress(values, seen, commaList);
        if (collection != null) {
            for (String value : collection) {
                addAddress(values, seen, value);
            }
        }
        return values;
    }

    private static void addAddress(List<String> values, Set<String> seen, String raw) {
        if (String.isBlank(raw)) {
            return;
        }
        for (String part : raw.split(',')) {
            String email = part.trim();
            if (email.length() == 0) {
                continue;
            }
            String key = email.toLowerCase();
            if (seen.contains(key)) {
                continue;
            }
            seen.add(key);
            values.add(email);
        }
    }

    private static String joinLists(String commaList, List<String> collection) {
        List<String> parts = new List<String>();
        if (!String.isBlank(commaList)) {
            parts.add(commaList);
        }
        if (collection != null) {
            parts.addAll(collection);
        }
        return String.join(parts, ',');
    }

    private static Set<Id> parseIds(String raw) {
        Set<Id> ids = new Set<Id>();
        if (String.isBlank(raw)) {
            return ids;
        }
        for (String part : raw.split(',')) {
            String token = part.trim();
            if (token.length() == 0) {
                continue;
            }
            try {
                ids.add((Id) token);
            } catch (Exception e) {
                throw new SimpleEmailWithEventException('Attachment "' + token + '" is not a valid Salesforce Id.');
            }
        }
        return ids;
    }

    private static String fileName(ContentVersion version) {
        String title = String.isBlank(version.Title) ? 'attachment' : version.Title;
        if (String.isBlank(version.FileExtension)) {
            return title;
        }
        if (title.toLowerCase().endsWith('.' + version.FileExtension.toLowerCase())) {
            return title;
        }
        return title + '.' + version.FileExtension;
    }

    private static String joinToken(String value, String token) {
        if (String.isBlank(token)) {
            return value;
        }
        if (String.isBlank(value)) {
            return token;
        }
        return value + ' ' + token;
    }

    private static String firstNonBlank(String first, String second) {
        return firstNonBlank(first, second, null);
    }

    private static String firstNonBlank(String first, String second, String third) {
        if (!String.isBlank(first)) {
            return first;
        }
        if (!String.isBlank(second)) {
            return second;
        }
        return third;
    }

    private static String formatUtc(Datetime value) {
        return value.formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'');
    }

    private static String cnParam(String name) {
        if (String.isBlank(name)) {
            return '';
        }
        String escaped = name.replace('\\', '\\\\').replace('"', '\\"');
        return ';CN="' + escaped + '"';
    }

    private static String escapeText(String value) {
        if (value == null) {
            return '';
        }
        return value
            .replace('\\', '\\\\')
            .replace('\r\n', '\n')
            .replace('\r', '\n')
            .replace('\n', '\\n')
            .replace(',', '\\,')
            .replace(';', '\\;');
    }

    private static String foldLines(List<String> lines) {
        String ics = '';
        for (String line : lines) {
            ics += foldLine(line);
        }
        return ics;
    }

    private static String foldLine(String line) {
        if (line.length() <= 75) {
            return line + '\r\n';
        }
        String folded = line.substring(0, 75) + '\r\n';
        Integer index = 75;
        while (index < line.length()) {
            Integer endIndex = Math.min(index + 74, line.length());
            folded += ' ' + line.substring(index, endIndex) + '\r\n';
            index = endIndex;
        }
        return folded;
    }

    private static String sendError(Messaging.SendEmailResult result) {
        List<String> messages = new List<String>();
        for (Messaging.SendEmailError error : result.getErrors()) {
            messages.add(error.getMessage());
        }
        return messages.isEmpty() ? 'The email could not be sent.' : String.join(messages, ' ');
    }
}
