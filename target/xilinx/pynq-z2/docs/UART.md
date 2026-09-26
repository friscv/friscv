# Connecting to FRISC-V via Serial

FRISC-V has a hardware UART interface connected to the Raspberry Pi header in the standard pinout (pins 8 and 10). Hardware support is provided by a Xilinx AXI UART 16550 module. The baud rate is configured in software via a divisor register; the ZSBL sets a divisor of `14`, which gives `115200` baud with the 25 MHz clock.

![PYNQ-Z2 Raspberry Pi header pinout](assets/images/pynq-z2-raspi-header-pinout.png)

## Pinouts and Addresses

### FRISC-V Side

**Standard Pinout:**

Pin No. | Board Port Label | ZYNQ Port Label | Function
------- | ---------------- | --------------- | --------
6       | `GND`            | N/A             | Ground
8       | `RPIO14`         | `V6`            | UART Transmit
10      | `RPIO15`         | `Y6`            | UART Receive

**Address Map:**

The base address of hardware UART is `0x1000_0000`. Each NS16550 register occupies one 32-bit word (only the low 8 bits are used). The address space spans `0x1000_0000`–`0x1000_FFFF`.

Offset  | Register              | Description
------- | --------------------- | -----------
`0x00`  | `RBR` / `THR` / `DLL` | Receive Buffer (read) / Transmit Holding (write) / Divisor Latch Low (when `LCR[7]`=1)
`0x04`  | `IER` / `DLM`         | Interrupt Enable / Divisor Latch High (when `LCR[7]`=1)
`0x08`  | `IIR` / `FCR`         | Interrupt Identification (read) / FIFO Control (write)
`0x0C`  | `LCR`                 | Line Control
`0x10`  | `MCR`                 | Modem Control
`0x14`  | `LSR`                 | Line Status
`0x18`  | `MSR`                 | Modem Status
`0x1C`  | `SCR`                 | Scratch

**Register Bit Map:**

Read from `RBR` to receive a byte; write to `THR` to transmit a byte. Access the divisor latches (`DLL`/`DLM`) by setting `LCR[7]` (DLAB) to `1` first.

`LCR` (Line Control Register):

Bit(s) | Name   | Description
------ | ------ | -----------
`1:0`  | `WLS`  | Word length: `0x3` = 8-bit
`2`    | `STB`  | Stop bits: `0` = 1 stop bit
`5:3`  | `PEN`  | Parity: `0` = none
`7`    | `DLAB` | Divisor Latch Access Bit – set to `1` to access `DLL`/`DLM`

`FCR` (FIFO Control Register, write-only):

Bit(s) | Name     | Description
------ | -------- | -----------
`0`    | `FEN`    | FIFO enable
`1`    | `RFIFOR` | Receiver FIFO reset
`2`    | `XFIFOR` | Transmitter FIFO reset
`7:6`  | `RXTRIG` | Receiver trigger level

`LSR` (Line Status Register):

Bit | Name   | Description
--- | ------ | -----------
`0` | `DR`   | Data Ready – received byte available in `RBR`
`5` | `THRE` | Transmitter Holding Register Empty – safe to write `THR`
`6` | `TEMT` | Transmitter Empty – all bytes have been shifted out

`IER` (Interrupt Enable Register):

Bit | Name    | Description
--- | ------- | -----------
`0` | `ERBFI` | Enable Received Data Available interrupt
`1` | `ETBEI` | Enable Transmitter Holding Register Empty interrupt
`2` | `ELSI`  | Enable Receiver Line Status interrupt
`3` | `EDSSI` | Enable Modem Status interrupt

**Baud Rate Configuration:**

The baud rate is set by writing a 16-bit divisor to `DLL` (low byte) and `DLM` (high byte) while `LCR[7]` (DLAB) is `1`:

$$\text{Divisor} = \frac{f_{\text{clk}}}{16 \times \text{Baud Rate}}$$

With the 25 MHz clock, the divisor for 115200 baud is 25 000 000 / (16 × 115200) = 13.56, rounded to `14`. The resulting 3% error is small enough for the UART to work.

### I/O Board Side

FRISC-V has first party support for the Embedded Artists LPCXpresso Base Board (I/O board).

The I/O board features a USB-to-UART bridge connected to the primary power source interface on the right side of the board (`U22`, `X3`). Default jumper positions should be used. Consult the LPCXpresso Base Board Rev B User’s Guide if needed.

![I/O Board USB-to-UART Connector](assets/images/io-board-uart.png)

The UART TX and RX pins are directly connected to the 50-pin expansion headers on the top side of the board.

Connection to the PYNQ-Z2 board should be done as follows:

