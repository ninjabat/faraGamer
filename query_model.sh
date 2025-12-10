#!/bin/bash
# from windows, run chrome:  & "C:\Program Files\Google\Chrome\Application\chrome.exe" --remote-debugging-port=9222 --remote-allow-origins=* --remote-debugging-address=0.0.0.0

cd ~/fara
python3 -m venv .venv
source .venv/bin/activate

fara-cli --headful --task "whats the weather in new york now"
