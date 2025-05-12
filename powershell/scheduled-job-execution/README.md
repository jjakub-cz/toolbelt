# 🐚 Powershell Script for scheduled tasks

This folder contains template and example script for scenario where I had to manage multiple scheduled jobs on windows platform, that are calling local/remote endpoints. Key features had to be ability to write output and status to LOG file forwarded to Splunk AND send e-mail notifications.

&nbsp;

## 📜 Available Scripts

### `example.ps1`
Example script for one job.

### `utils.psm1`
Script that has to be included in our `example.ps1` script file.

&nbsp;

## 🛠️ Settings

You have to be aware of some setting needed to be done in scripts. For example:
* `utils.psm1` L:89 - to set _$LogPath_
* `utils.psm1` L:111 - to set SMTP server address
* `utils.psm1` L:113 - to set e-mail sender address
* `example.ps1` - self explanatory, you'll figure it out ;-)


&nbsp;

## 📄 License
All scripts in this folder are covered by the root-level [MIT License](../../LICENSE).
