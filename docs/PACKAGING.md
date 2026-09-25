# Packaging (2GP)

**This public repo** is for source distribution, documentation, and deploy-from-source.

**2GP package builds** (`package version create`, promote, subscriber version Ids) are done from the private **ThreeLeversDevOrg** monorepo:

- Package name: `Send Email with Calendar Event`
- Package path: `force-app/package-send-email-with-calendar-event/` (Apex `SimpleEmailWithEvent` and Flow input grouping)
- Internal docs: `docs/send-email-with-calendar-event.md`
- Sync: `scripts/sync-package-send-email-with-calendar-event.ps1` (main → package)
- Public sync: `scripts/sync-public-send-email-with-calendar-event.ps1` (main → this repo)

Subscriber-facing Apex stays `global`: the class, invocable method, input and output classes, and invocable variables. `SimpleEmailWithEventException` stays `public`.

When a new package version is released, update the install URLs in [README.md](../README.md) and [docs/INSTALL.md](INSTALL.md) with the new `04t…` subscriber version Id.

Do not run `package version create` from this repo clone alone unless you have configured the same Dev Hub and package directory layout.
