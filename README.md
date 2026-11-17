# msx-picoverse-symbos-network-daemon
A network daemon for MSX machines booting Symbos using the PicoVerse2350

<a href="https://msx.pics/image/x4SNT"><img src="https://msx.pics/images/2026/10/14/net-test3.md.jpeg" alt="net test3" border="0"></a>

<a href="https://msx.pics/image/xtisp"><img src="https://msx.pics/images/2026/10/14/net-test2.md.jpeg" alt="net test2" border="0"></a>

<a href="https://msx.pics/image/x4VGP"><img src="https://msx.pics/images/2026/10/14/net-test1.md.jpeg" alt="net test1" border="0"></a>

<img width="500" height="375" alt="image" src="https://github.com/user-attachments/assets/b94422b1-2d25-43a6-b713-1f5d77370af1" />


# SymbOS Network Daemon driver for ESP8266 UNAPI firmware on PicoVerse 2350

Status, working on MSX2 with PicoVerse 2350 (SymbOS 4.0). The daemon finds the card, gets
the IP settings through DHCP from the ESP, resolves names and moves TCP data. wget and SymTel
were used successfully. UDP works too (tested with SNTP). Driver version 0.8, shown in the Driver tab as MSX PcVrs ESP v0.8. HTTPS (TLS) is supported through the ESP, see below and the notes there (untested at the time of writing).

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
* Largest datagram is 576 bytes by default (UDPMAX), larger ones are refused on send and dropped on receive.

## HTTPS / TLS (changed in version 0.8)
The ESP firmware (BearSSL) does the TLS itself. Since version 0.8 the program asks for TLS explicitly in
TCP_Open, the same way as ducasp's OCM daemon does. There is no guessing by port number and no cache of DNS
names any more. This is not compatible with programs that rely on the old port list, they connect in plain
text now.
* A = mode byte. Bit 0 server, bit 1 reserved (must be 0), bit 2 TLS, bit 3 check the certificate and the
  host name, bits 4 to 7 the bank of the host name.
* BC = address of the zero terminated host name (SNI and name check), 0 for a plain connection.
  Plain client A=0, TLS client A=4, TLS with certificate check A=12. A TLS server is not possible, error 3.
* A missing, empty, unterminated or longer than 255 bytes host name gives error 26.
* A failed TLS open ends as a closed socket with the close reason 25 (TLS handshake or certificate) and
  8 for no free session. The reason is returned in H of TCP_Status and in H of the TCP event.
* The check box "Check HTTPS server certificates" in the ESP8266 tab of the settings (Network settings
  button) adds the certificate check (bit 3) to every TLS connection, whatever the program asks for. It is
  saved in network.ini. TLSVERIFY in the wrapper is only the start value. The ESP checks against its
  certificate store (certs.ar, put there by the certificate update), a connection fails if the store is
  missing, the certificate is not known or the date of the ESP is wrong.
* Limits of the ESP: only one TLS connection at a time, TLS 1.2 at most, the handshake takes a few
  seconds, big pages and servers with very large certificate chains can fail on the little RAM.

## Protocol fixes taken from the OCM daemon (version 0.8)
ducasp found a number of problems in the daemon while working on the OCM WiFi driver, see issue 1 and the
porting guide. Ported to this driver, the hardware transport and the slot window are untouched.
* The ESP handles one command at a time. While a TCP open or a DNS request is outstanding the driver
  refuses every other command at the driver entry points (TCP status, send, receive, close, UDP open, send,
  close, status), before the slot window is opened. Receive and send return nothing transferred, close returns
  error 5 and the socket stays, status reports "in process". TCP_Open and UDP_Open are refused before a
  socket is taken, so none is lost.
* Close and disconnect ask the driver first and free the socket only when it worked, so a busy close can be
  repeated. A refused TCP open gives its socket back.
* A connection that the server closed but that still has data in the ESP keeps showing as established
  with data until the program has read it, so downloads are not cut short (CLOSE_WAIT and LAST_ACK).
* The events use the socket that is really being checked, and "Reset all connections" in the menu now closes
  every socket (it used socket 0 only).
* UDP_Receive BC contract. BC=0 copies the whole datagram, BC larger than the datagram copies all of it, BC
  from 1 up to the length copies BC bytes and drops the rest. The datagram is consumed in all cases and BC
  returns the number of bytes copied. UDP_Status still shows the full length.
* The largest UDP datagram is UDPMAX in the wrapper, 576 by default. 1468 can be chosen, it costs about
  1.8 KB more transfer area because the send and the receive buffer are separate in this driver.
* Not ported. UDP_STATEX (needs a firmware that has function 210, the direct UDP_RCV model is kept, so the
  socket index problem of that model does not exist here), the ESP hosted IP configuration and the OCM
  user interface parts.

## Scan tab (version 0.6)
The status window has a fourth tab, Scan, modelled on the Scan tab that ducasp added to his SM-X daemon.
* Scan looks for access points (ESP command S, then s until the scan is ready). Up to 10 names are kept,
  hidden networks and double names are left out, encrypted networks get a * behind the name.
* Choose a network in the list, type the password (Show password unmasks it) and press Connect.
  The ESP joins the network (command A, up to about 12 seconds). Open networks need no password.
* Disconnect makes the ESP leave the access point and forget it (command a).
* After Connect or Disconnect the daemon goes back to "no IP" and reads the IP data from the ESP again,
  the line "WiFi: name" at the top shows the access point.
* S, s, a and g are single byte commands without a length field, A has the normal header. The answer of s has no
  length field either, it is [s][rc][count] and then name,0,O or E for every network.
* The ESP stores the credentials in its own flash, the daemon does not save them.
* The scan code was run in an emulator against a scripted ESP (busy, ready, none, no answer, full table).
  The window layout itself has not been tried on a real SymbOS yet.

## ESP8266 tab of the settings (version 0.7, file selector and progress window in 0.8)
Network settings has a third tab, ESP8266.
* ESP firmware version - read with the V command at the start and after an update.
* Check HTTPS server certificates - see the TLS notes.
* Update from a file - press Firmware... (fw8266.bin) or Certificates... (cert8266.bin, mask AR in the
  selector). The SymbOS file selector opens, pick the file and the update starts at once. The chosen path is
  shown in the file line. Both files are in the ESPFW folder of ducasp's packs. The daemon reads the file
  twice (first for the size), starts the update with Z or Y, sends it in blocks of 256 bytes (z, every
  block is acknowledged), ends it with E and waits until the ESP answers again. After a certificate update
  it asks the ESP to build the certificate index (I). Updating the firmware erases the certificates, so
  update them again afterwards.
* A progress window shows what happens (starting, sent n of m KB, writing, certificate index) with a
  progress bar. It closes when the update is ready, the result stays in the message line of the tab.
* A firmware update takes a few minutes. Do not switch off. The ESP cannot abort an update, if a block
  fails the message says to switch the MSX off and on.
* The protocol follows CFGESP of ducasp and the ESP firmware source. The update code was tested in an
  emulator against a scripted ESP (start, blocks, refusal, no answer, restart, certificate index), not
  yet with a real ESP, and the tab itself has not been tried on a real SymbOS.

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
Signal strength, language packs, server mode and the reset of all connections are not tested or not done. The probe waits up to 1 second per
strategy, a wrong saved slot makes the start slow until the scan has found the right one once.
