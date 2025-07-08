# MCScripts

MCScripts is a repository that contains multiple utility scripts for your Minecraft servers or proxies.

## Installation scripts

Setting up servers like Paper, Velocity, or others can be tedious: you need to download the jar, move it,
and write a script to run it. These installation scripts aim to simplify that process. They work on both
Linux and Windows and are ideal for local or development servers (In production, panels usually handle this for you).

### Before installing

Below you will find the installation scripts for both Linux and Windows. I recommend to keep a copy
of these scripts on your desktop or somewhere accessible and just copy-paste them when needed,
as they are designed to auto-update if they ever stop working!

The first time you run an installation script, it will ask you:

- The platform to use (`paper`, `folia`, `velocity`, or `waterfall`)
- The version to use (typically just `latest`)
- The amount of RAM to allocate (default: `1G`)
- (Optional) JVM flags (`aikar` will be replaced with [Aikar's flags](https://docs.papermc.io/paper/aikars-flags/))
- (Optional) Jar flags (e.g., `--nogui` for Paper)

These settings will be saved to an `mcsconfig.env` file that you can edit later if needed.

### For linux

For linux you will need to install:
- curl (`sudo apt install curl`). Used to download the scripts and to get the JSONs.
- jq (`sudo apt install jq`). Used for JSON parsing.
- java, for obvious reasons.

You can just run the installation script with:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/xDec0de/MCScripts/refs/heads/main/start.sh)
```

This will download and run the `start.sh` script found on this repository. You can also
create a simple script with the following content to reuse it, you can name it `run.sh`:

```bash
#!/bin/bash

bash <(curl -fsSL https://raw.githubusercontent.com/xDec0de/MCScripts/refs/heads/main/start.sh)
```

You may need to make the script executable with `chmod +x run.sh`

### For Windows

I personally develop servers locally on Windows, so this will be helpful for those like me.
Fortunately, Windows 10 and 11 come with **curl** pre-installed, and **jq** is not required.
You still obviously need **Java**.

Just create a script with the following content to re-use it, you can name it `run.bat`:

```batch
@echo off

setlocal
set "URL=https://raw.githubusercontent.com/xDec0de/MCScripts/refs/heads/main/start.bat"
set "FILE=%TEMP%\remote_start.bat"
powershell -Command "Invoke-WebRequest -Uri '%URL%' -OutFile '%FILE%'"
call "%FILE%"
del "%FILE%"
endlocal
```
