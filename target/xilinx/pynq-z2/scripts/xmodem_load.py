#!/usr/bin/env python3
from __future__ import annotations

import argparse
import struct
import sys
import time
from pathlib import Path

import serial
from serial.tools.miniterm import Miniterm

# XMODEM control bytes
SOH       = 0x01  # Start of 128-byte data packet
EOT       = 0x04  # End of transmission
ACK       = 0x06  # Acknowledge
NAK       = 0x15  # Not acknowledge
CAN       = 0x18  # Cancel
CRC_START = 0x43  # 'C' - sent by receiver to request CRC mode

PACKET_SIZE   = 128
MAX_RETRIES   = 10
START_TIMEOUT = 60   # seconds to wait for initial 'C'
ACK_TIMEOUT   = 2    # seconds to wait for ACK per packet


def crc16_xmodem(data: bytes) -> int:
    """CRC-16/XMODEM: polynomial 0x1021, init 0x0000, no reflection."""
    crc = 0
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) if (crc & 0x8000) else (crc << 1)
            crc &= 0xFFFF
    return crc


def require_pyserial() -> None:
    if serial is None or Miniterm is None:
        print("Error: pyserial not installed. Run: pip install pyserial", file=sys.stderr)
        sys.exit(1)


def wait_for_start(port: serial.Serial, verbose: bool) -> bool:
    """Wait for the bootloader to send 'C', indicating readiness."""
    if verbose:
        print(f"Waiting up to {START_TIMEOUT}s for XMODEM-CRC start byte ('C') from target...")

    deadline = time.monotonic() + START_TIMEOUT
    while time.monotonic() < deadline:
        byte = port.read(1)
        if not byte:
            continue
        if byte[0] == CRC_START:
            if verbose:
                print("Got 'C' - starting XMODEM-CRC transfer.")
            # Drain any extra 'C' bytes the bootloader may have queued
            port.timeout = 0.1
            while True:
                extra = port.read(1)
                if not extra or extra[0] != CRC_START:
                    break
            port.timeout = ACK_TIMEOUT
            return True
        if verbose:
            # print(f"  Ignoring unexpected byte: 0x{byte[0]:02x}")
            pass

    print("Timed out waiting for start byte.", file=sys.stderr)
    return False


