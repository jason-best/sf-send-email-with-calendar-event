# Flow configuration

Add Apex action **Send Email with Calendar Event**. Each run sends one event. Inputs are grouped into Recipients, Sender, Message, Attachments and Logging, Event, Update or Cancel, and Meeting Request.

## Action name

| Install method | Flow action |
|----------------|-------------|
| Unlocked package | **Send Email with Calendar Event** (`three_levers.SimpleEmailWithEvent`) |
| Deploy from source | **Send Email with Calendar Event** (`SimpleEmailWithEvent`) |

## Send an event

1. Set To addresses, or a Recipient ID.
2. Set Subject and Body, or an Email Template ID.
3. Set **Event Start**.
4. Store the **Event UID** output.

A blank Event End makes a timed event last one hour. For an all-day event, Event End is the last day, and a blank end means that day only. Timed events are written in UTC. All-day events use a calendar date in Event Time Zone, or the UTC date when that zone is blank.

Event Method defaults to **Publish**: an event with no participants. **Request** sends a meeting invite. **Cancel** removes an event when you reuse Event UID and send a higher Event Sequence.

## Required pieces

| Input | When it is required |
|-------|---------------------|
| Event Start | Always. |
| Subject and Body | When no Email Template ID is set. |
| Recipient ID | When using an email template, and when Log Email on Send is true. |
| Sender Email Address | When Sender Type is OrgWideEmailAddress. |
| Related Record ID | When using merge fields, logging against a record, or adding an Email-to-Case threading token. A Lead Recipient ID cannot be combined with Related Record ID. |

## Event inputs

| Input | When it is blank |
|-------|------------------|
| Event End | Timed events last one hour. All-day events last the start day only. |
| Event All Day | Timed event. |
| Event Time Zone | All-day dates use the UTC date. |
| Event Summary | Uses Subject. |
| Event Description | Uses the plain-text email body. |
| Event Location | Omitted. |
| Event URL | Omitted. |
| Organizer Name | Uses the sending address display name when available. |
| Organizer Email | Uses Sender Email Address, then the running user email. |
| Event UID | A new id is created. Store the output to cancel later. |
| Event Sequence | `0` for a new event. Increase it when canceling or replacing an existing Event UID. |
| Event Method | Publish. |
| Event Reminder Minutes | No reminder. |
| Event Show As Busy | Busy. |
| Event Attendee addresses | Used only when Event Method is Request. Blank uses the To recipients. |

## Cancel

Send again with:

- Event Method `Cancel`
- The same Event UID you stored
- A higher Event Sequence than the previous send for that UID

## Outputs

| Output | Notes |
|--------|-------|
| Success | True when the email is sent. |
| Error Message | Blank on success. |
| Event UID | The id written into the calendar file. Store it to cancel the same event later. |

Pass that Event UID into **Add to Calendar** when a screen button should download the same event.
