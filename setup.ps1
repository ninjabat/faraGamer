<#
.SYNOPSIS
    Automated idempotent setup for FaraGamer environment on Windows + WSL.
.DESCRIPTION
    1. Installs WSL and Ubuntu-24.04 if missing.
    2. Downloads models (User Interactive Selection).
    3. Executes the standalone provision.sh script inside WSL.
#>

$DistroName = "Ubuntu-24.04"
$ProvisionScriptName = "provision.sh"

# --- Robust Path Detection ---
# Fixes issue where $PSScriptRoot is empty when running interactively (e.g. F8 in VS Code)
if ($PSScriptRoot) {
    $ScriptDir = $PSScriptRoot
} else {
    $ScriptDir = Get-Location
}

# --- Step 1: Check/Install WSL and Distro ---
Write-Host "--- Step 1: Checking WSL Prerequisites ---" -ForegroundColor Cyan

if (!(wsl --list --online)) {
    Write-Host "WSL does not appear to be installed or accessible. Installing..."
    wsl --install
    Write-Host "WSL installed. You may need to reboot and run this script again." -ForegroundColor Yellow
    exit
}

# Try to run 'true' inside the distro. 
# 2>$null hides the error text if the distro doesn't exist.
wsl -d $DistroName -e true 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "$DistroName is already installed." -ForegroundColor Green
} else { 
    Write-Host "Distro not found. Installing $DistroName..."
    wsl --install -d $DistroName
    Write-Host "Distro installed. Please create your user account in the popup window, then re-run this script." -ForegroundColor Yellow
    exit
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

# --- Step 3: Locate and Run Provisioning Script ---
Write-Host "`n--- Step 3: Running Provisioning inside $DistroName ---" -ForegroundColor Cyan

# Locate the provision.sh script relative to this script
$LocalScriptPath = Join-Path -Path $ScriptDir -ChildPath $ProvisionScriptName

if (!(Test-Path $LocalScriptPath)) {
    Write-Error "Could not find $ProvisionScriptName in $ScriptDir. Please ensure both files are in the same directory."
    exit
}

# Fix: Replace backslashes with forward slashes so Linux doesn't treat them as escape characters
$SafePath = $LocalScriptPath -replace "\\", "/"
Write-Host "Using safe path: $SafePath" -ForegroundColor Gray

# Convert the Windows path to a WSL path using the safe string
$WslScriptPath = wsl -d $DistroName wslpath -a "$SafePath" 2>$null

if ([string]::IsNullOrWhiteSpace($WslScriptPath)) {
    Write-Error "Failed to convert path to WSL format. Please check WSL functionality."
    exit
}

Write-Host "Executing $ProvisionScriptName from $WslScriptPath..."

# Execute the script. 
# Fix: Use 'cat | tr' instead of '<' redirection to avoid path parsing issues
# This creates a safe temp copy in /tmp and runs it.
wsl -d $DistroName --cd "~" bash -c "cat '$WslScriptPath' | tr -d '\r' > /tmp/provision_safe.sh && bash /tmp/provision_safe.sh '$ModelFileName'"

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
