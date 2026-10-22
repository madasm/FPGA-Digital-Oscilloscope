"""
FPGA-Based Digital Oscilloscope - PC-Side Client
Reads 4-digit ASCII samples from Basys 3 over UART and displays live.
Requires: pyserial, numpy, pyqtgraph, PyQt5
"""

import sys, time, serial
import numpy as np
import pyqtgraph as pg
from pyqtgraph.Qt import QtCore, QtWidgets

# ---- CONFIG ----
COM_PORT    = 'COM5'  # UPDATE THIS TO MATCH YOUR PC (e.g., COM3, COM6)
BAUD        = 921600
SAMPLES     = 640
Y_MAX       = 4095
ADC_VREF    = 1.0
# ----------------

class SerialReader:
    def __init__(self, port, baud):
        self.ser = serial.Serial(port, baud, timeout=0)
        self.ser.reset_input_buffer()
        self.buffer = b''
        print(f"[OK] {port} @ {baud} baud")

    def close(self):
        if self.ser and self.ser.is_open: self.ser.close()

    def read_samples(self, max_count=2000):
        out = []
        if not self.ser or not self.ser.is_open: return out
        try:
            n = self.ser.in_waiting
            if n == 0: return out
            self.buffer += self.ser.read(n)
        except serial.SerialException: return out

        while b'\n' in self.buffer and len(out) < max_count:
            line, self.buffer = self.buffer.split(b'\n', 1)
            line = line.strip()
            if not line: continue
            try:
                val = int(line.decode('ascii'))
                if 0 <= val <= Y_MAX: out.append(val)
            except (ValueError, UnicodeDecodeError): continue
        if len(self.buffer) > 16384: self.buffer = b''
        return out

class ScopeWindow:
    def __init__(self, reader):
        self.reader = reader
        self.y_data = np.full(SAMPLES, Y_MAX // 2, dtype=float)
        self.x_data = np.arange(SAMPLES)
        self.sample_pool = []
        self.frozen = False
        self.frame_count = 0
        self.fps = 0.0
        self.last_fps_time = time.time()

        self.app = pg.mkQApp("FPGA Oscilloscope")
        self.win = pg.GraphicsLayoutWidget(title="FPGA Oscilloscope")
        self.win.resize(1280, 720)
        self.win.setBackground('#050505')
        self.win.setWindowFlags(QtCore.Qt.Window)
        self.win.showNormal()
        self.win.show()

        self.plot = self.win.addPlot()
        self.plot.setLabel('left', 'Voltage', units='V', color='#00ff80')
        self.plot.setLabel('bottom', 'Sample Index', color='#00ff80')
        self.plot.setXRange(0, SAMPLES, padding=0)
        self.plot.setYRange(0, ADC_VREF, padding=0)
        self.plot.getAxis('left').setPen('#00ff80')
        self.plot.getAxis('bottom').setPen('#00ff80')
        self.plot.getAxis('left').setTextPen('#00ff80')
        self.plot.getAxis('bottom').setTextPen('#00ff80')

        for i in range(1, 10):
            self.plot.addLine(x=SAMPLES*i/10, pen=pg.mkPen((0,110,60), style=QtCore.Qt.DotLine))
        for i in range(1, 8):
            self.plot.addLine(y=ADC_VREF*i/8, pen=pg.mkPen((0,110,60), style=QtCore.Qt.DotLine))

        self.curve = self.plot.plot(self.x_data, self.y_data, pen=pg.mkPen((0,255,80), width=2))

        self.status_text = pg.TextItem("● RUN", color=(80,255,80), anchor=(0,0))
        self.status_text.setPos(8, ADC_VREF*0.95)
        self.plot.addItem(self.status_text)

        self.meas_text = pg.TextItem('', color=(220,255,220), anchor=(1,0))
        self.meas_text.setPos(SAMPLES-8, ADC_VREF*0.95)
        self.plot.addItem(self.meas_text)

        self.hint_text = pg.TextItem('[a] auto-scale  [f] freeze  [r] reset  [q] quit', color=(140,140,140), anchor=(1,1))
        self.hint_text.setPos(SAMPLES-8, ADC_VREF*0.03)
        self.plot.addItem(self.hint_text)

        self.plot.setTitle("FPGA Oscilloscope — waiting for data...", color='#00ff80', size='11pt')

        self.win.keyPressEvent = self.on_key
        self.timer = QtCore.QTimer()
        self.timer.timeout.connect(self.update)
        self.timer.start(20)

    def on_key(self, event):
        k = event.key()
        if k == QtCore.Qt.Key_A: self.plot.setYRange(0, ADC_VREF, padding=0)
        elif k == QtCore.Qt.Key_F:
            self.frozen = not self.frozen
            if self.frozen: self.status_text.setText("■ STOP", color=(255,100,100))
            else: self.status_text.setText("● RUN", color=(80,255,80))
        elif k == QtCore.Qt.Key_R: self.sample_pool = []
        elif k == QtCore.Qt.Key_Q: QtWidgets.QApplication.instance().quit()

    def update(self):
        if self.frozen: return
        new_vals = self.reader.read_samples(2000)
        if new_vals: self.sample_pool.extend(new_vals)

        if len(self.sample_pool) >= SAMPLES:
            frame = np.asarray(self.sample_pool[:SAMPLES], dtype=float)
            self.sample_pool = self.sample_pool[SAMPLES:]
            volts = frame / Y_MAX * ADC_VREF
            self.y_data = volts
            self.curve.setData(self.x_data, self.y_data)
            self.frame_count += 1
            now = time.time()
            if now - self.last_fps_time >= 0.5:
                self.fps = self.frame_count / (now - self.last_fps_time)
                self.frame_count = 0
                self.last_fps_time = now
                self._update_measurements(volts)

    def _update_measurements(self, volts):
        vmin, vmax = float(volts.min()), float(volts.max())
        vpp, vavg, vrms = vmax - vmin, float(volts.mean()), float(np.sqrt(np.mean(volts ** 2)))
        mid = (vmin + vmax) / 2.0
        crossings = np.where(np.diff(np.signbit(volts - mid)))[0]
        freq = 96000.0 / (np.mean(np.diff(crossings)) * 2) if len(crossings) >= 4 else 0.0

        self.meas_text.setText(f"Vpp:  {vpp:6.3f} V\nVmax: {vmax:6.3f} V\nVmin: {vmin:6.3f} V\nVavg: {vavg:6.3f} V\nVrms: {vrms:6.3f} V\nFreq: {freq:6.1f} Hz\nFPS:  {self.fps:6.1f}")
        self.plot.setTitle(f"FPGA Oscilloscope — {self.fps:.1f} fps", color='#00ff80', size='11pt')

    def run(self):
        self.app.exec_()
        self.reader.close()

def main():
    reader = SerialReader(COM_PORT, BAUD)
    win = ScopeWindow(reader)
    print("[INFO] a=auto  f=freeze  r=reset  q=quit")
    win.run()

if __name__ == "__main__":
    try: main()
    except KeyboardInterrupt: sys.exit(0)