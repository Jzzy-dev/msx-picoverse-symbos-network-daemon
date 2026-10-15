;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@                                                                            @
;@               S y m b O S   -   N e t w o r k - D a e m o n                @
;@                                                                            @
;@             (c) 2015-2025 by Prodatron / SymbiosiS (Jörn Mika)             @
;@             Net4Cpc drivers & UI modifications by d_kef (2022)             @
;@                                                                            @
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

;todo
;- no hardware -> kein ip config aufrufbar

;- UDP handling (UDP status darf immer nur größe des ersten packets liefern! - nach receive entweder rückgabe rest [bisher nicht definiert] oder neuer event, falls daten übrig)
;- DNS
;  - secondary server
;  - recursive handling
;  - close socket

;- connection reset -> sendet "close" messages an processe
;- CFGGET,A=?? gibt alle möglichen infos zurück (anzahl sockets, was kann er alles blabla)
;- sleep mode bei 0 connections und nicht driver tab

;? localhost -> client 2x starten? (edo)


;--- STATUS WINDOW ------------------------------------------------------------
;### STAUPD -> update status window
;### STAHID -> hide status window
;### STAAPL -> Apply driver settings
;### STATAB -> changes status window tab
;### STACFG -> opens/focus config window

;--- CONFIG WINDOW ------------------------------------------------------------
;### CFGPTH -> Generates config path
;### CFGLOD -> load config data
;### CFGSAV -> save config data
;### CFGINI -> prepare config window
;### CFGIPC -> generates config-IP number input controls for config window
;### CFGIPR -> generates real-IP number string for status window
;### CFGTAB -> changes config window tab
;### CFGOKY -> apply settings and close config window
;### CFGCNC -> close config window
;### CFGHID -> hide on start up on/off

;--- NETWORK MANAGEMENT -------------------------------------------------------
;### NETINI -> Initializes network hardware
;### NETIPS -> initialize IP and DNS settings
;### NETPRT -> generates random local port, if required
;### NETDIN -> increases incoming bytes
;### NETDOU -> increases outgoing bytes
;### NETPOL -> polls status and sockets
;### NETTCP -> manages TCP socket
;### NETUDP -> manages UDP socket
;### NETDNS -> manages DNS socket
;### NETDHC -> manages DHCP socket
;### NETCMD -> execute network command
;### NETMSG -> send message to process
;### NETRES -> resets all connections

;--- SOCKET HANDLING ----------------------------------------------------------
;### SCKNEW -> get new socket
;### SCKGET -> get socket datarecord
;### SCKDEC -> decreases number of used sockets

;--- TCP ROUTINES -------------------------------------------------------------
;### TCPOPN -> TCP open connection
;### TCPCLO -> TCP close connection
;### TCPSTA -> TCP status of connection
;### TCPRCV -> TCP receive from connection
;### TCPSND -> TCP send to connection
;### TCPSKP -> TCP skip received data
;### TCPFLS -> TCP flush send buffer
;### TCPDIS -> TCP disconnect connection

;--- UDP ROUTINES -------------------------------------------------------------
    ;### UDPOPN -> UDP open
    ;### UDPCLO -> UDP close
    ;### UDPSTA -> UDP status
    ;### UDPRCV -> UDP receive
    ;### UDPSND -> UDP send
    ;### UDPSKP -> UDP skip received data

;--- DNS ROUTINES -------------------------------------------------------------
;### DNSRSV -> resolve domain name
;### DNSCNV -> convert domain name string into the DNS packet format
;### DNSGPK -> generate DNS request packet
;### DNSGIP -> get IP address from resource record
;### DNSRQS -> send DNS request
;### DNSRQR -> check for DNS resolve
;### DNSVFY -> verify domain name
;### DNSSUB -> analyse dot-separated sub-part of a domain string

;--- DHCP ROUTINES ------------------------------------------------------------
;### DHCBEG -> start DHCP procedure
;### DHCPOL -> polls DHCP server answers
;### DHCPAK -> prepares a DHCP package
;### DHCOPT -> searches for a special option

;--- CONFIG ROUTINES ----------------------------------------------------------
;### CFGGET -> get config data
;### CFGSET -> set config data
;### CFGSCK -> get socket status

;--- SUB ROUTINES -------------------------------------------------------------
;### CLCUCS -> Change letters to uppercase
;### CLCN08 -> Converst 8bit number into ASCII string (0-terminated)
;### CLCN32 -> Converts 32Bit number into ASCII string (0-terminated)
;### CLCHEX -> Converts 8bit value into hex string
;### CLCHXB -> converts HEX string into value


;### ERROR CODES
neterrnhw   equ 1   ;no hardware setup
neterrnip   equ 2   ;no IP configuration
neterrfnc   equ 3   ;function not supported
neterruhw   equ 4   ;unknown hardware error
neterrcon   equ 5   ;offline/not connected
neterrwif   equ 6   ;wifi error (SF3 specific)

neterrsfr   equ 8   ;socket - no more free socket
neterrsex   equ 9   ;socket - does not exist
neterrstp   equ 10  ;socket - wrong type
neterrspr   equ 11  ;socket - is in use for another process

neterrdiv   equ 16  ;dns - invalid domain string
neterrdto   equ 17  ;dns - timeout
neterrdrc   equ 18  ;dns - recursion not supported
neterrdtr   equ 19  ;dns - truncated answer
neterrdln   equ 20  ;dns - package too large

neterrtes   equ 24  ;tcp - connection not yet established


;==============================================================================
;### VARIABLES ################################################################
;==============================================================================

sckdattyp   equ 0   ;0=free, 1=TCP, 2=UDP, 3=DNS
sckdatprc   equ 1   ;process ID
sckdatsta   equ 2   ;+128=data received, 0=TCP listening, 1=TCP opening, 2=TCP established, 3=TCP close waiting, 4=TCP close, 16=UDP sending, 32=DNS lookup required, 33=DNS lookup in process
sckdatbnk   equ 3   ;UDP DNS memory bank
sckdatlpo   equ 4   ;TCP UDP local port, DNS string address
sckdatrip   equ 6   ;TCP UDP remote IP
sckdatrpo   equ 10  ;TCP UDP remote port
sckdatrcv   equ 12  ;TCP UDP received length
sckdatrsv   equ 14  ;*reserved*
sckdatlen   equ 16  ;struct length
sckdatmem   ds sckdatlen*low_sockmax

scktypfre   equ 0   ;socket free
scktyptcp   equ 1   ;socket in use as TCP connection
scktypudp   equ 2   ;socket in use as UDP session
scktypdns   equ 3   ;socket in use for DNS lookup

sckstatli   equ 0   ;tcp listening
sckstatop   equ 1   ;tcp opening
sckstates   equ 2   ;tcp established
sckstatcw   equ 3   ;tcp close waiting
sckstatcl   equ 4   ;tcp close
sckstausn   equ 16  ;udp sending in process
sckstadrq   equ 32  ;dns lookup required
sckstadpr   equ 33  ;dns lookup in process

netprcnum   db 0    ;process ID
netscknum   db 0    ;socket ID


net_status  db 0            ;0=no hardware, 1=no IP setup, 2=DHCP request, 3=DHCP failure, -1=connected
net_staadd  db 0            ;additional status, if "connected" -> 5=idle, 6=connecting, 7=wrong password, 8=no accesspoint found, 9=connection failed, 11=unknown error
net_timsec  dw 0
net_timtic  db 0

net_ipaadr  db 0,0,0,0      ;ip address
net_ipasbn  db 0,0,0,0      ;subnet mask
net_ipagat  db 0,0,0,0      ;gateway
net_dnspri  db 0,0,0,0      ;dns primary
net_dnssec  db 0,0,0,0      ;dns secondary

cfg_beg     ;***\\ CONFIG DATA

cfg_ipatyp  db 1            ;DHCP (0) or manually (1) IP
cfg_dnstyp  db 1            ;DHCP (0) or manually (1) DNS

cfg_ipaadr  ds 4                    ;\ don't change order
cfg_ipasbn  ds 4
cfg_ipagat  ds 4
cfg_dnspri  ds 4
cfg_dnssec  ds 4

cfg_hstnam  db "SYMBOS_Z80",0:ds 6  ;/

cfg_macadr  ds 6
if DRIVER=2
cfg_slots   db 0,0      ;index=0 as default for gr8net
else
cfg_slots   db 1,0      ;pslot=1 as default for denyonet
endif
cfg_hide    db 0

cfg_end     ;***// CONFIG DATA

pck_buffer  ds 576          ;UDP package buffer (for DNS and DHCP)
            db 255          ;(dhcp terminator)

neticnid    db 0            ;systray icon ID


;==============================================================================
;### MAIN #####################################################################
;==============================================================================

prgprz  call SySystem_HLPINI
        call prgdbl
        call prglng
        call cfglod
if M4BOARD=1
        ld a,5
        call lowini
        ld a,6
        call nc,lowini
endif
        call cfgini
        call netini

;call w51dmp ;##!!##

        ld a,(App_BnkNum)
        ld de,prgicnsml
        ld l,-1
        call SyDesktop_STIADD
        jr c,prgprz3
        ld (neticnid),a
prgprz3 ld a,low_sockmax
        ld hl,statxttxe0
        call clcn08

        ld a,(cfg_hide)
        or a
        call z,prgtry1

prgprz0 rst #30
        call netpol             ;polls status and sockets
        call staupd             ;update status display
prgprz1 ld a,(App_PrcID)
        db #dd:ld l,a
        db #dd:ld h,-1
        ld iy,App_MsgBuf
;...sleep handling
jr prgprz4
        rst #08
        jr prgprz5
prgprz4 rst #18                 ;check for messages
prgprz5 db #dd:dec l
        jr nz,prgprz0
        ld a,(App_MsgBuf+0)
        or a
        jp z,prgend
        db #dd:ld a,h
        cp PRC_ID_DESKTOP
        jr z,prgprz2
        cp PRC_ID_SYSTEM
        ;...
        ld (netprcnum),a        ;*** message from applications
        call netcmd
        jr prgprz1
prgprz2 ld a,(App_MsgBuf+0)     ;*** message from desktop manager
        ;...
        cp MSR_DSK_EVTCLK
        jr z,prgtry
        cp MSR_DSK_WCLICK
        jr nz,prgprz0
        ld a,(App_MsgBuf+2)
        cp DSK_ACT_CLOSE
        jp z,stahid
        cp DSK_ACT_MENU
        jr z,prgprz6
        cp DSK_ACT_CONTENT
        jr nz,prgprz0
prgprz6 ld hl,(App_MsgBuf+8)
        ld a,h
        or l
        jr z,prgprz0
        jp (hl)

;### PRGTRY -> tray icon clicked
prgtry  ld a,(stawinvis)
        or a
        ld a,(stawinid)
        jp nz,stacfg1
        call prgtry1
        jp prgprz0
prgtry1 ld a,(App_BnkNum)
        ld de,stawindat
        call SyDesktop_WINOPN
        ret c
        ld (stawinid),a
        ld a,-1
        ld (stawinvis),a
        ret

;### PRGLNG -> load language pack
prglnge db ".exe",0

prglng
if LNGSKIP=2
        ret                     ;direct texts, there is no pointer list and no language pack
endif
if LNGSKIP=1
        ld a,(App_BnkNum)       ;no OS call - write the real text bank into every pointer entry
        ld hl,texts_int
        ld de,(texts_int+1)     ;address of the first string = end of the pointer list
prglngp ld (hl),a
        inc hl
        inc hl
        inc hl
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,prglngp
        ret
endif
        ld hl,(App_BegCode)
        ld de,App_BegCode
        dec h
        add hl,de               ;HL=code area end=path
        push hl
prglng1 ld a,(hl)
        inc hl
        or a
        jr nz,prglng1
        ld bc,-9
        add hl,bc
        ex de,hl
        ld hl,prglnge
        ld bc,5
        ldir
        pop de
        ld a,(App_BnkNum)
        ld c,a
        ld hl,texts_int
        ld ix,256*0+9           ;default language=9 (english), pack=0
        ld iyl,0                ;language-file version 0
        jp SySystem_LNGLOD

;### PRGDBL -> Check,if program is already running
prgdbln db "Network Daem"
prgdbl  xor a
        ld (App_BegCode+prgdatnam),a
        ld e,0
        ld hl,prgdbln
        ld a,(App_BnkNum)
        call SySystem_PRGSRV
        or a
        jr z,prgend
        ld a,"N"
        ld (App_BegCode+prgdatnam),a
        ret

;### PRGHLP -> shows help
prghlp  call SySystem_HLPOPN
        jp prgprz0

;### PRGINF -> show info-box
prginf  ld hl,prgtxtinf
        ld b,1+128+64
prginf1 call prginf0
        jp prgprz0
prginf0 ld a,(App_BnkNum)
        ld de,stawindat
        jp SySystem_SYSWRN

;### PRGEND -> End program
prgend  ld a,(neticnid)
        or a
        call nz,SyDesktop_STIREM
        ld hl,(App_BegCode+prgpstnum)
        call SySystem_PRGEND
prgend0 rst #30
        jr prgend0


;==============================================================================
;### STATUS WINDOW ############################################################
;==============================================================================

stawinid    db 0

stawinvis   db 0    ;0=not visible, -1=visible
staupdcnt   db 1    ;update counter (only show updates every 50 ticks)

staupdflg   db 0    ;bit0=sockets changed, bit1=incoming data changed, bit2=outgoing data changed, bit3=status changed

staupdtab   dw statxttxc0,statxttxc1,statxttxc2,statxttxc3,statxttxc4
if M4BOARD=1
            dw statxttxc5,statxttxc6,statxttxc7,statxttxc8,statxttxc9,statxttxc10,statxttxc10
endif

stasckcnt   db 0    ;number of current sockets
staincbyt   ds 4    ;amount of incoming bytes
stainckby   ds 3    ;in KB
staoutbyt   ds 4    ;amount of outgoing bytes
staoutkby   ds 3    ;in KB

if DRIVER=4
staupdw51   db 0    ;last w5100s status
staupdctl   dw 32*4+stawindatc0:db 2*4+5    ;Cable unplugged
            dw 32*1+stawindatc0:db 2*1+5    ;Link
            dw 32*5+stawindatc0:db 2*5+5    ;100mbit
            dw 32*2+stawindatc0:db 2*2+5    ;full duplex
            dw 32*0+stawindatc0:db 2*0+5    ;-
            dw 32*3+stawindatc0:db 2*3+5    ;-
else
staupdw51   db 0    ;last w5100 status
staupdctl   dw 32*0+stawindatc0:db 2*0+5    ;TX
            dw 32*3+stawindatc0:db 2*3+5    ;RX
            dw 32*4+stawindatc0:db 2*4+5    ;collision
            dw 32*2+stawindatc0:db 2*2+5    ;full duplex
            dw 32*5+stawindatc0:db 2*5+5    ;100mbit
            dw 32*1+stawindatc0:db 2*1+5    ;link
endif

staupdsic   db 1    ;read signal strength only 1/sec
staupdsig   db -1   ;last signal strength (0-5)
staupdsta   db 0    ;last status
staupdsnw   dw 0    ;new signal/status

;### STAUPD -> update status window
staupd  ld a,(stawinvis)
        or a
        ret z
if M4BOARD=1
        ld hl,staupdsic         ;M4Board -> check signal and connection (every 50 frames)
        dec (hl)
        jr nz,staupdi
        ld (hl),100
        call m4csig
        ld (staupdsnw),de
        ld hl,staupdsta
        ld a,d
        cp (hl)
        jr z,staupdi
        ld (hl),a
        cp 5
        jr nz,staupdh
        ld a,6
        call lowini
        call cfgini
        call cfgipr
        ld a,-5
staupdh add 5
        ld (net_staadd),a
        ld hl,staupdflg
        set 3,(hl)
staupdi
endif
        ld a,(stactltba0)
        sub 1
        ret z
        jp nc,staupd6
        ld hl,staupdcnt         ;*** STATUS TAB
        dec (hl)
        ret nz
        ld (hl),50
        ld hl,staupdflg
        ld a,(hl)
        or a
        ret z
        ld (hl),0
        bit 3,a
        jr z,staupd5
        push af             ;update status
        ld hl,(net_status)
        ld a,l
        inc a
        jr nz,staupde
        add h
staupde add a
        ld c,a
        ld b,0
        ld hl,staupdtab
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (stactltxc0),hl
        ld e,10
        ld a,(stawinid)
        call SyDesktop_WINDIN
        pop af
staupd5 bit 0,a
        jr z,staupd1
        push af             ;update number of connections
        ld a,(stasckcnt)
        ld hl,statxttxd0
        call clcn08
        ld e,12
        ld a,(stawinid)
        call SyDesktop_WINDIN
        pop af
staupd1 bit 1,a
        jr z,staupd2
        push af             ;update amount of incoming data
        ld ix,staincbyt
        ld e,18
        ld iy,statxttxg0
        call staupd3
        pop af
staupd2 bit 2,a
        ret z
        ld ix,staoutbyt     ;update amount of outgoing data
        ld e,16
        ld iy,statxttxf0
staupd3 ld c,(ix+1)         ;e=control, ix=amount in bytes and kb, iy=textbuffer
        ld b,(ix+2)
        ld a,(ix+3)
        srl a:rr b:rr c
        srl a:rr b:rr c
        cp (ix+6)
        jr nz,staupd4
        ld l,(ix+4)
        ld h,(ix+5)
        sbc hl,bc
        ret z
staupd4 ld (ix+4),c
        ld (ix+5),b
        ld (ix+6),a
        push de
        ld e,a
        ld d,0
        db #dd:ld l,c
        db #dd:ld h,b
        call clcn32
        ld (iy+1)," "
        ld (iy+2),"K"
        ld (iy+3),"B"
        ld (iy+4)," "
        ld (iy+5),0
        pop de
        ld a,(stawinid)
        jp SyDesktop_WINDIN
