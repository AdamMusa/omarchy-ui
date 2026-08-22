# Omarchy Phone Ruby

Ruby-framework reimplementation of Omarchy Phone. It discovers Android devices through ADB,
trusted iPhones through libimobiledevice, launches scrcpy for Android control, and runs UxPlay
for iPhone AirPlay mirroring.

Deploy from the framework repository:

```bash
bin/omarchy_ui push examples/omarchy-phone
```

The push command vendors the Ruby framework and QML runtime into its staging directory; this
source directory intentionally contains only application-specific Ruby and manifest files.
