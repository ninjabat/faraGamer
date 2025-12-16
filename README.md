# faraGamer

**faraGamer** is a wrapper for Microsoft's [Fara-7B](https://github.com/microsoft/fara) agentic model, optimized for gamer-spec PCs (consumer NVIDIA GPUs with <32GB VRAM).

It enables you to host the LLM locally using **llama.cpp** (avoiding cloud costs) and allows the agent to browse the web autonomously using a headful **Firefox** instance via Playwright.

## Prerequisites

* **Hardware**: NVIDIA GPU with CUDA support (Recommended: 12GB+ VRAM, e.g., RTX 3060, 4070, 4090). Also tested on the smallest model with my 6Gb RTX 3060.
* **OS**: Windows 11 (with WSL2 capability) **OR** Ubuntu (Bare Metal).

## Installation
First make sure you have the most up to date video drivers (including CUDA stuff).

### Option A: Windows 11 (WSL2)
I have a PowerShell script to automate the entire setup, including installing WSL distributions and dependencies.

1.  Open **PowerShell** as Administrator.
2.  Run the setup script:
    ```powershell
    .\setup.ps1
    ```
    *Note: You may need to restart WSL or your computer a few times during this process. The script will prompt you if necessary.*
3. You may need to rerun the script depending on your restart requirements.
   
### Option B: Bare Metal Ubuntu
If you are running natively on Ubuntu, use the provision script to install dependencies, compile `llama.cpp`, and set up the Python environment.

1.  Download the best fit model file for your GPU (powershell install provides a menu): https://huggingface.co/bartowski/microsoft_Fara-7B-GGUF.
2.  Open a terminal.
3.  Run the provision script:
    ```bash
    ./provision.sh $MODELFILE
    ```

## Usage

### 1. Start the Model Server
Open a terminal (in WSL or Ubuntu) and launch the `llama.cpp` server. This hosts the Fara model locally on port 5000.

```bash
cd ~/llama.cpp
./llama-server -m models/$MODEL_NAME --mmproj models/Qwen2.5-VL-7B-mmproj-f16.gguf -ngl 99 --port 5000 --ctx-size 15000
```

### 2. Query the model
(separate tab) if installed correctly the virtual environment should be handled for you.
```
cd ~/fara
fara-cli --headful --task "whats the weather in san francisco now"
```
