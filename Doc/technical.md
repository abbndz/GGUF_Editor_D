# Technical Architecture

Documentation for developers and contributors.

## Technologies Used

- **Language:** Delphi 10/11/12 (Object Pascal).
- **GUI:** VCL (Visual Component Library).
- **Graphics:** TeeChart (for complex charts).
- **FFI:** Dynamic loading of C/C++ DLLs (`ggml-base.dll`).

## Module Structure

| Unit File | Role |
|---|---|
| `uGGUFModel.pas` | Data class definitions (Tensors, KVs). |
| `uGGUFReader.pas` | Binary reading of GGUF files. |
| `uGGUFWriter.pas` | Writing and manipulation of output streams. |
| `uGgmlQuants.pas` | Interface with quantization functions (DLL or Impl). |
| `uViewTensors.pas` | Visualization logic, anomaly detection, and charts. |
| `uTensorTranspose.pas` | Matrix transposition logic (for Safetensors). |

## Mapping Format

Mapping files are text files (`.txt`) containing `pattern=replacement` rules.

model.layers.0.input_layernorm.weight -> attention.input_layernorm
model.layers.{}.feed_forward.w1.weight -> mlp.gate


## Memory Management

The application uses a **"Lazy Load"** approach for tensor data. Raw data is only decoded into memory (F32) at the moment of display in charts or quantization, in order to minimize RAM footprint on very large models.

---
[ 🏠 Home ](index.md)  [⚙️ Features ](features.md)  [📘 User Guide](usage.md)  [🔧 Technical ](technical.md) [ ❤️ Support ](donate.md) 
---

© 2026 GGUF Editor D++ By ABBN.
