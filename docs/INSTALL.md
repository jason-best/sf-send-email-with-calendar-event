# Installation

## Option A — Install unlocked package (recommended)

**Version:** `0.1.0-4` (released)  
**Subscriber package version Id:** `04tgL000000VyxZQAS`

| Org type | Install URL |
|----------|-------------|
| Production | https://login.salesforce.com/packaging/installPackage.apexp?p0=04tgL000000VyxZQAS |
| Sandbox | https://test.salesforce.com/packaging/installPackage.apexp?p0=04tgL000000VyxZQAS |

CLI:

```bash
sf package install --package 04tgL000000VyxZQAS --target-org <alias>
```

No installation key. After install, add Flow action **Send Email with Calendar Event** (`three_levers.SimpleEmailWithEvent`).

## Option B — Deploy from source

### Namespaced scratch org (matches package)

```bash
sf org create scratch --definition-file config/project-scratch-def.json --alias send-email-calendar-scratch --set-default
sf project deploy start --manifest manifest/package.xml --target-org send-email-calendar-scratch --test-level RunLocalTests
```

### Unpackaged deploy (no namespace)

Remove or omit `"namespace"` in `sfdx-project.json`, then deploy to your dev org:

```bash
sf project deploy start --manifest manifest/package.xml --target-org <alias> --test-level RunLocalTests
```

The Flow action class is `SimpleEmailWithEvent`. In a subscriber org that installed the package, Flow Builder shows it only because the class, invocable method, and invocable variables are `global`.

## Post-install

Confirm the running user, or the organization-wide address you select, can send email. No Sites or Named Credentials.

## Upgrade

Install a newer package version from the [README](../README.md#install-package) or redeploy from source.
