<#
.SYNOPSIS
    Automated idempotent setup for FaraGamer environment on Windows + WSL.
.DESCRIPTION
    1. Installs WSL and Ubuntu-24.04 if missing.
    2. Bootstraps the WSL instance with all dependencies (CUDA, llama.cpp, Fara).
    3. Downloads models (User Interactive Selection) and sets up Python venvs.
#>

$DistroName = "Ubuntu-24.04"

# --- Step 1: Check/Install WSL and Distro ---
Write-Host "--- Step 1: Checking WSL Prerequisites ---" -ForegroundColor Cyan

if (!(wsl --list --online)) {
    Write-Host "WSL does not appear to be installed or accessible. Installing..."
    wsl --install
    Write-Host "WSL installed. You may need to reboot and run this script again." -ForegroundColor Yellow
    exit
}

$wslList = wsl --list --verbose
if ($wslList -notmatch $DistroName) {
    Write-Host "Installing $DistroName..."
    wsl --install -d $DistroName
    Write-Host "Distro installed. Please create your user account in the popup window, then re-run this script." -ForegroundColor Yellow
    exit
} else {
    Write-Host "$DistroName is already installed." -ForegroundColor Green
}

# --- Step 2: Model Selection ---
Write-Host "`n--- Step 2: Select Model Quantization ---" -ForegroundColor Cyan
Write-Host "Please select a model size appropriate for your VRAM."
Write-Host "Source: https://huggingface.co/bartowski/microsoft_Fara-7B-GGUF" -ForegroundColor Gray

$models = @(
    [PSCustomObject]@{ID=1; Name="Q8_0";   Size="~8.1 GB"; Desc="Max Quality (High VRAM)"; File="microsoft_Fara-7B-Q8_0.gguf"}
    [PSCustomObject]@{ID=2; Name="Q6_K_L"; Size="~6.5 GB"; Desc="High Quality (Good VRAM)"; File="microsoft_Fara-7B-Q6_K_L.gguf"}
    [PSCustomObject]@{ID=3; Name="Q5_K_M"; Size="~5.4 GB"; Desc="Good Balance"; File="microsoft_Fara-7B-Q5_K_M.gguf"}
    [PSCustomObject]@{ID=4; Name="Q4_K_M"; Size="~4.7 GB"; Desc="Recommended (Standard)"; File="microsoft_Fara-7B-Q4_K_M.gguf"}
    [PSCustomObject]@{ID=5; Name="Q3_K_M"; Size="~3.8 GB"; Desc="Low VRAM (Smallest)"; File="microsoft_Fara-7B-Q3_K_M.gguf"}
)

$models | Format-Table -Property ID, Name, Size, Desc -AutoSize

$selection = Read-Host "Enter ID to select (default is 4)"
if ([string]::IsNullOrWhiteSpace($selection)) { $selection = "4" }

$selectedModel = $models | Where-Object { $_.ID -eq $selection }

if ($null -eq $selectedModel) {
    Write-Host "Invalid selection. Defaulting to Q4_K_M." -ForegroundColor Yellow
    $selectedModel = $models | Where-Object { $_.ID -eq 4 }
}

Write-Host "Selected: $($selectedModel.Name) ($($selectedModel.File))" -ForegroundColor Green
$ModelFileName = $selectedModel.File

# --- Step 3: Define the Linux Provisioning Script ---
# We pass the selected filename dynamically into the bash script
$linuxScript = @"
set -e

# Function to check if a package is installed
is_installed() {
    dpkg -s "`$1" &> /dev/null
}

echo "--- Updating Repositories ---"
sudo apt-get update

echo "--- Installing System Dependencies ---"
# Note: Added firefox to dependencies since we removed mirrored networking for Chrome
DEPS="build-essential cmake curl git libcurl4-openssl-dev nvidia-cuda-toolkit python3 python3-pip python3.12-venv direnv firefox"
sudo apt-get install -y \$DEPS

# --- Llama.cpp Setup ---
if [ ! -d ~/llama.cpp ]; then
    echo "--- Cloning llama.cpp ---"
    cd ~
    git clone https://github.com/ggml-org/llama.cpp
else
    echo "llama.cpp directory exists, skipping clone."
fi

echo "--- Building llama.cpp ---"
cd ~/llama.cpp
if [ ! -f ./llama-server ]; then
    cmake -B build -DGGML_CUDA=ON
    cmake --build build --config Release
    if [ ! -L llama-server ]; then
        ln -s ./build/bin/llama-server llama-server
    fi
else
    echo "llama-server binary exists, skipping build."
fi

mkdir -p models

# --- Model Downloads ---
MODEL_FILE="$ModelFileName"
MODEL_URL="https://huggingface.co/bartowski/microsoft_Fara-7B-GGUF/resolve/main/\$MODEL_FILE"

if [ ! -s "models/\$MODEL_FILE" ]; then
    echo "--- Downloading Fara-7B (\$MODEL_FILE) ---"
    wget -O "models/\$MODEL_FILE" "\$MODEL_URL"
else
    echo "Fara-7B Model (\$MODEL_FILE) already downloaded."
fi

if [ ! -s models/Qwen2.5-VL-7B-mmproj-f16.gguf ]; then
    echo "--- Downloading Vision Encoder ---"
    wget -O models/Qwen2.5-VL-7B-mmproj-f16.gguf https://huggingface.co/unsloth/Qwen2.5-VL-7B-Instruct-GGUF/resolve/main/mmproj-F16.gguf
else
    echo "Vision Encoder already downloaded."
fi

# --- Fara Setup ---
cd ~
if [ ! -d ~/fara ]; then
    echo "--- Cloning Fara ---"
    git clone https://github.com/microsoft/fara.git
else
    echo "Fara directory exists, skipping clone."
fi

cd ~/fara

if [ ! -d .venv ]; then
    echo "--- Creating Python Venv ---"
    python3 -m venv .venv
fi

echo "--- Installing Fara Dependencies ---"
source .venv/bin/activate
pip install -e .

if [ ! -d ~/.cache/ms-playwright ]; then
    playwright install
    playwright install-deps
fi

# --- Direnv Setup ---
if ! grep -q "direnv hook bash" ~/.bashrc; then
    echo 'eval "\$(direnv hook bash)"' >> ~/.bashrc
    echo "Added direnv hook to bashrc."
fi

if [ ! -f .envrc ]; then
    echo "source .venv/bin/activate" > .envrc
    direnv allow
fi

echo "--- Checking GPU Status ---"
nvidia-smi
"@

# --- Step 4: Execute Linux Script inside WSL ---
Write-Host "`n--- Step 4: Running Provisioning inside $DistroName ---" -ForegroundColor Cyan
wsl -d $DistroName --cd "~" bash -c "$linuxScript"

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n--- Setup Complete! ---" -ForegroundColor Green
    Write-Host "To start the server, run this inside WSL:"
    Write-Host "cd ~/llama.cpp && ./llama-server -m models/$ModelFileName --mmproj models/Qwen2.5-VL-7B-mmproj-f16.gguf -ngl 99 --port 5000 --ctx-size 15000" -ForegroundColor Yellow
    
    $startNow = Read-Host "Do you want to start the server now? (y/n)"
    if ($startNow -eq 'y') {
        wsl -d $DistroName --cd "~/llama.cpp" bash -c "./llama-server -m models/$ModelFileName --mmproj models/Qwen2.5-VL-7B-mmproj-f16.gguf -ngl 99 --port 5000 --ctx-size 15000"
    }
} else {
    Write-Host "Setup encountered errors." -ForegroundColor Red
}
