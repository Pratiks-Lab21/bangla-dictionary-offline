# Windows Installer

This folder contains an Inno Setup script to build a one-click installer `.exe`.

## Steps

1. Build the app in release mode:

```powershell
flutter build windows --release
```

2. Install Inno Setup:

https://jrsoftware.org/isinfo.php

3. Open:

`installer\english_bangla_dictionary_desktop.iss`

4. In Inno Setup, click `Build` > `Compile`

5. Your installer `.exe` will be created in:

`installer_output\english-bangla-dictionary-setup.exe`

## Notes

- Before publishing, update `MyAppVersion`
- Replace `MyAppURL` with your real GitHub repo URL
- If you later add an app icon, it can be wired into the installer too
