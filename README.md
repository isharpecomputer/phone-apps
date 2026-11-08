# iSharpe phone apps

Install files (APKs) for iSharpe's own Android apps. Each app version is a [release](../../releases);
`apps.json` lists the latest version of every app and is what the **My Apps** installer reads.

## Install on a phone
- **My Apps installer (easiest):** open the latest `My Apps` release on the phone, download the APK, and install it
  (Android asks once to allow installs from your browser). From then on, My Apps shows every app here with
  Install / Update buttons, and updates itself too.
- **Obtainium:** add `https://github.com/isharpecomputer/phone-apps` as an app source, and under
  "Filter release titles by regular expression" put the app's name, e.g. `^Minimal Launcher`. Add it once per app.

All apps are signed with the same key, so updates install over the old version without losing settings.