Pin  | PYNQ (Connection Board) Name | I/O Pin Name | I/O Board Marking
---- | ---------------------------- | ------------ | -----------------
`RX` | `GPIO15/RXD0`                | `GPIO_6-RXD` | `PIO1.6`
`TX` | `GPIO14/TXD0`                | `GPIO_5-TXD` | `PIO1.7`

> [!IMPORTANT]
> If connecting without the connection board, grounds of the I/O board and PYNQ-Z2 should also be connected.

![Expansion Port UART Pins](assets/images/io-board-expansion-uart.png)

## Host Machine Connection

On Linux, the simplest way of connecting to the USB-to-UART bridge on the I/O board is `screen`. With a USB cable connected to the port shown in [I/O Board Side](#io-board-side) and detected as `/dev/ttyUSB0`, run:

```bash
sudo screen /dev/ttyUSB0 115200
```

`/dev/ttyUSB0` is the most common port. If the board was detected as a different port, its device path should be used. `115200` is the default baudrate used by FRISC-V. If FRISC-V is configured with a different baudrate, use that instead.

Install screen by running `sudo apt install screen -y` in a Linux terminal.

On Windows, the bridge shows up as a COM port (check Device Manager). Use PuTTY, TeraTerm, or pyserial's terminal:

```powershell
python -m serial.tools.miniterm COM3 115200
```

`python fpga.py go -t -p COM3` programs the board, starts FRISC-V and opens the same terminal in one step.

## Software Examples

Before using UART, the baud rate divisor and line parameters must be configured. The divisor is written while the Divisor Latch Access Bit (`LCR[7]`, DLAB) is set.

```c
// Initialize UART 16550 at UART_BASE
// divisor: baud rate = clk / (16 * divisor)
// For 115200 baud @ 25 MHz: divisor = 14
void uart_init(uint8_t divisor) {
    UART_IER = 0;           // Disable all interrupts

    UART_LCR = 0x80;        // Set DLAB=1 to access divisor latches
    UART_DLL = divisor;     // Divisor low byte
    UART_DLM = 0;           // Divisor high byte

    UART_LCR = 0x03;        // 8N1, DLAB=0
    UART_FCR = 0x07;        // Enable FIFOs, reset RX and TX, 1-byte trigger
    UART_MCR = 0;           // No modem control
}
```

When writing a byte, software must wait until the Transmitter Holding Register is empty (`LSR[5]`, THRE).

```c
void uart_putc(char c) {
    // Wait until TX holding register is empty
    while (!(UART_LSR & UART_LSR_THRE));
    UART_THR = c;
}
```

When reading a byte, software must wait for the Data Ready flag (`LSR[0]`, DR).

```c
char uart_getc() {
    // Wait until received data is ready
    while (!(UART_LSR & UART_LSR_DR));
    return UART_RBR & 0xFF;
}
```

The constant values are defined as in [Pinouts and Addresses](#pinouts-and-addresses).

```c
#include <stdint.h>

// AXI UART 16550 register definitions
// Each register occupies one 32-bit word, only the low 8 bits are used.
#define UART_BASE  0x10000000

#define UART_RBR  (*(volatile uint8_t *)(UART_BASE + 0x00))  // Receive Buffer (read)
#define UART_THR  (*(volatile uint8_t *)(UART_BASE + 0x00))  // Transmit Holding (write)
#define UART_DLL  (*(volatile uint8_t *)(UART_BASE + 0x00))  // Divisor Latch Low  (DLAB=1)
#define UART_IER  (*(volatile uint8_t *)(UART_BASE + 0x04))  // Interrupt Enable
#define UART_DLM  (*(volatile uint8_t *)(UART_BASE + 0x04))  // Divisor Latch High (DLAB=1)
#define UART_FCR  (*(volatile uint8_t *)(UART_BASE + 0x08))  // FIFO Control (write)
#define UART_LCR  (*(volatile uint8_t *)(UART_BASE + 0x0C))  // Line Control
#define UART_MCR  (*(volatile uint8_t *)(UART_BASE + 0x10))  // Modem Control
#define UART_LSR  (*(volatile uint8_t *)(UART_BASE + 0x14))  // Line Status
#define UART_MSR  (*(volatile uint8_t *)(UART_BASE + 0x18))  // Modem Status
#define UART_SCR  (*(volatile uint8_t *)(UART_BASE + 0x1C))  // Scratch

// LSR bits
#define UART_LSR_DR    0x01  // Data Ready
#define UART_LSR_THRE  0x20  // Transmitter Holding Register Empty
#define UART_LSR_TEMT  0x40  // Transmitter Empty
```