staupd6                         ;*** DRIVER TAB
if DRIVER=6
        ld a,(esp_ssidchg)      ;the access point text changed, redraw that line (control 17)
        or a
        jr z,staupd6a
        xor a
        ld (esp_ssidchg),a
        ld e,17
        ld a,(stawinid)
        call SyDesktop_WINDIN
staupd6a
endif
if DRIVER=0
        ld a,r
        and #3f
        ld c,a
elseif DRIVER=1
        in a,(w51_sta_port)
        ld c,a
elseif DRIVER=2
        ld c,32
        ld hl,g8n_sta_tx
        ld a,(hl)
        sub 1
        jr c,staupda
        ld (hl),a
        set 0,c
staupda inc hl
        ld a,(hl)
        sub 1
        jr c,staupdb
        ld (hl),a
        set 1,c
staupdb ld a,c
elseif DRIVER=6
        ld c,0                  ;ESP8266 - link is on while the network is online
        ld a,(net_status)
        inc a
        jr nz,staupdl
        ld c,32
staupdl ld hl,esp_sta_tx        ;TX and RX stay on for a short moment after data moved
        ld a,(hl)
        sub 1
        jr c,staupda
        ld (hl),a
        set 0,c
staupda inc hl
        ld a,(hl)
        sub 1
        jr c,staupdb
        ld (hl),a
        set 1,c
staupdb ld a,c
elseif M4BOARD=1
        ld a,(staupdsnw)
        ld hl,staupdsig
        cp (hl)
        jr z,staupdc
        ld (hl),a               ;signal changed
        add a
        ld c,a
        ld b,0
        ld hl,siggfxtab
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (stawindatc1+4),hl
        ld a,(stawinid)
        ld e,14
        call SyDesktop_WINDIN
staupdc ld a,(staupdsig)        ;link depends on signal
        or a
        ld c,a
        jr z,staupdd
        ld c,32
staupdd ld hl,m4c_sta_tx        ;check TX and RX
        ld a,(hl)
        sub 1
        jr c,staupda
        ld (hl),a
        set 0,c
staupda inc hl
        ld a,(hl)
        sub 1
        jr c,staupdb
        ld (hl),a
        set 1,c
staupdb ld a,c
elseif DRIVER=4
        db #fd:ld h,0
        call w51rbr:db w51_com_physr       ;check status
        ld a,e
        bit 0,a
        jr z,stupd10
        and %11111110
        jr stupd11	
stupd10	or %00000001
stupd11	rlca                               ;move cable status to bit0
        ld c,a
endif
        ld hl,staupdw51
        xor (hl)
        ld (hl),c
        ret z
        ld l,a              ;l=changed bits
        ld h,c              ;h=bits
        ld ix,staupdctl-3
        ld b,6
        ld a,(stawinid)
        ld c,a
staupd7 ld de,3
        add ix,de
        rrc l
        rr h
        bit 7,l
        jr z,staupd9
        push hl
        push bc
        push ix
        ld l,(ix+0)
        ld h,(ix+1)
        ld a,c
        ld bc,stactllg0
        jr nc,staupd8
        ld bc,stactllg1
staupd8 ld (hl),c
        inc hl
        ld (hl),b
        ld e,(ix+2)
        call SyDesktop_WINDIN
        pop ix
        pop bc
        pop hl
staupd9 djnz staupd7
        ret

;### STAHID -> hide status window
stahid  xor a
        ld (stawinvis),a
        ld a,(stawinid)
        call SyDesktop_WINCLS
        jp prgprz0

;### STAAPL -> Apply driver settings
staapl  ld a,(stactlpsl+12)
        ld (cfg_slots+0),a
        ld a,(stactlssl+12)
        dec a
        ld (cfg_slots+1),a
if DRIVER=6
        cp 4                    ;the list entry "-" gives 255, use sub-slot 0 then
        jr c,staapl0
        xor a
        ld (cfg_slots+1),a
staapl0 jp staapl3
endif
        ld ix,stabufim0
        ld de,cfg_macadr
        db #fd:ld l,6
        ld bc,3
staapl1 ld l,(ix+0)
        ld h,(ix+1)
        call clchxb
        jr c,staapl2
        ld (de),a
        inc de
        add ix,bc
        db #fd:dec l
        jr nz,staapl1
staapl3 call netini
        ;...check if its still wrong
        ld de,256*23+256-6
        ld a,(stawinid)
        call SyDesktop_WINDIN
        call cfgsav
        jp prgprz0
staapl2 ;...message "wrong mac"
        jp prgprz0

;### STATAB -> changes status window tab
statabadr   dw stawingrpa,stawingrpb,stawingrpc
statabact   db 0
statab  ld a,(stactltba0)
        ld hl,statabact
        ld bc,statabadr
        ld ix,stawindat0
        ld de,stawinid
        call cfgtab0
        jp prgprz0

;### STACFG -> opens/focus config window
stacfg  ld a,(cfgwinid)
        or a
        jr nz,stacfg1
        ld a,(App_BnkNum)
        ld de,cfgwindat
        call SyDesktop_WINOPN
        jp c,prgprz0
        ld (cfgwinid),a
        jp prgprz0
stacfg1 call SyDesktop_WINTOP
        jp prgprz0

if M4BOARD=1
;### STACON -> re-connect (M4Board)
stacon  ld a,7
        call lowini
        xor a
        ld (staupdsta),a
        jp prgprz0

;### STAPWS -> show/hide password
stapws  ld hl,stactlia1p
        ld a,(hl)
        xor 1
        ld (hl),a
        ld e,22
        ld a,(stawinid)
        call SyDesktop_WINDIN
        jp prgprz0
endif


;==============================================================================
;### CONFIG WINDOW ############################################################
;==============================================================================

cfgwinid    db 0

cfgpthfil   db "network.ini",0:cfgpthfil0
cfgpthadr   dw 0

;### CFGPTH -> Generates config path
cfgpth  ld hl,(App_BegCode)
        ld de,App_BegCode
        dec h
        add hl,de           ;HL = CodeEnd = path
        ld (cfgpthadr),hl
        ld e,l
        ld d,h              ;DE=HL
        ld b,255
cfgpth1 ld a,(hl)           ;search end of path
        or a
        jr z,cfgpth2
        inc hl
        djnz cfgpth1
        jr cfgpth4
        ld a,255
        sub b
        jr z,cfgpth4
        ld b,a
cfgpth2 ld (hl),0
        dec hl              ;search start of filename
        call cfgpth5
        jr z,cfgpth3
        djnz cfgpth2
        jr cfgpth4
cfgpth3 inc hl
        ex de,hl
cfgpth4 ld hl,cfgpthfil     ;replace application filename with config filename
        ld bc,cfgpthfil0-cfgpthfil
        ldir
        ret
cfgpth5 ld a,(hl)
        cp "/"
        ret z
        cp "\"
        ret z
        cp ":"
        ret

;### CFGLOD -> load config data
cfglod  call cfgpth
        ld hl,(cfgpthadr)
        ld a,(App_BnkNum)
        db #dd:ld h,a
        call SyFile_FILOPN          ;open file
        ret c
        ld hl,cfg_beg
        ld bc,cfg_end-cfg_beg
        ld de,(App_BnkNum)
        push af
        call SyFile_FILINP          ;load configdata
        pop af
        jp SyFile_FILCLO            ;close file

;### CFGSAV -> save config data
cfgsav  ld hl,(cfgpthadr)
        ld a,(App_BnkNum)
        db #dd:ld h,a
        xor a
        call SyFile_FILNEW          ;open file
        ret c
        ld hl,cfg_beg
        ld bc,cfg_end-cfg_beg
        ld de,(App_BnkNum)
        push af
        call SyFile_FILOUT          ;save configdata
        pop af
        call SyFile_FILCLO          ;close file
        ret

;### CFGINI -> prepare config window
cfgini  ld a,(cfg_hide)
        call cfghid1
        call cfgini0            ;set MAC address in driver window
        ld a,(cfg_slots+0)      ;set slots in driver window
        ld (stactlpsl+12),a
        ld a,(cfg_slots+1)
        inc a
        ld (stactlssl+12),a

        call cfgipc             ;set IP addresses in config window
        ld hl,cfg_hstnam        ;set hostname in config window
        ld de,cfgbufina
        ld bc,16
        ldir
        ld ix,cfgctlina
        call strinp

        ld a,(cfg_ipatyp)       ;set IP mode in config window
        ld (cfgctlras),a
        ld hl,stawindatb1
        call cfgini2
        ld a,(cfg_dnstyp)       ;set DNS mode in config window
        ld (cfgctlrbs),a
        ld hl,stawindatb2
cfgini2 or a
        ld bc,stactltxh0
        jr z,cfgini3
        ld bc,stactltxh1
cfgini3 ld (hl),c
        inc hl
        ld (hl),b
        ret
cfgini0 ld hl,cfg_macadr        ;set MAC address in config window
        ld b,6
        ld de,stabufim0
        ld ix,stactlim0
cfgini4 push bc
        ld a,(hl)
        inc hl
        call clchex
        inc de
        ld bc,13
        ld (ix+4),2
        ld (ix+8),2
        ld (ix+2),b
        ld (ix+6),b
        add ix,bc
        pop bc
        djnz cfgini4
        ret

;### CFGIPC -> generates config-IP number input controls for config window
cfgipc  ld hl,cfg_ipaadr    ;hl=IP
        ld ix,cfgctlia0     ;ix=input control
        ld de,cfgbufia0     ;de=input buffer
        ld c,5
cfgipc1 ld b,4
cfgipc2 push bc
        ld a,(hl)
        inc hl
        push hl
        ld l,e
        ld h,d
        call clcn08
        or a
        sbc hl,de
        ld (ix+4),l
        ld (ix+8),l
        ld (ix+2),h
        ld (ix+6),h
        ld bc,13
        add ix,bc
        inc de:inc de:inc de:inc de
        pop hl
        pop bc
        djnz cfgipc2
        dec c
        jr nz,cfgipc1
        ret

;### CFGIPR -> generates real-IP number string for status window
cfgipr  ld hl,net_ipaadr    ;hl=IP
        ld de,statxttxi0    ;de=strings (16bytes)
        ld c,5
cfgipr1 push de
        call cfgipr0
        pop de
        ld a,c
        ld c,16
        ex de,hl
        add hl,bc
        ex de,hl
        ld c,a
        dec c
        jr nz,cfgipr1
        ld a,(stawinvis)
        or a
        ret z
        ld a,(stactltba0)
        dec a
        ret nz
        ld a,(stawinid)
        ld e,-1
        jp SyDesktop_WINDIN
cfgipr0 ld b,4      ;hl=ip, de=string -> converts IP into string -> hl=hl+4, de=strend(0)
cfgipr2 push bc
        ld a,(hl)
        inc hl
        ex de,hl
        call clcn08
        ld (hl),"."
        inc hl
        ex de,hl
        pop bc
        djnz cfgipr2
        xor a
        dec de
        ld (de),a
        ret

;### CFGTAB -> changes config window tab
cfgtabadr   dw cfgwingrpa,cfgwingrpb
cfgtabact   db 0
cfgtab  ld a,(cfgctltba0)
        ld hl,cfgtabact
        ld bc,cfgtabadr
        ld ix,cfgwindat0
        ld de,cfgwinid
        call cfgtab0
        jp prgprz0
cfgtab0 cp (hl)
        ret z
        ld (hl),a
        add a
        ld l,a
        ld h,0
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (ix+0),l
        ld (ix+1),h
        ld a,(de)
        ld e,-1
        jp SyDesktop_WININH

;### CFGOKY -> apply settings and close config window
cfgokyb ds 5*4

cfgoky  ld hl,cfgbufia0     ;hl=input buffer
        ld de,cfgokyb       ;de=IP
        ld b,5*4
cfgoky1 ld c,0
        push hl
cfgoky2 ld a,(hl)
        or a
        jr z,cfgoky3
        cp "9"+1
        jr nc,cfgoky5
        ld a,c
        add a
        jr c,cfgoky5
        ld c,a
        add a
        jr c,cfgoky5
        add a
        jr c,cfgoky5
        add c
        jr c,cfgoky5
        ld c,a
        ld a,(hl)
        sub "0"
        jr c,cfgoky5
        add c
        jr c,cfgoky5
        ld c,a
        inc hl
        jr cfgoky2
cfgoky3 ld a,c
        ld (de),a
        inc de
        pop hl
        inc hl
        inc hl
        inc hl
        inc hl
        djnz cfgoky1
        ld hl,cfgokyb
        ld de,cfg_ipaadr
        ld c,5*4
        ldir
        ld hl,cfgbufina
        ld c,16
        ldir
        ld a,(cfgctlras)
        ld (cfg_ipatyp),a
        ld a,(cfgctlrbs)
        ld (cfg_dnstyp),a
        call cfgini
        call cfgsav
if M4BOARD=1
        ld a,7
        call lowini
        xor a
        ld (staupdsta),a
else
        ld a,(net_status)
        or a
        jr z,cfgoky4
        ld a,1
        call netini0
        call netips
endif
cfgoky4 ld a,(stactltba0)
        or a
        jr nz,cfgcnc
        ld a,(stawinvis)
        or a
        jr z,cfgcnc
        ld a,(stawinid)
        ld e,7
        call SyDesktop_WINDIN
        jr cfgcnc
cfgoky5 pop hl              ;*** WRONG IP FORMAT
        ld a,5*4
        sub b
        ld l,a
        ld h,0
        cp 3*4
        ld de,0*256+13      ;d=tab, e=first input control ID
        ld ix,cfgwingrpa
        jr c,cfgoky6
        ld de,1*256+256+11-24
        ld ix,cfgwingrpb
cfgoky6 add a
        add e               ;a=input control ID
        ld (ix+14),a        ;set focus control
        ld e,a
        ld c,l:ld b,h
        add hl,hl
        add hl,bc
        add hl,hl
        add hl,hl
        add hl,bc
        ld bc,cfgctlia0+4
        add hl,bc
        ld (hl),0
        ld bc,4
        add hl,bc
        ld a,(hl)
        dec hl
        dec hl
        ld (hl),a           ;mark whole text of the control
        push de
        ld a,d
        ld (cfgctltba0),a
        ld hl,cfgtabact
        ld bc,cfgtabadr
        ld ix,cfgwindat0
        ld de,cfgwinid
        call cfgtab0        ;show tab with wrong IP
        pop de
        dec e
        ld a,(cfgwinid)
        call SyDesktop_WININH
        ld hl,cfgerrmsg
        ld a,(App_BnkNum)
        ld b,1+8+64
        ld de,cfgwindat
        call SySystem_SYSWRN
        jp prgprz0

;### CFGCNC -> close config window
cfgcnc  ld hl,cfgwinid
        ld a,(hl)
        ld (hl),0
        call SyDesktop_WINCLS
        jp prgprz0

;### CFGHID -> hide on start up on/off
cfghid  ld hl,cfg_hide
        ld a,(hl)
        xor 1
        ld (hl),a
        call cfghid1
        call cfgsav
        jp prgprz0
cfghid1 add a
        inc a
        add 32
        ld (stamendat1a),a
        ret


;==============================================================================
;### NETWORK MANAGEMENT #######################################################
;==============================================================================

if DRIVER=0
netips
netini
        ld a,-1
netini0 ld (net_status),a
        ld hl,staupdflg
        set 3,(hl)
        ret
elseif M4BOARD=1
;### NETINI -> Initializes network hardware (M4CPC)
netini  xor a
        call netini0
        ld a,(m4cromnum)
        or a
        ret z
        ld a,1
netini0 ld (net_status),a
        ld hl,staupdflg
        set 3,(hl)
        ret

;### NETIPS -> initialize IP and DNS settings (M4CPC)
netips  ;...
        ld a,-1
        call netini0
        jp cfgipr

elseif DRIVER=6
;### NETINI -> Initializes network hardware (ESP8266 UNAPI firmware)
netini  xor a
        call netini0
        ld hl,(cfg_slots)       ;slot before the detection
        push hl
        xor a
        call lowini             ;probe and find the ESP, CF=1 means no hardware
        pop hl
        ret c
        ld de,(cfg_slots)
        or a
        sbc hl,de
        call nz,espslt          ;a different slot was found, show it and save it
        ld a,1
netini0 ld (net_status),a
        ld hl,staupdflg
        set 3,(hl)
        ret

;### ESPSLT -> show the detected slot in the driver tab and save the configuration
espslt  ld a,(cfg_slots+0)
        ld (stactlpsl+12),a
        ld a,(cfg_slots+1)
        inc a
        ld (stactlssl+12),a
        jp cfgsav

;### NETIPS -> read IP settings from the ESP (it does DHCP itself)
;### called by NETPOL while net_status=1, so throttle the polling
netipsc db 1
netips  ld hl,netipsc
        dec (hl)
        ret nz
        ld (hl),250             ;retry about every 5 seconds
        call espips             ;fills net_ipaadr (ip,mask,gateway) and net_dnspri
        ret c
        ld hl,net_ipaadr        ;0.0.0.0 -> WiFi not connected yet
        ld a,(hl):inc hl:or (hl):inc hl:or (hl):inc hl:or (hl)
        ret z
        ld a,-1
        call netini0            ;status "connected"
        jp cfgipr

elseif DRIVER=4
;### NETINI -> Initializes network hardware (Net4CPC)
netini 	xor a
        call netini0
        call w51set             ;set hardware
        ret c
        xor a
        call lowini             ;init hardware
        ld hl,cfg_macadr
        ld b,6
        call netini3
        jr nz,netini2
        ld hl,w51rommac
        ld de,cfg_macadr
        ld bc,6
        ldir
