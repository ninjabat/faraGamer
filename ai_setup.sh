#!/bin/bash

# this script helps set up the wsl instance with the LLM
# FARA model comparison: https://huggingface.co/bartowski/microsoft_Fara-7B-GGUF
#

# in powershell:
# wsl --install
# wsl --install -d Ubuntu-24.04
## set up your user account
# 
# create wsl config (for chrome suport), save in .wslconfig in your home user directory in windows
#[wsl2]
#networkingMode=mirrored
# powershell, restart WSL
# wsl --shutdown

# (in WSL) install dependencies
cd ~
sudo apt update
sudo apt install -y build-essential cmake curl git libcurl4-openssl-dev
sudo apt install -y nvidia-cuda-toolkit

# install lamma.cpp
git clone https://github.com/ggml-org/llama.cpp
cd llama.cpp
cmake -B build -DGGML_CUDA=ON
cmake --build build --config Release
ln -s ./build/bin/llama-server llama-server
mkdir -p models

# replace this with a smaller model if needed
wget -O models/microsoft_Fara-7B-Q6_K_L.gguf https://huggingface.co/bartowski/microsoft_Fara-7B-GGUF/resolve/main/microsoft_Fara-7B-Q6_K_L.gguf

# download the vision encoder
wget -O models/Qwen2.5-VL-7B-mmproj-f16.gguf https://huggingface.co/unsloth/Qwen2.5-VL-7B-Instruct-GGUF/resolve/main/mmproj-F16.gguf


# now install fara
cd ~
sudo apt install git python3 python3-pip python3.12-venv
git clone https://github.com/microsoft/fara.git
cd fara/
python3 -m venv .venv
source .venv/bin/activate
pip install -e .
playwright install
playwright install-deps


#pip install vllm
#pip install torch-c-dlpack-ext

# check gpu is working 
nvidia-smi

# pause before coontinueing
read -p "Press enter to start the server...."

# quantization for 16GB vram, single card
#vllm serve microsoft/Fara-7B --quantization $QUANT --port 5000 --dtype auto --tensor-parallel-size 1
cd llama.cpp
./llama-server -m models/microsoft_Fara-7B-Q6_K_L.gguf --mmproj models/Qwen2.5-VL-7B-mmproj-f16.gguf -ngl 99 --port 5000 --ctx-size 8192
