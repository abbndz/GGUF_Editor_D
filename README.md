# GGUF Editor D++ 🛠️

<div align="center">

  [![License](https://img.shields.io/badge/License-Non--Commercial%20Open%20Source-blue.svg)](LICENSE)
  [![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-green.svg)](https://www.microsoft.com)
  [![Language](https://img.shields.io/badge/Language-Delphi%20Object%20Pascal-orange.svg)](https://www.embarcadero.com/products/delphi)

  **The visual IDE for GGUF and Safetensors model manipulation.**

  *Bridge the gap between complex Python scripts and simple inference tools.*

  [📖 Documentation](Doc/index.md) • [✨ Features](#-key-features) • [⬇️ Download](#-download)

</div>
 
---

## 🚀 Overview

Most LLM manipulation tools (like Mergekit or AutoGPTQ) require a deep knowledge of Python, command-line environments, and complex configuration files. **GGUF Editor D++** changes that.

It is a high-performance, native Windows desktop application designed for researchers and AI enthusiasts who need **surgical precision** over their model weights without the overhead of a Python environment. 

Whether you are merging models, inspecting tensor distributions, or performing intelligent quantization, GGUF Editor D++ provides a powerful, visual, and intuitive interface.

---

## ✨ Key Features

### 🔄 Advanced Model Merging & Editing
*   **Multi-Source Engine:** Load up to three sources simultaneously:
    *   **Model A (GGUF):** Your base architecture.
    *   **Model B (GGUF):** The weights to merge.
    *   **Model S (Safetensors):** Direct integration of PyTorch weights.
*   **Granular Layer Control:** Don't just merge everything. Select specific tensors, entire blocks (`blks`), or use filters (e.g., `Mod 2` for odd layers) to perform complex architectural surgery.

### 👁️ Visual Tensor Intelligence (The "IDE" Experience)
*   **Real-Time Inspection:** View the raw float values of any tensor instantly.
*   **Visual Analysis:** Use interactive **Time-Series plots** and **Histograms** to detect anomalies, outliers, or weight distribution shifts.
*   **Mathematical Diffing:** Subtract two tensors (**T1 - T2**) to visualize exactly how a merge or a quantization affected the weights.

### 🧠 Intelligent Quantization
*   **High-Fidelity Engine:** Leverages native `ggml-base.dll` (Llama.cpp) for quantization/dequantization with minimal RMSE loss.
*   **Software Fallback:** Built-in implementation mode for maximum stability when DLLs are unavailable.
*   **Quantization Simulation:** Preview the impact of a quantization (e.g., FP32 $\rightarrow$ Q4_K) before committing to disk.

### 🗺️ Automated Name Mapping
*   Adapt models to new architectures instantly using a powerful pattern-matching engine (e.g., `blk.{}.attn.weight`).
*   Support for external `.txt` mapping configuration files.

### 📦 File Management
*   **Smart Split:** Break massive GGUF models into manageable shards (e.g., 4GB).
*   **Seamless Merge:** Recombine shards into a single, coherent file.

---

## 🛠️ Technical Architecture

Built for performance and low memory footprint.

*   **Engine:** Native Windows (Delphi/Object Pascal) for maximum stability.
*   **Memory Management:** **Lazy-Loading Architecture**. Raw tensor data is only decoded into RAM during visualization or processing, allowing you to handle massive models even on hardware with limited RAM.
*   **Core Modules:**
    *   `uGGUFReader/Writer`: High-speed binary I/O.
    *   `uGgmlQuants`: C++/DLL integration for math-heavy operations.
    *   `uViewTensors`: Real-time graphical processing.

---

##   [📖 Documentation](Doc/index.md) 

---

## 📥 Download & Installation

1.  Go to the [Releases](#) page.
2.  Download the latest `.zip` for Windows.
3.  Extract and run `GGUFEditorD++.exe`.
4.  *Note: Ensure all accompanying DLLs are in the same folder.*

---

## 🤝 Support & Contribution

GGUF Editor D++ is a passion project. If this tool helps your research, please consider supporting its development.

*   **Donations:** [PayPal](mailto:abbndz@gmail.com) • [Ko-fi](https://ko-fi.com/abbndz)
*   **Contributions:** We welcome bug reports, feature requests, and new mapping files!

---

## 📄 License

This project is **Open Source for Non-Commercial Use**. 
For commercial licensing or enterprise inquiries, please contact the author.

© 2026 GGUF Editor D++ By ABBN.