netini2 ld a,1
        call netini0
        call cfgini0            ;set mac address in driver window
        ld a,1
        ld hl,cfg_macadr
        jp lowini               ;set mac address
netini3 xor a
netini1 or (hl)
        inc hl
        djnz netini1
        or a
        ret
netini0 ld (net_status),a
        ld hl,staupdflg
        set 3,(hl)
        ret

;### NETIPS -> initialize IP and DNS settings (Net4CPC)
netips  ld a,(cfg_ipatyp)
        or a
        jr z,netips1
        ld hl,cfg_ipaadr        ;IP manual
        ld b,4
        push hl
        call netini3        ;(hl+0-3)=0 -> zf=1
        pop hl
        ret z
        ld de,net_ipaadr
        ld bc,4*3
        ldir
        call cfgipr
        ld a,2
        ld hl,net_ipaadr
        call lowini
        ld a,-1
        call netini0
        jr netips2
netips1 call dhcbeg             ;IP dhcp
        ld a,2
        call netini0
netips2 ld a,(cfg_dnstyp)
        or a
        ret z
        ld hl,cfg_dnspri        ;DNS manual
        ld de,net_dnspri
        ld bc,4*2
        ldir
        jp cfgipr

else
;### NETINI -> Initializes network hardware (W5100 based)
netini  xor a
        call netini0
        ld hl,(cfg_slots)
        call w51slt             ;set hardware
        ret c
        xor a
        call lowini             ;init hardware
        ld hl,cfg_macadr
        ld b,6
        call netini3
        jr nz,netini2
        ld hl,w51rommac
        ld de,cfg_macadr
        ld bc,6
        ldir
netini2 ld a,1
        call netini0
        call cfgini0            ;set mac address in driver window
        ld a,1
        ld hl,cfg_macadr
        jp lowini               ;set mac address
netini3 xor a
netini1 or (hl)
        inc hl
        djnz netini1
        or a
        ret
netini0 ld (net_status),a
        ld hl,staupdflg
        set 3,(hl)
        ret

;### NETIPS -> initialize IP and DNS settings
netips  ld a,(cfg_ipatyp)
        or a
        jr z,netips1
        ld hl,cfg_ipaadr        ;IP manual
        ld b,4
        push hl
        call netini3        ;(hl+0-3)=0 -> zf=1
        pop hl
        ret z
        ld de,net_ipaadr
        ld bc,4*3
        ldir
        call cfgipr
        ld a,2
        ld hl,net_ipaadr
        call lowini
        ld a,-1
        call netini0
        jr netips2
netips1 call dhcbeg             ;IP dhcp
        ld a,2
        call netini0
netips2 ld a,(cfg_dnstyp)
        or a
        ret z
        ld hl,cfg_dnspri        ;DNS manual
        ld de,net_dnspri
        ld bc,4*2
        ldir
        jp cfgipr
endif

;### NETPRT -> generates random local port, if required
;### Input      HL=port (-1=random port)
;### Output     HL=port (original or 49152–65534)
;### Destroyed  AF
netprtn dw 49152-1
netprt  ld a,l
        and h
        inc a
        ret nz
        push bc
        push de
        push ix
        ld hl,(netprtn)
netprt1 inc hl
        ld a,l
        and h
        inc a
        jr nz,netprt5
        ld hl,49152
netprt5 ld b,low_sockmax
        ld ix,sckdatmem
netprt2 ld a,(ix+sckdattyp)
        cp scktyptcp
        jr z,netprt3
        cp scktypudp
        jr nz,netprt4
netprt3 ld e,(ix+sckdatlpo+0)
        ld d,(ix+sckdatlpo+1)
        ex de,hl
        or a
        sbc hl,de
        ex de,hl
        jr z,netprt1
netprt4 ld de,sckdatlen
        add ix,de
        djnz netprt2
        ld (netprtn),hl
        pop ix
        pop de
        pop bc
        ret

;### NETDIN -> increases incoming bytes
;### Input      BC=number of bytes
;### Destroyed  -
netdin  push af
        push hl
        ld hl,(staincbyt+0)
        add hl,bc
        ld (staincbyt+0),hl
        ld hl,(staincbyt+2)
        ld a,0
        adc l
        ld l,a
        ld a,0
        adc h
        ld h,a
        ld (staincbyt+2),hl
        ld hl,staupdflg
        set 1,(hl)
        pop hl
        pop af
        ret

;### NETDOU -> increases outgoing bytes
;### Input      BC=number of bytes
;### Destroyed  -
netdou  push af
        push hl
        ld hl,(staoutbyt+0)
        add hl,bc
        ld (staoutbyt+0),hl
        ld hl,(staoutbyt+2)
        ld a,0
        adc l
        ld l,a
        ld a,0
        adc h
        ld h,a
        ld (staoutbyt+2),hl
        ld hl,staupdflg
        set 2,(hl)
        pop hl
        pop af
        ret

;### NETPOL -> polls status and sockets
netpol  
if M4BOARD=1
        call m4cpol
endif
if DRIVER=6
        call esppol             ;ESP8266 - collect pending TCP-open / DNS replies
endif
        ld hl,net_timtic
        dec (hl)
        jr nz,netpol5
        ld (hl),50
        ld hl,(net_timsec)
        inc hl
        ld (net_timsec),hl
netpol5 ld a,(net_status)
        inc a
        jr nz,netpol3
        ld ix,sckdatmem             ;*** SOCKET CHECK
        ld bc,low_sockmax*256   ;b=counter, c=socket
netpol1 ld (netpols+1),bc
        ld a,(ix+sckdatprc)
        ld (netprcnum),a
        ld a,(ix+sckdattyp)
        or a
        jr nz,netpol4
netpol2 ld bc,sckdatlen
        add ix,bc
netpols ld bc,0                 ;(netpols+1)=current socket
        inc c
        djnz netpol1
        ret
netpol4 push ix
        cp 2
        jr c,nettcp
        jp z,netudp
        jp netdns
netpol0 pop ix
        jr netpol2
netpol3 dec a                       ;*** STATUS CHECK
        ret z                   ;0 = no hardware
        cp 2
        jp z,dhcpol             ;2 = DHCP request
        ret nc                  ;3 = DHCP failed
        jp netips               ;1 = no IP setup

;### NETTCP -> manages TCP socket
;### Input      C=socket ID, IX=socket data
nettcps db 0,0          ;old status
nettcp  ld a,c
        call lowtst             ;A=status, BC=received bytes, IX,IY=remote IP, DE=remote port
        or a
        jr z,netpol0                ;in process -> skip
        ex (sp),ix              ;ix=data record
        ld l,(ix+sckdatsta)
        cp l
        jr nz,nettcp1
        ex (sp),ix              ;no overall-status change -> skip
        jr netpol0
nettcp1 ld (nettcps),hl
        pop hl                  ;hl,iy=ip
        push ix
        push af
        ld (ix+sckdatsta+0),a       ;store new status
        ld (ix+sckdatrcv+0),c       ;store received bytes
        ld (ix+sckdatrcv+1),b
        ld (ix+sckdatrpo+0),e       ;store remote port
        ld (ix+sckdatrpo+1),d
        ld (ix+sckdatrip+0),l       ;store remote IP
        ld (ix+sckdatrip+1),h
        db #fd:ld a,l
        ld (ix+sckdatrip+2),a
        db #fd:ld a,h
        ld (ix+sckdatrip+3),a
        ex (sp),hl
        ld l,h                  ;l=new status
        pop ix                  ;ix,iy=ip
        call netmsg0                ;prepare BC,DE,IX,IY
        bit 7,h
        jr z,nettcp2            ;no data received -> only send "connection status" event
        ld a,(nettcps)          ;a=old status
        bit 7,a
        jr nz,nettcp2           ;data received didn't change -> only send "connection status" event
        ld h,a
        push hl
        ld l,128                ;new data received -> send "data received" event
        call nettcp3
        pop hl
        res 7,l
        res 7,h
        ld a,l                  ;test, if connection status changed
        cp h
        jr z,netpol0
nettcp2 res 7,l                 ;send "connection status" event
        call nettcp3
        jr netpol0
;l=status
nettcp3 ld a,(netpols+1)
        or a
        call netmsg1:db MSR_NET_TCPEVT
        ret

;### NETUDP -> manages UDP socket
;### Input      C=socket ID, IX=socket data
if DRIVER=6
netudps db 0,0          ;old status
netudp  ld a,c
        call lowust             ;A=status, BC=received bytes, IX,IY=remote IP, DE=remote port
        or a
        jp z,netpol0                ;in process -> skip
        ex (sp),ix              ;ix=data record
        ld l,(ix+sckdatsta)
        cp l
        jr nz,netudp1
        ex (sp),ix              ;no overall-status change -> skip
        jp netpol0
netudp1 ld (netudps),hl
        pop hl                  ;hl,iy=ip
        push ix
        push af
        ld (ix+sckdatsta+0),a       ;store new status
        ld (ix+sckdatrcv+0),c       ;store received bytes
        ld (ix+sckdatrcv+1),b
        ld (ix+sckdatrpo+0),e       ;store remote port
        ld (ix+sckdatrpo+1),d
        ld (ix+sckdatrip+0),l       ;store remote IP
        ld (ix+sckdatrip+1),h
        db #fd:ld a,l
        ld (ix+sckdatrip+2),a
        db #fd:ld a,h
        ld (ix+sckdatrip+3),a
        ex (sp),hl
        ld l,h                  ;l=new status
        pop ix                  ;ix,iy=ip
        call netmsg0                ;prepare BC,DE,IX,IY
        bit 7,h
        jr z,netudp2            ;no data received -> only send "connection status" event
        ld a,(netudps)          ;a=old status
        bit 7,a
        jr nz,netudp2           ;data received didn't change -> only send "connection status" event
        ld h,a
        push hl
        ld l,128                ;new data received -> send "data received" event
        call netudp3
        pop hl
        res 7,l
        res 7,h
        ld a,l                  ;test, if connection status changed
        cp h
        jp z,netpol0
netudp2 res 7,l                 ;send "connection status" event
        call netudp3
        jp netpol0
;l=status
netudp3 ld a,(netpols+1)
        or a
        call netmsg1:db MSR_NET_UDPEVT
        ret
else
netudp  ;...
        jr netpol0
endif

;### NETDNS -> manages DNS socket
;### Input      C=socket ID, IX=socket data
netdns  ld a,(ix+sckdatsta)
        cp sckstadrq
        jr nz,netdns1
        ld hl,dnslupflg             ;** request is waiting
        ld a,(hl)
        or a
        jp nz,netpol0               ;another request is still proceeded -> keep it waiting
        ld (hl),1
        ld (ix+sckdatsta),sckstadpr
        ld a,(App_BnkNum)
        add a:add a:add a:add a
        add (ix+sckdatbnk+0)
        ld l,(ix+sckdatbnk+1)
        ld h,(ix+sckdatbnk+2)
        ld de,pck_buffer+576-256
        ld bc,256
        push de
        rst #20:dw jmp_bnkcop       ;copy domain name string to own buffer
        pop hl
        ld a,(netpols+1)
        call dnsrqs                 ;send DNS request
        jp netpol0
netdns1 call dnsrqr                 ;** request in process
        jp nc,netdns2               ;ok -> finish
        inc a:dec a
        jp z,netpol0                ;still in process
netdns2 ld hl,dnslupflg             ;dns is available again
        ld (hl),0
        pop hl                      ;free socket, send message
        push hl
        ld (hl),scktypfre
        call sckdec
        call netmsg:db FNC_NET_DNSRSV+128
        jp netpol0

;### NETCMD -> execute network command
;### Input      (netprcnum)=process ID, (App_MsgBuf)=data
;### Output     [process receives answer]
;### Destroyed  AF,BC,DE,HL,IX,IY
netcmdtab
dw 000000,cfgget,cfgset,cfgsck,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000  ;config
dw tcpopn,tcpclo,tcpsta,tcprcv,tcpsnd,tcpskp,tcpfls,tcpdis,000000,000000,000000,000000,000000,000000,000000,000000  ;TCP
dw udpopn,udpclo,udpsta,udprcv,udpsnd,udpskp,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000  ;UDP
dw 000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000
dw 000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000
dw 000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000
dw 000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000
dw dnsrsv,dnsvfy,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000,000000  ;DNS

netcmd  ld a,(App_MsgBuf+00)
        add 128
        ret c
        ld (netcmd2+3),a
        add a
        ld l,a
        ld h,0
        ld bc,netcmdtab
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        or h
        ret z
        ld (netcmd1+1),hl
        ld hl,(App_MsgBuf+02)
        push hl
        pop af
        ld bc,(App_MsgBuf+04)
        ld de,(App_MsgBuf+06)
        ld hl,(App_MsgBuf+08)
        ld ix,(App_MsgBuf+10)
        ld iy,(App_MsgBuf+12)
        ld (netscknum),a
netcmd1 call 0
        jr c,netcmd2
        ld a,(netscknum)
netcmd2 call netmsg:db 0
        ret

;### NETMSG -> send message to process
;### Input      (netprcnum)=process ID, ((SP+0))=network manager response
;###            AF,BC,DE,HL,IX,IY=registers
;### Destroyed  AF,BC,DE,HL,IX,IY
netmsg  call netmsg0
netmsg1 ld (App_MsgBuf+08),hl
        push af
        pop hl
        ld (App_MsgBuf+02),hl
        pop hl
        ld a,(hl)
        inc hl
        push hl
        ld (App_MsgBuf+00),a
        ld iy,App_MsgBuf
        ld a,(App_PrcID)
        db #dd:ld l,a
        ld a,(netprcnum)
        db #dd:ld h,a
        rst #10
        ret
netmsg0 ld (App_MsgBuf+04),bc
        ld (App_MsgBuf+06),de
        ld (App_MsgBuf+10),ix
        ld (App_MsgBuf+12),iy
        ret

;### NETRES -> resets all connections
netres  ld hl,sckdatmem+sckdattyp
        ld bc,low_sockmax*256
netres1 ld a,(hl)
        cp 1
        jr c,netres2
        push bc
        push hl
        ld a,c
        push af
        call z,lowtcl
        pop af
        call nz,lowucl
        call sckdec
        pop hl
        ld (hl),0
        pop bc
netres2 ld de,sckdatlen
        add hl,de
        djnz netres1
        xor a
        ld (dnslupflg),a
        jp prgprz0


;==============================================================================
;### SOCKET HANDLING ##########################################################
;==============================================================================

;### SCKNEW -> get new socket
;### Input      A=type (1=TCP, 2=UDP, 3=DNS), (netprcnum)=process ID
;### Output     CF=0 ok,    A=socket ID, IY=socket data record
;###            CF=1 error, A=error code
;### Destroyed  F,B,DE
scknew  ld b,a
        ld a,(net_status)
        inc a
        scf
        ret nz
        ld a,b
        ld iy,sckdatmem
        ld b,low_sockmax
        ld de,sckdatlen
scknew1 inc (iy+sckdattyp)
        dec (iy+sckdattyp)
        jr z,scknew2
        add iy,de
        djnz scknew1
        ld a,neterrsfr      ;error -> no free socket
        scf
        ret
scknew2 ld (iy+sckdattyp),a
        ld a,(netprcnum)
        ld (iy+sckdatprc),a
        ex de,hl
        ld hl,stasckcnt
        inc (hl)
        ld hl,staupdflg
        set 0,(hl)
        ex de,hl
        ld a,low_sockmax
        sub b
        ret

;### SCKGET -> get socket datarecord
;### Input      A=socket ID, C=socket type, (netprcnum)=process ID
;### Output     CF=0 ok,    IY=socket data record, A=socket ID
;###            CF=1 error, A=error code
;### Destroyed  AF,BC
sckget  cp low_sockmax
        jr nc,sckget3
        ld b,a
        push bc
        inc a
        ld bc,sckdatlen
        ld iy,sckdatmem-sckdatlen
sckget1 add iy,bc
        dec a
        jr nz,sckget1
        pop bc
        ld a,(netprcnum)
        cp (iy+sckdatprc)
        ld a,neterrspr      ;error -> wrong process id
        jr nz,sckget2
        ld a,c
        cp (iy+sckdattyp)
        ld a,b
        ret z
        ld a,neterrstp      ;error -> wrong socket type
sckget2 scf
        ret
sckget3 ld a,neterrsex      ;error -> socket not existing
        scf
        ret

;### SCKDEC -> decreases number of used sockets
;### Destroyed  ZF
sckdec  push hl
        ld hl,stasckcnt
        dec (hl)
        ld hl,staupdflg
        set 0,(hl)
        pop hl
        ret


;==============================================================================
;### TCP ROUTINES #############################################################
;==============================================================================

;### TCPOPN -> TCP open connection
;### Input      A=mode (0=client, 1=server), (netprcnum)=pID, HL=local port (,IX,IY=remote IP, DE=remote port)
;### Output     CF=0 ok,    (netscknum)=socket
;###            CF=1 error, A=error code
;### Destroyed  BC,DE,HL,IX,IY
tcpopns ds 8
tcpopn  push af
        call netprt
        pop af
        ld (tcpopns+0),hl
        ld (tcpopns+2),ix
        ld (tcpopns+4),iy
        ld (tcpopns+6),de
        ld c,a
        ld a,scktyptcp
        call scknew
        ret c
        ld (iy+sckdatlpo+0),l
        ld (iy+sckdatlpo+1),h
        dec c
        jr z,tcpopn2
        db #dd:ld e,l                   ;** client
        ld (iy+sckdatrip+0),e
        db #dd:ld e,h
        ld (iy+sckdatrip+1),e
        ld hl,(tcpopns+4)
        ld (iy+sckdatrip+2),l
        ld (iy+sckdatrip+3),h
        ld hl,(tcpopns+6)
        ld (iy+sckdatrpo+0),l
        ld (iy+sckdatrpo+1),h
        ld de,256*sckstatop+0
