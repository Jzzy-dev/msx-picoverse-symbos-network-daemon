# msx-picoverse-symbos-network-daemon
A network daemon for MSX machines booting Symbos using the PicoVerse2350

<a href="https://msx.pics/image/xtaHE"><img src="https://msx.pics/images/2026/10/05/SL-3002.md.jpeg" alt="SL 3002" border="0"></a>

# SymbOS Network Daemon driver for ESP8266 UNAPI firmware on PicoVerse 2350

Status, working on MSX2 with PicoVerse 2350 (SymbOS 4.0). The daemon finds the card, gets
the IP settings through DHCP from the ESP, resolves names and moves TCP data. wget and SymTel
were used successfully. UDP works too (tested with SNTP). Driver version 0.4, shown in the Driver tab as MSX PcVrs ESP v0.4.

## Build
Wrapper order, constants file, Dmn-Network-head.asm, Dmn-Network-libs.asm, Dmn-Network.asm
(patched), Dmn-Network-ESP.asm. Dmn-Network-i18n-direct.asm must be in the same folder.
In WinAPE 1.0.13 no colon may appear inside a comment.

| File | Purpose |
|---|---|
| Dmn-Network-_ESP.asm | wrapper with the switches below |
| Dmn-Network-ESP.asm | hardware layer, transfer area, memio transport, ESP protocol, DNS, link check |
| Dmn-Network.asm | daemon patched for DRIVER 6 (see Dmn-Network-DRIVER6.diff) |
| Dmn-Network-libs.asm | flattened SymbOS libs, no ifdef or macro |
| Dmn-Network-i18n-direct.asm | texts without the 3 byte pointer list |

Switches in the wrapper

| Switch | Meaning |
|---|---|
| DRIVER equ 6 | this driver |
| LNGSKIP equ 2 | direct texts, no language pack |
| ESPDEBUG equ 0 | 1 shows the slot scan log and a FIFO snapshot in the status tab |
| low_sockmax equ 4 | maximum TCP connections, must be defined before the daemon |

## How it works
* The ESP does DHCP, DNS and TCP. The driver follows the M4Board "high level" model.
* The slot is found automatically. The configured slot is tried first, then all slots are
  scanned. A candidate needs the AB ROM header, a memio like status byte (bit 7 and bit 3)
  and must react to the clear command. The result goes into the combo boxes and the config.
* SymbOS slot helper in page 0 (#0202, operands #0203 #0207 #020C, normal registers #0218
  and #0219). The hardware code lives in the transfer area and touches only its own memory
  while the cartridge is mapped. The helper operands are saved and restored.
* Link light is on while the network is online, a NET_STATE check runs about every 5 seconds
  and drops the status to "No IP" if the WiFi is gone. TX and RX lights hold for a short time
  after data moved.

## UDP
The daemon had no application UDP at all, the handlers udpopn, udpsta, udprcv, udpsnd and udpskp and
the poll handler netudp were empty stubs for every driver. They are implemented now for this driver,
modelled on the TCP ones, and the driver has the matching hooks (UNAPI functions 8 to 12).
Tested on real hardware with Net Test (World clock, SNTP).
* The driver never uses UDP_STATE. The ESP firmware calls parsePacket in UDP_STATE and again in
  UDP_RCV, and a datagram that was seen by the first call is thrown away by the second one. So the
  driver asks UDP_RCV directly, every 2nd poll while an application waits on the socket. That is also what
  ducasp's SNTP tool for Nextor does.
* UDP_RCV delivers the sender together with the data. The datagram is kept in one buffer until the
  application receives or skips it. One datagram at a time for all UDP sockets, the others wait inside the ESP.
* UDP sockets are opened as transient. At daemon start and with Apply the driver sends UDP_CLOSE 0, which
  closes all transient UDP sockets in the ESP, so a program that was killed cannot block the four ESP
  connections. The ESP has four connections for TCP and UDP together.
* The answer to UDP_SEND is waited for up to 3 seconds, the ESP can need a while.
* Largest datagram is 576 bytes, larger ones are refused on send and cut on receive.

## WiFi state and signal strength
The ESP firmware has no signal strength command. What it offers is the state of the WiFi connection and the
name of the access point (command g). The name is shown in the driver tab and refreshed with the link check.
A real signal level needs a new command in the ESP firmware that returns the RSSI, the daemon already has
the six level signal graphics from the M4 Board build that could show it.

## Things learned
* The head file needs the line `dw App_BegData-App_BegCode` (16 colour icon offset).
* This SymbOS does not follow the `db 1:dw string` text pointers, menus need inline text.
* The daemon read the TCP socket status through IX where the socket record is in IY (tcpsta), fixed
  in Dmn-Network.asm. Programs that poll the status (wget did not) got garbage before.
* The ESP firmware source is at https://github.com/ducasp/ESP8266-UNAPI-Firmware, the UNAPI BIOS
  sources at https://github.com/ducasp/MSX-Development, they were the key to find the UDP problem.
* The PicoVerse status register has bit 6 clear on the real hardware, the doc says set.
* MSC_SYS_EXTFNC and FNC_DXT_LNGLOD are unknown, never call LNGLOD with guessed values.

## Not done
Signal strength, TLS, language packs, server mode and the reset of all connections are not tested or not done. The probe waits up to 1 second per
strategy, a wrong saved slot makes the start slow until the scan has found the right one once.
