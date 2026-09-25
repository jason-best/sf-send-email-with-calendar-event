# Send Email with Calendar Event

Flow invocable that sends an email and attaches a calendar file so clients can add the event. A later send can cancel that same event.

[![License](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](LICENSE)
[![Salesforce API](https://img.shields.io/badge/Salesforce_API-65.0-00A1E0)](https://developer.salesforce.com)

---

## Features

- Flow action with the same recipient, sender, template, and attachment style as Send Email
- Attaches one calendar event clients can add. There is no Event Collection input
- **Publish** (default) sends an event with no participants
- **Request** sends a meeting invite
- **Cancel** reuses the stored Event UID with a higher Event Sequence
- Timed events are written in UTC. All-day events use a calendar date in the named time zone
- **Unlocked 2GP package** — install in any org

---

## Quick start

1. **Install** the unlocked package ([Install](#install-package)) or [deploy from source](docs/INSTALL.md).
2. In a Flow, add the action **Send Email with Calendar Event**.
3. Set recipients, subject or an email template, body, and **Event Start**.
4. Store the **Event UID** output. To cancel later, send again with Event Method `Cancel`, that same UID, and a higher Event Sequence.

See [Flow configuration](docs/FLOW.md).

---

## Install package

**Version `0.1.1-1` (released)** · Subscriber version Id `04tgL000000W4WjQAK`

| Org | URL |
|-----|-----|
| Production | https://login.salesforce.com/packaging/installPackage.apexp?p0=04tgL000000W4WjQAK |
| Sandbox | https://test.salesforce.com/packaging/installPackage.apexp?p0=04tgL000000W4WjQAK |

```bash
sf package install --package 04tgL000000W4WjQAK --target-org <alias>
```

After install, the Flow action is **Send Email with Calendar Event** (`three_levers.SimpleEmailWithEvent`).

**Deploy from source:** [docs/INSTALL.md](docs/INSTALL.md)

---

## Requirements

- Salesforce with Flow and permission to send email (API 65.0 source)
- A verified organization-wide email address when Sender Type is OrgWideEmailAddress

---

## Development

```bash
sf org create scratch --definition-file config/project-scratch-def.json --alias send-email-calendar-scratch --set-default
sf project deploy start --manifest manifest/package.xml --target-org send-email-calendar-scratch --test-level RunLocalTests
```

Packaging and 2GP releases are maintained in the private [ThreeLeversDevOrg](https://github.com/jason-best/ThreeLeversDevOrg) monorepo. Source and docs: [jason-best/sf-send-email-with-calendar-event](https://github.com/jason-best/sf-send-email-with-calendar-event). See [docs/PACKAGING.md](docs/PACKAGING.md).

---

## License

[BSD 3-Clause](LICENSE) · Copyright Three Levers

---

## Support

Questions or consulting: [threelevers.com/contact](https://threelevers.com/contact/)