tcpopn1 ld (iy+sckdatsta),d
        ld ix,tcpopns
        push af
        call lowtop
        pop bc
        ret c
        ld a,b
        ld (netscknum),a
        ret
tcpopn2 ld de,256*sckstatli+1           ;** server
        jr tcpopn1

;### TCPCLO -> TCP close connection
;### Input      A=socket
;### Output     CF=0 ok
;###            CF=1 error, A=error code
;### Destroyed  BC,DE,HL,IX,IY
tcpclo  ld c,scktyptcp
        call sckget
        ret c
        ld (iy+sckdattyp),scktypfre
        call sckdec
        call lowtcl
        or a
        ret

;### TCPRCV -> TCP receive from connection
;### Input      A=socket, BC=length, E,HL=memory
;### Output     CF=0 ok,    BC=number of received bytes, HL=number of remaining bytes, ZF=1 -> no remaining bytes
;###            CF=1 error, A=error code
;### Destroyed  DE,IX,IY
tcprcv  push bc
        ld c,scktyptcp
        call sckget
        pop bc
        ret c
        ld d,a                  ;check, if connection established or higher
        ld a,(iy+sckdatsta)
        cp sckstates
        ld a,neterrtes
        ret c
        push hl
        ld l,(iy+sckdatrcv+0)
        ld h,(iy+sckdatrcv+1)
        sbc hl,bc
        jr nc,tcprcv1
        add hl,bc
        ld c,l
        ld b,h                  ;bc=min(remaining, requested)
tcprcv1 pop hl
        ld a,c:or b
        jr z,tcprcv4
        push bc
        call netdin
        push iy
        ld a,d
tcprcv2 call lowtrx
        pop iy
        ld l,c
        ld h,b
        pop bc
        ld (iy+sckdatrcv+0),l
        ld (iy+sckdatrcv+1),h
tcprcv3 ld a,l
        or h
        ret nz
        res 7,(iy+sckdatsta)    ;no data left -> reset received-flag
        ret
tcprcv4 ld l,(iy+sckdatrcv+0)
        ld h,(iy+sckdatrcv+1)
        jr tcprcv3

;### TCPSND -> TCP send to connection
;### Input      A=socket, BC=length, E,HL=memory
;### Output     CF=0 ok,    BC=number of sent bytes, HL=number of remaining bytes, ZF=1 -> all bytes have been sent
;###            CF=1 error, A=error code
;### Destroyed  BC,DE,HL,IX,IY
tcpsnd  push bc
        ld c,scktyptcp
        call sckget
        pop bc
        ret c
        ld d,a                  ;check, if connection established
        ld a,(iy+sckdatsta)
        res 7,a
        cp sckstates            ;only possible, if established
        ld a,neterrtes
        scf
        ret nz
        ld a,d
        call lowttx
        call netdou
        scf
        ccf
        ret

;### TCPDIS -> TCP disconnect connection
;### Input      A=socket
;### Output     CF=0 ok
;###            CF=1 error, A=error code
;### Destroyed  BC,DE,HL,IX,IY
tcpdis  ld c,scktyptcp
        call sckget
        ret c
        ld (iy+sckdattyp),scktypfre
        call sckdec
        call lowtdc
        or a
        ret

;### TCPSTA -> TCP status of connection
;### Input      A=socket
;### Output     CF=0 ok,    L=status (, BC=received bytes, IX,IY=remote IP, DE=remote port)
;###            CF=1 error, A=error code
;### Destroyed  BC,DE,HL,IX,IY
tcpsta  ld c,scktyptcp
        call sckget
        ret c
        ld c,(iy+sckdatrcv+0)
        ld b,(iy+sckdatrcv+1)
        ld e,(iy+sckdatrpo+0)
        ld d,(iy+sckdatrpo+1)
        ld l,(iy+sckdatrip+0)
        ld h,(iy+sckdatrip+1)
        push hl
        ld l,(iy+sckdatrip+2)
        ld h,(iy+sckdatrip+3)
        push hl
        ld l,(iy+sckdatsta)
        pop iy
        pop ix
        or a
        ret

;### TCPSKP -> TCP skip incoming data
;### Input      A=socket, BC=length
;### Output     CF=0 ok,    BC=number of skipped bytes, HL=number of remaining bytes, ZF=1 -> no remaining bytes
;###            CF=1 error, A=error code
;### Destroyed  BC,DE,HL,IX,IY
tcpskp  ld hl,lowtsk
        ld (tcprcv2+1),hl
        call tcprcv
        ld de,lowtrx
        ld (tcprcv2+1),de
        ret

;### TCPFLS -> TCP flush outgoing data
;### Input      A=socket
;### Output     CF=0 ok
;###            CF=1 error, A=error code
;### Destroyed  BC,DE,HL,IX,IY
tcpfls  call sckget
        ret c
        jp lowtfl


;==============================================================================
;### UDP ROUTINES #############################################################
;==============================================================================

;### UDPOPN -> UDP open session
;### Input      HL=local port, E=source/destination bank for receive/send
;### Output     CF=0 ok,    (netscknum)=socket
;###            CF=1 error, A=error code
;### Destroyed  BC,DE,HL,IX,IY
udpopn
if DRIVER=6
        push de                 ;e=bank
        call netprt
        ld a,scktypudp
        call scknew             ;a=socket, iy=record
        pop de
        ret c
        ld (iy+sckdatlpo+0),l
        ld (iy+sckdatlpo+1),h
        ld (iy+sckdatbnk),e
        ld (iy+sckdatsta),3     ;idle
        ld (iy+sckdatrcv+0),0
        ld (iy+sckdatrcv+1),0
        ld (udpopns),hl
        push iy
        push af
        ld ix,udpopns
        call lowuop
        pop bc
        pop iy
        jr c,udpopn1
        ld a,b
        ld (netscknum),a
        or a
        ret
udpopn1 ld (iy+sckdattyp),scktypfre     ;the ESP refused it, give the socket back
        call sckdec
        scf
        ret
udpopns dw 0
else
        ;...
        ret
endif

;### UDPCLO -> UDP close session
;### Input      A=socket
;### Output     CF=0 ok
;###            CF=1 error, A=error code
;### Destroyed  BC,DE,HL,IX,IY
udpclo  ld c,scktypudp
        call sckget
        ret c
        ld (iy+sckdattyp),scktypfre
        call sckdec
        call lowucl
        or a
        ret

;### UDPSTA -> UDP status of session
;### Input      A=socket
;### Output     CF=0 ok,    L=status (, BC=received bytes, IX,IY=remote IP, DE=remote port)
;###            CF=1 error, A=error code
;### Destroyed  BC,DE,HL,IX,IY
udpsta
if DRIVER=6
        ld c,scktypudp
        call sckget
        ret c
        ld c,(iy+sckdatrcv+0)
        ld b,(iy+sckdatrcv+1)
        ld e,(iy+sckdatrpo+0)
        ld d,(iy+sckdatrpo+1)
        ld l,(iy+sckdatrip+2)
        ld h,(iy+sckdatrip+3)
        push hl
        ld l,(iy+sckdatrip+0)
        ld h,(iy+sckdatrip+1)
        push hl
        ld l,(iy+sckdatsta)
        pop ix
        pop iy
        or a
        ret
else
        ;...
        ret
endif

;### UDPRCV -> UDP receive data package
;### Input      A=socket, HL=memory
;### Output     CF=0 ok
;###            CF=1 error, A=error code
;### Destroyed  BC,DE,HL,IX,IY
udprcv
if DRIVER=6
        push hl                 ;destination
        ld c,scktypudp
        call sckget             ;iy=record, a=socket
        pop hl
        ret c
        bit 7,(iy+sckdatsta)    ;ZF=1 means nothing is waiting
        ld d,a                  ;d=socket
        ld a,neterrtes
        scf
        ret z
        ld c,(iy+sckdatrcv+0)
        ld b,(iy+sckdatrcv+1)
        ld e,(iy+sckdatbnk)
        call netdin
        push iy
        ld a,d
        call lowurx             ;a=socket, bc=length, e=bank, hl=destination
        pop iy
        ld (iy+sckdatrcv+0),0
        ld (iy+sckdatrcv+1),0
        res 7,(iy+sckdatsta)
        or a
        ret
else
        ;...
        ret
endif

;### UDPSND -> UDP send data package
;### Input      A=socket, HL=memory, BC=length
;### Output     CF=0 ok
;###            CF=1 error, A=error code
;### Destroyed  BC,DE,HL,IX,IY
udpsnd
if DRIVER=6
        ld (udpsnds+0),ix       ;destination, 4 bytes IP and 2 bytes port
        ld (udpsnds+2),iy
        ld (udpsnds+4),de
        push bc
        push hl
        ld c,scktypudp
        call sckget             ;iy=record, a=socket
        pop hl
        pop bc
        ret c
        ld e,(iy+sckdatbnk)
        ld ix,udpsnds
        push bc
        call lowutx             ;a=socket, hl=data, e=bank, bc=length, ix=destination
        pop bc
        ret c
        call netdou
        or a
        ret
udpsnds ds 6
else
        ;...
        ret
endif

;### UDPSKP -> UDP skip incoming data
;### Input      A=socket
;### Output     CF=0 ok
;###            CF=1 error, A=error code
;### Destroyed  BC,DE,HL,IX,IY
udpskp
if DRIVER=6
        ld c,scktypudp
        call sckget
        ret c
        push iy
        call lowusk
        pop iy
        ld (iy+sckdatrcv+0),0
        ld (iy+sckdatrcv+1),0
        res 7,(iy+sckdatsta)
        or a
        ret
else
        ;...
        ret
endif


;==============================================================================
;### DNS ROUTINES #############################################################
;==============================================================================

dnslupflg   db 0    ;1=dns lookup in process

if DRIVER=0             ;*** local host (dummy)

dnsrsv  ld ix,127
        ld iy,1*256
        or a
dnsrqs
dnsrqr
        ret

else

;### DNSRSV -> resolve domain name
;### Input      E,HL=domain name string (dot separated, 0-terminated)
;### Output     (only, if direct IP address) CF=0, IX,IY=IP address
dnsrsv  push de
        push hl
        call dnsvfy
        ld a,l
        pop hl
        pop de
        cp 1
        ret z
        jr nc,dnsrsv1
        scf
        ld a,neterrdiv
        ret
dnsrsv1 ld a,scktypdns
        ld c,e
        call scknew                 ;new socket for DNS request
        ret c
        ld (iy+sckdatbnk+0),c       ;save data and status
        ld (iy+sckdatbnk+1),l
        ld (iy+sckdatbnk+2),h
        ld (iy+sckdatsta),sckstadrq
        pop hl                      ;skip return to NETCMD, answer message will be sent later when DNSRQR has been proceeded
        ret

if DRIVER=6         ;*** HIGH LEVEL BASED for ESP8266 UNAPI firmware (see Dmn-Network-ESP.asm)

;### DNSRQS -> send DNS request
;### Input      HL=domain name string (dot separated, 0-terminated), A=socket
dnsrqse db 0        ;error flag
dnsrqs  call espdns
        ld a,neterrdto
        jr c,dnsrqs1
        xor a
dnsrqs1 ld (dnsrqse),a
        ret

;### DNSRQR -> check for DNS resolve
;### Output     CF=0 -> IP received, IX,IY=IP ; CF=1 -> A=status (0=in progress, >0=error)
dnsrqr  ld a,(dnsrqse)
        or a
        scf
        ret nz
        jp espdnr

elseif M4BOARD=1    ;*** HIGH LEVEL BASED (using external function) for M4Board

;### DNSRQS -> send DNS request
;### Input      HL=domain name string (dot separated, 0-terminated), A=socket
;### Destroyed  AF,BC,DE,HL,IX,IYH
dnsrqs  ld de,pck_buffer+3
        ld bc,256
        ldir
        call m4cdns
        jr c,dnsrqs1
        xor a
dnsrqs1 ld (dnsrqse),a
        ret

;### DNSRQR -> check for DNS resolve
;### Input      DNSRQS has been called before
;### Output     CF=0 -> IP received, IX,IY=IP
;###            CF=1 -> A=status (0=still in progress, >0=error)
;### Destroyed  AF,BC,DE,HL,IX,IY
dnsrqse db 0        ;error flag

dnsrqr  ld a,(dnsrqse)
        or a
        scf
        ret nz
        jp m4cdnr

else                    ;*** LOW LEVEL BASED (using UDP)

dns_server_prt  equ 53      ;server port
dns_client_prt  equ 68      ;client port
dns_timeout     equ 50*3    ;timeout for dns request (3 seconds)

dns_id          dw #1234

;### DNSCNV -> convert domain name string into the DNS packet format
;### Input      HL=domain name string (dot separated, 0-terminated), DE=destination buffer
;### Output     DE=behind last byte
;### Destroyed  AF,C,HL,IX
dnscnv  ld a,(hl)
        or a
        jr z,dnscnv4
dnscnv1 ld c,0
        push de
        pop ix
        inc de
dnscnv2 ld a,(hl)
        inc hl
        cp "."
        jr z,dnscnv3
        or a
        jr z,dnscnv3
        call clcucs
        ld (de),a
        inc de
        inc c
        jr dnscnv2
dnscnv3 ld (ix+0),c
        or a
        jr nz,dnscnv1
dnscnv4 ld (de),a
        inc de
        ret

;### DNSGPK -> generate DNS request packet
;### Input      HL=domain name string (dot separated, 0-terminated)
;### Output     (pck_buffer)=DNS request packet, BC=packet length
;### Destroyed  AF,BC,DE,HL,IX
dnsgpk  ld de,pck_buffer+12
        call dnscnv
        ex de,hl
        ld (hl),0:inc hl
        ld (hl),1:inc hl
        ld (hl),0:inc hl
        ld (hl),1:inc hl
        ld bc,pck_buffer
        or a
        sbc hl,bc
        ld c,l
        ld b,h                  ;bc=packet length
        ld hl,#0100             ;MSB -> one entry for QD
        ld (pck_buffer+4),hl    ;qdcount
        ld hl,0
        ld (pck_buffer+6),hl    ;ancount
        ld (pck_buffer+8),hl    ;nscount
        ld (pck_buffer+10),hl   ;arcount
        ld hl,(dns_id)
        inc hl
        ld (dns_id),hl
        ld (pck_buffer+0),hl    ;identifier
        ld hl,#0001             ;MSB -> bit8=1 (Recursion Desired)
        ld (pck_buffer+2),hl    ;flags
        ret

;### DNSGIP -> get IP address from resource record
;### Input      IX=zone data, BC=number or resource records
;### Output     IX=next zone
;###            CF=0 ok, (dnsgipadr)=first IP, CF=1 no IP included
;### Destroyed  AF,BC,DE,HL,IYL
dnsgipadr   ds 4

dnsgip  db #fd:ld l,0           ;found = 0
dnsgip1 ld a,(ix+0)             ;skip name
        inc ix
        or a
        jr z,dnsgip2
        bit 7,a
        jr z,dnsgip1
        inc ix                  ;skip 2nd compression byte
dnsgip2 db #fd:inc l
        db #fd:dec l
        jr nz,dnsgip3           ;we already have an IP -> skip record
        ld h,(ix+0)
        ld l,(ix+1)
        ld de,1
        or a
        sbc hl,de
        jr nz,dnsgip3           ;not an IP address -> skip record
        ld l,(ix+10)            ;IP found, get it
        ld h,(ix+11)
        ld (dnsgipadr+0),hl
        ld l,(ix+12)
        ld h,(ix+13)
        ld (dnsgipadr+2),hl
        db #fd:inc l            ;found = 1
dnsgip3 ld h,(ix+8)
        ld l,(ix+9)
        ld de,10
        add hl,de
        ex de,hl
        add ix,de
        dec bc
        ld a,c
        or b
        jr nz,dnsgip1
        db #fd:dec l
        ret z
        scf
        ret

;### DNSRQS -> send DNS request
;### Input      HL=domain name string (dot separated, 0-terminated), A=socket
;### Destroyed  AF,BC,DE,HL,IX,IYH
dnsrqsprt   dw dns_client_prt
dnsrqssrv   ds 4:dw dns_server_prt
dnsrqstim   dw 0                    ;timeout counter
dnsrqssck   db 0                    ;socket

dnsrqs  ld (dnsrqssck),a
        push af
        call dnsgpk
        pop af
        push bc
        ld ix,dnsrqsprt
        call lowuop
        pop bc
        ld hl,dns_timeout
        ld (dnsrqstim),hl
dnsrqs1 ld hl,net_dnspri
        ld de,dnsrqssrv
        push bc
        ld bc,4
        ldir
        pop bc
        ld hl,pck_buffer
        ld a,(App_BnkNum)
        ld e,a
        ld ix,dnsrqssrv
        push bc
        ld a,(dnsrqssck)
        call lowutx         ;A=socket number (0-3), HL=source address, E=source bank, BC=length, IX=structure (4byte destination IP, 2byte destination port])
        pop bc
        ret nc
        rst #30             ;send buffer full, wait until it's empty
        jr dnsrqs1

;### DNSRQR -> check for DNS resolve
;### Input      DNSRQS has been called before
;### Output     CF=0 -> IP received, IX,IY=IP
;###            CF=1 -> A=status (0=still in progress, >0=error)
;### Destroyed  AF,BC,DE,HL,IX,IY
dnsrqr  ld a,(dnsrqssck)
        call lowust         ;A=status (0=in process, 3=idle, +128=data received [BC=received bytes, IX,IY=remote IP, DE=remote port])
        bit 7,a
        jr nz,dnsrqr2
