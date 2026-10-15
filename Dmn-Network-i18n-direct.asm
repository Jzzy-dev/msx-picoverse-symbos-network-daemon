;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@                                                                            @
;@               S y m b O S   -   N e t w o r k - D a e m o n                @
;@                   (default application texts [english])                    @
;@                                                                            @
;@             (c) 2015-2025 by Prodatron / SymbiosiS (Jörn Mika)             @
;@                                                                            @
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

;### DIRECT TEXT VARIANT - the 3-byte text pointer list has been removed,
;### every text label now points straight at its string










;config dialogue text data







;### TEXTS ####################################################################

prgtxtoky   db "Ok",0
prgtxtcnc   db "Cancel",0

stamentxt1  db "File",0
stamentxt2  db "?",0
stamentxt11_poi   db " Hide on startup",0
stamentxt12_poi   db " Reset all connections",0
stamentxt13_poi   db " Quit",0
stamentxt21_poi   db " Index",0
stamentxt22_poi   db " About",0

statxttit   db "Network daemon",0
statxtbta   db "Hide",0
statxtbtb   db "Network settings",0
statxtbtc   db "Apply",0

statxttba1  db "Status",0
statxttba3  db "Driver",0

statxtfra   db "Network status",0

statxttxc   db "Status",0
statxttxd   db "Connections",0
statxttxe   db "Maximum",0
statxttxf   db "Sent",0
statxttxg   db "Received",0

statxttxh   db "Type",0
statxttxh1  db "Manually set",0

statxtfrb   db "IP settings",0
statxtfrc   db "DNS settings",0

statxtfrd   db "Status",0
statxtfre   db "MSX PcVrs ESP v0.4",0
statxtfrf   db "Localhost Settings",0
statxtfrg   db "GR8NET Settings",0
statxtfrh   db "M4 Board Settings",0
statxtfri   db "Net4CPC Settings",0

;config dialogue text data
cfgtxttit   db "TCP/IP properties",0

cfgtxttba1  db "IP address",0
cfgtxttba2  db "DNS & Hostname",0

cfgtxttxa   db "You can get IP settings assigned automatically",0
cfgtxttxb   db "if your network supports this capability.",0
cfgtxttxc   db "Otherwise, you need to ask your network admin",0
cfgtxttxd   db "for the appropriate IP settings.",0

cfgtxttxf   db "IP address",0
cfgtxttxg   db "Subnet mask",0
cfgtxttxh   db "Default gateway",0

cfgtxttxi   db "Hostname",0
cfgtxttxj   db "Primary DNS",0
cfgtxttxk   db "Secondary DNS",0

cfgtxtrda   db "Obtain an IP address automatically",0
cfgtxtrdb   db "Use the following IP address ",0
cfgtxtrdc   db "Obtain DNS server addresses automatically",0
cfgtxtrdd   db "Use the following DNS server addresses ",0

cfgerrtxt0  db "Wrong IP format",0
cfgerrtxt1  db "Please enter a correct",0
cfgerrtxt2  db "number between 0 and 255.",0

;### RESERVE
ds 80