def send_xmodem(port: serial.Serial, data: bytes | None, verbose: bool = True) -> bool:
    """
    Transmit data using XMODEM-CRC. Returns True on success.
    Data is padded with 0x1A (Ctrl-Z) to a multiple of PACKET_SIZE.
    """
    if data is None:
        return True

    # Flush any stale bytes in the OS RX buffer before starting
    port.reset_input_buffer()

    # Pad to a multiple of PACKET_SIZE
    remainder = len(data) % PACKET_SIZE
    if remainder:
        data = data + b'\x1a' * (PACKET_SIZE - remainder)
    total_packets = len(data) // PACKET_SIZE

    if not wait_for_start(port, verbose):
        return False

    for seq in range(1, total_packets + 1):
        chunk = data[(seq - 1) * PACKET_SIZE: seq * PACKET_SIZE]
        crc   = crc16_xmodem(chunk)
        # SOH | block# (mod 256) | ~block# (mod 256) | payload | CRC high | CRC low
        packet = bytes([SOH, seq & 0xFF, (~seq) & 0xFF]) + chunk + struct.pack('>H', crc)

        for attempt in range(1, MAX_RETRIES + 1):
            port.write(packet)
            port.flush()

            resp = port.read(1)
            if not resp:
                if verbose:
                    print(f"\n  No response for packet {seq} (attempt {attempt})", file=sys.stderr)
                continue
            if resp[0] == ACK:
                if verbose:
                    pct = seq * 100 // total_packets
                    bar = '#' * (pct // 2) + '.' * (50 - pct // 2)
                    print(f"\r  [{bar}] {pct:3d}%  packet {seq}/{total_packets}", end='', flush=True)
                break
            elif resp[0] == NAK:
                if verbose:
                    print(f"\n  NAK on packet {seq}, retrying (attempt {attempt})...", file=sys.stderr)
            elif resp[0] == CAN:
                print(f"\nTransfer cancelled by target (CAN).", file=sys.stderr)
                return False
            elif resp[0] == CRC_START:
                # Bootloader timed out and restarted its receive loop - drain extra 'C'
                # bytes then resend the current packet
                if verbose:
                    print(f"\n  Bootloader restarted receive (got 'C'), resending packet {seq}...",
                          file=sys.stderr)
                port.timeout = 0.1
                while True:
                    extra = port.read(1)
                    if not extra or extra[0] != CRC_START:
                        break
                port.timeout = ACK_TIMEOUT
            else:
                if verbose:
                    print(f"\n  Unexpected 0x{resp[0]:02x} for packet {seq} (attempt {attempt})",
                          file=sys.stderr)
        else:
            print(f"\nFailed to send packet {seq} after {MAX_RETRIES} attempts.", file=sys.stderr)
            return False

    if verbose:
        print()  # newline after progress bar

    # End of transmission
    if verbose:
        print("Sending EOT...")
    for attempt in range(MAX_RETRIES):
        port.write(bytes([EOT]))
        port.flush()
        resp = port.read(1)
        if resp and resp[0] == ACK:
            if verbose:
                print("Transfer complete - program loaded and executing.")
            return True
        if verbose:
            print(f"  No ACK for EOT (attempt {attempt + 1})", file=sys.stderr)

    print("No ACK for EOT after retries.", file=sys.stderr)
    return False


def open_terminal(port: serial.Serial, quiet: bool = False) -> None:
    """Start an interactive serial terminal on an already-open port."""
    port.timeout = 0.1
    port.write_timeout = None

    term = Miniterm(port, eol="lf", filters=[])
    term.exit_character = chr(0x1D)  # Ctrl+]
    term.menu_character = chr(0x14)  # Ctrl+T
    term.set_rx_encoding("utf-8")
    term.set_tx_encoding("utf-8")

    if not quiet:
        print(f"Opening terminal on {port.port} at {port.baudrate} baud.")
        print("Exit with Ctrl+] | Menu/help with Ctrl+T")

    try:
        term.start()
        term.join(True)
    except KeyboardInterrupt:
        if not quiet:
            print("\nTerminal interrupted.")
    finally:
        term.stop()


def main():
    parser = argparse.ArgumentParser(
        description="Load a binary via XMODEM-CRC and/or open a serial terminal.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--port", "-p", default="/dev/ttyUSB0",
        help="Serial port",
    )
    parser.add_argument(
        "--baud", "-b", type=int, default=115200,
        help="Baud rate",
    )
    parser.add_argument(
        "--bin", dest="binfile", default=None, metavar="FILE",
        help="Binary to send (default: test/prog.bin relative to repo root)",
    )
    parser.add_argument(
        "--quiet", "-q", action="store_true",
        help="Suppress progress output",
    )
    parser.add_argument(
        "--terminal", "-t", action="store_true",
        help="Open an interactive terminal after a successful load",
    )
    parser.add_argument(
        "--terminal-only", action="store_true",
        help="Skip XMODEM transfer and open the terminal immediately",
    )
    args = parser.parse_args()
    require_pyserial()

    if args.terminal_only and args.binfile:
        print("Note: --bin is ignored when --terminal-only is used.", file=sys.stderr)

    data = None
    bin_path = None
    if not args.terminal_only:
        # Resolve binary path: explicit arg, or test/prog.bin from repo root
        if args.binfile:
            bin_path = Path(args.binfile)
        else:
            repo_root = Path(__file__).parent.parent
            bin_path = repo_root / "test" / "prog.bin"

        if not bin_path.exists():
            print(f"Error: file not found: {bin_path}", file=sys.stderr)
            sys.exit(1)

        data = bin_path.read_bytes()
        if not args.quiet:
            print(f"Binary: {bin_path}  ({len(data)} bytes, "
                  f"{(len(data) + PACKET_SIZE - 1) // PACKET_SIZE} packets)")

    try:
        with serial.Serial(args.port, args.baud, timeout=ACK_TIMEOUT) as port:
            if not args.quiet:
                print(f"Port:   {args.port}  ({args.baud} baud)")
            if args.terminal_only:
                port.reset_input_buffer()
                open_terminal(port, quiet=args.quiet)
                success = True
            else:
                success = send_xmodem(port, data, verbose=not args.quiet)
                if success and args.terminal:
                    open_terminal(port, quiet=args.quiet)
    except serial.SerialException as e:
        print(f"Serial error: {e}", file=sys.stderr)
        sys.exit(1)

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