dnsrqr1 ld hl,(dnsrqstim)
        dec hl
        ld (dnsrqstim),hl
        ld a,l
        or h
        ld a,0
        scf
        ret nz
        ld a,neterrdto
        ret

dnsrqr8 ld a,neterrdln
        scf
        ret
dnsrqr2 ld a,b                  ;*** check package length (<=576)
        cp 2
        jr c,dnsrqr7
        jr nz,dnsrqr8
        ld a,c
        cp 576-512+1
        jr nc,dnsrqr8
dnsrqr7 ld a,e                  ;*** check sender port (53)
        cp 53
        jr z,dnsrqr9
        inc d:dec d
        jr z,dnsrqr9
        ld a,(dnsrqssck)    ;wrong port -> skip this packet
        call lowusk
        xor a
        scf
        ret

dnsrqr9 ld a,(App_BnkNum)
        ld e,a
        ld hl,pck_buffer
        push bc
        ld a,(dnsrqssck)
        call lowurx
        pop bc
        ld hl,(pck_buffer+0)    ;*** check FLAGS
        ld de,(dns_id)
        or a
        sbc hl,de
        jr nz,dnsrqr1       ;wrong ID -> ignore this packet
        ld hl,(pck_buffer+2)
        bit 1,l
        jr nz,dsnrqr5       ;truncated -> cancel or 2nd DNS
        ld a,h
        and #0f
        jr nz,dsnrqr5       ;error code -> cancel or 2nd DNS
        ld hl,pck_buffer+12     ;*** skip QD (query) section
dnsrqr3 ld a,(hl)
        inc hl
        or a
        jr z,dnsrqr4        ;0 -> end reached
        bit 7,a
        jr z,dnsrqr3
        inc hl              ;compression -> skip word
dnsrqr4 ld de,4
        add hl,de           ;skip QTYPE and QCLASS
        push hl:pop ix          ;*** check answer
        ld bc,(pck_buffer+6)
        ld a,c:ld c,b:ld b,a
        or c
        jr z,dnsrqr6        ;no answer section -> check for recursive DNS server
        call dnsgip
        jr c,dnsrqr6        ;no IP found -> check for recursive DNS server
        ld ix,(dnsgipadr+0)
        ld iy,(dnsgipadr+2)
        ret
dnsrqr6 ;...                    ;*** check for recursive DNS servers in NS/AR
        ld a,neterrdrc
        scf
        ret
dsnrqr5 ;...                    ;*** error/2nd DNS
        ld a,neterrdtr
        scf
        ret
endif
endif

;### DNSVFY -> verify domain name
;### Input      E,HL=domain name string (dot separated, 0-terminated)
;### Output     L=type (0=no valid address, 1=IP address [IX,IY], 2=domain address)
;### Destroyed  F,BC,DE,HL
dnsvfyb ds 4
dnsvfy  ld a,(App_BnkNum)
        add a:add a:add a:add a
        add e
        ld de,pck_buffer
        ld bc,256
        push de
        rst #20:dw jmp_bnkcop       ;copy domain name string to own buffer
        pop hl              ;hl=source string
        ld ix,dnsvfyb       ;ix=destination IP
        ld c,0              ;c=number of parts
dnsvfy2 call dnssub
        ld a,0
        jr c,dnsvfy1
        push af
        dec e
        jr z,dnsvfy4
        inc c
        ld a,c
        cp 5
        jr nc,dnsvfy3
        ld (ix+0),d
        inc ix
dnsvfy3 pop af
        jr nz,dnsvfy2
        ld a,c
        cp 4
        ld a,2
        jr nz,dnsvfy1
        dec a
        ld ix,(dnsvfyb+0)
        ld iy,(dnsvfyb+2)
dnsvfy1 ld l,a
        or a
        ret
dnsvfy4 ld c,5              ;no number -> set invalid number of parts (>4)
        jr dnsvfy3

;### DNSSUB -> analyse dot-separated sub-part of a domain string
;### Input      HL=string
;### Output     CF=0 ok,    E=type (0=number [D], 1=string), HL=next substring, ZF=1 end
;###            CF=1 invalid string
;### Destroyed  AF,D,B
dnssub  ld a,(hl)
        or a
        scf                 ;emtpy -> invalid
        ret z
        cp "."
        scf
        ret z
        ld de,0             ;d=number, e=flag if string
dnssub1 ld a,(hl)
        inc hl
        or a
        ret z
        cp "."
        jr nz,dnssub4
        or a
        ret
dnssub4 cp "0"
        jr c,dnssub2
        cp "9"+1
        jr nc,dnssub2
        sub "0"
        ld b,a
        ld a,d
        cp 26
        jr nc,dnssub3
        add a:add a
        add d
        add a
        jr c,dnssub3
        add b
        jr c,dnssub3
        ld d,a
        jr dnssub1
dnssub2 call clcucs
        cp "-"
        jr z,dnssub3
        cp "A"
        ret c
        cp "Z"+1
        ccf                 ;no number and no valid string
        ret c
dnssub3 ld e,1              ;no number -> set string flag
        jr dnssub1


;==============================================================================
;### DHCP ROUTINES ############################################################
;==============================================================================

if DRIVER=0
dhcbeg  ret
dhcpol  ld a,-1
        jp netini0

elseif DRIVER=6
dhcbeg  ret             ;ESP does DHCP
dhcpol  ld a,-1
        jp netini0
elseif M4BOARD=1
dhcbeg  ret             ;##!!##
dhcpol  ld a,-1
        jp netini0
else

dhcp_discover   equ 1
dhcp_offer      equ 2
dhcp_request    equ 3
dhcp_ack        equ 5
dhcp_nak        equ 6

;DHCP options
dopt_msgtype    equ 53

dopt_maxsize    equ 57
dopt_reqparams  equ 55
dopt_clientip   equ 50
dopt_serverip   equ 54
dopt_subnetmsk  equ 1
dopt_router     equ 3
dopt_dnsserver  equ 6
dopt_hostname   equ 12

dopt_optoverld  equ 52
dopt_pad        equ 0
dopt_end        equ 255

dhcdatser   ds 4                ;DHCP server IP
dhcdatcli   ds 4                ;new client IP
dhcdatxid   db #00,#11,#22,#33

dhcipcini   ds 3*4              ;empty IP/subnet/gateway

dhccliprt   dw  68              ;client port
dhcsrvprt   equ 67              ;server port
dhcsrvdat   db 255,255,255,255  ;broadcast address
            dw dhcsrvprt

;### DHCBEG -> start DHCP procedure
dhcbeg  ld a,1
        ld (dhcpolr),a
dhcbeg0 ld a,r
        ld (dhcdatxid),a
        ld hl,50*10
        ld (dhcpolt),hl
        ld a,2
        ld hl,dhcipcini
        call lowini
        xor a
        ld (dhcpols),a
        ld ix,dhccliprt
        call lowuop0
        ld a,dhcp_discover      ;send "discover" packet
        jp nc,dhcpak
jp dhcpak   ;...error here


;### DHCPOL -> polls DHCP server answers
dhcpols db 0    ;0=discover, 1=request
dhcpolt dw 0    ;timeout counter
dhcpolr db 0    ;retry flag

dhcpol  xor a
        call lowust             ;test, if data received
        bit 7,a
        jr nz,dhcpol1
        ld hl,(dhcpolt)
        dec hl
        ld (dhcpolt),hl
        ld a,l
        or h
        ret nz
        ld hl,dhcpolr
        bit 0,(hl)
        ld (hl),0
        jr nz,dhcbeg0           ;try again
        jp dhcpol7              ;timeout
dhcpol1 inc d                   ;test, if sender uses port 67 (dhcp server)
        dec d
        jr nz,dhcpol2
        ld a,e
        cp dhcsrvprt
        jr z,dhcpol3
dhcpol2 xor a                   ;no -> skip packet
        call w51usk
        jr dhcpol
dhcpol3 xor a                   ;get packet
        ld hl,pck_buffer
        ld de,(App_BnkNum)
        push hl
        push bc
        call lowurx
        pop bc
        pop hl
        add hl,bc
        ld (hl),255             ;add terminator
        ld a,(dhcpols)
        or a
        ld e,dopt_msgtype
        jr nz,dhcpol4
        call dhcopt                 ;*** DHCP_DISCOVER has been send -> check for DHCP_OFFER
        jr c,dhcpol
        ld a,(hl)
        cp dhcp_offer
        jr nz,dhcpol            ;wrong packet, check next one
        ld e,dopt_serverip
        call dhcopt
        jr c,dhcpol             ;no server IP included -> strange packet
        ld de,dhcdatser
        ld bc,4
        ldir                    ;get server IP
        ld hl,pck_buffer+016
        ld de,dhcdatcli
        ld c,4
        ldir                    ;get client IP
        ld hl,pck_buffer+004
        ld de,dhcdatxid
        ld c,4
        ldir                    ;get xid (??)
        ld a,1
        ld (dhcpols),a
        ld a,dhcp_request       ;send "request packet"
        jp dhcpak
dhcpol4 call dhcopt                 ;*** DHCP_REQUEST has been send -> check for DHCP_ACK or DHCP_NAK
        jp c,dhcpol
        ld a,(hl)
        cp dhcp_nak
        jr z,dhcpol7
        cp dhcp_ack
        jp nz,dhcpol            ;wrong packet, check next one
        ld hl,pck_buffer+016
        ld de,net_ipaadr
        ld c,4
        ldir                    ;get IP
        ld e,dopt_subnetmsk
        call dhcopt
        jr c,dhcpol7
        ld de,net_ipasbn
        ld bc,4
        ldir                    ;get subnet mask
        ld e,dopt_router
        call dhcopt
        jr c,dhcpol7
        ld de,net_ipagat
        ld bc,4
        ldir                    ;get gateway
        ld a,(cfg_dnstyp)
        or a
        jr nz,dhcpol6
        ld e,dopt_dnsserver
        call dhcopt
        jr c,dhcpol6
        ld a,c
        cp 8+1
        jr c,dhcpol5
        ld c,8
dhcpol5 ld b,0
        ld de,net_dnspri
        ldir                    ;get DNS
dhcpol6 ld a,2
        ld hl,net_ipaadr
        call lowini
        call cfgipr
        ld a,-1
        jr dhcpol8
dhcpol7 ld a,3                      ;*** error
dhcpol8 jp netini0

;### DHCPAK -> prepares and sends a DHCP package
;### Input      A=type
;### Output     (pck_buffer)=packet, BC=length
;### Destroyed  AF,DE,HL
dhcdatcok   db #63,#82,#53,#63
            db dopt_msgtype,1               ;option 53 -> DHCP Message Type
dhcdatopt   db dopt_maxsize,2, 2,64         ;option 57 -> Maximum DHCP Message Size (576)
            db dopt_reqparams,3             ;option 55 -> Parameter Request List (1=Subnet Mask, 3=Router [gateway], 6=Domain Name Server)
            db dopt_subnetmsk,dopt_router,dopt_dnsserver

;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@               addition by d_kef                                            @
            db dopt_hostname                ;option 12
dhchstnlen  db 0                            ;Host name length
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
			
dhcpak  ld (pck_buffer+242),a       ;set message type
        ld hl,#0101                 ;set op,htype,hlen,hops
        ld (pck_buffer+000),hl
        ld hl,#0006
        ld (pck_buffer+002),hl
        ld hl,dhcdatxid             ;set xid
        ld de,pck_buffer+004
        ld bc,4
        ldir
        ld hl,(net_timsec)          ;set seconds
        ld c,l
        ld l,h
        ld h,c
        ld (pck_buffer+008),hl
	ld hl,#0080                 ;set flags
	ld (pck_buffer+010),hl
        ld hl,pck_buffer+012        ;clear remaining packet bytes
        ld de,pck_buffer+012+1
        ld c,32+192-1
        ld (hl),0
        ldir
        ld hl,cfg_macadr            ;set hardware (mac) address
        ld de,pck_buffer+28
        ld c,6
        ldir
        ld hl,dhcdatcok             ;set magic cookie and first option (message type)
        ld de,pck_buffer+236
        ld c,4+2
        ldir
        inc de
        cp dhcp_discover
        jr z,dhcpak1
        ld hl,4*256+dopt_clientip   ;"request" -> set server and client IPs
        ld (pck_buffer+243+0),hl
        ld hl,4*256+dopt_serverip
        ld (pck_buffer+243+6),hl
        ld hl,dhcdatcli
        ld de,pck_buffer+243+2
        ld c,4
        ldir
        ld hl,dhcdatser
        ld de,pck_buffer+020
        ld c,4
        push hl
        ldir
        pop hl
        ld de,pck_buffer+243+2+6
        ld c,4
        ldir

;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@               addition by d_kef                                            @
        ld hl,cfg_hstnam
        ld c,0
dhcpak3 ld a,c
        ld (dhchstnlen),a
        ld a,(hl)                   ;check if hostname is set
        cp 0
        jr z,dhcpak1
        inc c
        inc hl
        jr dhcpak3
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


dhcpak1 ld hl,dhcdatopt             ;set options (Maximum DHCP Message Size, Parameter Request List)
        ld c,4+5

;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@               addition by d_kef                                            @
;       ldir
        ld a,(dhchstnlen)           ;check if hostname is set
        cp 0
        jr z,dhcpak4
        inc c                       ;include option 12 and length
        inc c
        ldir
        ld hl,cfg_hstnam            ;include hostname 
        ld a,(dhchstnlen)
        ld c,a
dhcpak4 ldir
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

        ld a,(cfg_dnstyp)
        or a
        jr z,dhcpak2
        dec de                      ;manual DNS setup -> remove option 6
        ld l,e
        ld h,d
        dec hl:dec hl:dec hl
        ld (hl),2
dhcpak2 ex de,hl
        ld (hl),dopt_end
        inc hl
        ld de,pck_buffer
        sbc hl,de
        ld c,l
        ld b,h                      ;BC=packet length
        xor a
        ex de,hl
        ld de,(App_BnkNum)
        ld ix,dhcsrvdat
        jp lowutx

;### DHCOPT -> searches for a special option
;### Input      E=option ID, (pck_buffer)=packet (terminated by 255)
;### Output     CF=0 option found -> C=length, HL=data pointer
;###            CF=1 option not found
;### Destroyed  AF,B
dhcopto db 0    ;overload flags (bit0=file[108], bit 4=sname[44])

dhcopt  ld hl,pck_buffer+240
        xor a
        ld (dhcopto),a
        ld b,a
dhcopt1 ld a,(hl)           ;A=option code
        inc hl
        or a
        jr z,dhcopt1        ;pad
        ld c,(hl)
        inc hl
        cp e
        ret z
        cp dopt_optoverld   ;option overload
        jr z,dhcopt3
        inc a               ;end (255)
        jr z,dhcopt4
dhcopt2 add hl,bc
        jr dhcopt1
dhcopt3 ld a,(hl)
        ld (dhcopto),a
        jr dhcopt2
dhcopt4 ld hl,dhcopto
        bit 0,(hl)
        res 0,(hl)
        ld hl,pck_buffer+108
        jr nz,dhcopt1
        ld hl,dhcopto
        bit 4,(hl)
        res 4,(hl)
        ld hl,pck_buffer+044
        jr nz,dhcopt1
        or a
        ret

endif


;==============================================================================
;### CONFIG ROUTINES ##########################################################
;==============================================================================

if DRIVER=0
cfgdatids   db "Localhost":         ds 32-9         ;ID string
cfgdatver   db 0,1                                  ;minor, major
elseif DRIVER=1
cfgdatids   db "DenYoNet MSX W5100":ds 32-18
cfgdatver   db 0,1
elseif DRIVER=2
cfgdatids   db "GR8NET MSX W5100":  ds 32-16
cfgdatver   db 0,1
elseif DRIVER=3
cfgdatids   db "M4 CPC ESP8266":    ds 32-14
cfgdatver   db 1,0
elseif DRIVER=4
cfgdatids   db "Net4CPC W5100S":    ds 32-14
cfgdatver   db 0,1
elseif DRIVER=5
cfgdatids   db "M4 EP ESP8266":     ds 32-13
cfgdatver   db 1,0
elseif DRIVER=6
cfgdatids   db "ESP8266 UNAPI PicoVerse":ds 32-23
cfgdatver   db 0,1
endif

cfgadr  dw cfgdatids,32+2

cfgadrmax   equ 1

;### CFGGET -> get config data
;### Input      A=type, E,HL=data buffer
;### Output     CF=1 -> invalid type
;### Destroyed  AF,BC,DE,HL,IX,IYH
cfgget  call cfgset1
        ret c
        ex de,hl
        rlca:rlca:rlca:rlca
        jr cfgset0

;### CFGSET -> set config data
;### Input      A=type, E,HL=config data
;### Output     CF=1 -> invalid type
;### Destroyed  AF,BC,DE,HL,IX,IYH
cfgset  or a
        scf
        ret z
        call cfgset1
        ret c
cfgset0 rst #20:dw jmp_bnkcop
        or a
        ret
cfgset1 cp cfgadrmax
        ccf
        ret c
        add a:add a
        ld c,a
        ld b,0
        ld ix,cfgadr
        add ix,bc
        ld a,(App_BnkNum)
        add a:add a:add a:add a
        add e                   ;a=source/destination bank
        ld e,(ix+0)
        ld d,(ix+1)             ;de=destination
        ld c,(ix+2)
        ld b,0                  ;bc=length
        ret

