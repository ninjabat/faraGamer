#!/bin/bash
set -e

# The model filename is passed as the first argument
MODEL_FILE="$1"

if [ -z "$MODEL_FILE" ]; then
    echo "Error: No model filename provided. Usage: ./provision.sh <filename>"
    exit 1
fi

# Function to check if a package is installed
is_installed() {
    dpkg -s "$1" &> /dev/null
}

echo "--- Updating Repositories ---"
sudo apt-get update

echo "--- Installing System Dependencies ---"
# Added firefox, removed chrome/wslview specific dependencies
DEPS="build-essential cmake curl git libcurl4-openssl-dev nvidia-cuda-toolkit python3 python3-pip python3.12-venv direnv firefox"
sudo apt-get install -y $DEPS

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
MODEL_URL="https://huggingface.co/bartowski/microsoft_Fara-7B-GGUF/resolve/main/$MODEL_FILE"

if [ ! -s "models/$MODEL_FILE" ]; then
    echo "--- Downloading Fara-7B ($MODEL_FILE) ---"
    wget -O "models/$MODEL_FILE" "$MODEL_URL"
else
    echo "Fara-7B Model ($MODEL_FILE) already downloaded."
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
    echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
    echo "Added direnv hook to bashrc."
fi

if [ ! -f .envrc ]; then
    echo "source .venv/bin/activate" > .envrc
    direnv allow
fi

echo "--- Checking GPU Status ---"
nvidia-smi
