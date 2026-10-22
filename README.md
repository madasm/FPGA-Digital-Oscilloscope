# FPGA-Based Digital Oscilloscope (Basys 3)

A 12-bit digital storage oscilloscope implemented on the Digilent Basys 3 (Artix-7 FPGA). The system captures analog signals using the onboard XADC, stores them in Block RAM, and streams the data over UART to a Python-based PC application for real-time waveform visualization.

## 🚀 Features
*   **12-bit Resolution:** Utilizes the built-in Xilinx XADC.
*   **640-Sample Buffer:** Captures 640 samples per frame in on-chip Block RAM (BRAM).
*   **Hardware Triggering:** Rising-edge trigger logic with an adjustable threshold (controlled via onboard DIP switches SW8–SW15).
*   **High-Speed UART:** Streams data to the PC at 921,600 baud.
*   **Real-Time GUI:** Python + PyQtGraph viewer with a scope-style graticule and live measurements (Vpp, Vmax, Vmin, Vavg, Vrms, Frequency).

## 🛠️ Architecture
The signal flows through the following pipeline:
`Analog Input -> Voltage Divider -> XADC -> Trigger FSM -> BRAM -> Readout FSM -> UART -> Python GUI`

## 📂 Repository Structure
*   `rtl/` - Verilog source files for the FPGA logic.
*   `constraints/` - XDC file for Basys 3 pin mapping.
*   `sim/` - Vivado behavioral simulation testbench (`tb_scope.v`).
*   `python/` - PC-side real-time visualization script (`scope.py`).

## 📋 Hardware Requirements
*   Digilent Basys 3 (Artix-7 XC7A35T)
*   Function Generator
*   Breadboard & Jumper Wires
*   **10kΩ and 1kΩ Resistors** (For the voltage divider)

> ⚠️ **CRITICAL WARNING:** The XADC has a maximum input limit of **1V**. Feeding a standard function generator (which outputs 4Vpp to 10Vpp) directly into the board will permanently damage the FPGA. A 10kΩ + 1kΩ voltage divider (÷11 attenuation) is strictly required to scale the signal down to a safe 0–0.36V range.

## 💻 Software Requirements
*   Xilinx Vivado (Tested on 2018.2)
*   Python 3.x
*   Python Libraries: `pyserial`, `numpy`, `pyqtgraph`, `PyQt5`

## 🏃‍♂️ How to Run

### 1. FPGA Setup
1. Open Vivado and create a new RTL project for the Basys 3.
2. Add all files from the `rtl/` folder to Design Sources.
3. Add `constraints/oscilloscope.xdc` to Constraints.
4. Set `top_oscilloscope.v` as the top module.
5. Generate the bitstream and program the board.

### 2. Hardware Wiring
Connect the function generator to the JXADC header on the Basys 3 through the voltage divider:
*   **JXADC Pin 1 (J3):** Signal input (from the divider junction).
*   **JXADC Pin 2 (L3):** Ground.
*   **JXADC Pin 5 (GND):** Ground.
*(Ensure the ground of the function generator is tied to the Basys 3 ground).*

### 3. Python GUI Setup
1. Navigate to the `python/` folder on your PC.
2. Install dependencies:
   ```bash
   pip install pyserial numpy pyqtgraph PyQt5