;### CFGSCK -> get socket status
;### Input      A=first socket, C=number of sockets, E,HL=destination
;### Destroyed  AF,BC,DE,HL,IX,IYH
cfgsck  ld b,a
        add c
        cp low_sockmax+1
        ccf
        ret c
        inc c
        dec c
        ret z
        ld d,e
        push hl
        push de
        ld hl,sckdatmem-sckdatlen
        ld de,sckdatlen
        inc b
cfgsck1 add hl,de
        djnz cfgsck1
        ex de,hl        ;de=start
        ld a,c
        ld c,l
        ld b,h
        ld hl,0
cfgsck2 add hl,bc
        dec a
        jr nz,cfgsck2
        ld c,l
        ld b,h          ;bc=length
        pop af
        add a:add a:add a:add a
        ld hl,App_BnkNum
        add (hl)        ;a=source/dest bank
        ex de,hl        ;hl=start
        pop de          ;de=destination
        jp cfgset0


;==============================================================================
;### SUB ROUTINES #############################################################
;==============================================================================

;### STRINP -> Initialisiert Textinput (abhängig vom String, den es bearbeitet)
;### Eingabe    IX=Control
;### Ausgabe    HL=Stringende (0), BC=Länge (maximal 255)
;### Verändert  AF
strinp  ld l,(ix+0)
        ld h,(ix+1)
        call strlen
        ld (ix+8),c
        ld (ix+4),c
        xor a
        ld (ix+2),a
        ld (ix+6),a
        ret

;### STRLEN -> Ermittelt Länge eines Strings
;### Eingabe    HL=String (0-terminiert)
;### Ausgabe    HL=Stringende (0), BC=Länge (maximal 255, ohne Terminator)
;### Verändert  -
strlen  push af
        xor a
        ld bc,255
        cpir
        ld a,254
        sub c
        ld c,a
        dec hl
        pop af
        ret

SySystem_HLPFLG db 0    ;flag, if HLP-path is valid
SySystem_HLPPTH db "%help.exe "
SySystem_HLPPTH1 ds 128
SySHInX db ".HLP",0

SySystem_HLPINI
        ld hl,(App_BegCode)
        ld de,App_BegCode
        dec h
        add hl,de                   ;HL = CodeEnd = Command line
        ld de,SySystem_HLPPTH1
        ld bc,0
        db #dd:ld l,128
SySHIn1 ld a,(hl)
        or a
        jr z,SySHIn3
        cp " "
        jr z,SySHIn3
        cp "."
        jr nz,SySHIn2
        ld c,e
        ld b,d
SySHIn2 ld (de),a
        inc hl
        inc de
        db #dd:dec l
        ret z
        jr SySHIn1
SySHIn3 ld a,c
        or b
        ret z
        ld hl,-4
        add hl,bc
        ex de,hl
        ld hl,SySHInX
        ld bc,5
        ldir
        ld a,1
        ld (SySystem_HLPFLG),a
        ret

SySystem_HLPOPN
        ld a,(SySystem_HLPFLG)
        or a
        ret z
        ld hl,SySystem_HLPPTH
        ld a,(App_BnkNum)
        jp SySystem_PRGRUN

;### CLCUCS -> Change letters to uppercase
;### Input      A=char
;### Output     A=ucase(char)
;### Destroyed  F
clcucs  cp "a"
        ret c
        cp "z"+1
        ret nc
        add "A"-"a"
        ret

;### CLCN08 -> Converst 8bit number into ASCII string (0-terminated)
;### Input      A=Value, HL=Destination
;### Output     HL=points behind last digit
;### Destroyed  AF,BC
clcn08  cp 10
        jr c,clcn082
        cp 100
        jr c,clcn081
        ld c,100
        call clcn083
clcn081 ld c,10
        call clcn083
clcn082 add "0"
        ld (hl),a
        inc hl
        ld (hl),0
        ret
clcn083 ld b,"0"-1
clcn084 sub c
        inc b
        jr nc,clcn084
        add c
        ld (hl),b
        inc hl
        ret

;### CLCN32 -> Converts 32Bit number into ASCII string (0-terminated)
;### Input      DE,IX=value, IY=address
;### Output     IY=address of last char
;### Veraendert AF,BC,DE,HL,IX,IY
clcn32t dw 1,0,     10,0,     100,0,     1000,0,     10000,0
        dw #86a0,1, #4240,#f, #9680,#98, #e100,#5f5, #ca00,#3b9a
clcn32z ds 4

clcn32  ld (clcn32z),ix
        ld (clcn32z+2),de
        ld ix,clcn32t+36
        ld b,9
        ld c,0
clcn321 ld a,"0"
        or a
clcn322 ld e,(ix+0):ld d,(ix+1):ld hl,(clcn32z):  sbc hl,de:ld (clcn32z),hl
        ld e,(ix+2):ld d,(ix+3):ld hl,(clcn32z+2):sbc hl,de:ld (clcn32z+2),hl
        jr c,clcn325
        inc c
        inc a
        jr clcn322
clcn325 ld e,(ix+0):ld d,(ix+1):ld hl,(clcn32z):  add hl,de:ld (clcn32z),hl
        ld e,(ix+2):ld d,(ix+3):ld hl,(clcn32z+2):adc hl,de:ld (clcn32z+2),hl
        ld de,-4
        add ix,de
        inc c
        dec c
        jr z,clcn323
        ld (iy+0),a
        inc iy
clcn323 djnz clcn321
        ld a,(clcn32z)
        add "0"
        ld (iy+0),a
        ld (iy+1),0
        ret

;### CLCHEX -> Converts 8bit value into hex string
;### Input      A=value, (DE)=string
;### Output     DE=DE+2
;### Destroyed  F,C
clchex  ld c,a          ;a=number -> (DE)=hexdigits, DE=DE+2
        rlca:rlca:rlca:rlca
        call clchex1
        ld a,c
clchex1 and 15
        add "0"
        cp "9"+1
        jr c,clchex2
        add "A"-"9"-1
clchex2 ld (de),a
        inc de
        ret

;### CLCHXB -> converts HEX string into value
;### Input      HL=hex string (L=16er, H=1er or L=1er, H=0)
;### Output     CF=1 -> invalid value, CF=0 -> A=value
;### Destroyed  HL
clchxb  ld a,l
        call clchxb0
        ret c
        inc h
        dec h
        ret z
        ld l,a
        ld a,h
        call clchxb0
        ret c
        ld h,a
        ld a,l
        add a:add a:add a:add a
        add h
        ret
clchxb0 call clcucs
        cp "9"+1
        jr nc,clchxb1
        sub "0"
        ret
clchxb1 cp "A"
        ret c
        cp "Z"+1
        ccf
        ret c
        sub "A"-10
        ret


;==============================================================================
;### DATA AREA ################################################################
;==============================================================================

low_bufadr  db 0    ;!!last in code area!!

App_BegData

;icon !!first in data area!!
prgicn16c   db 12,24,24:dw $+7:dw $+4,12*24:db 5
db #66,#55,#55,#55,#55,#55,#55,#56,#66,#66,#66,#66,#65,#dd,#dd,#dd,#dd,#dd,#d8,#51,#63,#33,#33,#16,#58,#88,#88,#88,#88,#88,#85,#51,#33,#d8,#d3,#13,#58,#d1,#11,#11,#11,#11,#d5,#51,#83,#d8,#d3,#18
db #58,#d1,#44,#44,#44,#48,#d5,#51,#13,#d8,#d3,#11,#58,#d1,#44,#44,#44,#48,#d5,#51,#61,#11,#11,#16,#58,#d1,#44,#44,#44,#48,#d5,#51,#66,#63,#81,#66,#58,#d1,#44,#44,#44,#55,#55,#55,#55,#55,#55,#56
db #58,#d1,#88,#88,#85,#dd,#dd,#dd,#dd,#dd,#d8,#51,#58,#dd,#dd,#dd,#58,#88,#88,#88,#88,#88,#85,#51,#55,#55,#55,#55,#58,#d1,#11,#11,#11,#11,#d5,#51,#11,#11,#11,#11,#58,#d1,#44,#44,#44,#48,#d5,#51
db #58,#88,#88,#88,#58,#d1,#44,#44,#44,#48,#d5,#51,#58,#dd,#dd,#11,#58,#d1,#44,#44,#44,#48,#d5,#51,#58,#da,#dd,#dd,#58,#d1,#44,#44,#44,#48,#d5,#51,#55,#55,#55,#55,#58,#d1,#88,#88,#88,#88,#d5,#51
db #11,#11,#11,#11,#58,#dd,#dd,#dd,#dd,#dd,#d5,#51,#66,#63,#81,#66,#55,#55,#55,#55,#55,#55,#55,#15,#63,#33,#33,#16,#11,#11,#11,#11,#11,#11,#11,#51,#33,#d8,#d3,#15,#58,#88,#88,#88,#88,#88,#85,#51
db #83,#d8,#d3,#18,#58,#dd,#dd,#d1,#11,#11,#d5,#51,#13,#d8,#d3,#11,#58,#da,#dd,#dd,#d5,#dd,#d5,#51,#61,#11,#11,#16,#55,#55,#55,#55,#55,#55,#55,#16,#66,#66,#66,#66,#11,#11,#11,#11,#11,#11,#11,#66

prgicn16c2  db 12,24,24:dw $+7:dw $+4,12*24:db 5
db #88,#77,#77,#77,#77,#88,#88,#88,#88,#88,#88,#88,#87,#44,#44,#44,#67,#18,#88,#88,#88,#88,#88,#88,#87,#41,#11,#11,#67,#18,#88,#88,#88,#88,#88,#88,#87,#41,#47,#67,#67,#18,#88,#88,#88,#88,#88,#88
db #87,#41,#76,#77,#67,#18,#88,#77,#77,#77,#77,#88,#87,#41,#77,#77,#67,#18,#87,#44,#44,#44,#67,#18,#87,#66,#66,#66,#67,#11,#87,#41,#11,#11,#67,#18,#87,#11,#11,#11,#11,#71,#87,#41,#03,#23,#67,#18
db #74,#44,#44,#44,#44,#71,#87,#41,#32,#33,#67,#18,#74,#66,#66,#11,#16,#71,#87,#41,#33,#33,#67,#18,#77,#77,#77,#77,#77,#71,#87,#66,#66,#66,#67,#11,#81,#11,#11,#11,#11,#18,#87,#11,#11,#11,#11,#71
db #88,#88,#87,#18,#88,#88,#74,#44,#44,#44,#44,#71,#88,#88,#87,#18,#88,#88,#74,#66,#66,#11,#16,#71,#88,#88,#87,#18,#88,#88,#77,#77,#77,#77,#77,#71,#88,#88,#87,#18,#88,#88,#81,#11,#11,#11,#11,#18
db #88,#88,#87,#18,#88,#88,#88,#88,#87,#18,#88,#88,#77,#77,#7E,#E1,#77,#77,#88,#88,#87,#18,#88,#88,#11,#11,#CE,#E1,#11,#11,#78,#88,#87,#18,#88,#88,#88,#88,#11,#11,#88,#81,#78,#88,#87,#18,#88,#88
db #88,#88,#88,#88,#88,#81,#78,#88,#87,#18,#88,#88,#88,#88,#88,#88,#88,#81,#77,#77,#7E,#E1,#77,#77,#88,#88,#88,#88,#88,#88,#11,#11,#CE,#E1,#11,#11,#88,#88,#88,#88,#88,#88,#88,#88,#11,#11,#88,#88

;
stactllg0   db 4,6,6:dw $+7:dw $+4,4*6:db 5
db #88,#88,#88,#88
db #88,#88,#88,#88
db #88,#88,#88,#88
db #88,#88,#88,#88
db #88,#88,#88,#88
db #88,#88,#88,#88
stactllg1   db 4,6,6:dw $+7:dw $+4,4*6:db 5
db #77,#77,#77,#77
db #77,#77,#77,#77
db #77,#77,#77,#77
db #77,#77,#77,#77
db #77,#77,#77,#77
db #77,#77,#77,#77

;==============================================================================
;%%% MULTI LANGUAGE TEXTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;==============================================================================

texts_int
read"Dmn-Network-i18n-direct.asm"
texts_int_end

list
texts_int_len   equ texts_int_end-texts_int
nolist

;### infobox
prgtxtinf1  db "Network Daemon for SymbOS",0
prgtxtinf2  db " Version 1.2 (ESP draft)",0
prgtxtinf3  db " Copyright <c> 2025 SymbiosiS"
prgtxtinf0  db 0

;### status text data
stamentxt11 db 6,128,-1:dw menicn_hide        +1:db " Hide on startup",0
stamentxt12 db 6,128,-1:dw menicn_delete      +1:db " Reset all connections",0
stamentxt13 db 6,128,-1:dw menicn_quit        +1:db " Quit",0
stamentxt21 db 6,128,-1:dw menicn_help        +1:db " Index",0
stamentxt22 db 6,128,-1:dw menicn_about       +1:db " About",0

menicn_hide         db 4,8,7:dw $+7,$+4,28:db 5: db #66,#11,#11,#66, #66,#18,#81,#66, #11,#18,#81,#11, #61,#88,#88,#16, #66,#18,#81,#66, #77,#71,#17,#77, #77,#77,#77,#77
menicn_delete       db 4,8,7:dw $+7,$+4,28:db 5: db #ff,#66,#66,#ff, #6f,#f6,#6f,#f6, #66,#ff,#ff,#66, #66,#6f,#f6,#66, #66,#ff,#ff,#66, #6f,#f6,#6f,#f6, #ff,#66,#66,#ff
menicn_quit         db 4,8,7:dw $+7,$+4,28:db 5: db #11,#16,#16,#66, #14,#46,#11,#66, #14,#11,#1e,#16, #14,#1e,#ee,#e1, #14,#11,#1e,#16, #14,#46,#11,#66, #11,#16,#16,#66
menicn_help         db 4,8,7:dw $+7,$+4,28:db 5: db #66,#1f,#f1,#66, #61,#fc,#cf,#16, #1f,#ff,#fc,#f1, #ff,#fc,#cc,#f1, #ff,#ff,#ff,#18, #1f,#cf,#f1,#81, #61,#ff,#18,#16
menicn_about        db 4,8,7:dw $+7,$+4,28:db 5: db #66,#10,#07,#66, #66,#10,#07,#66, #66,#66,#66,#66, #61,#00,#07,#66, #66,#10,#07,#66, #66,#10,#07,#66, #61,#00,#00,#76

if DRIVER=0
statxttxa   db "Adapter: Localhost",0
elseif DRIVER=1
statxttxa   db "Adapter: DenYoNet W5100",0
elseif DRIVER=2
statxttxa   db "Adapter: GR8NET W5100",0
elseif DRIVER=6
statxttxa   db "Adapter: ESP8266 "
esp_dbgtxt  db "no device",0
            ds 14
elseif M4BOARD=1
statxttxa   db "Adapter: M4 Board ESP8266",0

statxtrom   db "M4 at ROM "
statxtrom0  ds 23
statxtrom1  db " (Firmware "

siggfxtab   dw siggfx0,siggfx1,siggfx2,siggfx3,siggfx4,siggfx5
siggfx0     db 4,16,13,#6F,#0F,#0F,#67,#7F,#0F,#0F,#EF,#3F,#8F,#19,#ED,#1F,#CF,#3B,#A9,#0F,#EE,#7F,#21,#0F,#7F,#FE,#21,#0E,#37,#DC,#21,#0E,#77,#FE,#21,#02,#EE,#F7,#21,#31,#CC,#B3,#A9,#33,#C8,#91,#ED,#77,#40,#90,#EF,#6F,#D2,#B4,#6F
siggfx1     db 4,16,13,#0F,#0F,#0F,#CF,#0F,#0F,#0F,#ED,#0F,#0F,#6F,#ED,#0F,#0F,#7E,#ED,#0F,#3F,#7E,#ED,#0F,#3F,#F6,#ED,#1F,#BF,#F6,#ED,#1F,#FB,#F6,#ED,#13,#FB,#F6,#ED,#31,#FB,#F6,#ED,#31,#FB,#F6,#ED,#31,#FB,#F6,#ED,#69,#D2,#B4,#69
siggfx2     db 4,16,13,#0F,#0F,#0F,#CF,#0F,#0F,#0F,#ED,#0F,#0F,#6F,#ED,#0F,#0F,#7E,#ED,#0F,#3F,#7E,#ED,#0F,#3F,#F6,#ED,#0E,#37,#F6,#ED,#0E,#73,#F6,#ED,#02,#73,#F6,#ED,#20,#73,#F6,#ED,#20,#73,#F6,#ED,#20,#73,#F6,#ED,#69,#D2,#B4,#69
siggfx3     db 4,16,13,#0F,#0F,#0F,#CF,#0F,#0F,#0F,#ED,#0F,#0F,#6F,#ED,#0F,#0F,#7E,#ED,#0F,#0C,#7E,#ED,#0F,#0C,#F6,#ED,#0E,#04,#F6,#ED,#0E,#40,#F6,#ED,#02,#40,#F6,#ED,#20,#40,#F6,#ED,#20,#40,#F6,#ED,#20,#40,#F6,#ED,#69,#D2,#B4,#69
siggfx4     db 4,16,13,#0F,#0F,#0F,#CF,#0F,#0F,#0F,#ED,#0F,#0F,#09,#ED,#0F,#0F,#18,#ED,#0F,#0C,#18,#ED,#0F,#0C,#90,#ED,#0E,#04,#90,#ED,#0E,#40,#90,#ED,#02,#40,#90,#ED,#20,#40,#90,#ED,#20,#40,#90,#ED,#20,#40,#90,#ED,#69,#D2,#B4,#69
siggfx5     db 4,16,13,#0F,#0F,#0F,#03,#0F,#0F,#0F,#21,#0F,#0F,#09,#21,#0F,#0F,#18,#21,#0F,#0C,#18,#21,#0F,#0C,#90,#21,#0E,#04,#90,#21,#0E,#40,#90,#21,#02,#40,#90,#21,#20,#40,#90,#21,#20,#40,#90,#21,#20,#40,#90,#21,#69,#D2,#B4,#69

