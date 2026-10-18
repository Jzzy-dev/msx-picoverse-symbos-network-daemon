nolist

DRIVER      equ 6    ;0=localhost 1=denyonet 2=gr8net 3=m4cpc 4=net4cpc 5=m4ep 6=esp8266-unapi
M4BOARD     equ 0
low_buflen  equ 0
TLSVERIFY   equ 0    ;1 = the ESP checks the server certificate (needs certs.ar in the ESP), 0 = encrypted but not checked
ESPDEBUG    equ 0    ;1 = show the slot scan log and FIFO snapshot in the status tab
LNGSKIP     equ 2    ;2 = direct texts, no language pack at all (use with Dmn-Network-i18n-direct.asm)
low_sockmax equ 4    ;max parallel TCP connections, must be defined BEFORE Dmn-Network.asm
low_vermaj  equ 0    ;driver version shown in the daemon info box
low_vermin  equ 5

org #1000

;--- output file, folder must exist
WRITE "C:\Users\flcle\Downloads\symnet\netd-esp.exe"
print "STEP 1 WRITE accepted"

;--- SymbOS constants file, use the file that really contains MSC_ MSR_ PRC_ etc.
;--- the original wrapper reads SymbOS-Constants.asm from SRC-Main
READ "C:\Users\flcle\Downloads\symnet\SRC-Main\SymbOS-Constants.asm"
print "STEP 2 constants read"
READ "Dmn-Network-head.asm"
print "STEP 3 head read"

;--- one flattened file replaces the three symbos_lib files
READ "Dmn-Network-libs.asm"
print "STEP 4 libs read"

READ "Dmn-Network.asm"
print "STEP 5 daemon read"
READ "Dmn-Network-ESP.asm"
print "STEP 6 esp driver read"

App_EndTrns

relocate_table
relocate_end
