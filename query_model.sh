#!/bin/bash
# from windows: kill chrome then relaunch in debug mode
# echo "killing your chrome!!!"
# taskkill /F /IM chrome.exe
# & "C:\Program Files\Google\Chrome\Application\chrome.exe" --remote-debugging-port=9222 --remote-allow-origins=127.0.0.1 --remote-debugging-address=0.0.0.0

cd ~/fara
python3 -m venv .venv
source .venv/bin/activate

fara-cli --headful --task "whats the weather in new york now"