elseif DRIVER=4
statxttxa   db "Adapter: Net4CPC W5100S",0
endif

if DRIVER=6
if ESPDEBUG=1
statxttxb   db "v"
            db low_vermaj+48
            db "."
            db low_vermin+48
            db " "
esp_dbglog  db "no rom",0
            ds 24
else
statxttxb   db "(driver version "
            db low_vermaj+48
            db "."
            db low_vermin+48
            db ")",0
endif
else
statxttxb   db "(driver version "
            db low_vermaj+48
            db "."
            db low_vermin+48
            db ")",0
endif
statxttxk   db "Host: "
cfgbufina   ds 1+16

statxttxd0  db "0",0,0
statxttxe0  db "0",0,0
statxttxf0  db "0 KB",0:ds 6
statxttxg0  db "0 KB",0:ds 6

staslttu    db "-",0
stasltt0    db "0",0
stasltt1    db "1",0
stasltt2    db "2",0
stasltt3    db "3",0

statxttxi0 ds 16
statxttxi1 ds 16
statxttxi2 ds 16
statxttxj0 ds 16
statxttxj1 ds 16

statxttxh0  db "DHCP",0
statxttba2  db "TCP/IP",0

statxttxc0  db "ONLINE",0
statxttxc1  db "NO DEVICE",0
statxttxc2  db "NO IP SETUP",0
statxttxc3  db "DHCP REQUEST",0
statxttxc4  db "DHCP FAILURE",0
statxttxc5  db "IDLE",0
statxttxc6  db "CONNECTING",0
statxttxc7  db "WRONG PASSWRD",0
statxttxc8  db "NO AP FOUND",0
statxttxc9  db "CON. FAILED",0
statxttxc10 db "UNKNOWN ERROR",0

statxttxl   db "TX",0
statxttxm   db "Link",0
statxttxn   db "Full duplex",0
statxttxo   db "RX",0
statxttxp   db "Collision",0
statxttxq   db "100mbit",0
if DRIVER=6
statxttxr   db "WiFi: not connected",0
            ds 24
else
statxttxr   db "MAC address",0
endif
statxttxs   db "Cartridge Slot",0
statxttxt   db "Subslot",0
statxttxu   db "Card Index",0
statxttxv   db "Signal",0
statxttxw   db "SSID",0
statxttxx   db "Key",0
statxttxy   db "Show",0
statxttxz   db "Connect",0
statxttza   db "Cable plugged",0

;### config dialogue text data
cfgtxttxe   db ".",0
cfgtxtfra   db "     ",0

cfgbufia0   ds 1+3  ;IP address
cfgbufia1   ds 1+3
cfgbufia2   ds 1+3
cfgbufia3   ds 1+3
cfgbufib0   ds 1+3  ;subnet mask
cfgbufib1   ds 1+3
cfgbufib2   ds 1+3
cfgbufib3   ds 1+3
cfgbufic0   ds 1+3  ;default gateway
cfgbufic1   ds 1+3
cfgbufic2   ds 1+3
cfgbufic3   ds 1+3
cfgbufid0   ds 1+3  ;primary DNS
cfgbufid1   ds 1+3
cfgbufid2   ds 1+3
cfgbufid3   ds 1+3
cfgbufie0   ds 1+3  ;secondary DNS
cfgbufie1   ds 1+3
cfgbufie2   ds 1+3
cfgbufie3   ds 1+3
stabufim0   ds 1+2  ;mac address
stabufim1   ds 1+2
stabufim2   ds 1+2
stabufim3   ds 1+2
stabufim4   ds 1+2
stabufim5   ds 1+2
if M4BOARD=1
stabufia0   ds 1+32 ;ssid/password
stabufia1   ds 1+65
endif

;==============================================================================
;### TRANSFER AREA ############################################################
;==============================================================================

App_BegTrns
;### PRGPRZS -> stack for application process
        ds 128
prgstk  ds 6*2
        dw prgprz
App_PrcID db 0

;### App_MsgBuf -> message buffer
App_MsgBuf ds 14

;### alert boxes
prgtxtinf  dw prgtxtinf1,4*1+2,prgtxtinf2,4*1+2,prgtxtinf3,4*1+2,0,prgicnbig,prgicn16c

;### status window data
stawindat   dw #3501,0,56,26,155,122,0,0,155,122,155,122,155,122,prgicnsml,statxttit,0,stamendat
stawindat0  dw stawingrpa,0,0:ds 136+14
stawingrpa  db 19,0:dw stawindata,0,0,4*256+3,0,0,2
stawingrpb  db 20,0:dw stawindatb,0,0,4*256+3,0,0,2
if DRIVER=0
stawingrpc  db 18,0:dw stawindatc,0,0,4*256+3,0,0,2
elseif DRIVER=1
stawingrpc  db 30,0:dw stawindatc,0,0,4*256+3,0,0,2
elseif DRIVER=2
stawingrpc  db 30,0:dw stawindatc,0,0,4*256+3,0,0,2
elseif DRIVER=6
stawingrpc  db 30,0:dw stawindatc,0,0,4*256+3,0,0,2
elseif M4BOARD=1
stawingrpc  db 25,0:dw stawindatc,0,0,4*256+3,0,0,2
elseif DRIVER=4
stawingrpc  db 30,0:dw stawindatc,0,0,4*256+3,0,0,2
endif

stamendat   dw 2, 1+4,stamentxt1,stamendat1,0,     1+4,stamentxt2,stamendat2,0
stamendat1  dw 4
stamendat1a dw    33,stamentxt11,cfghid,0,   1+8,#0000,0,0, 33,stamentxt12,netres,0, 33,stamentxt13,prgend,0    ;hide to systray/-/reset all connections/quit
stamendat2  dw 3, 33,stamentxt21,prghlp,0,   1+8,#0000,0,0, 33,stamentxt22,prginf,0                             ;index/-/about

stawindata                                                              ;*** STATUS
; onclick         type   property   xpos   ypos   xlen   ylen
dw      0,  255*256+ 0,         2,     0,     0, 10000, 10000, 0    ;background
dw statab,  255*256+20, stactltba,     0,     2,   205,    11, 0    ;tab
dw stahid,  255*256+16, statxtbta,     3,   107,    56,    12, 0    ;button hide
dw stacfg,  255*256+16, statxtbtb,    65,   107,    87,    12, 0    ;button settings
dw      0,  255*256+10, prgicn16c2,    3,    18,    24,    24, 0    ;icon
dw      0,  255*256+ 1, stactltxa,    35,    18,    60,     8, 0    ;display hardware driver
dw      0,  255*256+ 1, stactltxb,    35,    26,    60,     8, 0    ;display hardware driver
dw      0,  255*256+ 1, stactltxk,    35,    37,   116,     8, 0    ;display hostname
dw      0,  255*256+ 3, stactlfra,     0,    49,   155,    57, 0    ;frame status
dw      0,  255*256+ 1, stactltxc,    10,    59,    60,     8, 0    ;description status
dw      0,  255*256+ 1, stactltxc0,   78,    59,    68,     8, 0    ;display     status
dw      0,  255*256+ 1, stactltxd,    10,    67,    60,     8, 0    ;description current
dw      0,  255*256+ 1, stactltxd0,   78,    67,    60,     8, 0    ;display     current
dw      0,  255*256+ 1, stactltxe,    10,    75,    60,     8, 0    ;description maximum
dw      0,  255*256+ 1, stactltxe0,   78,    75,    60,     8, 0    ;display     maximum
dw      0,  255*256+ 1, stactltxf,    10,    83,    60,     8, 0    ;description sent
dw      0,  255*256+ 1, stactltxf0,   78,    83,    60,     8, 0    ;display     sent
dw      0,  255*256+ 1, stactltxg,    10,    91,    60,     8, 0    ;description received
dw      0,  255*256+ 1, stactltxg0,   78,    91,    60,     8, 0    ;display     received

stawindatb                                                              ;*** TCP/IP
; onclick         type   property   xpos   ypos   xlen   ylen
dw      0,  255*256+ 0,         2,     0,     0, 10000, 10000, 0    ;background
dw statab,  255*256+20, stactltba,     0,     2,   205,    11, 0    ;tab
dw stahid,  255*256+16, statxtbta,     3,   107,    56,    12, 0    ;button hide
dw stacfg,  255*256+16, statxtbtb,    65,   107,    87,    12, 0    ;button settings
dw      0,  255*256+ 3, stactlfrb,     0,    16,   155,    49, 0    ;frame IP
dw      0,  255*256+ 1, stactltxh,    10,    26,    60,     8, 0    ;description type
dw      0,  255*256+ 1
stawindatb1          dw stactltxh0,   78,    26,    60,     8, 0    ;display     type
dw      0,  255*256+ 1, cfgctltxf,    10,    34,    60,     8, 0    ;description IP
dw      0,  255*256+ 1, stactltxi0,   78,    34,    60,     8, 0    ;display     IP
dw      0,  255*256+ 1, cfgctltxg,    10,    42,    60,     8, 0    ;description subnet mask
dw      0,  255*256+ 1, stactltxi1,   78,    42,    60,     8, 0    ;display     subnet mask
dw      0,  255*256+ 1, cfgctltxh,    10,    50,    60,     8, 0    ;description default gateway
dw      0,  255*256+ 1, stactltxi2,   78,    50,    60,     8, 0    ;display     default gateway
dw      0,  255*256+ 3, stactlfrc,     0,    65,   155,    41, 0    ;frame DNS
dw      0,  255*256+ 1, stactltxh,    10,    75,    60,     8, 0    ;description type
dw      0,  255*256+ 1
stawindatb2          dw stactltxh0,   78,    75,    60,     8, 0    ;display     type
dw      0,  255*256+ 1, cfgctltxj,    10,    83,    60,     8, 0    ;description primary DNS
dw      0,  255*256+ 1, stactltxj0,   78,    83,    60,     8, 0    ;display     primary DNS
dw      0,  255*256+ 1, cfgctltxk,    10,    91,    60,     8, 0    ;description secondary DNS
dw      0,  255*256+ 1, stactltxj1,   78,    91,    60,     8, 0    ;display     secondary DNS

stawindatc                                                              ;*** DRIVER
; onclick         type   property   xpos   ypos   xlen   ylen
dw      0,  255*256+ 0,         2,     0,     0, 10000, 10000, 0    ;background
dw statab,  255*256+20, stactltba,     0,     2,   205,    11, 0    ;tab
dw stahid,  255*256+16, statxtbta,     3,   107,    56,    12, 0    ;button hide
dw stacfg,  255*256+16, statxtbtb,    65,   107,    87,    12, 0    ;button settings
dw      0,  255*256+ 3, stactlfrd,     0,    16,   155,    33, 0    ;frame Status

if DRIVER=0         ;*** LOCALHOST **************

dw      0,  255*256+10
stawindatc0 dw          stactllg0,     9,    27,     6,     6, 0    ;display     TX
dw      0,  255*256+ 1, stactltxl,    18,    26,    60,     8, 0    ;description 
dw      0,  255*256+10, stactllg1,    39,    27,     6,     6, 0    ;display     LINK
dw      0,  255*256+ 1, stactltxm,    48,    26,    60,     8, 0    ;description 
dw      0,  255*256+10, stactllg0,    91,    27,     6,     6, 0    ;display     FULL DUPLEX
dw      0,  255*256+ 1, stactltxn,   100,    26,    60,     8, 0    ;description 
dw      0,  255*256+10, stactllg1,     9,    35,     6,     6, 0    ;display     RX
dw      0,  255*256+ 1, stactltxo,    18,    34,    60,     8, 0    ;description 
dw      0,  255*256+10, stactllg0,    39,    35,     6,     6, 0    ;display     COLLISION
dw      0,  255*256+ 1, stactltxp,    48,    34,    60,     8, 0    ;description 
dw      0,  255*256+10, stactllg1,    91,    35,     6,     6, 0    ;display     100MBIT
dw      0,  255*256+ 1, stactltxq,   100,    34,    60,     8, 0    ;description 
dw      0,  255*256+ 3, stactlfrf,     0,    49,   155,    57, 0    ;frame Settings

elseif DRIVER=1     ;*** DENYONET ***************

dw      0,  255*256+10
stawindatc0 dw          stactllg0,     9,    27,     6,     6, 0    ;display     TX
dw      0,  255*256+ 1, stactltxl,    18,    26,    60,     8, 0    ;description 
dw      0,  255*256+10, stactllg0,    39,    27,     6,     6, 0    ;display     LINK
dw      0,  255*256+ 1, stactltxm,    48,    26,    60,     8, 0    ;description 
dw      0,  255*256+10, stactllg0,    91,    27,     6,     6, 0    ;display     FULL DUPLEX
dw      0,  255*256+ 1, stactltxn,   100,    26,    60,     8, 0    ;description 
dw      0,  255*256+10, stactllg0,     9,    35,     6,     6, 0    ;display     RX
dw      0,  255*256+ 1, stactltxo,    18,    34,    60,     8, 0    ;description 
dw      0,  255*256+10, stactllg0,    39,    35,     6,     6, 0    ;display     COLLISION
dw      0,  255*256+ 1, stactltxp,    48,    34,    60,     8, 0    ;description 
dw      0,  255*256+10, stactllg0,    91,    35,     6,     6, 0    ;display     100MBIT
dw      0,  255*256+ 1, stactltxq,   100,    34,    60,     8, 0    ;description 
dw      0,  255*256+ 3, stactlfre,     0,    49,   155,    57, 0    ;frame Settings
dw      0,  255*256+ 1, stactltxs,    10,    62,    10,     8, 0    ;description slot
dw      0,  255*256+42, stactlpsl,    69,    61,    17,    10, 0    ;PRIMRAY SLOT
dw      0,  255*256+ 1, stactltxt,    92,    62,    10,     8, 0    ;description subslot
dw      0,  255*256+42, stactlssl,   124,    61,    17,    10, 0    ;SECONDAY SLOT
dw      0,  255*256+ 1, stactltxr,    10,    76,    40,     8, 0    ;description mac address
dw      0,  255*256+32, stactlim0,    10,    85,    14,    12, 0    ;input mac-0
dw      0,  255*256+32, stactlim1,    25,    85,    14,    12, 0    ;input mac-1
dw      0,  255*256+32, stactlim2,    40,    85,    14,    12, 0    ;input mac-2
dw      0,  255*256+32, stactlim3,    55,    85,    14,    12, 0    ;input mac-3
dw      0,  255*256+32, stactlim4,    70,    85,    14,    12, 0    ;input mac-4
dw      0,  255*256+32, stactlim5,    85,    85,    14,    12, 0    ;input mac-5
dw staapl,  255*256+16, statxtbtc,   109,    85,    36,    12, 0    ;button apply

elseif DRIVER=6     ;*** ESP8266 UNAPI (PicoVerse) ***

dw      0,  255*256+10
stawindatc0 dw          stactllg0,     9,    27,     6,     6, 0    ;display     TX
dw      0,  255*256+ 1, stactltxl,    18,    26,    60,     8, 0    ;description TX
dw      0,  255*256+10, stactllg0,    39,    27,     6,     6, 0    ;display     LINK
dw      0,  255*256+ 1, stactltxm,    48,    26,    60,     8, 0    ;description LINK
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+10, stactllg0,     9,    35,     6,     6, 0    ;display     RX
dw      0,  255*256+ 1, stactltxo,    18,    34,    60,     8, 0    ;description RX
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+ 3, stactlfre,     0,    49,   155,    57, 0    ;frame Settings
dw      0,  255*256+ 1, stactltxs,    10,    62,    10,     8, 0    ;description slot
dw      0,  255*256+42, stactlpsl,    69,    61,    17,    10, 0    ;PRIMARY SLOT
dw      0,  255*256+ 1, stactltxt,    92,    62,    10,     8, 0    ;description subslot
dw      0,  255*256+42, stactlssl,   124,    61,    17,    10, 0    ;SUBSLOT
dw      0,  255*256+ 1, stactltxr,    10,    74,   140,     8, 0    ;note, the slot is detected automatically
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw staapl,  255*256+16, statxtbtc,   109,    85,    36,    12, 0    ;button apply

elseif DRIVER=2     ;*** GR8NET *****************

dw      0,  255*256+10
stawindatc0 dw          stactllg0,     9,    27,     6,     6, 0    ;display     TX
dw      0,  255*256+ 1, stactltxl,    18,    26,    60,     8, 0    ;description 
dw      0,  255*256+10, stactllg0,    39,    27,     6,     6, 0    ;display     LINK
dw      0,  255*256+ 1, stactltxm,    48,    26,    60,     8, 0    ;description 
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+10, stactllg0,     9,    35,     6,     6, 0    ;display     RX
dw      0,  255*256+ 1, stactltxo,    18,    34,    60,     8, 0    ;description 
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+ 3, stactlfrg,     0,    49,   155,    57, 0    ;frame Settings
dw      0,  255*256+ 1, stactltxu,    10,    62,    10,     8, 0    ;description index
dw      0,  255*256+42, stactlpsl,    69,    61,    17,    10, 0    ;CARD INDEX
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+ 1, stactltxr,    10,    76,    40,     8, 0    ;description mac address
dw      0,  255*256+32, stactlim0,    10,    85,    14,    12, 0    ;input mac-0
dw      0,  255*256+32, stactlim1,    25,    85,    14,    12, 0    ;input mac-1
dw      0,  255*256+32, stactlim2,    40,    85,    14,    12, 0    ;input mac-2
dw      0,  255*256+32, stactlim3,    55,    85,    14,    12, 0    ;input mac-3
dw      0,  255*256+32, stactlim4,    70,    85,    14,    12, 0    ;input mac-4
dw      0,  255*256+32, stactlim5,    85,    85,    14,    12, 0    ;input mac-5
dw staapl,  255*256+16, statxtbtc,   109,    85,    36,    12, 0    ;button apply

