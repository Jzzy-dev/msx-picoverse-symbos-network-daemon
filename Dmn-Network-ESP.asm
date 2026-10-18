;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@                                                                            @
;@   SymbOS Network Daemon - hardware layer for ESP8266 UNAPI firmware        @
;@   (ducasp) behind the PicoVerse 2350 "memio" UART (MSX2, Sunrise/Nextor    @
;@   WiFi sub-slot).  DRIVER=6                                                @
;@                                                                            @
;@   STATUS - FIRST DRAFT, NOT ASSEMBLED, NOT TESTED ON HARDWARE.              @
;@   Everything marked ";!!VERIFY" is inferred, not confirmed.                @
;@                                                                            @
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;
; Sources this was derived from -
;  - ESP8266_memio.asm (ducasp, UNAPI BIOS v1.3 MSX PICO UART version) -
;      wire protocol, command numbers, response layout, memio registers
;  - msx-picoverse-2350-wifi.md - memory map (#7F05-#7F07), status bits, FIFO
;  - Dmn-Network.asm (Prodatron) - the hooks the daemon calls (low*, dns*)
;
; WIRE PROTOCOL (from ESP8266_memio.asm)
;   request - [fn] [len MSB] [len LSB] [payload...]
;   response - [fn] [rc] [len MSB] [len LSB] [payload... only if rc=0]
;   fn is the UNAPI function number, except DNS query = 206.
;   Unrelated bytes may precede the response; skip until fn is seen.
;
; DESIGN
;   * All ESP access happens inside a short "window" (espenter..espleave)
;     with interrupts off, because the memio registers live at #7F05-#7F07
;     inside the cartridge sub-slot that must be switched into page 1.
;   * The window is NEVER held across a wait.  Long operations (TCP open up to
;     60s, DNS up to 15s) are split - the request is sent in one window, and the
;     answer is collected by polling in later windows (lowtst / espdnr).
;   * The ESP does DHCP, DNS and TCP itself, so this layer plugs into the
;     daemon the same way the M4Board "high level" build does - no DHCP, no
;     UDP-based DNS.

; low_sockmax / low_vermaj / low_vermin are defined in the WRAPPER (Dmn-Network-_ESP.asm),
; before Dmn-Network.asm is read, because the daemon uses low_sockmax in a "ds" at line 148.

esp_mem_cmd     equ #7f06       ;write=command, read=RX data
esp_mem_tx      equ #7f07       ;write=TX data, read=status
esp_mem_f2      equ #7f05       ;F2 state byte - DO NOT TOUCH (Nextor/BIOS side)

esp_cmd_clrfifo equ 20          ;only command the PicoVerse honours
esp_fn_ipinfo   equ 2
esp_fn_netstate equ 3
esp_fn_tcpopen  equ 13
esp_fn_tcpclose equ 14
esp_fn_tcpabort equ 15
esp_fn_tcpstate equ 16
esp_fn_tcpsend  equ 17
esp_fn_tcprcv   equ 18
esp_fn_dnsq     equ 206         ;DNS_Q_NEW (not 6!)

esp_spin        equ 1500        ;poll iterations per espgetb attempt (tune!)

; set to 1 to enable the reference slot switching below.  With 0 the driver
; reports "no hardware" instead of risking a crash.
; 1 = real slot access using the SymbOS slot helper, 0 = report "no device".
; The first version of this routine switched page 3 from code running in page 3
; and hung the machine. It now follows the GR8NET and DenYoNet drivers.
ESP_SLOTSW      equ 1


;==============================================================================
;### STATE ####################################################################
;==============================================================================

esp_pend        db 0            ;0=idle, else fn of an outstanding request
esp_pendsck     db 0            ;socket that owns the outstanding request
esp_conn        ds low_sockmax  ;ESP connection number per daemon socket (0=none)
esp_stat        ds low_sockmax  ;cached daemon status (for pending open result)
esp_dnsres      ds 4            ;last DNS result
esp_dnsst       db 0            ;0=idle,1=pending,2=ok,3=failed
esp_mac         ds 6            ;pseudo MAC (ESP owns the real one)
esp_sta_tx      db 0            ;TX and RX hold counters for the lights in the driver tab,
esp_sta_rx      db 0            ;the daemon counts them down, they are set whenever data moves
esp_sta_delay   equ 3

; Everything the code touches while the slot window is open must live in this
; file (transfer area, page 3). The daemon data may not be reachable then.
esp_tmp         ds 8            ;copy of the TCP open parameter block
esp_ip4         ds 4            ;IP info answer
esp_dnsb        ds 64           ;copy of the domain name for a DNS request
esp_dnsl        dw 0            ;its length
esp_blen        equ 128
esp_buf         ds esp_blen     ;bounce buffer (own bank) for bank copies


;==============================================================================
;### SLOT WINDOW ##############################################################
;==============================================================================
; espenter - map the WiFi sub-slot into CPU page 1 (#4000-#7FFF), interrupts off.
;   Output  CF=0 always (the window is open)
; espleave - restore the normal SymbOS slot layout, interrupts on.
;            Preserves AF,BC,DE,HL.
;
; Slot = (cfg_slots+0)=primary slot 0-3, (cfg_slots+1)=sub-slot 0-3
;
; This is the method the SymbOS GR8NET and DenYoNet drivers use (taken from
; Dmn-Network-W5100G8N.asm and Dmn-Network-W5100DYO.asm).  SymbOS keeps a slot
; switching helper in its always mapped system page 0.
;   #0202   helper, run it with CALL, it does three steps
;           1 OUT (#A8) with the value patched into #0203   (page 3 = target slot)
;           2 write the value patched into #0207 to #FFFF   (expander register)
;           3 OUT (#A8) with the value patched into #020C   (final layout)
;   #0218   normal primary slot register of SymbOS
;   #0219   normal sub-slot register of SymbOS
; The helper runs in page 0, so switching page 3 away is safe there.  This code
; itself and its stack stay in the transfer area (page 3) and are never touched
; while page 3 is switched, exactly like the GR8NET and DenYoNet drivers.
; This code MUST stay in the transfer area, read it after the daemon.

sys_slthlp      equ #0202
sys_slt1        equ #0203
sys_slt2        equ #0207
sys_slt3        equ #020c
sys_pri         equ #0218
sys_sub         equ #0219

esp_open        db 0            ;window open flag
esp_sv1         db 0            ;saved helper operands, restored when the window closes
esp_sv2         db 0
esp_sv3         db 0

if ESP_SLOTSW=0

espenter
        scf                     ;safe default - report no hardware
        ret
espleave
        ret

else

espenter
        push bc
        push hl
        di                      ;SymbOS uses the same helper in its interrupt
        ld a,(sys_slt1)         ;remember what the helper had before we touch it
        ld (esp_sv1),a
        ld a,(sys_slt2)
        ld (esp_sv2),a
        ld a,(sys_slt3)
        ld (esp_sv3),a
        ld a,(cfg_slots+0)
        and 3
        ld l,a                  ;L=primary slot of the WiFi cartridge
        ld a,(cfg_slots+1)
        and 3
        ld h,a                  ;H=sub-slot of the WiFi cartridge
        ;--- step 3 value, page 1 = cartridge slot, all other pages normal
        ld a,l
        add a
        add a                   ;primary slot at page 1 position
        ld c,a
        ld a,(sys_pri)
        and #f3
        or c
        ld (sys_slt3),a
        ;--- step 1 value, page 3 = cartridge slot, pages 0 and 1 normal, page 2 = slot 0
        ld a,l
        rrca
        rrca                    ;primary slot at page 3 position
        ld c,a
        ld a,(sys_pri)
        and #0f
        or c
        ld (sys_slt1),a
        ;--- step 2 value, expander register of the cartridge slot, page 1 = sub-slot
        ld a,h
        add a
        add a                   ;sub-slot at page 1 position
        ld c,a
        ld a,(sys_sub)
        and #f3
        or c
        ld (sys_slt2),a
        call sys_slthlp
        ld a,1
        ld (esp_open),a
        pop hl
        pop bc
        or a                    ;CF=0
        ret

espleave
        push af
        ld a,(esp_open)
        or a
        jr z,espleav9           ;no window open, nothing to undo
        ld a,(sys_pri)
        out (#a8),a             ;normal primary slot layout, page 1 is RAM again
        ld a,(sys_sub)
        ld (#ffff),a            ;normal sub-slot layout
        ld a,(esp_sv1)          ;give the helper operands back to the system
        ld (sys_slt1),a
        ld a,(esp_sv2)
        ld (sys_slt2),a
        ld a,(esp_sv3)
        ld (sys_slt3),a
        xor a
        ld (esp_open),a
espleav9 pop af
        ei
        ret
endif


;==============================================================================
;### LOW LEVEL TRANSPORT (window must be open) ################################
;==============================================================================

;### ESPSND -> send one byte
;### Input      A=byte
espsnd  ld (esp_mem_tx),a
        ret

;### ESPGTB -> try to read one byte (preserves BC,DE,HL)
;### Output     CF=0 A=byte, CF=1 nothing arrived within esp_spin polls
espgtb  push bc
        ld bc,esp_spin
espgtb1 ld a,(esp_mem_tx)       ;status
        bit 0,a                 ;RX FIFO has data?
        jr nz,espgtb2
        dec bc
        ld a,b
        or c
        jr nz,espgtb1
        pop bc
        scf
        ret
espgtb2 ld a,(esp_mem_cmd)      ;RX data
        pop bc
        or a
        ret

;### ESPHDR -> send request header
;### Input      A=fn, HL=payload length
espcmd  ld (esp_mem_tx),a
        ld a,h
        ld (esp_mem_tx),a
        ld a,l
        ld (esp_mem_tx),a
        ret

;### ESPGTW -> like ESPGTB, but if nothing arrives it closes the slot window,
;###          waits one video frame with interrupts on, and tries again
;### Input      window open, (esp_wcnt)=frames to wait at most
;### Output     CF=0 A=byte, CF=1 timeout (window is open again in both cases)
;### Destroyed  F,BC,DE,HL
esp_wcnt        db 0
espgtw  call espgtb
        ret nc
espgtw1 ld a,(esp_wcnt)
        or a
        jr z,espgtw9
        dec a
        ld (esp_wcnt),a
        call espleave           ;interrupts on, normal slots
        halt                    ;one frame
        call espenter
        jr c,espgtw9
        call espgtb
        ret nc
        jr espgtw1
espgtw9 scf
        ret

;### ESPRSP -> wait for a response header
;### Input      A=expected fn, (esp_wdef) = frames to wait for it (ESPRSP0 does not wait)
;### Output     CF=0 - A=return code, HL=payload length
;###            CF=1 - no (complete) response
;### Destroyed  BC,DE
;  At most esp_skipmax unrelated bytes are skipped, so a floating bus can never
;  keep this loop alive forever.
esp_skipmax     equ 1200
esp_skipn       dw 0
esp_wdef        db 20           ;default wait in frames for a response

esprsp0 ld d,a
        xor a
        jr esprsp3
esprsp  ld d,a
        ld a,(esp_wdef)
esprsp3 ld (esp_wcnt),a
        ld hl,esp_skipmax
        ld (esp_skipn),hl
esprsp1 call espgtw
        ret c
        cp d
        jr z,esprsp2
        ld hl,(esp_skipn)
        dec hl
        ld (esp_skipn),hl
        ld a,h
        or l
        jr nz,esprsp1
        scf
        ret
esprsp2 call espgtb             ;return code
        ret c
        ld e,a
        call espgtb             ;length MSB
        ret c
        ld h,a
        call espgtb             ;length LSB
        ret c
        ld l,a
        ld a,e
        or a                    ;CF=0
        ret

;### ESPSKP -> discard HL payload bytes
;### Output     CF=1 on timeout or if the length is not plausible
espskp  ld a,h
        cp 8                    ;more than 2047 bytes can not be right here
        jr c,espskp0
        scf
        ret
espskp0 or l
        ret z
espskp1 push hl
        call espgtb
        pop hl
        ret c
        dec hl
        ld a,h
        or l
        jr nz,espskp1
        ret


;==============================================================================
;### DAEMON HOOKS #############################################################
;==============================================================================

;### LOWINI -> hardware init / configuration
;### Input      A=0 init hardware, 1 set MAC (HL), 2 set IP data (HL),
;###            5,6,7 = M4Board only (ignored)
;### Output     CF=1 -> hardware not found (A=0 only)
;### Destroyed  AF,BC,DE,HL,IX,IY
;!!VERIFY  contract inferred from the netini/netips call sites in Dmn-Network.asm
lowini  or a
        jr z,lowini0
        or a
        ret                     ;MAC and IP are owned by the ESP, nothing to do
lowini0 xor a
        ld (esp_pend),a
        ld (esp_dnsst),a
        ld hl,esp_conn
        ld de,esp_conn+1
        ld bc,low_sockmax*2-1
        ld (hl),0
        ldir
        ld hl,esp_uconn
        ld de,esp_uconn+1
        ld bc,low_sockmax-1
        ld (hl),0
        ldir
        ld a,255
        ld (esp_uown),a
        ld a,1
        ld (esp_upoll),a
        call espfind            ;CF=1 when no ESP was found
        ret c
        call espucl0            ;close UDP connections left behind by earlier runs
        call espap              ;read the access point name
        or a
        ret

;### DIAGNOSTIC LOG - the first three candidates with an "AB" ROM header are
;### recorded as "PSXXR" = primary slot, sub-slot, status byte in hex, result
;### result  - = status not plausible, R = ROM that ignores writes, N = no answer, 0 1 2 = answered with that strategy
esp_logbuf      ds 20
esp_logn        db 0
esp_logp        dw 0
esp_logres      dw 0

esplog  ld a,(esp_logn)
        cp 3
        jr c,esplog1
        ld hl,0
        ld (esp_logres),hl
        ret
esplog1 inc a
        ld (esp_logn),a
        ld hl,(esp_logp)
        ld a,(cfg_slots+0)
        add 48
        ld (hl),a
        inc hl
        ld a,(cfg_slots+1)
        add 48
        ld (hl),a
        inc hl
        ld a,(esp_sig+2)
        push af
        rrca
        rrca
        rrca
        rrca
        call esphex
        inc hl
        pop af
        call esphex
        inc hl
        ld (esp_logres),hl
        ld (hl),45              ;result character, default -
        inc hl
        ld (hl),32
        inc hl
        ld (esp_logp),hl
        ret

;### ESPHEX -> low nibble of A as an ASCII hex digit into (HL)
esphex  and 15
        add 48
        cp 58
        jr c,esphex1
        add 7
esphex1 ld (hl),a
        ret

;### ESPLGS -> set the result character of the current log entry
;### Input      A=character
esplgs  ld hl,(esp_logres)
        ld c,a
        ld a,h
        or l
        ret z
        ld (hl),c
        ret

;### ESPTRY -> test the slot and sub-slot that are in cfg_slots
;### Output     CF=0 - a working ESP answered
;###            CF=1 - A=0 nothing there, A=1 ROM header seen but no answer
;### Destroyed  AF,BC,DE,HL
esp_sig         ds 3            ;ROM header bytes and status seen inside the window
esp_post        db 0            ;status after the clear command

esptry  call espenter
        jp c,esptry9
        ld a,(#4000)
        ld (esp_sig+0),a
        ld a,(#4001)
        ld (esp_sig+1),a
        ld a,(esp_mem_tx)       ;memio status
        ld (esp_sig+2),a
        call espleave
        ld a,(esp_sig+0)
        cp #41
        jp nz,esptry9           ;no "AB" ROM header
        ld a,(esp_sig+1)
        cp #42
        jp nz,esptry9
        call esplog
        ld a,(esp_sig+2)
        and #88                 ;bit 7 and bit 3 (quick receive supported) must be 1
        cp #88                  ;bit 6 is not set on the real hardware although the doc says so
        jp nz,esptry8           ;a ROM, but not the memio status register
        call espenter           ;a real memio reacts to the clear command, a ROM does not
        jp c,esptry9
        ld a,esp_cmd_clrfifo
        ld (esp_mem_cmd),a
        ld a,(esp_mem_tx)
        ld (esp_post),a
        call espleave
        ld a,(esp_post)
        bit 0,a                 ;still data waiting after the clear
        jr z,esptry1
        ld hl,esp_sig+2
        cp (hl)                 ;and the status did not change at all
        jr nz,esptry1
        ld a,82
        call esplgs             ;R = looks like a ROM, constant bytes
        jp esptry8
esptry1 ld a,78
        call esplgs             ;N until the ESP has answered
        xor a
        ld (esp_strat),a
esptry2 ld a,60                 ;wait up to 1 second per attempt
        ld (esp_wdef),a
        ld a,(esp_strat)
        call espprobe
        jp nc,esptry5
        ld a,(esp_strat)
        inc a
        ld (esp_strat),a
        cp 3
        jr c,esptry2
        ld a,20
        ld (esp_wdef),a
        ld a,(esp_snapdone)     ;nothing worked, look at what is left in the FIFO once
        or a
        call z,espsnap
        jp esptry8
esptry5 ld a,20
        ld (esp_wdef),a
        ld a,(esp_strat)
        add 48                  ;result character 0, 1 or 2 = the strategy that worked
        call esplgs
        or a                    ;an answer, whatever the return code
        ret
esptry8 ld a,1
        scf
        ret
esptry9 xor a
        scf
        ret

;### ESPPROBE -> one attempt to get a NET_STATE answer
;### Input      A=strategy 0 = clear FIFO then send, 1 = clear, wait 2 frames, send,
;###                      2 = read and discard until the FIFO is empty, then send
;### Output     CF=0 answered, CF=1 no answer
;### Destroyed  AF,BC,DE,HL
esp_strat       db 0
esp_snapdone    db 0
esp_snap        ds 4            ;status byte and up to 3 pending bytes
esp_snapn       db 0

espprobe cp 1
        jr z,espprb1
        cp 2
        jr z,espprb2
        call espenter           ;strategy 0, the sequence the original ROM uses
        ret c
        ld a,esp_cmd_clrfifo
        ld (esp_mem_cmd),a
        jr espprb9
espprb1 call espenter
        ret c
        ld a,esp_cmd_clrfifo
        ld (esp_mem_cmd),a
        call espleave
        halt
        halt
        call espenter
        ret c
        jr espprb9
espprb2 call espenter
        ret c
        call espdrain
espprb9 ld a,esp_fn_netstate
        ld hl,0
        call espcmd
        ld a,esp_fn_netstate
        call esprsp
        push af
        call nc,espskp
        call espleave
        pop af
        ret

;### ESPDRAIN -> read and throw away what is waiting in the RX FIFO, window must be open
espdrain ld bc,4000
espdrn1 ld a,(esp_mem_tx)
        bit 0,a
        ret z
        ld a,(esp_mem_cmd)
        dec bc
        ld a,b
        or c
        jr nz,espdrn1
        ret

;### ESPSNAP -> remember the status byte and the first pending bytes, once
espsnap ld a,1
        ld (esp_snapdone),a
        call espenter
        ret c
        ld a,(esp_mem_tx)
        ld (esp_snap),a
        ld b,3
        ld hl,esp_snap+1
espsn1  call espgtb
        jr c,espsn2
        ld (hl),a
        inc hl
        djnz espsn1
espsn2  ld a,3
        sub b
        ld (esp_snapn),a
        jp espleave

;### ESPHEXB -> A as two ASCII hex digits into (HL), HL advances by 2
esphexb push af
        rrca
        rrca
        rrca
        rrca
        call esphex
        inc hl
        pop af
        call esphex
        inc hl
        ret

;### ESPSNTX -> build the text of the adapter line from the snapshot
esp_sntxt       ds 14
espsntx ld hl,esp_sntxt
        ld a,(esp_snap)
        call esphexb
        ld a,(esp_snapn)
        or a
        jr nz,espsnt1
        ld (hl),32
        inc hl
        ld (hl),69              ;E for empty
        inc hl
        jr espsnt9
espsnt1 ld b,a
        ld de,esp_snap+1
espsnt2 ld (hl),32
        inc hl
        ld a,(de)
        inc de
        call esphexb
        djnz espsnt2
espsnt9 ld (hl),0
        ld hl,esp_sntxt
        ret

;### ESPFIND -> find the ESP, first the configured slot, then all slots
;### Output     CF=0 found (cfg_slots updated), CF=1 not found (cfg_slots unchanged)
;### Destroyed  AF,BC,DE,HL
esp_scantab     db 1,2,3,0      ;scan order of the primary slots
esp_scp         db 0
esp_scs         db 0
esp_seen        db 0
esp_cfgbak      dw 0

espfind xor a
        ld (esp_seen),a
        ld (esp_snapdone),a
        ld (esp_snapn),a
        ld (esp_logn),a
        ld hl,esp_logbuf
        ld (esp_logp),hl
        ld de,esp_logbuf+1
        ld bc,19
        ld (hl),0
        ldir
        call esptry
        jp nc,espfin6
        or a
        jr z,espfin0
        ld a,1
        ld (esp_seen),a
espfin0 ld hl,(cfg_slots)
        ld (esp_cfgbak),hl
        xor a
        ld (esp_scp),a
espfin1 xor a
        ld (esp_scs),a
espfin2 ld a,(esp_scp)
        ld e,a
        ld d,0
        ld hl,esp_scantab
        add hl,de
        ld a,(hl)
        ld (cfg_slots+0),a
        ld a,(esp_scs)
        ld (cfg_slots+1),a
        call esptry
        jp nc,espfin6
        or a
        jr z,espfin3
        ld a,1
        ld (esp_seen),a
espfin3 ld a,(esp_scs)
        inc a
        ld (esp_scs),a
        cp 4
        jr c,espfin2
        ld a,(esp_scp)
        inc a
        ld (esp_scp),a
        cp 4
        jp c,espfin1
        ld hl,(esp_cfgbak)      ;nothing found, restore the configuration
        ld (cfg_slots),hl
        ld hl,esptxt0
if ESPDEBUG=1
        ld a,(esp_seen)
        or a
        jr z,espfin4
        ld hl,esptxt1
        ld a,(esp_snapdone)
        or a
        jr z,espfin4
        call espsntx            ;shows status and pending bytes as hex
endif
espfin4 call esptext
if ESPDEBUG=1
        call esplogtx
endif
        scf
        ret
espfin6 ld hl,esptxt2         ;found, the adapter line reads Adapter: ESP8266 WiFi
        call esptext
if ESPDEBUG=1
        call esplogtx
endif
        or a
        ret

;### ESPLOGTX -> copy the diagnostic log to the second text line of the window
if ESPDEBUG=1
esplogtx ld hl,esp_logbuf
        ld de,esp_dbglog
        ld bc,19
        ldir
        xor a
        ld (de),a
        ret
endif

;### ESPTEXT -> copy the 0 terminated text in HL to the adapter text line
esptext ld de,esp_dbgtxt
        ld bc,15
        ldir
        ret
esptxt0 db "no device",0
        ds 6
esptxt1 db "ROM no ans",0
        ds 5
esptxt2 db "WiFi",0
        ds 10

;### ESPIPS -> read IP / mask / gateway / DNS from the ESP into net_ipaadr/net_dnspri
;### Output     CF=1 on failure
;### Destroyed  AF,BC,DE,HL,IX
espips  ld ix,net_ipaadr        ;ip, mask, gateway (3 x 4 byte)
        ld b,1:call espips1     ;local IP
        ret c
        ld ix,net_ipaadr+4
        ld b,3:call espips1     ;subnet mask
        ret c
        ld ix,net_ipaadr+8
        ld b,4:call espips1     ;default gateway
        ret c
        ld ix,net_dnspri
        ld b,5:call espips1     ;primary DNS
        ret c
        ld ix,net_dnspri+4
        ld b,6                  ;secondary DNS
espips1 call espenter
        ret c
        ld a,esp_fn_ipinfo
        ld hl,1
        call espcmd
        ld a,b
        call espsnd
        ld a,esp_fn_ipinfo
        call esprsp
        jr c,espips9
        or a
        jr nz,espips8
        call espgtb:jr c,espips9:ld (esp_ip4+0),a
        call espgtb:jr c,espips9:ld (esp_ip4+1),a
        call espgtb:jr c,espips9:ld (esp_ip4+2),a
        call espgtb:jr c,espips9:ld (esp_ip4+3),a
        call espleave
        ld hl,(esp_ip4+0)       ;copy to the daemon data, window is closed now
        ld (ix+0),l
        ld (ix+1),h
        ld hl,(esp_ip4+2)
        ld (ix+2),l
        ld (ix+3),h
        or a
        ret
espips8 call espskp
espips9 call espleave
        scf
        ret

;### ESPPOL -> hook for netpol (replaces m4cpol); completes pending replies
;### Destroyed  AF,BC,DE,HL,IX,IY
esppol  ld a,(esp_pend)
        or a
        jr z,esppoli
        cp esp_fn_dnsq
        jp z,espdnp
        cp esp_fn_tcpopen
        jp z,esptop
        ret

;--- nothing is pending, while online check the link now and then
esp_chkcnt      db 250
esp_state       db 0
esppoli ld a,(net_status)
        inc a                   ;255 = online
        ret nz
        ld hl,esp_chkcnt
        dec (hl)
        ret nz
        ld (hl),250             ;about every 5 seconds
        call espenter
        ret c
        ld a,esp_fn_netstate
        ld hl,0
        call espcmd
        ld a,esp_fn_netstate
        call esprsp
        jr c,esppol9            ;no answer, leave the state as it is
        or a
        jr nz,esppol8           ;the ESP reports an error, leave the state as it is
        ld a,h
        or l
        jr z,esppol9
        push hl
        call espgtb             ;the state byte
        pop hl
        jr c,esppol9
        ld (esp_state),a
        dec hl
        call espskp
        call espleave
        call espap              ;refresh the access point name now and then
        ld a,(esp_state)
        cp 2                    ;2 = open
        ret z
        ld a,1                  ;the link is gone, back to "no IP", NETIPS brings it back
        jp netini0
esppol8 call espskp
esppol9 call espleave
        ret

;------------------------------------------------------------------------------
;--- TCP ----------------------------------------------------------------------
;------------------------------------------------------------------------------

;### LOWTOP -> open TCP socket
;### Input      A=socket, E=0 client / 1 server, IX=param block
;###            (IX+0)=local port, (IX+2..5)=remote IP (octet order), (IX+6)=remote port
;### Output     CF=0 request started (result arrives via lowtst), CF=1 A=error
;### Destroyed  AF,BC,DE,HL,IX,IY
lowtop  ld c,a
        ld a,(esp_pend)
        or a
        ld a,neterrcon          ;another long request is outstanding
        scf
        ret nz
        push bc                 ;c=socket
        push de                 ;e=mode
        push ix
        pop hl                  ;copy the parameter block into the transfer area
        ld de,esp_tmp
        ld bc,8
        ldir
        pop de                  ;e=mode, still needed below
        push de
        call esptlsd            ;TLS port? then flags and host name are prepared
        call espenter
        jp c,lowtop9
        ld hl,(esp_tlsl)        ;0 = plain TCP, else the host name block follows the flags
        ld de,11
        add hl,de
        ld a,esp_fn_tcpopen
        call espcmd
        ld a,(esp_tmp+2):call espsnd    ;remote IP
        ld a,(esp_tmp+3):call espsnd
        ld a,(esp_tmp+4):call espsnd
        ld a,(esp_tmp+5):call espsnd
        ld a,(esp_tmp+6):call espsnd    ;remote port, little endian as UNAPI wants
        ld a,(esp_tmp+7):call espsnd
        ld a,(esp_tmp+0):call espsnd    ;local port
        ld a,(esp_tmp+1):call espsnd
        xor a:call espsnd       ;timeout suggestion 0 = default
        xor a:call espsnd
        pop de
        ld a,e                  ;flags, bit0 = passive (server), bit2 = TLS, bit3 = check the certificate
        and 1
        ld hl,esp_tlsf
        or (hl)
        call espsnd
        ld hl,(esp_tlsp)        ;host name for TLS (SNI), 0 terminated, nothing for plain TCP
        ld bc,(esp_tlsl)
lowtop6 ld a,b
        or c
        jr z,lowtop7
        ld a,(hl)
        ld (esp_mem_tx),a
        inc hl
        dec bc
        jr lowtop6
lowtop7 call espleave
        pop bc
        ld a,c
        ld (esp_pendsck),a
        ld a,esp_fn_tcpopen
        ld (esp_pend),a
        ld hl,esp_conn
        ld b,0
        add hl,bc
        ld (hl),0
        ld hl,esp_stat
        add hl,bc
        ld (hl),0               ;0 = still opening
        or a
        ret
lowtop9 pop de
        pop bc
        ld a,neterrnhw
        scf
        ret

;### ESPTLSD -> decide if this open is TLS and prepare flags and host name
;### Input      E=mode (bit 0 = server), esp_tmp = parameter block
;### Output     esp_tlsf = flag bits for the ESP, esp_tlsl = number of host name bytes (0 = plain TCP),
;###            esp_tlsp = the host name
;### The ESP firmware (BearSSL) does the TLS work, only one TLS connection at a time. A connection to
;### one of the ports in esp_tlsports is made a TLS connection, the program talks plain data.
;### The host name is looked up by IP in the last DNS answers, it is needed for SNI and the name check.
esp_tlsf        db 0
esp_tlsl        dw 0
esp_tlsp        dw 0
esp_nohost      db 0
esp_tlsports    dw 443,8443,465,993,995,0
esp_hni         db 0
esp_hn          ds 4*68         ;last 4 DNS answers - IP (4) and name (64)

esptlsd xor a
        ld (esp_tlsf),a
        ld hl,0
        ld (esp_tlsl),hl
        bit 0,e
        ret nz                  ;server connections stay plain
        ld hl,esp_tlsports
        ld a,(esp_tmp+6)
        ld c,a
        ld a,(esp_tmp+7)
        ld b,a
esptl0  ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        ret z                   ;not a TLS port
        ld a,e
        cp c
        jr nz,esptl0
        ld a,d
        cp b
        jr nz,esptl0
if TLSVERIFY=1
        ld a,12                 ;TLS and check the certificate
else
        ld a,4                  ;TLS, the certificate is not checked
endif
        ld (esp_tlsf),a
        ld hl,esp_nohost        ;without a known name only the terminator is sent
        ld (esp_tlsp),hl
        ld hl,1
        ld (esp_tlsl),hl
        ld ix,esp_hn
        ld b,4
esptl1  ld a,(ix+4)
        or a
        jr z,esptl4             ;entry not used
        ld a,(esp_tmp+2)
        cp (ix+0)
        jr nz,esptl4
        ld a,(esp_tmp+3)
        cp (ix+1)
        jr nz,esptl4
        ld a,(esp_tmp+4)
        cp (ix+2)
        jr nz,esptl4
        ld a,(esp_tmp+5)
        cp (ix+3)
        jr nz,esptl4
        push ix                 ;found, count the name with its terminator
        pop hl
        ld de,4
        add hl,de
        ld (esp_tlsp),hl
        ld bc,1
esptl3  ld a,(hl)
        or a
        jr z,esptl5
        inc hl
        inc bc
        jr esptl3
esptl5  ld (esp_tlsl),bc
        ret
esptl4  ld de,68
        add ix,de
        djnz esptl1
        ret

;### ESPHNADD -> remember the name and the IP of the DNS answer that just arrived
esphnadd ld ix,esp_hn
        ld a,(esp_hni)
        or a
        jr z,esphna2
        ld b,a
        ld de,68
esphna1 add ix,de
        djnz esphna1
esphna2 push ix
        pop de
        ld hl,esp_dnsres
        ld bc,4
        ldir
        ld hl,esp_dnsb
        ld bc,64
        ldir
        ld a,(esp_hni)
        inc a
        and 3
        ld (esp_hni),a
        ret

;### ESPTOP -> poll the outstanding TCP open
esptop  call espenter
        ret c
        ld a,esp_fn_tcpopen
        call esprsp0
        jp c,esptop9            ;not there yet, try again on the next poll
        or a
        jr nz,esptop5
        call espgtb             ;payload = 1 byte - the ESP connection number
        jr c,esptop9
        ld d,a
        call espleave
        ld a,(esp_pendsck)
        call espslot
        ld (hl),d
        ld a,sckstates
        jr esptop7
esptop5 call espskp             ;failed - drain payload, mark closed
        call espleave
        ld a,sckstatcl
esptop7 push af
        ld a,(esp_pendsck)
        ld c,a
        ld b,0
        ld hl,esp_stat
        add hl,bc
        pop af
        ld (hl),a
        xor a
        ld (esp_pend),a
        ret
esptop9 call espleave
        ret

;### ESPSLT -> HL=address of esp_conn entry for socket A
espslot ld c,a
        ld b,0
        ld hl,esp_conn
        add hl,bc
        ret

;### ESPSTQ -> query ESP TCP state of one daemon socket
;### Input      A=socket
;### Output     CF=0 - esp_st_* filled in; CF=1 - ESP did not answer / no conn
;###            ZF... (rc<>0 from ESP is reported as CF=0, esp_st_state=0)
;### Destroyed  AF,BC,DE,HL
esp_st_state    db 0            ;UNAPI TCP state
esp_st_avail    dw 0            ;bytes available to read
esp_st_ip       ds 4
esp_st_port     dw 0

espstq  call espslot
        ld a,(hl)
        or a
        scf
        ret z                   ;socket has no ESP connection
        ld d,a                  ;d=conn number
        xor a
        ld (esp_st_state),a
        ld hl,0
        ld (esp_st_avail),hl
        call espenter
        ret c
        ld hl,1
        ld a,esp_fn_tcpstate
        call espcmd
        ld a,d
        call espsnd
        ld a,esp_fn_tcpstate
        call esprsp
        jp c,espstq9
        or a
        jr nz,espstq8           ;ESP - no such connection -> state 0 (closed)
        call espgtb:jr c,espstq9        ;byte0 = close reason (ignored)
        call espgtb:jr c,espstq9
        ld (esp_st_state),a             ;byte1 = state
        call espgtb:jr c,espstq9
        ld (esp_st_avail+0),a           ;bytes2-3 = bytes available
        call espgtb:jr c,espstq9
        ld (esp_st_avail+1),a
        ld b,4                          ;bytes4-7 = urgent + free space - skip
espstq1 call espgtb:jr c,espstq9
        djnz espstq1
        ld hl,esp_st_ip                 ;8 byte info block - IP(4), rport(2), lport(2)
        ld b,6
espstq2 call espgtb:jr c,espstq9
        ld (hl),a
        inc hl
        djnz espstq2
        call espgtb:jr c,espstq9        ;local port, ignored
        call espgtb:jr c,espstq9
        call espleave
        or a
        ret
espstq8 call espskp
        call espleave
        or a
        ret
espstq9 call espleave
        scf
        ret

;### LOWTST -> TCP status of a socket
;### Input      A=socket
;### Output     A=status (0=in process -> daemon skips), +128=data received,
;###            BC=received bytes available, IX,IY=remote IP, DE=remote port
;### Destroyed  F,HL
;!!VERIFY  daemon status numbers (Dmn-Network.asm) - 0 listen, 1 opening,
;          2 established, 3 close waiting, 4 closed.
;!!VERIFY  UNAPI TCP states assumed - 0 closed,1 listen,2 syn-sent,3 syn-rcvd,
;          4 established,9 close-wait (check TCP/IP UNAPI spec 4.5.x).
lowtst  ld (lowtsts),a
        ld c,a
        ld a,(esp_pend)
        cp esp_fn_tcpopen
        jr nz,lowtst1
        ld a,(esp_pendsck)
        cp c
        jr nz,lowtst1
        call esppol             ;try to finish the pending open
lowtst1 ld a,(lowtsts)
        call espslot
        ld a,(hl)
        or a
        jr nz,lowtst2
        ld c,a                  ;no ESP conn yet - cached result of the open
        ld a,(lowtsts)
        ld c,a
        ld b,0
        ld hl,esp_stat
        add hl,bc
        ld a,(hl)
        or a
        jp z,lowtstz            ;still opening -> A=0 -> daemon skips
        jp lowtstc
lowtst2 ld a,(lowtsts)
        call espstq
        jp c,lowtstc            ;ESP silent - report closed
        ld a,(esp_st_state)
        ld b,sckstatcl
        or a:jr z,lowtst3       ;0 closed
        ld b,sckstatli
        cp 1:jr z,lowtst3       ;1 listen
        ld b,sckstatop
        cp 2:jr z,lowtst3       ;2 syn sent
        cp 3:jr z,lowtst3       ;3 syn rcvd
        ld b,sckstates
        cp 4:jr z,lowtst3       ;4 established
        ld b,sckstatcw
        cp 9:jr z,lowtst3       ;9 close wait
        ld b,sckstatcl          ;anything else = closing/unknown
lowtst3 ld a,b
        ld bc,(esp_st_avail)
        ld ix,(esp_st_ip+0)
        ld iy,(esp_st_ip+2)
        ld de,(esp_st_port)
        ld l,a
        ld a,b
        or c
        ld a,l
        ret z
        set 7,a                 ;data waiting
        ret
lowtstc ld a,sckstatcl
        ld bc,0
        ld ix,0
        ld iy,0
        ld de,0
        ret
lowtstz xor a
        ret
lowtsts db 0

;### LOWTTX -> TCP send
;### Input      A=socket, BC=length, E,HL=source (E=bank)
;### Output     BC=sent bytes, HL=remaining bytes (ZF=1 -> all sent)
;### Destroyed  AF,DE,IX,IY
;  Data is bounced through esp_buf in chunks; it is copied OUT of the caller's
;  bank with jmp_bnkcop BEFORE the window is opened.
lowttx  ld (lowttxs),a
        ld (lowttxb),de         ;e=bank
        ld (lowttxl),bc
        ld (lowttxa),hl
        ld bc,0
        ld (lowttxd),bc         ;sent so far
lowttx1 ld bc,(lowttxl)
        ld a,b
        or c
        jp z,lowttx8
        ld hl,esp_blen
        or a
        sbc hl,bc
        jr nc,lowttx2           ;remaining <= chunk
        ld bc,esp_blen
lowttx2 ld (lowttxc),bc
        ld a,(App_BnkNum)       ;bank copy - A=(dest<<4)+src, HL=src, DE=dest
        add a:add a:add a:add a
        ld hl,lowttxb
        add (hl)
        ld hl,(lowttxa)
        ld de,esp_buf
        rst #20:dw jmp_bnkcop
        ld a,(lowttxs)
        call espslot
        ld a,(hl)
        or a
        jp z,lowttx8            ;no ESP connection
        ld (lowttxn),a
        call espenter
        jp c,lowttx8
        ld bc,(lowttxc)
        ld hl,2
        add hl,bc
        ld a,esp_fn_tcpsend
        call espcmd
        ld a,(lowttxn):call espsnd
        ld a,1:call espsnd      ;flags - PUSH
        ld hl,esp_buf
        ld bc,(lowttxc)
lowttx3 ld a,(hl):ld (esp_mem_tx),a
        inc hl
        dec bc
        ld a,b:or c
        jr nz,lowttx3
        ld a,esp_fn_tcpsend
        call esprsp
        push af
        call nc,espskp
        call espleave
        pop af
        jr c,lowttx8            ;no answer
        or a
        jr nz,lowttx8           ;ESP refused (buffer full/closed) -> report partial
        ld a,esp_sta_delay
        ld (esp_sta_tx),a       ;TX light
        ld bc,(lowttxc)
        ld hl,(lowttxd):add hl,bc:ld (lowttxd),hl
        ld hl,(lowttxa):add hl,bc:ld (lowttxa),hl
        ld hl,(lowttxl):or a:sbc hl,bc:ld (lowttxl),hl
        jp lowttx1
lowttx8 ld bc,(lowttxd)
        ld hl,(lowttxl)
        ld a,h
        or l
        ret
lowttxs db 0
lowttxn db 0
lowttxb dw 0
lowttxl dw 0
lowttxa dw 0
lowttxd dw 0
lowttxc dw 0

;### LOWTRX -> TCP receive          LOWTSK -> TCP skip (discard)
;### Input      A=socket, BC=length, E,HL=destination (E=bank)
;### Output     BC=bytes REMAINING in the socket afterwards
;### Destroyed  AF,DE,HL,IX,IY
;  ESP TCP_RCV (18) returns up to the requested size.  Data goes into esp_buf
;  inside a window, then is copied to the caller's bank OUTSIDE the window.
;!!VERIFY  the daemon treats BC after lowtrx as "bytes remaining" (tcprcv in
;          Dmn-Network.asm stores it into sckdatrcv).
lowtsk  ld d,1
        jr lowtrx0
lowtrx  ld d,0
lowtrx0 ld (lowtrxm),de         ;d=mode(1=skip) e=bank
        ld (lowtrxs),a
        ld (lowtrxl),bc
        ld (lowtrxa),hl
lowtrx1 ld bc,(lowtrxl)
        ld a,b
        or c
        jp z,lowtrx9
        ld hl,esp_blen
        or a
        sbc hl,bc
        jr nc,lowtrx2
        ld bc,esp_blen
lowtrx2 ld (lowtrxc),bc         ;chunk size requested
        ld a,(lowtrxs)
        call espslot
        ld a,(hl)
        or a
        jp z,lowtrx9
        ld d,a                  ;d=conn
        call espenter
        jp c,lowtrx9
        ld hl,3
        ld a,esp_fn_tcprcv
        call espcmd
        ld a,d:call espsnd
        ld a,(lowtrxc+0):call espsnd
        ld a,(lowtrxc+1):call espsnd
        ld a,esp_fn_tcprcv
        call esprsp
        jp c,lowtrxw
        or a
        jp nz,lowtrxe
        ld a,h
        or l
        jp z,lowtrxw            ;nothing delivered
        dec hl:dec hl           ;minus the 2 urgent-count bytes
        ld (lowtrxn),hl
        call espgtb:jp c,lowtrxw
        call espgtb:jp c,lowtrxw
        ld hl,esp_buf
        ld bc,(lowtrxn)
lowtrx3 ld a,b:or c
        jr z,lowtrx4
        push bc
        call espgtb
        pop bc
        jp c,lowtrxw
        ld (hl),a
        inc hl
        dec bc
        jr lowtrx3
lowtrx4 call espleave
        ld a,esp_sta_delay
        ld (esp_sta_rx),a       ;RX light
        ld a,(lowtrxm+1)        ;mode (1=skip)
        or a
        jr nz,lowtrx5           ;skip mode - discard, no copy
        ld a,(App_BnkNum)
        ld e,a                  ;e=own bank (source)
        ld a,(lowtrxm+0)        ;a=caller bank (destination)
        add a:add a:add a:add a
        add e                   ;A=(dest<<4)+src
        ld hl,esp_buf
        ld de,(lowtrxa)         ;caller destination address
        ld bc,(lowtrxn)
        rst #20:dw jmp_bnkcop
lowtrx5 ld bc,(lowtrxn)
        ld hl,(lowtrxa):add hl,bc:ld (lowtrxa),hl
        ld hl,(lowtrxl):or a:sbc hl,bc:ld (lowtrxl),hl
        ld hl,(lowtrxc)
        or a
        sbc hl,bc
        jp z,lowtrx1            ;full chunk delivered -> maybe more
        jr lowtrx9              ;short chunk = ESP has nothing more
lowtrxe call espskp
lowtrxw call espleave
lowtrx9 ld a,(lowtrxs)          ;remaining bytes = ask the ESP
        call espstq
        ld bc,0
        ret c
        ld bc,(esp_st_avail)
        ret
lowtrxm dw 0                    ;low=bank (E), high=mode (D)
lowtrxs db 0
lowtrxl dw 0
lowtrxa dw 0
lowtrxc dw 0
lowtrxn dw 0

;### LOWTCL -> close (graceful)      LOWTDC -> disconnect (abort)
;### Input      A=socket
;### Output     A=0
lowtdc  ld c,esp_fn_tcpabort
        jr lowtcl0
lowtcl  ld c,esp_fn_tcpclose
lowtcl0 push bc
        call espslot
        ld a,(hl)
        ld b,a
        ld (hl),0
        pop de                  ;e=fn
        or a
        ret z                   ;nothing open on the ESP side
        call espenter
        ret c
        ld a,e
        ld hl,1
        call espcmd
        ld a,b
        call espsnd
        ld a,e
        call esprsp
        call nc,espskp
        call espleave
        xor a
        ret

;### LOWTFL -> flush - the ESP has no send buffer to flush
lowtfl  or a
        ret


;------------------------------------------------------------------------------
;--- ACCESS POINT STATE AND NAME ---------------------------------------------
;------------------------------------------------------------------------------
; The ESP firmware has no signal strength command. What it can tell us is the state of
; the WiFi connection and the name of the access point (command g), that is shown in
; the driver tab. State, 0 idle, 1 connecting, 2 wrong password, 3 not found,
; 4 connection failed, 5 connected with an IP.

esp_apst        db 0
esp_ssidn       ds 34           ;access point name as read
esp_ssidt       ds 40           ;the text for the driver tab
esp_ssidchg     db 0            ;set when the text changed, the daemon redraws it
esptxw1         db "WiFi: "
esptxw2         db "WiFi: not connected",0

;### ESPAP -> read access point state and name, update the text of the driver tab
;### Output     CF=0
;### Destroyed  AF,BC,DE,HL
espap   call espenter
        jp c,espapx
        ld a,esp_cmd_clrfifo
        ld (esp_mem_cmd),a
        ld a,103                ;g = request access point status
        call espsnd
        ld a,103
        call esprsp
        jp c,espap9
        or a
        jp nz,espap8
        ld a,h
        or l
        jp z,espap8
        call espgtb             ;the state
        jp c,espap9
        ld (esp_apst),a
        dec hl
        ld de,esp_ssidn
        ld b,32
espap1  ld a,h
        or l
        jr z,espap3
        ld a,b
        or a
        jr z,espap2
        call espgtb
        jp c,espap9
        dec hl
        ld (de),a
        inc de
        dec b
        jr espap1
espap2  call espskp             ;name longer than the buffer
espap3  xor a
        ld (de),a
        call espleave
        call espssid
        or a
        ret
espap8  call espskp
espap9  call espleave
espapx  or a
        ret

;### ESPSSID -> build the driver tab text from state and name, tell the daemon if it changed
espssid ld de,esp_ssidt
        ld a,(esp_apst)
        cp 5
        jr z,espss0
        ld hl,esptxw2           ;not connected
        ld bc,20
        ldir
        jr espss3
espss0  ld hl,esptxw1           ;the text WiFi and then the name
        ld bc,6
        ldir
        ld hl,esp_ssidn
espss1  ld a,(hl)
        ld (de),a
        or a
        jr z,espss3
        inc hl
        inc de
        jr espss1
espss3  nop
        ld hl,esp_ssidt         ;compare with what the tab shows now
        ld de,statxttxr
        ld b,38
espss4  ld a,(de)
        cp (hl)
        jr nz,espss5
        or a
        ret z                   ;same text
        inc hl
        inc de
        djnz espss4
        ret
espss5  ld hl,esp_ssidt
        ld de,statxttxr
        ld bc,39
        ldir
        ld a,1
        ld (esp_ssidchg),a
        ret


;------------------------------------------------------------------------------
;--- UDP ----------------------------------------------------------------------
;------------------------------------------------------------------------------
; The ESP does not tell who sent a datagram until it is received, and the daemon wants the
; sender at status time. The firmware also drops a datagram when UDP_STATE is followed by
; UDP_RCV (both call parsePacket), so UDP_STATE is never used. The driver simply asks
; UDP_RCV every 2nd poll, keeps what it got in esp_urxb until the application receives or
; skips it. One datagram at a time, for all UDP sockets together, the others wait in the ESP.

esp_fn_udpopen  equ 8
esp_fn_udpclose equ 9
esp_fn_udpstate equ 10
esp_fn_udpsend  equ 11
esp_fn_udprcv   equ 12
esp_udpmax      equ 576         ;largest datagram payload handled
esp_udpmaxl     equ #40         ;576 = #0240
esp_udpmaxh     equ #02

esp_uconn       ds low_sockmax  ;ESP connection number per daemon socket, 0 = none
esp_uown        db 255          ;socket that owns the datagram in esp_urxb, 255 = none
esp_urxn        dw 0            ;its data length
esp_urxip       ds 4            ;sender IP, keep these two together
esp_urxpo       dw 0            ;sender port
esp_urxl2       dw 0
esp_upoll       db 1            ;divider, the ESP is asked for a datagram on every 2nd poll
esp_usck        db 0
esp_ucn         db 0
esp_utxs        db 0
esp_utxl        dw 0            ;length of the datagram to send
esp_utxh        ds 6            ;destination IP (4) and port (2)
lowutxb         db 0
lowutxa         dw 0
lowurxb         db 0
lowurxa         dw 0
esp_utxb        ds esp_udpmax
esp_urxb        ds esp_udpmax

;### ESPUSLT -> HL=address of the esp_uconn entry of socket A
espuslt ld c,a
        ld b,0
        ld hl,esp_uconn
        add hl,bc
        ret

;### LOWUOP -> open UDP socket
;### Input      A=socket, IX=parameter block, (IX+0)=local port
;### Output     CF=0 ok, CF=1 A=error
;### Destroyed  AF,BC,DE,HL,IX
lowuop  push af
        ld a,(ix+0)             ;read the parameter before the slot window opens
        ld (esp_tmp+0),a
        ld a,(ix+1)
        ld (esp_tmp+1),a
        pop af
        ld (esp_usck),a
        call espenter
        jp c,lowuop9
        ld hl,3
        ld a,esp_fn_udpopen
        call espcmd
        ld a,(esp_tmp+0):call espsnd
        ld a,(esp_tmp+1):call espsnd
        xor a:call espsnd       ;transient connection, UDP_CLOSE 0 can clean up after a crash
        ld a,esp_fn_udpopen
        call esprsp
        jp c,lowuop8
        or a
        jp nz,lowuop7
        call espgtb             ;the connection number
        jp c,lowuop8
        ld (esp_ucn),a
        call espleave
        ld a,(esp_usck)
        call espuslt
        ld a,(esp_ucn)
        ld (hl),a
        or a
        ret
lowuop7 call espskp
        call espleave
        ld a,neterrsfr          ;the ESP has no free connection
        scf
        ret
lowuop8 call espleave
lowuop9 ld a,neterrcon
        scf
        ret
lowuop0 equ lowuop

;### LOWUCL -> close UDP socket
;### Input      A=socket
;### Output     A=0
lowucl  ld (esp_usck),a
        call espuslt
        ld a,(hl)
        ld (esp_ucn),a
        ld (hl),0
        ld a,(esp_uown)
        ld hl,esp_usck
        cp (hl)
        jr nz,lowucl1
        ld a,255                ;drop its waiting datagram
        ld (esp_uown),a
lowucl1 ld a,(esp_ucn)
        or a
        ret z
        call espenter
        ret c
        ld hl,1
        ld a,esp_fn_udpclose
        call espcmd
        ld a,(esp_ucn)
        call espsnd
        ld a,esp_fn_udpclose
        call esprsp
        call nc,espskp
        call espleave
        xor a
        ret

;### ESPUCL0 -> UDP_CLOSE with connection 0 = close all transient UDP connections of the ESP
espucl0 call espenter
        ret c
        ld hl,1
        ld a,esp_fn_udpclose
        call espcmd
        xor a
        call espsnd
        ld a,esp_fn_udpclose
        call esprsp
        call nc,espskp
        call espleave
        ret

;### LOWUTX -> send a datagram
;### Input      A=socket, HL=data, E=data bank, BC=length, IX=destination (IP 4 bytes, port 2 bytes)
;### Output     CF=0 sent, CF=1 A=error
;### Destroyed  AF,BC,DE,HL,IX,IY
lowutx  ld (esp_utxs),a
        ld a,e
        ld (lowutxb),a
        ld (esp_utxl),bc
        ld (lowutxa),hl
        ld hl,esp_udpmax
        or a
        sbc hl,bc
        ld a,neterrdln          ;datagram too large
        jp c,lowutxe
        push ix
        pop hl
        ld de,esp_utxh          ;destination into the transfer area
        ld bc,6
        ldir
        ld bc,(esp_utxl)
        ld a,b
        or c
        jr z,lowutx0
        ld a,(App_BnkNum)       ;data from the caller's bank, A=(dest<<4)+src
        add a:add a:add a:add a
        ld hl,lowutxb
        add (hl)
        ld hl,(lowutxa)
        ld de,esp_utxb
        rst #20:dw jmp_bnkcop
lowutx0 ld a,(esp_utxs)
        call espuslt
        ld a,(hl)
        or a
        jp z,lowutxc            ;no ESP connection
        ld (esp_ucn),a
        call espenter
        jp c,lowutxc
        ld hl,(esp_utxl)
        ld de,7                 ;connection, IP and port come before the data
        add hl,de
        ld a,esp_fn_udpsend
        call espcmd
        ld a,(esp_ucn):call espsnd
        ld hl,esp_utxh
        ld b,6
lowutx1 ld a,(hl):ld (esp_mem_tx),a
        inc hl
        djnz lowutx1
        ld hl,esp_utxb
        ld bc,(esp_utxl)
lowutx2 ld a,b
        or c
        jr z,lowutx3
        ld a,(hl):ld (esp_mem_tx),a
        inc hl
        dec bc
        jr lowutx2
lowutx3 ld a,150                ;the ESP may need a while to send (the BIOS waits 600 ticks)
        ld (esp_wdef),a
        ld a,esp_fn_udpsend
        call esprsp
        push af
        ld a,20
        ld (esp_wdef),a
        pop af
        push af
        call nc,espskp
        call espleave
        pop af
        jr c,lowutxc
        or a
        jr nz,lowutxc
        ld a,esp_sta_delay
        ld (esp_sta_tx),a       ;TX light
        or a
        ret
lowutxc ld a,neterrcon
lowutxe scf
        ret

;### ESPURCV -> fetch the oldest datagram of connection (esp_ucn) into esp_urxb
;### Output     CF=0 ok (esp_urxip, esp_urxpo, esp_urxn filled), CF=1 failed
espurcv call espenter
        ret c
        ld hl,3
        ld a,esp_fn_udprcv
        call espcmd
        ld a,(esp_ucn):call espsnd
        ld a,esp_udpmaxl:call espsnd
        ld a,esp_udpmaxh:call espsnd
        ld a,esp_fn_udprcv
        call esprsp
        jp c,espurc9
        or a
        jp nz,espurc8
        push hl
        ld de,esp_udpmax+7      ;6 bytes of address plus the data, must fit
        or a
        sbc hl,de
        pop hl
        jp nc,espurc8
        push hl
        ld de,6
        or a
        sbc hl,de
        pop hl
        jp c,espurc8            ;shorter than the address part, not valid
        ld (esp_urxl2),hl
        ld b,6                  ;sender IP and port
        ld de,esp_urxip
espurc1 call espgtb
        jp c,espurc9
        ld (de),a
        inc de
        djnz espurc1
        ld hl,(esp_urxl2)
        ld de,6
        or a
        sbc hl,de
        ld (esp_urxn),hl        ;data length
        ld de,esp_urxb
espurc2 ld a,h
        or l
        jr z,espurc3
        call espgtb
        jp c,espurc9
        ld (de),a
        inc de
        dec hl
        jr espurc2
espurc3 nop
        call espleave
        or a
        ret
espurc8 call espskp
espurc9 call espleave
        scf
        ret

;### LOWUST -> status of a UDP socket
;### Input      A=socket
;### Output     A=status, 0 in process, 3 idle, +128 datagram waiting
;###            BC=its length, IX,IY=sender IP, DE=sender port
;### Destroyed  F,HL
lowust  ld (esp_usck),a
        ld c,a
        ld a,(esp_uown)
        cp c
        jr z,lowust5            ;a datagram of this socket is waiting
        inc a
        jp nz,lowusti           ;the buffer holds the datagram of another socket
        ld hl,esp_upoll
        dec (hl)
        jr nz,lowusti
        ld (hl),2               ;ask the ESP on every 2nd poll while an application waits
        ld a,(esp_usck)
        call espuslt
        ld a,(hl)
        or a
        jr z,lowusti
        ld (esp_ucn),a
        call espurcv            ;no UDP_STATE first, the firmware drops a datagram on the second parsePacket
        jr c,lowusti
        ld a,(esp_usck)
        ld (esp_uown),a
lowust5 ld bc,(esp_urxn)
        ld ix,(esp_urxip+0)
        ld iy,(esp_urxip+2)
        ld de,(esp_urxpo)
        ld a,131                ;idle plus data received
        ret
lowusti ld bc,0
        ld ix,0
        ld iy,0
        ld de,0
        ld a,3                  ;idle
        ret

;### LOWURX -> hand the waiting datagram over to the caller
;### Input      A=socket, BC=maximum length, E=destination bank, HL=destination
;### Destroyed  AF,BC,DE,HL
lowurx  ld a,e
        ld (lowurxb),a
        ld (lowurxa),hl
        ld hl,(esp_urxn)
        or a
        sbc hl,bc
        jr nc,lowurx1           ;the datagram is not shorter than the buffer, use BC
        ld bc,(esp_urxn)
lowurx1 ld a,b
        or c
        jr z,lowurx2
        ld a,(lowurxb)          ;A=(dest<<4)+src
        add a:add a:add a:add a
        ld hl,App_BnkNum
        add (hl)
        ld hl,esp_urxb
        ld de,(lowurxa)
        rst #20:dw jmp_bnkcop
lowurx2 ld a,255
        ld (esp_uown),a         ;the buffer is free again
        ld a,esp_sta_delay
        ld (esp_sta_rx),a       ;RX light
        or a
        ret

;### LOWUSK -> throw the waiting datagram away
;### Input      A=socket
lowusk  ld hl,esp_uown
        cp (hl)
        ret nz
        ld (hl),255
        ret


;------------------------------------------------------------------------------
;--- DNS (replaces m4cdns / m4cdnr in the M4Board high-level path) ------------
;------------------------------------------------------------------------------

;### ESPDNS -> start DNS request (blocking on the wire, so - send now, poll later)
;### Input      HL=domain string (0-terminated, in own bank)
;### Output     CF=1 on error
espdns  ld a,(esp_pend)
        or a
        scf
        ret nz
        ld de,esp_dnsb          ;copy the name into the transfer area, max 63 chars
        ld bc,0
espdns1 ld a,(hl)
        ld (de),a
        or a
        jr z,espdns2
        inc hl
        inc de
        inc bc
        ld a,c
        cp 63
        jr c,espdns1
        xor a                   ;too long, cut and terminate
        ld (de),a
espdns2 ld (esp_dnsl),bc        ;length without the terminator
        call espenter
        ret c
        ld hl,(esp_dnsl)
        inc hl                  ;plus the flag byte
        ld a,esp_fn_dnsq
        call espcmd
        xor a
        call espsnd             ;flags = 0
        ld hl,esp_dnsb
        ld bc,(esp_dnsl)
espdns3 ld a,b
        or c
        jr z,espdns4
        ld a,(hl)
        ld (esp_mem_tx),a
        inc hl
        dec bc
        jr espdns3
espdns4 call espleave
        ld a,esp_fn_dnsq
        ld (esp_pend),a
        ld a,1
        ld (esp_dnsst),a
        or a
        ret

;### ESPDNP -> poll outstanding DNS reply (called from esppol)
espdnp  call espenter
        ret c
        ld a,esp_fn_dnsq
        call esprsp0
        jr c,espdnp9
        or a
        jr nz,espdnp5
        call espgtb:jr c,espdnp9:ld (esp_dnsres+0),a
        call espgtb:jr c,espdnp9:ld (esp_dnsres+1),a
        call espgtb:jr c,espdnp9:ld (esp_dnsres+2),a
        call espgtb:jr c,espdnp9:ld (esp_dnsres+3),a
        call espleave
        call esphnadd
        ld a,2
        jr espdnp7
espdnp5 call espskp
        call espleave
        ld a,3
espdnp7 ld (esp_dnsst),a
        xor a
        ld (esp_pend),a
        ret
espdnp9 call espleave
        ret

;### ESPDNR -> DNSRQR equivalent
;### Output     CF=0 -> IP in IX,IY ; CF=1 -> A=0 still in progress, >0 error
espdnr  call esppol
        ld a,(esp_dnsst)
        cp 2
        jr z,espdnr1
        cp 3
        jr z,espdnr2
        xor a                   ;still in progress
        scf
        ret
espdnr1 xor a
        ld (esp_dnsst),a
        ld ix,(esp_dnsres+0)
        ld iy,(esp_dnsres+2)
        or a
        ret
espdnr2 xor a
        ld (esp_dnsst),a
        ld a,neterrdto          ;ESP gives no detail on DNS failure
        scf
        ret
