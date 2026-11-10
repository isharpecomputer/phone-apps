# iSharpe phone apps

Install files (APKs) for iSharpe's own Android apps. Each app version is a [release](../../releases);
`apps.json` lists the latest version of every app and is what the **iSharpe Depot** installer (called My Apps before 0.3) reads.

## Install on a phone
- **iSharpe Depot installer (easiest):** open the latest `iSharpe Depot` release on the phone, download the APK, and install it
  (Android asks once to allow installs from your browser). From then on, iSharpe Depot shows every app here with
  Install / Update buttons, and updates itself too.
- **Obtainium:** add `https://github.com/isharpecomputer/phone-apps` as an app source, and under
  "Filter release titles by regular expression" put the app's name, e.g. `^Sharp`. Add it once per app.

All apps are signed with the same key, so updates install over the old version without losing settings.