elseif M4BOARD=1    ;*** M4BOARD ****************

dw      0,  255*256+10
stawindatc0 dw          stactllg0,     9,    27,     6,     6, 0    ;display     TX
dw      0,  255*256+ 1, stactltxl,    18,    26,    60,     8, 0    ;description 
dw      0,  255*256+10, stactllg1,    39,    27,     6,     6, 0    ;display     LINK
dw      0,  255*256+ 1, stactltxm,    48,    26,    60,     8, 0    ;description 
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+10, stactllg0,     9,    35,     6,     6, 0    ;display     RX
dw      0,  255*256+ 1, stactltxo,    18,    34,    60,     8, 0    ;description 
dw      0,  255*256+ 1, stactltxv,   100,    28,    60,     8, 0    ;description signal
stawindatc1
dw      0,  255*256+ 8, siggfx0  ,   130,    26,    16,    13, 0    ;display     signal
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+ 3, stactlfrh,     0,    49,   155,    57, 0    ;frame Settings
dw      0,  255*256+ 1, stactltxw,    10,    63,    20,     8, 0    ;ssid description
dw      0,  255*256+32, stactlia0,    31,    61,    73,    12, 0    ;ssid input
dw stacon,  255*256+16, statxttxz,   106,    61,    39,    10, 0    ;connect
dw      0,  255*256+ 1, stactltxx,    10,    77,    20,     8, 0    ;pswd description
dw      0,  255*256+32, stactlia1,    31,    75,    73,    12, 0    ;pswd input
dw stapws,  255*256+17, stactlshc,   106,    77,    39,     8, 0    ;pswd show
dw      0,  255*256+ 1, stactltx0,    10,    91,   135,     8, 0    ;firmware description

stactltx0   dw statxtrom,2+4+256

cfgsf2flg   db 0 ;g9k flag

elseif DRIVER=4     ;*** Net4CPC ***************
; onclick         type   property   xpos   ypos   xlen   ylen
dw      0,  255*256+64
stawindatc0 dw                  0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+10, stactllg0,     9,    27,     6,     6, 0    ;display     LINK
dw      0,  255*256+ 1, stactltxm,    18,    26,    60,     8, 0    ;description 
dw      0,  255*256+10, stactllg0,    91,    27,     6,     6, 0    ;display     FULL DUPLEX
dw      0,  255*256+ 1, stactltxn,   100,    26,    60,     8, 0    ;description 
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+10, stactllg0,     9,    35,     6,     6, 0    ;display     CABLE PLUGGED
dw      0,  255*256+ 1, stactltza,    18,    34,    60,     8, 0    ;description 
dw      0,  255*256+10, stactllg0,    91,    35,     6,     6, 0    ;display     100MBIT
dw      0,  255*256+ 1, stactltxq,   100,    34,    60,     8, 0    ;description 
dw      0,  255*256+ 3, stactlfri,     0,    49,   155,    57, 0    ;frame Settings
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+64,         0,     0,     0,     1,     1, 0    ;-
dw      0,  255*256+ 1, stactltxr,    10,    76,    40,     8, 0    ;description mac address
dw      0,  255*256+32, stactlim0,    10,    85,    14,    12, 0    ;input mac-0
dw      0,  255*256+32, stactlim1,    25,    85,    14,    12, 0    ;input mac-1
dw      0,  255*256+32, stactlim2,    40,    85,    14,    12, 0    ;input mac-2
dw      0,  255*256+32, stactlim3,    55,    85,    14,    12, 0    ;input mac-3
dw      0,  255*256+32, stactlim4,    70,    85,    14,    12, 0    ;input mac-4
dw      0,  255*256+32, stactlim5,    85,    85,    14,    12, 0    ;input mac-5
dw staapl,  255*256+16, statxtbtc,   109,    85,    36,    12, 0    ;button apply

endif


stactlpsl   dw 04,0,stalstpsl,0,1,starowpsl,0,1
starowpsl   dw 0,17,0,0
stalstpsl   dw               0,stasltt0, 1,stasltt1, 2,stasltt2, 3,stasltt3

stactlssl   dw 05,0,stalstssl,0,1,starowssl,0,1
starowssl   dw 0,17,0,0
stalstssl   dw 255,staslttu, 0,stasltt0, 1,stasltt1, 2,stasltt2, 3,stasltt3



;### config dialogue window data 
cfgwindat   dw #1501,0,80,10,205,155,0,0,205,155,205,155,205,155,prgicnsml,cfgtxttit,0,0
cfgwindat0  dw cfgwingrpa,0,0:ds 136+14

cfgwingrpa  db 35,0:dw cfgwindata,0,0,4*256+3,0,0,2
cfgwingrpb  db 25,0:dw cfgwindatb,0,0,4*256+3,0,0,2

cfgwindata
; onclick         type   property   xpos   ypos   xlen   ylen
dw      0,  255*256+ 0,         2,     0,     0, 10000, 10000, 0    ;background
dw cfgtab,  255*256+20, cfgctltba,     0,     2,   205,    11, 0    ;tab
dw cfgoky,  255*256+16, prgtxtoky,    99,   140,    50,    12, 0    ;button ok
dw cfgcnc,  255*256+16, prgtxtcnc,   152,   140,    50,    12, 0    ;button cancel
dw      0,  255*256+ 1, cfgctltxa,     5,    18,   194,     8, 0    ;description intro
dw      0,  255*256+ 1, cfgctltxb,     5,    26,   194,     8, 0    ;description intro
dw      0,  255*256+ 1, cfgctltxc,     5,    34,   194,     8, 0    ;description intro
dw      0,  255*256+ 1, cfgctltxd,     5,    42,   194,     8, 0    ;description intro
dw      0,  255*256+ 3, cfgctlfra,     0,    74,   205,    65, 0    ;frame
dw      0,  255*256+18, cfgctlrda,    10,    60,   149,     8, 0    ;radio a
dw      0,  255*256+18, cfgctlrdb,    10,    73,   123,     8, 0    ;radio b
dw      0,  255*256+ 1, cfgctltxf,    10,    88,    72,     8, 0    ;description IP address
dw      0,  255*256+32, cfgctlia0,    86,    86,    20,    12, 0    ;input IPa-0
dw      0,  255*256+ 1, cfgctltxe,   107,    88,     5,     8, 0    ;dot
dw      0,  255*256+32, cfgctlia1,   109,    86,    20,    12, 0    ;input IPa-1
dw      0,  255*256+ 1, cfgctltxe,   130,    88,     5,     8, 0    ;dot
dw      0,  255*256+32, cfgctlia2,   132,    86,    20,    12, 0    ;input IPa-2
dw      0,  255*256+ 1, cfgctltxe,   153,    88,     5,     8, 0    ;dot
dw      0,  255*256+32, cfgctlia3,   155,    86,    20,    12, 0    ;input IPa-3
dw      0,  255*256+ 1, cfgctltxg,    10,   103,    72,     8, 0    ;description subnet mask
dw      0,  255*256+32, cfgctlib0,    86,   101,    20,    12, 0    ;input IPb-0
dw      0,  255*256+ 1, cfgctltxe,   107,   103,     5,     8, 0    ;dot
dw      0,  255*256+32, cfgctlib1,   109,   101,    20,    12, 0    ;input IPb-1
dw      0,  255*256+ 1, cfgctltxe,   130,   103,     5,     8, 0    ;dot
dw      0,  255*256+32, cfgctlib2,   132,   101,    20,    12, 0    ;input IPb-2
dw      0,  255*256+ 1, cfgctltxe,   153,   103,     5,     8, 0    ;dot
dw      0,  255*256+32, cfgctlib3,   155,   101,    20,    12, 0    ;input IPb-3
dw      0,  255*256+ 1, cfgctltxh,    10,   118,    72,     8, 0    ;description default gateway
dw      0,  255*256+32, cfgctlic0,    86,   116,    20,    12, 0    ;input IPc-0
dw      0,  255*256+ 1, cfgctltxe,   107,   118,     5,     8, 0    ;dot
dw      0,  255*256+32, cfgctlic1,   109,   116,    20,    12, 0    ;input IPc-1
dw      0,  255*256+ 1, cfgctltxe,   130,   118,     5,     8, 0    ;dot
dw      0,  255*256+32, cfgctlic2,   132,   116,    20,    12, 0    ;input IPc-2
dw      0,  255*256+ 1, cfgctltxe,   153,   118,     5,     8, 0    ;dot
dw      0,  255*256+32, cfgctlic3,   155,   116,    20,    12, 0    ;input IPc-3

cfgwindatb
; onclick         type   property   xpos   ypos   xlen   ylen
dw      0,  255*256+ 0,         2,     0,     0, 10000, 10000, 0    ;background
dw cfgtab,  255*256+20, cfgctltba,     0,     2,   205,    11, 0    ;tab
dw cfgoky,  255*256+16, prgtxtoky,    99,   140,    50,    12, 0    ;button ok
dw cfgcnc,  255*256+16, prgtxtcnc,   152,   140,    50,    12, 0    ;button cancel
dw      0,  255*256+ 1, cfgctltxi,    10,    32,    72,     8, 0    ;description hostname
dw      0,  255*256+32, cfgctlina,    86,    30,    89,    12, 0    ;input hostname
dw      0,  255*256+ 3, cfgctlfra,     0,    74,   205,    50, 0    ;frame
dw      0,  255*256+18, cfgctlrdc,    10,    60,   185,     8, 0    ;radio c
dw      0,  255*256+18, cfgctlrdd,    10,    73,   172,     8, 0    ;radio d
dw      0,  255*256+ 1, cfgctltxj,    10,    88,    72,     8, 0    ;description primary DNS
dw      0,  255*256+32, cfgctlid0,    86,    86,    20,    12, 0    ;input IPd-0
dw      0,  255*256+ 1, cfgctltxe,   107,    88,     5,     8, 0    ;dot
dw      0,  255*256+32, cfgctlid1,   109,    86,    20,    12, 0    ;input IPd-1
dw      0,  255*256+ 1, cfgctltxe,   130,    88,     5,     8, 0    ;dot
dw      0,  255*256+32, cfgctlid2,   132,    86,    20,    12, 0    ;input IPd-2
dw      0,  255*256+ 1, cfgctltxe,   153,    88,     5,     8, 0    ;dot
dw      0,  255*256+32, cfgctlid3,   155,    86,    20,    12, 0    ;input IPd-3
dw      0,  255*256+ 1, cfgctltxk,    10,   103,    72,     8, 0    ;description secondary DNS
dw      0,  255*256+32, cfgctlie0,    86,   101,    20,    12, 0    ;input IPe-0
dw      0,  255*256+ 1, cfgctltxe,   107,   103,     5,     8, 0    ;dot
dw      0,  255*256+32, cfgctlie1,   109,   101,    20,    12, 0    ;input IPe-1
dw      0,  255*256+ 1, cfgctltxe,   130,   103,     5,     8, 0    ;dot
dw      0,  255*256+32, cfgctlie2,   132,   101,    20,    12, 0    ;input IPe-2
dw      0,  255*256+ 1, cfgctltxe,   153,   103,     5,     8, 0    ;dot
dw      0,  255*256+32, cfgctlie3,   155,   101,    20,    12, 0    ;input IPe-3

;### config dialogue control data
cfgctltba   db 2,2+4+48+64
cfgctltba0  db 0:dw cfgtxttba1:db -1:dw cfgtxttba2:db -1

cfgctltxa   dw cfgtxttxa,2+4
cfgctltxb   dw cfgtxttxb,2+4
cfgctltxc   dw cfgtxttxc,2+4
cfgctltxd   dw cfgtxttxd,2+4
cfgctltxe   dw cfgtxttxe,2+4
cfgctltxf   dw cfgtxttxf,2+4
cfgctltxg   dw cfgtxttxg,2+4
cfgctltxh   dw cfgtxttxh,2+4
cfgctltxi   dw cfgtxttxi,2+4+256
cfgctltxj   dw cfgtxttxj,2+4
cfgctltxk   dw cfgtxttxk,2+4

cfgctlfra   dw cfgtxtfra,2+4

cfgctlras   db 0
cfgctlrab   ds 4
cfgctlrda   dw cfgctlras,cfgtxtrda,256*0+2+4,cfgctlrab
cfgctlrdb   dw cfgctlras,cfgtxtrdb,256*1+2+4,cfgctlrab

cfgctlrbs   db 0
cfgctlrbb   ds 4
cfgctlrdc   dw cfgctlrbs,cfgtxtrdc,256*0+2+4,cfgctlrbb
cfgctlrdd   dw cfgctlrbs,cfgtxtrdd,256*1+2+4,cfgctlrbb

cfgctlia0   dw cfgbufia0,0,0,0,0,3:db 0
cfgctlia1   dw cfgbufia1,0,0,0,0,3:db 0
cfgctlia2   dw cfgbufia2,0,0,0,0,3:db 0
cfgctlia3   dw cfgbufia3,0,0,0,0,3:db 0
cfgctlib0   dw cfgbufib0,0,0,0,0,3:db 0
cfgctlib1   dw cfgbufib1,0,0,0,0,3:db 0
cfgctlib2   dw cfgbufib2,0,0,0,0,3:db 0
cfgctlib3   dw cfgbufib3,0,0,0,0,3:db 0
cfgctlic0   dw cfgbufic0,0,0,0,0,3:db 0
cfgctlic1   dw cfgbufic1,0,0,0,0,3:db 0
cfgctlic2   dw cfgbufic2,0,0,0,0,3:db 0
cfgctlic3   dw cfgbufic3,0,0,0,0,3:db 0

cfgctlid0   dw cfgbufid0,0,0,0,0,3:db 0
cfgctlid1   dw cfgbufid1,0,0,0,0,3:db 0
cfgctlid2   dw cfgbufid2,0,0,0,0,3:db 0
cfgctlid3   dw cfgbufid3,0,0,0,0,3:db 0
cfgctlie0   dw cfgbufie0,0,0,0,0,3:db 0
cfgctlie1   dw cfgbufie1,0,0,0,0,3:db 0
cfgctlie2   dw cfgbufie2,0,0,0,0,3:db 0
cfgctlie3   dw cfgbufie3,0,0,0,0,3:db 0

cfgctlina   dw cfgbufina,0,0,0,0,16:db 0

cfgerrmsg   dw cfgerrtxt0,4*1+2,cfgerrtxt1,4*1+2,cfgerrtxt2,4*1+2


;### status control data
stactltba   db 3,2+4+48+64
stactltba0  db 0:dw statxttba1:db -1:dw statxttba2:db -1:dw statxttba3:db -1

stactlfra   dw statxtfra,2+4
stactlfrb   dw statxtfrb,2+4
stactlfrc   dw statxtfrc,2+4
stactlfrd   dw statxtfrd,2+4
stactlfre   dw statxtfre,2+4
stactlfrf   dw statxtfrf,2+4
stactlfrg   dw statxtfrg,2+4
stactlfrh   dw statxtfrh,2+4
stactlfri   dw statxtfri,2+4

stactltxa   dw statxttxa ,2+4
stactltxb   dw statxttxb ,2+4
stactltxk   dw statxttxk ,2+4
stactltxc   dw statxttxc ,2+4
stactltxc0  dw statxttxc1,2+4+128
stactltxd   dw statxttxd ,2+4
stactltxd0  dw statxttxd0,2+4
stactltxe   dw statxttxe ,2+4
stactltxe0  dw statxttxe0,2+4
stactltxf   dw statxttxf ,2+4
stactltxf0  dw statxttxf0,2+4
stactltxg   dw statxttxg ,2+4
stactltxg0  dw statxttxg0,2+4

stactltxh   dw statxttxh,2+4
stactltxh0  dw statxttxh0,2+4
stactltxh1  dw statxttxh1,2+4
stactltxi0  dw statxttxi0,2+4
stactltxi1  dw statxttxi1,2+4
stactltxi2  dw statxttxi2,2+4
stactltxj0  dw statxttxj0,2+4
stactltxj1  dw statxttxj1,2+4

stactltxl   dw statxttxl,2+4
stactltxm   dw statxttxm,2+4
stactltxn   dw statxttxn,2+4
stactltxo   dw statxttxo,2+4
stactltxp   dw statxttxp,2+4
stactltxq   dw statxttxq,2+4
stactltxr   dw statxttxr,2+4
stactltxs   dw statxttxs,2+4
stactltxt   dw statxttxt,2+4
stactltxu   dw statxttxu,2+4
stactltza   dw statxttza,2+4

stactlim0   dw stabufim0,0,0,0,0,2:db 0
stactlim1   dw stabufim1,0,0,0,0,2:db 0
stactlim2   dw stabufim2,0,0,0,0,2:db 0
stactlim3   dw stabufim3,0,0,0,0,2:db 0
stactlim4   dw stabufim4,0,0,0,0,2:db 0
stactlim5   dw stabufim5,0,0,0,0,2:db 0

if M4BOARD=1
stactltxv   dw statxttxv,2+4
stactltxw   dw statxttxw,2+4
stactltxx   dw statxttxx,2+4
stactltxz   dw statxttxz,2+4

stactlia0   dw stabufia0,0,0,0,0,32:db 0
stactlia1   dw stabufia1,0,0,0,0,64:stactlia1p db 1

stactlshs   db 0
stactlshc   dw stactlshs,statxttxy,256*0+2+4
endif
