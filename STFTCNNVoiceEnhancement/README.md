# Audio Signal Processor
This is a VLSI Project for the course CE-392 at Northwestern University.

The goal is to design a signal processor, that records noisy audio data, performs a short-time Fourier Transform (STFT) and uses a u-net CNN to remove the background noise. 
We then perform an iSTFT to get back to frequency domain and ouput the cleaned audio.

## Design Characteristics
### Data formats
- STFT input: 16int
- STFT output: Q1.6
- Convolution weights input: Q1.6
- Convolution pixel input: Q1.6
- Convolutoin pixel output: Q6.12

## Testbench Usage

This Makefile automates the simulation and verification flow for multiple RTL modules using QuestaSim and Python-based reference models.

### Prerequisites
#### Testbenches

The SystemVerilog Testbenches need a licenced QuestaSim 22.1std or compatible version.

#### Python Verification Scripts
The python verification scripts run in a Conda Environment with Python 3.12 to ensure the correct version of Tensorflow.

### Basic Flow

Most test targets support the following stages:

- **GEN=1**: Generate input test vectors
- **SIM=1**: Run RTL simulation (default)
- **PLOT=1**: Plot verification results
- **GUI=1**: Launch QuestaSim GUI

### Common Commands

#### Run a complete test

```bash
make conv GEN=1 SIM=1
```

#### Run simulation only

```bash
make conv
```

#### Run with Questa GUI

```bash
make conv GUI=1
```

#### Generate data only

```bash
make conv GEN=1 SIM=0
```

#### Plot results

```bash
make conv PLOT=1
```

### Available Test Targets

| Target | Description |
|----------|------------|
| `conv` | 3×3 convolution |
| `addbias` | Bias addition |
| `relu` | ReLU activation |
| `upsample` | 2×2 upsampling |
| `multi_upsample` | Multi-channel upsampling |
| `onestage` | OneStage module |
| `block` | Block module |
| `down_serial` | Downstream Serial module |
| `conv_layer` | Convolution layer |
| `cnn_top` | CNN top-level |
| `cnn_top_folded` | Folded CNN top-level |
| `delay_fifo` | Delay FIFO |
| `stft` | STFT testbench |

### Environment Check

```bash
make check_env
```

Displays the Python executable used inside the Conda environment.

### Build Initialization

```bash
make init
```

Creates:

```text
build_sim/
└── work/
```

and initializes the Questa work library.

### Clean Workspace

```bash
make clean
```

Removes all simulation build artifacts.

### Examples

Run folded CNN verification:

```bash
make cnn_top_folded GEN=1 SIM=1
```

Open waveform GUI for convolution layer:

```bash
make conv_layer GUI=1
```

Generate plots for ReLU verification:

```bash
make relu PLOT=1
```

