; ==============================================================================
; This is the main FID-setting code.
; Copyright 2004 Emboss, all rights reserved
; See licence.txt for details.
; Version modified by Bogbert 2008-2010 (cf. changelog.txt)
; ==============================================================================

; Top 1kb of memory: temporary data storage
;   0x000   Old ESP           (dword)
;   0x004   Old SS            (word)
;   0x006   Cursor X          (byte)
;   0x007   Cursor Y          (byte)
;   0x008   Orig cursor style (word)
;   0x00A   GDT limit         (word)
;   0x00C   GDT address       (dword)
;   0x010   GDT               (0x38 bytes)
;   0x048   Temporary SP      (word)
;   0x04A   AP state flag     (byte)
;   0x04B   AP's SP           (word)
;   0x04D   AP's SS           (word)
;   0x04F   Video spinlock    (byte)
;   0x050   Timer2 spinlock   (byte)
;   0x051   'CPUn:',0         (6 bytes)
;   0x057   AP "can proceed"  (byte)
;   0x058   Target FID        (byte)
;   0x059   BOOTFID enabled   (byte)
;   0x060   Pause at exit     (byte)
;   0x061   Previous multiplier position (byte)
;   0x062   CPU freq. in MHz  (word)
;   0x064   SMBIOS status     (byte)
;   0x065   SMBIOS previous structure offset (word)
;   0x067   Bad multiplier in CMOS (byte)

; 2kb before top: BSP stack
; 3kb before top: CPU0 stack (if not BSP)
; 4kb before top: CPU1 stack (if not BSP)
; etc etc

; bp format:
;   bits 0..7 : APIC ID
;   bit 8     : Set if APIC ID not determined yet
;   bit 9     : Set if no APIC detected

; CMOS Byte 1 format:
;   bit 0..4  : The FID code
;   bit 5..6  : Always 0
;   bit 7     : Set if BOOTFID is enabled

; CMOS Byte 2 = CMOS Byte 1 + 0x55

%define DAT_OLD_ESP         0x000
%define DAT_OLD_SS          0x004
%define DAT_CURSOR_X        0x006
%define DAT_CURSOR_Y        0x007
%define DAT_OLDCURSOR       0x008
%define DAT_GDTLIMIT        0x00A
%define DAT_GDTADDRESS      0x00C
%define DAT_GDT             0x010
%define DAT_TEMPSP          0x048
%define DAT_APSTATE         0x04A
%define DAT_VIDEOLOCK       0x04F
%define DAT_TIMER2LOCK      0x050
%define DAT_CPUNSTR         0x051
%define DAT_AP_PROCEED      0x057
%define DAT_TARGET_FID      0x058
%define DAT_BOOTFID_ENABLED 0x059
%define DAT_PAUSE_AT_EXIT   0x060
%define DAT_PREV_MULT_POS   0x061
%define DAT_CPU_FREQ        0x062
%define DAT_SMBIOS_STATUS   0x064
%define DAT_SMBIOS_STRUCT   0x065
%define DAT_BAD_CMOS_MULT   0x067

; To store the multiplier in the CMOS, you have to find one
; or two unused CMOS bytes, specify the index of these bytes
; in the two macros below and set the macro FID_SET to 'cmos'.

; If it turns out that these CMOS bytes are actually used
; by the BIOS, and if the BIOS overrides one or two of them,
; there is a small chance that BOOTFID doesn't notice the
; corruption of its storage and sets the wrong multiplier.
; There's one chance out of 8 with one CMOS byte used, and
; one chance out of 2048 with two CMOS bytes used. That's
; why it is advised to use two CMOS bytes, yet the byte 2
; is optional, it's only used for safety. To disable it, set
; its macro to zero.

%define CMOS_BYTE_1 0x4E
%define CMOS_BYTE_2 0x4F

; To disable cmos checksum, set CMOS_CHECKSUM_LO to zero
%define CMOS_CHECKSUM_HI 0x7A
%define CMOS_CHECKSUM_LO 0x7B

%ifndef SPLASH_SCREEN_WAIT_TIME
  %define SPLASH_SCREEN_WAIT_TIME 100 ; in hundredth of a second
%endif

%ifndef SPLASH_SCREEN_WAIT_TIME_BAD_CMOS
  %define SPLASH_SCREEN_WAIT_TIME_BAD_CMOS 1000 ; in hundredth of a second
%endif

; If EXIT_WAIT_TIME is set to a negative value, bootfid waits
; for a key pressed to continue
%ifndef EXIT_WAIT_TIME
  %define EXIT_WAIT_TIME 350 ; in hundredth of a second
%endif

%define DEFAULT_FID 0x06

;%define VID_CODE 0x07   ; 1.650V, though vid changes not supported by the K7D so
                        ; it doesn't really matter.
%define VID_CODE 0x0B   ; 1.450V

%ifndef FID_SET
  %define FID_SET = 0
%endif

%if FID_SET = 0
  %define BOOTFID_ENABLED 0
%else
  %define BOOTFID_ENABLED 1
%endif

%ifidni FID_SET,'cmos'
%elif FID_SET = 0
  %define FID_CODE DEFAULT_FID
%elif FID_SET = 30
  %define FID_CODE 0x10
%elif FID_SET = 40
  %define FID_CODE 0x12
%elif FID_SET = 50
  %define FID_CODE 0x04
%elif FID_SET = 55
  %define FID_CODE 0x05
%elif FID_SET = 60
  %define FID_CODE 0x06
%elif FID_SET = 65
  %define FID_CODE 0x07
%elif FID_SET = 70
  %define FID_CODE 0x08
%elif FID_SET = 75
  %define FID_CODE 0x09
%elif FID_SET = 80
  %define FID_CODE 0x0A
%elif FID_SET = 85
  %define FID_CODE 0x0B
%elif FID_SET = 90
  %define FID_CODE 0x0C
%elif FID_SET = 95
  %define FID_CODE 0x0D
%elif FID_SET = 100
  %define FID_CODE 0x0E
%elif FID_SET = 105
  %define FID_CODE 0x0F
%elif FID_SET = 110
  %define FID_CODE 0x00
%elif FID_SET = 115
  %define FID_CODE 0x01
%elif FID_SET = 120
  %define FID_CODE 0x02
%elif FID_SET = 125
  %define FID_CODE 0x03
%elif FID_SET = 130
  %define FID_CODE 0x14
%elif FID_SET = 135
  %define FID_CODE 0x15
%elif FID_SET = 140
  %define FID_CODE 0x16
%elif FID_SET = 150
  %define FID_CODE 0x18
%elif FID_SET = 160
  %define FID_CODE 0x1A
%elif FID_SET = 165
  %define FID_CODE 0x1B
%elif FID_SET = 170
  %define FID_CODE 0x1C
%elif FID_SET = 180
  %define FID_CODE 0x1D
%elif FID_SET = 190
  %define FID_CODE 0x11
%elif FID_SET = 200
  %define FID_CODE 0x13
%elif FID_SET = 210
  %define FID_CODE 0x17
%elif FID_SET = 220
  %define FID_CODE 0x19
%elif FID_SET = 230
  %define FID_CODE 0x1E
%elif FID_SET = 240
  %define FID_CODE 0x1F
%else
  %error Invalid fixed multiplier specified.
%endif

; CONFIRMATION_THRESHOLD_INT is the position (an integer in the range [0, 31])
; of the first multiplier needing confirmation
%ifdef CONFIRMATION_THRESHOLD
  %if CONFIRMATION_THRESHOLD = 30
    %define CONFIRMATION_THRESHOLD_INT 0
  %elif CONFIRMATION_THRESHOLD = 40
    %define CONFIRMATION_THRESHOLD_INT 1
  %elif CONFIRMATION_THRESHOLD = 50
    %define CONFIRMATION_THRESHOLD_INT 2
  %elif CONFIRMATION_THRESHOLD = 55
    %define CONFIRMATION_THRESHOLD_INT 3
  %elif CONFIRMATION_THRESHOLD = 60
    %define CONFIRMATION_THRESHOLD_INT 4
  %elif CONFIRMATION_THRESHOLD = 65
    %define CONFIRMATION_THRESHOLD_INT 5
  %elif CONFIRMATION_THRESHOLD = 70
    %define CONFIRMATION_THRESHOLD_INT 6
  %elif CONFIRMATION_THRESHOLD = 75
    %define CONFIRMATION_THRESHOLD_INT 7
  %elif CONFIRMATION_THRESHOLD = 80
    %define CONFIRMATION_THRESHOLD_INT 8
  %elif CONFIRMATION_THRESHOLD = 85
    %define CONFIRMATION_THRESHOLD_INT 9
  %elif CONFIRMATION_THRESHOLD = 90
    %define CONFIRMATION_THRESHOLD_INT 10
  %elif CONFIRMATION_THRESHOLD = 95
    %define CONFIRMATION_THRESHOLD_INT 11
  %elif CONFIRMATION_THRESHOLD = 100
    %define CONFIRMATION_THRESHOLD_INT 12
  %elif CONFIRMATION_THRESHOLD = 105
    %define CONFIRMATION_THRESHOLD_INT 13
  %elif CONFIRMATION_THRESHOLD = 110
    %define CONFIRMATION_THRESHOLD_INT 14
  %elif CONFIRMATION_THRESHOLD = 115
    %define CONFIRMATION_THRESHOLD_INT 15
  %elif CONFIRMATION_THRESHOLD = 120
    %define CONFIRMATION_THRESHOLD_INT 16
  %elif CONFIRMATION_THRESHOLD = 125
    %define CONFIRMATION_THRESHOLD_INT 17
  %elif CONFIRMATION_THRESHOLD = 130
    %define CONFIRMATION_THRESHOLD_INT 18
  %elif CONFIRMATION_THRESHOLD = 135
    %define CONFIRMATION_THRESHOLD_INT 19
  %elif CONFIRMATION_THRESHOLD = 140
    %define CONFIRMATION_THRESHOLD_INT 20
  %elif CONFIRMATION_THRESHOLD = 150
    %define CONFIRMATION_THRESHOLD_INT 21
  %elif CONFIRMATION_THRESHOLD = 160
    %define CONFIRMATION_THRESHOLD_INT 22
  %elif CONFIRMATION_THRESHOLD = 165
    %define CONFIRMATION_THRESHOLD_INT 23
  %elif CONFIRMATION_THRESHOLD = 170
    %define CONFIRMATION_THRESHOLD_INT 24
  %elif CONFIRMATION_THRESHOLD = 180
    %define CONFIRMATION_THRESHOLD_INT 25
  %elif CONFIRMATION_THRESHOLD = 190
    %define CONFIRMATION_THRESHOLD_INT 26
  %elif CONFIRMATION_THRESHOLD = 200
    %define CONFIRMATION_THRESHOLD_INT 27
  %elif CONFIRMATION_THRESHOLD = 210
    %define CONFIRMATION_THRESHOLD_INT 28
  %elif CONFIRMATION_THRESHOLD = 220
    %define CONFIRMATION_THRESHOLD_INT 29
  %elif CONFIRMATION_THRESHOLD = 230
    %define CONFIRMATION_THRESHOLD_INT 30
  %elif CONFIRMATION_THRESHOLD = 240
    %define CONFIRMATION_THRESHOLD_INT 31
  %else
    %error Invalid confirmation threshold specified.
  %endif
%endif

; Format of a colour byte:
;   bits 0..3: foreground colour
;   bit  4   : set to make the text blink
;   bits 5..7: all these bits are set
;
; For example, to make a text yellow and blinking: VID_YELLOW | VID_BLINK
%define VID_BLACK       0xE0
%define VID_BLUE        0xE1
%define VID_GREEN       0xE2
%define VID_CYAN        0xE3
%define VID_RED         0xE4
%define VID_MAGENTA     0xE5
%define VID_BROWN       0xE6
%define VID_WHITE       0xE7
%define VID_GRAY        0xE8
%define VID_LT_BLUE     0xE9
%define VID_LT_GREEN    0xEA
%define VID_LT_CYAN     0xEB
%define VID_LT_RED      0xEC
%define VID_LT_MAGENTA  0xED
%define VID_YELLOW      0xEE
%define VID_LT_WHITE    0xEF
%define VID_BLINK       0x10

%define MSR_IA32_APIC_BASE  0x01B
%define STD_APIC_BASE       0x0FEE00000

%define APIC_APICID         0x00000020
%define APIC_ICRLO          0x00000300

%ifndef BF_VERSION
  %define BF_VERSION 'x.x'
%endif

%ifndef LOAD_SEGMENT
  %define LOAD_SEGMENT 0x3000
%endif

%define BARE_BUILD      0   ; bare build (default)
%define ISA_ROM_BUILD   1   ; build with ISA Option ROM header
%define PCI_ROM_BUILD   2   ; build with PCI Option ROM header
%define INJECTION_BUILD 3   ; build for code injection: put a ROM in front of the bootfid binary

%ifdef BUILD_TYPE
  %ifidni BUILD_TYPE,'bare'
    %define BUILD_TYPE_CODE BARE_BUILD
  %elifidni BUILD_TYPE,'isa'
    %define BUILD_TYPE_CODE ISA_ROM_BUILD
  %elifidni BUILD_TYPE,'pci'
    %define BUILD_TYPE_CODE PCI_ROM_BUILD
  %elifidni BUILD_TYPE,'injection'
    %define BUILD_TYPE_CODE INJECTION_BUILD
  %else
    %error Unknown build type.
  %endif
%else
  %define BUILD_TYPE_CODE BARE_BUILD
%endif

%ifndef INJECTION_OFFSET
  %define INJECTION_OFFSET 3
%endif

%macro SHOWMSG16 1
  push    si
  mov     si,%1
  call    ShowStr16
  pop     si
%endmacro

%macro SHOWMSG16NoCPU 1
  push    bp
  mov     bp,0x200
  push    si
  mov     si,%1
  call    ShowStr16
  pop     si
  pop bp
%endmacro

%macro SHOWMSG32 1
  push    esi
  mov     esi,%1
  call    ShowStr32
  pop     esi
%endmacro

%macro PREPARE_FS 0
  xor     ax,ax
  mov     fs,ax
  mov     ax,[fs:0x413]     ; Number of kbytes of conventional RAM
  dec     ax
  shl     ax,6              ; Change to paragraphs
  mov     fs,ax             ; fs:0000 = last kbyte of conventional RAM
%endmacro

%macro PREPARE_DS 0
  mov     ax,cs
  mov     ds,ax
%endmacro


; ==============================================================================
; Several useful protected-mode macros
; ==============================================================================

%macro PMODE_ENTER 0
  mov     ax,fs
  mov     ds,ax
  cli
  lgdt    [DAT_GDTLIMIT]
  mov     eax,cr0
  or      al,1
  mov     cr0,eax
  jmp     DWORD 0x08:%%PModeEntry

BITS 32
%%PModeEntry:
  ; Prepare segment registers
  mov     ax,0x010
  mov     ds,ax             ; DS base = image base
  mov     ax,0x018
  mov     es,ax             ; ES base = 0
  mov     ax,0x020
  mov     fs,ax             ; FS base = last kb of RAM
%endmacro

%macro PMODE_LEAVE 0
  jmp     0x28:%%BackTo16Bit
BITS 16
%%BackTo16Bit:
  mov     ax,0x30
  mov     ds,ax
  mov     es,ax
  mov     fs,ax
  mov     gs,ax
  mov     ss,ax

  mov     eax,cr0
  and     al,0xFE
  mov     cr0,eax

  jmp     LOAD_SEGMENT:%%BackToRM
%%BackToRM:
  PREPARE_DS
  PREPARE_FS
%endmacro


; ==============================================================================
; Several other various macros
; ==============================================================================

%macro CMOS_WRITE 2
  pushfd
  cli
  mov     al,0x80 + %1
  out     0x70,al
  mov     al,%2
  out     0x71,al
  mov     al,0x00
  out     0x70,al
  popfd
%endmacro

%macro CMOS_READ 1
  pushfd
  cli
  mov     al,0x80 + %1
  out     0x70,al
  in      al,0x71
  mov     ah,al
  mov     al,0x00
  out     0x70,al
  mov     al,ah
  popfd
%endmacro

%macro X_CMOS_WRITE 2
  mov     al,%1
  out     0x72,al
  mov     al,%2
  out     0x73,al
%endmacro

%macro X_CMOS_READ 1
  mov     al,%1
  out     0x72,al
  in      al,0x73
%endmacro

%macro X_CMOS_RESET_INDEX 0
  mov     al,0
  out     0x72,al
%endmacro


; ==============================================================================
; Header (for ISA option ROM, PCI option ROM, ...)
; ==============================================================================

; BUILD_TYPE_CODE = BARE_BUILD       =>  no header
; BUILD_TYPE_CODE = ISA_ROM_BUILD    =>  ISA Option ROM header
; BUILD_TYPE_CODE = PCI_ROM_BUILD    =>  PCI Option ROM header
; BUILD_TYPE_CODE = INJECTION_BUILD  =>  put a ROM in front of the bootfid binary which starts with a special header

org 0x0
BITS 16

SMPBOOT_Start:

%if BUILD_TYPE_CODE = ISA_ROM_BUILD || BUILD_TYPE_CODE = PCI_ROM_BUILD
  db      0x55
  db      0xAA
  db      (SMPBOOT_End - SMPBOOT_Start + 511) / 512 ; Size, in 512-byte blocks
  jmp     SHORT BSP_Entry
  db      0 ; checksum, to be filled in later
%endif

%if BUILD_TYPE_CODE = PCI_ROM_BUILD
  times (0x18 + $$ - $) db 0
  dw      PCI_Data_Struct
  dw      PnP_Header

  PCI_Data_Struct:
  db      'PCIR'       ; PCI header signature
  dw      0x10EC       ; Vendor Id
  dw      0x8139       ; Device Id
;  dw      0x1000       ; Vendor Id
;  dw      0x0003       ; Device Id
;  dw      0xB0, 0x07   ; Vendor Id
;  dw      0xF1, 0xD0   ; Device Id
  dw      0            ; Pointer to Vital Product Data
  dw      0x18         ; PCI Data Structure Length
  db      0            ; PCI Data Structure Revision
  db      0x2          ; Base Class Code, 0x2 == Network Controller
  db      0            ; Sub Class Code = 00h and interface = 00h -->Ethernet Controller
  db      0            ; Interface Code, see PCI Rev2.1 Spec Appendix D
  dw      (SMPBOOT_End - SMPBOOT_Start + 511) / 512 ; Image Length, in 512-byte blocks, little endian
  dw      25           ; Revision Level of Code/Data
  db      0            ; Code Type, 0 == x86
  db      0x80         ; Last image indicator (0x80 = last image, 0x0 = not last image)
  dw      0            ; Reserved

  PnP_Header:
  db      '$PnP'       ; PnP data structure signature
  db      1            ; PnP structure revision
  db      2            ; PnP structure length (in 16 bytes blocks)
  dw      0            ; Offset to next header (0-none)
  db      0            ; Reserved
  db      0x33         ; 8-Bit checksum for this header
  dd      0            ; Device identifier
  dw      0            ; Pointer to manufacturer string, we use empty string
  dw      0            ; Pointer to product name string, we use empty string
  db      0x2,0,0      ; Device class code    (2=network ctrlr,0=eth.)
  db      0x64         ; Device indicators (0x6h - shadowable,cacheable,notonly for boot,IPL device)
  dw      0            ; Boot Connection Vector, 0x0 = disabled
  dw      0            ; Disconnect Vector, 0x0 = disabled
  dw      0            ; Bootstrap Entry Vector (BEV), 0x0 = none
  dw      0            ; Reserved
  dw      0            ; Static resource Information vector (0x0 if unused)
%endif

%if BUILD_TYPE_CODE = INJECTION_BUILD
  incbin  ORIG_ROM_PATH
  INJ_SAV_B1    db      'X'        ; These 3 bytes will be used to store the original
  INJ_SAV_B2    db      'X'        ; 3 bytes overridden by the near jump for injection
  INJ_SAV_B3    db      'X'
  db      0            ; checksum, to be filled in later
  jmp     SHORT BSP_Entry
%endif


; ==============================================================================
; BSP code begins here
; ==============================================================================

BSP_Entry:
  ; Save the old stack
  push    fs
  PREPARE_FS
  mov     [fs:DAT_OLD_ESP],esp
  mov     [fs:DAT_OLD_SS],ss
%if EXIT_WAIT_TIME != 0
  mov     BYTE [fs:DAT_PAUSE_AT_EXIT],0
%endif
%ifdef SMBIOS
  mov     BYTE [fs:DAT_SMBIOS_STATUS],0
%endif
%ifidni FID_SET,'cmos'
  mov     BYTE [fs:DAT_BAD_CMOS_MULT],0
%endif

  ; Prepare the BSP stack
  mov     ax,fs
  sub     ax,1024/16
  mov     ss,ax
  mov     sp,1024

  ; Save registers (and prepare some others)
  pushfd
  pushad
  push    ds
  push    es
  PREPARE_DS
  cld

  ; Get the default FID
  call    GetCMOSFID

  ; Set the video mode
  mov     ax,0x0003         ; Change to mode 3 (80x25, text)
  int     0x10
  mov     ax,0x0500         ; Select page 0
  int     0x10

  ; Save the cursor style
  mov     ah,0x03
  mov     bh,0
  int     0x10
  mov     [fs:DAT_OLDCURSOR],cx

  ; Set the new cursor style (all hidden)
  mov     ah,1
  mov     cx,0x2020
  int     0x10

  call InitializeScreen

  ; Check if BOOTFID is enabled and if the FID is valid
  cmp     BYTE [fs:DAT_BOOTFID_ENABLED],1
  jne     .BOOTFIDIsDisabled

  mov     al,[fs:DAT_TARGET_FID]
  mov     cx,cs
  mov     es,cx
  ; Find the index of the current FID
  mov     cx,32
  mov     di,FIDVals
  repne   scasb
  ; if the FID is not found, we disable BOOTFID (this should never happen)
  jne     .BOOTFIDHasToBeDisabled
  ; Find the multiplier display and overwrite part of MSG_BSP_TargetMult with it (ugly part)
  neg     cl
  add     cl,31 ; cl = the multiplier position in interval [0, 31]
  mov     [fs:DAT_PREV_MULT_POS],cl
  shl     cx,3  ; cl = the relative position in bytes of the beginning of the substring to copy
  mov     si,MSG_Multipliers
  add     si,cx
  mov     di,MSG_BSP_MultOverwrite
  mov     cx,5
  rep     movsb

  SHOWMSG16 MSG_BSP_TargetMult
  jmp     .WaitForUser

.BOOTFIDHasToBeDisabled:
  mov     BYTE [fs:DAT_BOOTFID_ENABLED],0
.BOOTFIDIsDisabled:
  mov     BYTE [fs:DAT_PREV_MULT_POS],-1

%ifidni FID_SET,'cmos'
  cmp     BYTE [fs:DAT_BAD_CMOS_MULT],0
  je      .BOOTFIDIsDisabledMsg

  SHOWMSG16 MSG_BSP_BadCMOSMult
  jmp     .WaitForUser
%endif

.BOOTFIDIsDisabledMsg:
  SHOWMSG16 MSG_BSP_BFIDDisabled

.WaitForUser:
  ; Prepare timer 2
  in      al,0x61       ; set gate low
  and     al,0xFE
  out     0x61,al

  mov     al,0xB6
  out     0x43, al      ; set timer 2 mode
  mov     ax,11932      ; 100hz
  out     0x42, al      ; set timer 2 divisor LSB
  mov     al,ah
  out     0x42, al      ; set timer 2 divisor MSB

  in      al,0x61       ; set gate high
  or      al,1
  out     0x61,al

  mov     BYTE [fs:DAT_TIMER2LOCK], 0

  ; See if a key gets pressed

%ifidni FID_SET,'cmos'
  cmp     BYTE [fs:DAT_BAD_CMOS_MULT],0
  je      .NormalWaitTime

  mov     cx,SPLASH_SCREEN_WAIT_TIME_BAD_CMOS*2
  jmp     .DoTheWait
%endif
.NormalWaitTime:
  mov     cx,SPLASH_SCREEN_WAIT_TIME*2
.DoTheWait:
  in      al,0x61
  and     al,0x20
  mov     bh,al

.KeyWait:
  mov     ah,0x11
  int     0x16
  jnz     .GotAKey

  in      al,0x61
  and     al,0x20
  cmp     al,bh

  je      .KeyWait

  mov     bh,al
  dec     cx
  jnz     .KeyWait

  jmp     .GotNoKeys

.GotAKey:
  ; A keystroke has been detected using a non-blocking call that
  ; leaves the keystroke in the keyboard buffer, a blocking call
  ; is now made to remove the keystroke from the buffer
  mov     ah,0x10
  int     0x16

  cmp     ah,0x1F       ; S key
  jne     .NextKey1
%if EXIT_WAIT_TIME != 0
  mov     BYTE [fs:DAT_PAUSE_AT_EXIT],1
%endif
  call    ShowEditScreen
  jmp     .GotNoKeys
.NextKey1:
  cmp     ah,0x01       ; Esc key
  jne     .NextKey2
  jmp     .BSPDone

.NextKey2:
  ; Everything else is "continue"

.GotNoKeys:
  cmp     BYTE [fs:DAT_BOOTFID_ENABLED],1
  jne     NEAR .BSPDone

  ; One or two CPUs ?
  mov     eax,0x80000080
  mov     dx,0xcf8
  out     dx,eax
  mov     dx,0xcfc
  in      eax,dx
  not     eax
  and     eax, 0x30000
  jz      .APICCheck
  SHOWMSG16 MSG_BSP_UniProc
  jmp     .SkipAPInit

.APICCheck:
  ; See if the APIC is enabled, and try and enable it if it's not
  mov     bp,0x0100
  mov     ecx,MSR_IA32_APIC_BASE
  rdmsr
  test    eax,0x800
  jnz     .APICEn

  or      eax,0x800
  wrmsr

.APICEn:
  mov     eax,0x01
  cpuid
  test    edx,0x200         ; see if the APIC flag is enabled in CPUID
  jnz     .APICOK

  mov     bp,0x0300
  SHOWMSG16 MSG_BSP_APICNotFound
  jmp     .SkipAPInit
.APICOK:

  ; Prepare the "AP state" to be "unstarted", and tell it not to proceed
  mov     BYTE [fs:DAT_APSTATE],0
  mov     BYTE [fs:DAT_AP_PROCEED], 0

  ; Now, time to bring up the AP. First we need to create the GDT-to-be.
  mov     ax,fs
  mov     es,ax
  mov     si,GDT
  mov     di,DAT_GDT
  mov     cx,GDT_LIMIT + 1
  rep     movsb

  mov     ax,cs
  mov     dx,cs
  shl     ax,4
  shr     dx,12
  mov     [fs:DAT_GDT + 0x08 + 2],ax
  mov     [fs:DAT_GDT + 0x08 + 4],dl
  mov     [fs:DAT_GDT + 0x10 + 2],ax
  mov     [fs:DAT_GDT + 0x10 + 4],dl
  mov     [fs:DAT_GDT + 0x28 + 2],ax
  mov     [fs:DAT_GDT + 0x28 + 4],dl
  mov     [fs:DAT_GDT + 0x30 + 2],ax
  mov     [fs:DAT_GDT + 0x30 + 4],dl

  mov     ax,fs
  mov     dx,fs
  shl     ax,4
  shr     dx,12
  mov     [fs:DAT_GDT + 0x20 + 2],ax
  mov     [fs:DAT_GDT + 0x20 + 4],dl

  ; Prepare the GDT pointer
  xor     eax,eax
  mov     ax,fs
  shl     eax,4
  add     eax,DAT_GDT
  mov     [fs:DAT_GDTADDRESS],eax
  mov     WORD [fs:DAT_GDTLIMIT],GDT_LIMIT

  ; Prepare the IPI jump data
  xor     ax,ax
  mov     es,ax
  push    DWORD [es:0x1000]
  push    DWORD [es:0x1004]
  mov     eax,[cs:IPIJump]
  mov     [es:0x1000],eax
  mov     eax,[cs:IPIJump + 4]
  mov     [es:0x1004],eax
  mov     [es:0x1003],cs

  ; Prepare the "warm reboot" flag
  push    WORD [es:0x467]
  push    WORD [es:0x469]
  mov     WORD [es:0x467],AP_Entry
  mov     WORD [es:0x469],cs

  ; Set the warm reboot flag in the CMOS
  CMOS_WRITE 0x0F, 0x0A

  ; Remember the stack pointer (store it in edx, along with ss)
  mov     dx,sp
  rol     edx,16
  mov     dx,ss

  ; Create the 32-bit stack pointer (store it in ebx)
  xor     ebx,ebx
  mov     bx,ss
  shl     ebx,4
  xor     eax,eax
  mov     ax,sp
  add     ebx,eax

  ; Now, kick into pmode
  SHOWMSG16 MSG_BSP_PMEnter

  PMODE_ENTER

  ; Set up the protected-mode stack
  mov     ax,0x018
  mov     ss,ax
  mov     esp,ebx

  SHOWMSG32 MSG_BSP_APInit

  ; Get the APIC base
%ifdef STD_APIC_BASE
  mov     esi,STD_APIC_BASE
%else
  mov     ecx,MSR_IA32_APIC_BASE
  rdmsr
  and     eax,0xFFFFF000
  mov     esi,eax
%endif

  ; Get the APIC ID
  mov     eax,[es:esi + APIC_APICID]
  shr     eax,24
  mov     bp,ax
  SHOWMSG32 MSG_BSP_IAmTheBSP

  ; Get the APIC ID of the chip to wake up
  xor     al,1

  ; Bring up the AP
  lea     edi,[esi + APIC_ICRLO]
  mov     esi,IPIData
  call    APICSendIPI             ; Assert INIT
  call    APICWaitPending
  call    Wait10ms
  call    APICSendIPI             ; Deassert INIT
  call    APICWaitPending
  call    Wait10ms
  call    APICSendIPI             ; Sent STARTUP

  ; Wait for the AP to signal that it's started (wait up to 1 second)
  SHOWMSG32 MSG_BSP_APInitWait
  mov     ecx,100*2
  in      al,0x61
  and     al,0x20
  mov     ah,al
.APWait1:
  cmp     BYTE [fs:DAT_APSTATE],0
  jne     .APInitOK

  in      al,0x61
  and     al,0x20
  cmp     al,ah

  je      .APWait1

  mov     ah,al
  dec     ecx
  jnz     .APWait1

  jmp     .APInitFail

  ; Signal the AP that it should proceed, then wait for the AP to signal that
  ; it's done
.APInitOK:
  mov     BYTE [fs:DAT_AP_PROCEED], 1
  SHOWMSG32 MSG_BSP_APEndWait
.APWait2:
  cmp     BYTE [fs:DAT_APSTATE],1
  je      .APWait2
  jmp     .ExitPMode

.APInitFail:
  SHOWMSG32 MSG_BSP_APInitFail

  ; Leave protected mode
.ExitPMode:
  SHOWMSG32 MSG_BSP_PMLeave

  PMODE_LEAVE

  ; Restore the segment registers
  mov     ax,dx
  rol     edx,16
  mov     ss,ax
  mov     sp,dx

  ; Clear the warm reboot flag in the CMOS
  CMOS_WRITE 0x0F, 0x00

  ; Restore the space we used for the IPI jump and warm-reboot vector
  xor     ax,ax
  mov     es,ax
  pop     WORD [es:0x467]
  pop     WORD [es:0x469]
  pop     DWORD [es:0x1004]
  pop     DWORD [es:0x1000]

.SkipAPInit:
  call    CommonCode

  ; OK, all done so lets tidy up then exit
  SHOWMSG16 MSG_BSP_Finished

%if EXIT_WAIT_TIME != 0
  ; If the user has entered settings, we sleep for a moment
  ; so that he has enough time to read the output
  ; The user can press a key to skip the wait
  cmp     BYTE [fs:DAT_PAUSE_AT_EXIT],0
  je      .BSPDone

%if EXIT_WAIT_TIME < 0
  mov     bp,0x200
  SHOWMSG16 MSG_BSP_PressAnyKey

  mov     ah,0x10
  int     0x16
%else
  mov     cx,EXIT_WAIT_TIME*2
  in      al,0x61
  and     al,0x20
  mov     bh,al

.FinalWait:
  in      al,0x61
  and     al,0x20
  cmp     al,bh

  je      .FinalWait

  mov     bh,al
  dec     cx
  jz      .BSPDone

  mov     ah,0x11
  int     0x16
  jz      .FinalWait
  mov     ah,0x10
  int     0x16
%endif
%endif

.BSPDone:
  ; Restore the cursor and put it in the right place
  mov     ah,1
  mov     cx,[fs:DAT_OLDCURSOR]
  int     0x10

  mov     ah,2
  mov     bh,0
  mov     dl,[fs:DAT_CURSOR_X]
  mov     dh,[fs:DAT_CURSOR_Y]
  int     0x10

; Restore the 3 bytes of the original ROM overridden by
; the injection near jump
%if BUILD_TYPE_CODE = INJECTION_BUILD
  ; Restore byte 1 and byte 2
  mov     ax, [INJ_SAV_B1]
  mov     [SMPBOOT_Start + INJECTION_OFFSET], ax
  ; Restore byte 3
  mov     al, [INJ_SAV_B3]
  mov     [SMPBOOT_Start + INJECTION_OFFSET + 2], al
%endif

  ; Restore registers, etc
  pop     es
  pop     ds
  popad
  popfd

  mov     ax,[fs:DAT_OLD_SS]
  mov     ss,ax
  mov     esp,[fs:DAT_OLD_ESP]
  pop     fs

%if BUILD_TYPE_CODE = INJECTION_BUILD
  jmp     SMPBOOT_Start + INJECTION_OFFSET
%else
  retf
%endif


; ==============================================================================
; APIC code (and data)
; ==============================================================================

BITS 32

  ; IPI stuff (mask, or)
IPIJump:
  db    0xEA
  dw    AP_Entry
  dw    0
IPIData:
  dd  0xFFF00000, 0x0000C500                    ; INIT assert
  dd  0xFFF00000, 0x00008500                    ; INIT deassert
  dd  0xFFF0F800, (6 << 8) | (0x1000 >> 12)     ; STARTUP @ 0x1000

; Sends an IPI to a particular processor.
; eax = APIC ID, edi = APIC base, esi = IPI data (see above). Destroys ebx.
APICSendIPI:
  push    eax
  ; Set destination
  mov     ebx,[es:edi+0x10]
  and     ebx,0x00FFFFFF
  shl     eax,24
  or      eax,ebx
  mov     [es:edi + 0x10],eax

  ; Set interrupt data
  mov     eax,[es:edi]
  and     eax,[esi]
  or      eax,[esi+4]
  mov     [es:edi],eax
  add     esi,BYTE 8
  pop     eax
  ret

; Wait for an IPI to be signaled as "sent".
; edi = APIC base. Destroys ebx.
APICWaitPending:
  mov     ebx,[es:edi]
  test    bh,0x10
  jnz     APICWaitPending
  ret

; Waits for 10ms
; No registers affected (except the flags)
Wait10ms:
  push    eax
.WaitLo1:
  in      al,0x61
  test    al,0x20
  jnz     .WaitLo1

.WaitHi:
  in      al,0x61
  test    al,0x20
  jz      .WaitHi

.WaitLo2:
  in      al,0x61
  test    al,0x20
  jnz     .WaitLo2

  pop     eax
  ret


; ==============================================================================
; Main AP code
; ==============================================================================

BITS 16

AP_Entry:
  ; Prepare segment registers
  cli
  cld
  PREPARE_DS
  PREPARE_FS
  mov     bp,0x100

  ; Notify the BSP that we've started
  mov     BYTE [fs:DAT_APSTATE],1

  ; Wait until we're told to proceed
.ProceedWait:
  cmp     BYTE [fs:DAT_AP_PROCEED],0
  je      .ProceedWait

  ; Kick into protected mode (using the GDT set up by the BSP)
  PMODE_ENTER

  ; Get the APIC base
%ifdef STD_APIC_BASE
  mov     esi,STD_APIC_BASE
%else
  mov     ecx,MSR_IA32_APIC_BASE
  rdmsr
  and     eax,0xFFFFF000
  mov     esi,eax
%endif

  ; Get the APIC ID
  mov     ecx,[es:esi + APIC_APICID]
  shr     ecx,24
  mov     bp,cx

  ; Set up the stack
  mov     ax,[es:0x413]
  sub     ax,3
  sub     ax,cx
  shl     eax,10
  add     eax,1024
  mov     dx,0x018
  mov     ss,dx
  mov     esp,eax

  SHOWMSG32 MSG_AP_Starting
  SHOWMSG32 MSG_AP_IAmAnAP

  ; Leave protected mode
  PMODE_LEAVE
  ; Restore segment registers
  mov     eax,esp
  sub     eax,1024
  shr     eax,4
  mov     ss,ax
  mov     sp,1024

  ; OK, now we're finally ready to go
  call    CommonCode

  ; Notify the BSP that we're done and halt
  SHOWMSG16 MSG_AP_Shutdown
  mov     BYTE [fs:DAT_APSTATE],2

.Die:
  cli
  hlt
  jmp     .Die


; ==============================================================================
; Common code
; ==============================================================================

GetSpeed:
  push    edx
.SpinWait:
  mov     al,1
  xchg    [fs:DAT_TIMER2LOCK],al
  or      al,al
  jnz     .SpinWait

.WaitHi1:
  in      al,0x61
  test    al,0x20
  jz      .WaitHi1

.WaitLo1:
  in      al,0x61
  test    al,0x20
  jnz     .WaitLo1

  rdtsc
  push    eax

.WaitHi2:
  in      al,0x61
  test    al,0x20
  jz      .WaitHi2

.WaitLo2:
  in      al,0x61
  test    al,0x20
  jnz     .WaitLo2

  rdtsc
  pop     edx
  sub     eax,edx

  mov     BYTE [fs:DAT_TIMER2LOCK],0
  pop     edx
  ret

ShowSpeed:
  push    ds
  push    di
  push    edx

  ; Make a temporary copy of the string
  sub     sp,MSG_CurSpeed_LEN
  mov     di,sp
  mov     si,MSG_CurSpeed
  mov     cx,MSG_CurSpeed_LEN
  mov     ax,ss
  mov     es,ax
  rep     movsb

  ; Get the speed
  call    GetSpeed ; eax = number of ticks counted during 0.01s

  ; Get it in MHz
  mov     ecx,10000
  xor     edx,edx
  div     ecx      ; eax = number of mega-ticks/s, code below is to round to nearest
  shr     ecx,1
  cmp     edx,ecx
  jb      .SkipInc
  inc     eax      ; round up
.SkipInc:

%ifdef SMBIOS
  ; Save the frequency, it might be used to update SMBIOS tables
  mov     [fs:DAT_CPU_FREQ],ax
%endif

  ; Update the string
  mov     di,ss
  mov     ds,di
  mov     di,sp
  add     di,MSG_CurSpeed_MHzOff+3
  mov     cx,10
  xor     dx,dx

  or      ax,ax
  jz      .Zero4
  div     cx
  add     dl,'0'
  mov     [di],dl
  dec     di
  mov     dl,0

  or      ax,ax
  jz      .Zero3
  div     cx
  add     dl,'0'
  mov     [di],dl
  dec     di
  mov     dl,0

  or      ax,ax
  jz      .Zero2
  div     cx
  add     dl,'0'
  mov     [di],dl
  dec     di
  mov     dl,0

  or      ax,ax
  jz      .Zero1
  div     cx
  add     dl,'0'
  mov     [di],dl
  jmp     .DoShow

.Zero4:
  mov     BYTE [di],'0'
  dec     di
.Zero3:
  mov     BYTE [di],' '
  dec     di
.Zero2:
  mov     BYTE [di],' '
  dec     di
.Zero1:
  mov     BYTE [di],' '

.DoShow:
  mov     si,sp
  call    ShowStr16

  add     sp,MSG_CurSpeed_LEN
  pop     edx
  pop     di
  pop     ds
  ret

CommonCode:
  pushad
  call    ShowSpeed
  mov     eax,0x80000000
  CPUID
  cmp     eax,0x80000007
  jb      .NoPowerNow

  mov     eax,0x80000007
  CPUID
  test    edx,2
  jnz     .EnablePowerNow

.NoPowerNow:
  SHOWMSG16 MSG_NoPowerNow
  jmp     .ExitCommonCode

.EnablePowerNow:
  ; Enable PowerNow in the chipset if needed
  mov     eax,0x80000044
  mov     dx,0xcf8
  out     dx,eax
  mov     dx,0xcfc
  in      eax,dx
  test    al,0x1
  jnz     .SettingMult

  SHOWMSG16 MSG_EnablingPowerNow

  or      al,0x1
  out     dx,eax

.SettingMult:
  SHOWMSG16 MSG_SettingMult

  mov     eax,0x10000 + VID_CODE*256
  mov     al,[fs:DAT_TARGET_FID]
  mov     ecx,0xC0010041
  xor     edx,edx
  mov     dx,0x4E20
  wrmsr

  call    ShowSpeed

%ifdef SMBIOS

;;;; Update the SMBIOS (aka DMI) tables ;;;;

; NB: the SMBIOS update code only works if the SMBIOS
; tables (the entry point structure as well as the main
; structure) are stored in the f000 segment.

; The following versions of the SMBIOS standard are supported:
;     major version = 2
;     minor version >= 2  (because the code needs the end-of-table structure)

; The byte stored in DAT_SMBIOS_STATUS can take these values:
; 0x00: initial value, nothing has been done yet
; 0x01: offset of the previously processed structure stored in DAT_SMBIOS_STRUCT
; 0x31: (error 1) SMBIOS anchor string not found
; 0x32: (error 2) bad SMBIOS major version
; 0x33: (error 3) bad SMBIOS minor version
; 0x34: (error 4) SMBIOS structure table entry point overlaps beyond f000 segment
; 0x35: (error 5) SMBIOS structure table starts before segment f000
; 0x36: (error 6) SMBIOS structure table ends after segment f000
; 0x37: (error 7) end of SMBIOS table reached, processor structure not found

  SHOWMSG16 MSG_SMBIOS

  mov     ax,0xf000
  mov     es,ax
  mov     cl,[fs:DAT_SMBIOS_STATUS]
  cmp     cl,1
  je      .ContinueTableBrowsing
  or      cl,cl
  jnz     .SMBIOSFailureAgain

  ; Search the SMBIOS anchor string
  mov     cl,0x31  ; The error number is stored in cl in ASCII (here: error 1, anchor not found)
  xor     di,di
.SearchSMAnchor:
  ; Anchor string = "_SM_" = 0x5f4d535f
  cmp     DWORD [es:di],0x5f4d535f
  je      .SMAnchorFound
  add     di,0x10
  jnc     .SearchSMAnchor

.SMBIOSFailure:
  mov     [fs:DAT_SMBIOS_STATUS],cl
  mov     [MSG_SMBIOS_Error],cl
.SMBIOSFailureAgain:
  SHOWMSG16NoCPU MSG_Failed
  jmp     .ExitSMBIOS

.ContinueTableBrowsing:
  mov     di,[fs:DAT_SMBIOS_STRUCT]
.GoToNextStructure:
  xor     ax,ax
  mov     al,[es:di+1]
  add     di,ax
.SearchEndOfStructure:
  mov     ax,[es:di]
  inc     di
  or      ax,ax
  jnz     .SearchEndOfStructure
  inc     di        ;  Now di points to the first byte of the next stucture
  jmp     .TestSMBIOSStructure

.SMAnchorFound:
  ; Check table major and minor versions
  mov     cl,0x32
  cmp     BYTE [es:di+6],2
  jne     .SMBIOSFailure ; (error 2) bad SMBIOS major version

  mov     cl,0x33
  cmp     BYTE [es:di+7],2
  jl      .SMBIOSFailure ; (error 3) bad SMBIOS minor version

  ; Read the structure table address, and check
  ; that it starts and ends in the f000 segment
  mov     cl,0x34
  add     di,0x16
  jc      .SMBIOSFailure ; (error 4) if the anchor starts at offset fff0 (seems very unlikely !)
  mov     cl,0x35
  mov     eax,[es:di+2]
  sub     eax,0xf0000
  jb      .SMBIOSFailure ; (error 5) table starts before 000f_0000
  mov     cl,0x36
  xor     edx,edx
  mov     dx,[es:di]
  add     edx,eax        ; edx = address of the 1st byte after the table
  cmp     edx,0x10000
  jg      .SMBIOSFailure ; (error 6) table ends after 000f_ffff
  mov     di,ax          ; di = offset of the first table structure

.TestSMBIOSStructure:
  ; Check the structure type
  mov     cl,0x37
  mov     al,[es:di]
  cmp     al,127
  je      .SMBIOSFailure ; (error 7) end-of-table, processor structure not found
  cmp     al,4
  jne     .GoToNextStructure
  ; Processor structure found
  ; Check that it's a central processor
  cmp     BYTE [es:di+5],3
  jne     .GoToNextStructure
  ; Check that the socket is populated
  mov     al,[es:di+0x18]
  and     al,0x40
  jz      .GoToNextStructure

  ; Here we have to update the CPU current speed in the
  ; processor structure, but the structure is stored in
  ; the BIOS shadow RAM which is write-protected
  ; So we first have to play with MTRRs to make it
  ; writable
  ; For details, check AMD64 Architecture Programer's Manual, Volume 2: System Programming
  ; paragraph 7.9
  ; BTW, I noticed that the A7M266-D BIOS doesn't apply
  ; the same MTRR settings to the two CPUs: the shadow
  ; RAM is uncacheable (UC) for the BSP while it is set
  ; write-protected (WP) for the AP. Is this difference
  ; a mistake or intentional ?

  ; Set the bit MtrrFixDramModEn in the SYSCFG MSR to
  ; enable RdMem and WrMem bits in the MTRRs
  mov     ecx,0xc0010010
  rdmsr
  push    eax
  push    edx
  or      eax,(1<<19)
  wrmsr

  ; Set the fixed-range MTRRs to enable write access in the
  ; range 000f_0000 to 000f_7fff ...
  mov     ecx,0x26e
  rdmsr
  push    eax
  push    edx
  mov     eax,18181818h
  mov     edx,eax
  wrmsr

  ; ... and in the range 000f_8000 to 000f_ffff
  inc     ecx
  rdmsr
  push    eax
  push    edx
  mov     eax,18181818h
  mov     edx,eax
  wrmsr

  ; Write the CPU speed in the structure
  mov     ax,[fs:DAT_CPU_FREQ]
  mov     WORD [es:di+0x16],ax

  ; Restore the MTRRs settings
  pop     edx
  pop     eax
  wrmsr
  dec     ecx
  pop     edx
  pop     eax
  wrmsr
  mov     ecx,0xc0010010
  pop     edx
  pop     eax
  wrmsr

  mov     [fs:DAT_SMBIOS_STRUCT],di
  mov     BYTE [fs:DAT_SMBIOS_STATUS],1

  SHOWMSG16NoCPU MSG_Done

.ExitSMBIOS:
%endif   ; End of SMBIOS update code

.ExitCommonCode:
  popad
  ret


; ==============================================================================
; Messages
; ==============================================================================

MSG_BSP_Welcome       db  VID_LT_RED, 'BOOTFID v', BF_VERSION
%ifdef CREDITS
                      db  VID_RED, ' by M.Brown & Bogbert (2004-2010)'
%endif
                      db  13, 10, VID_WHITE
                      times 80 db '-'
                      db  0
MSG_BSP_TargetMult    db  'Target multiplier: ', VID_LT_WHITE
MSG_BSP_MultOverwrite db  '12345', VID_WHITE, 13, 10
                      db  'Press ', VID_LT_WHITE, 'S', VID_WHITE, ' to change settings or '
                      db  VID_LT_WHITE, 'Escape', VID_WHITE, ' to skip.', 13, 10
                      db  0
MSG_BSP_BFIDDisabled  db  'BOOTFID is disabled.', 13, 10
                      db  'Press ', VID_LT_WHITE, 'S', VID_WHITE, ' to enable BOOTFID and enter settings.', 13, 10
                      db  0
%ifidni FID_SET,'cmos'
MSG_BSP_BadCMOSMult   db  VID_YELLOW, "BOOTFID can't find a valid multiplier in CMOS.", 13, 10
                      db  'Press ', VID_LT_WHITE, 'S', VID_YELLOW, ' to choose a multiplier.', 13, 10
                      db  0
%endif
MSG_BSP_UniProc       db  'Only one processor detected', 13, 10, 0
MSG_BSP_APICNotFound  db  'APIC not found, continuing in uniprocessor mode', 13, 10, 0
MSG_BSP_PMEnter       db  'Entering protected mode', 13, 10, 0
MSG_BSP_IAmTheBSP     db  'I am the BSP', 13, 10, 0
MSG_BSP_APInit        db  'Bringing up AP', 13, 10, 0
MSG_BSP_PMLeave       db  'Leaving protected mode', 13, 10, 0
MSG_BSP_APInitWait    db  'Waiting for AP to initialise', 13, 10, 0
MSG_BSP_APInitFail    db  VID_LT_RED, 'AP init failed', 13, 10, 0
MSG_BSP_APEndWait     db  'Waiting for AP to finish execution', 13, 10, 0
MSG_BSP_Finished      db  'BOOTFID execution finished', 13, 10, 0
%if EXIT_WAIT_TIME < 0
MSG_BSP_PressAnyKey   db  VID_LT_WHITE | VID_BLINK, 'Press any key to continue', 13, 10, 0
%endif

MSG_AP_Starting       db  'Processor started', 13, 10, 0
MSG_AP_IAmAnAP        db  'I am an AP', 13, 10, 0
MSG_AP_Shutdown       db  'CPU halting', 13, 10, 0

MSG_CurSpeed          db  'Current speed: ', VID_LT_WHITE
MSG_CurSpeed_MHzOff   EQU $ - MSG_CurSpeed
                      db  'xxxxMHz', 13, 10, 0
MSG_CurSpeed_LEN      EQU $ - MSG_CurSpeed

MSG_EnablingPowerNow  db  'Enabling PowerNow', 13, 10, 0
MSG_SettingMult       db  'Setting multiplier', 13, 10, 0
MSG_NoPowerNow        db  'PowerNow not detected, skipping setting of multiplier', 13, 10, 0
%ifdef SMBIOS
MSG_SMBIOS            db  'Updating SMBIOS tables...', 0
MSG_Done              db  'Done', 13, 10, 0
MSG_Failed            db  VID_LT_RED, 'Failed (error '
MSG_SMBIOS_Error      db  'x)', 13, 10, 0
%endif

InitializeScreen:
  mov     ax,0xB800
  mov     es,ax
  xor     di,di
  mov     cx,80*25
  mov     ax,0x0720
  rep     stosw

  mov     BYTE [fs:DAT_CURSOR_X],0
  mov     BYTE [fs:DAT_CURSOR_Y],0
  mov     BYTE [fs:DAT_VIDEOLOCK],0
  mov     bp,0x0200

  SHOWMSG16 MSG_BSP_Welcome
  ret

ShowStr16:
  push    es
  pusha
  mov     ax,0xB800
  mov     es,ax

.SpinWait:
  mov     al,1
  xchg    [fs:DAT_VIDEOLOCK],al
  or      al,al
  jnz     .SpinWait

  ; Show which CPU we're being called from
  test    bp,0x200
  jnz     .SkipCPU
  push    ds
  push    fs
  pop     ds
  test    bp,0x100
  jnz     .UnknownCPU
  mov     DWORD [DAT_CPUNSTR],'CPU0'
  mov     ax,bp
  add     [DAT_CPUNSTR+3],al
  jmp     .ShowCPU

.UnknownCPU:
  mov     DWORD [DAT_CPUNSTR],'CPU?'
.ShowCPU:
  mov     WORD [DAT_CPUNSTR+4],0x003A ; The two chars ':',0
  push    si
  mov     si,DAT_CPUNSTR
  call    _ShowStr16
  pop     si
  pop     ds
.SkipCPU:
  call    _ShowStr16

  mov     BYTE [fs:DAT_VIDEOLOCK],0

  popa
  pop     es
  ret

_ShowStr16:
  mov     ah,0x07
.ShowLoop:
  lodsb
  cmp     al,0
  je      NEAR .ExitShowLoop
  cmp     al,13
  je      .CR
  cmp     al,10
  je      .LF
  cmp     al,1110_0000b
  jb      .NormalChar

  ; is the blinking bit set ?
  test    al,0x10
  jnz     .Blink
  and     al,0111_1111b
.Blink:
  and     al,1000_1111b
  mov     ah,al
  jmp     .ShowLoop

.CR:
  mov     BYTE [fs:DAT_CURSOR_X],0
  jmp     .ShowLoop

  ; Determine the cursor position
.NormalChar:
  mov     bx,ax
  mov     al,[fs:DAT_CURSOR_Y]
  mov     cl,80
  mul     cl
  mov     cl,[fs:DAT_CURSOR_X]
  mov     ch,0
  add     cx,ax
  mov     ax,bx
  shl     cx,1
  mov     di,cx

  ; Store it.
  stosw

  ; Move on to the next character
  mov     cl,[fs:DAT_CURSOR_X]
  inc     cl
  mov     [fs:DAT_CURSOR_X],cl
  cmp     cl,80
  jb      .ShowLoop
  mov     BYTE [fs:DAT_CURSOR_X],0
.LF:
  mov     cl,[fs:DAT_CURSOR_Y]
  inc     cl
  mov     [fs:DAT_CURSOR_Y],cl
  cmp     cl,25
  jb      .ShowLoop

  ; Scroll up one line
.ScrollUp:
  push    si
  push    ds
  mov     bh,ah
  mov     ax,es
  mov     ds,ax
  mov     si,80*2
  mov     di,0
  mov     cx,80*(25-1)
  rep     movsw
  pop     ds
  pop     si

  mov     ax,0x0720
  mov     cx,80
  rep     stosw
  mov     ah,bh

  mov     cl,[fs:DAT_CURSOR_Y]
  cmp     cl,0
  je      .ShowLoop
  dec     cl
  mov     [fs:DAT_CURSOR_Y],cl
  jmp     .ShowLoop

.ExitShowLoop:
  ret

BITS 32

ShowStr32:
  push    es
  pushad
.SpinWait:
  mov     al,1
  xchg    [fs:DAT_VIDEOLOCK],al
  or      al,al
  jnz     .SpinWait

  mov     ax,0x18
  mov     es,ax

  ; Show which CPU we're being called from
  test    bp,0x200
  jnz     .SkipCPU
  push    ds
  push    fs
  pop     ds
  test    bp,0x100
  jnz     .UnknownCPU
  mov     DWORD [DAT_CPUNSTR],'CPU0'
  mov     ax,bp
  add     [DAT_CPUNSTR+3],al
  jmp     .ShowCPU

.UnknownCPU:
  mov     DWORD [DAT_CPUNSTR],'CPU?'
.ShowCPU:
  mov     WORD [DAT_CPUNSTR+4],0x003A ; The two chars ':',0
  push    esi
  mov     esi,DAT_CPUNSTR
  call    _ShowStr32
  pop     esi
  pop     ds
.SkipCPU:
  call    _ShowStr32

  mov     BYTE [fs:DAT_VIDEOLOCK],0

  popa
  pop     es
  ret

_ShowStr32:
  mov     ah,0x07
.ShowLoop:
  lodsb
  cmp     al,0
  je      NEAR .ExitShowLoop
  cmp     al,13
  je      NEAR .CR
  cmp     al,10
  je      .LF
  cmp     al,1110_0000b
  jb      .NormalChar

  ; is the blinking bit set ?
  test    al,0x10
  jnz     .Blink
  and     al,0111_1111b
.Blink:
  and     al,1000_1111b
  mov     ah,al
  jmp     .ShowLoop

.CR:
  mov     BYTE [fs:DAT_CURSOR_X],0
  jmp     .ShowLoop

  ; Determine the cursor position
.NormalChar:
  mov     bx,ax
  mov     al,[fs:DAT_CURSOR_Y]
  mov     cl,80
  mul     cl
  mov     cl,[fs:DAT_CURSOR_X]
  mov     ch,0
  add     cx,ax
  mov     ax,bx
  shl     cx,1
  movzx   edi,cx
  add     edi,0xB8000

  ; Store it.
  stosw

  ; Move on to the next character
  mov     cl,[fs:DAT_CURSOR_X]
  inc     cl
  mov     [fs:DAT_CURSOR_X],cl
  cmp     cl,80
  jb      .ShowLoop
  mov     BYTE [fs:DAT_CURSOR_X],0
.LF:
  mov     cl,[fs:DAT_CURSOR_Y]
  inc     cl
  mov     [fs:DAT_CURSOR_Y],cl
  cmp     cl,25
  jb      .ShowLoop

  ; Scroll up one line
.ScrollUp:
  push    esi
  push    ds
  mov     bh,ah
  mov     ax,es
  mov     ds,ax
  mov     esi,0xB8000 + 80*2
  mov     edi,0xB8000
  mov     cx,80*(25-1)
  rep     movsw
  pop     ds
  pop     esi

  mov     ax,0x0720
  mov     cx,80
  rep     stosw
  mov     ah,bh

  mov     cl,[fs:DAT_CURSOR_Y]
  cmp     cl,0
  je      .ShowLoop
  dec     cl
  mov     [fs:DAT_CURSOR_Y],cl
  jmp     .ShowLoop

.ExitShowLoop:
  ret

BITS 16

GDT:
    dd  0x00000000, 0x00000000 ; Null descriptor                  00
    dd  0x0000FFFF, 0x00CF9800 ; code segment, 32-bit, 4GB        08 (cs)
    dd  0x0000FFFF, 0x00CF9200 ; data segment, 32-bit, 4GB        10 (ds, ss)
    dd  0x0000FFFF, 0x00CF9200 ; data segment, 32-bit, 0 to 4GB   18 (es)
    dd  0x0000FFFF, 0x00CF9200 ; data segment, 32-bit, 4GB        20 (fs)
    dd  0x0000FFFF, 0x00009E00 ; code segment, 16-bit, 64KB       28 (cs16)
    dd  0x0000FFFF, 0x00009200 ; data segment, 16-bit, 64KB       30 (ds16, es16)
    ;     BBBBLLLL    BB-L--BB
    ;     33221100    77665544
    GDT_LIMIT equ $ - GDT - 1


; ==============================================================================
; Code to get and edit the multiplier setting
; ==============================================================================

GetCMOSFID:
%ifidni FID_SET,'cmos'
  cli
  X_CMOS_READ CMOS_BYTE_1
  mov     ah,al
%if CMOS_BYTE_2 != 0
  X_CMOS_READ CMOS_BYTE_2
  sub     al,0x55
  cmp     al,ah
  jne     .CMOS_failure
%endif
  and     al,1111111b
  cmp     al,0x1F
  jnbe    .CMOS_failure
  mov     [fs:DAT_TARGET_FID],al

  shr     ah,7
  mov     [fs:DAT_BOOTFID_ENABLED],ah
  X_CMOS_RESET_INDEX
  ret

  .CMOS_failure:
  mov     BYTE [fs:DAT_BAD_CMOS_MULT],1
  mov     BYTE [fs:DAT_TARGET_FID],DEFAULT_FID
  mov     BYTE [fs:DAT_BOOTFID_ENABLED],0
  X_CMOS_RESET_INDEX
%else
  mov     BYTE [fs:DAT_TARGET_FID],FID_CODE
  mov     BYTE [fs:DAT_BOOTFID_ENABLED],BOOTFID_ENABLED
%endif
  ret

%ifidni FID_SET,'cmos'
SetCMOSFID:
  cli

%if CMOS_CHECKSUM_LO != 0
  push    dx

  ; Old checksum in dx
  X_CMOS_READ CMOS_CHECKSUM_HI
  mov    dh,al
  X_CMOS_READ CMOS_CHECKSUM_LO
  mov    dl,al

  ; Subtract from the old checksum in dx the old CMOS values
  xor    ah,ah
  X_CMOS_READ CMOS_BYTE_1
  sub   dx,ax

%if CMOS_BYTE_2 != 0
  X_CMOS_READ CMOS_BYTE_2
  sub   dx,ax
%endif ; end cmos byte2
%endif ; end checksum

  ; Compute the new CMOS values and store them
  mov     ah,[fs:DAT_TARGET_FID]
  mov     al,[fs:DAT_BOOTFID_ENABLED]
  shl     al,7
  xor     ah,al

  X_CMOS_WRITE CMOS_BYTE_1, ah

%if CMOS_BYTE_2 != 0
  add     ah,0x55
  X_CMOS_WRITE CMOS_BYTE_2, ah
%endif ; end cmos byte2

%if CMOS_CHECKSUM_LO != 0
  ; Add the new CMOS values to the checksum in dx
  xor     ah,ah
  add     dx,ax

%if CMOS_BYTE_2 != 0
  sub     al,0x55
  add     dx,ax
%endif ; end cmos byte2

  ; Write the new checksum in CMOS
  X_CMOS_WRITE CMOS_CHECKSUM_HI, dh
  X_CMOS_WRITE CMOS_CHECKSUM_LO, dl

  pop     dx
%endif ; end checksum

  X_CMOS_RESET_INDEX
  ret
%endif ; end cmos

ShowEditScreen:
  pusha

.ResetEditScreen:
  call InitializeScreen

  ; Get rid of the "CPU<n>:" part
  mov     bp,0x200

  ; Show the intro message and the multipliers
  SHOWMSG16 MSG_EditIntro
  SHOWMSG16 MSG_Multipliers

  ; Find the start location of the multiplier table
  xor     cx,cx
  mov     ax,80
  mov     cl,[fs:DAT_CURSOR_Y]
  sub     cl,5
  mul     cx
  mov     cl,[fs:DAT_CURSOR_X]
  add     ax,cx
  shl     ax,1
  mov     si,ax

  ; Get the current FID code
  mov     al,[fs:DAT_TARGET_FID]

.KeyLoop:
  mov     cx,cs
  mov     es,cx
  ; Find the index of the current FID
  mov     cx,32
  mov     di,FIDVals
  repne   scasb
  jne     .FIDNotFound
  mov     ah,cl
  neg     ah
  add     ah,31
  jmp     .FIDFound

.FIDNotFound:
  mov     ax,DEFAULT_FID

  ; Highlight the current FID
  ; al = FID
  ; ah = multiplier position (integer in [0, 31])
.FIDFound:
  mov     cx,0xB800
  mov     es,cx

  xor     cx,cx
  mov     di,si
.HighlightLoop:
  mov     dl,0x07
  mov     dh,8
  cmp     cl,ah
  jne     .Dehighlight
  mov     dl,0xA0
.Dehighlight:
  inc     di
  mov     [es:di],dl
  inc     di
  dec     dh
  jnz     .Dehighlight
  inc     cl
  test    cl,7
  jnz     .HighlightLoop
  add     di,32
  cmp     cl,32
  jne     .HighlightLoop

  ; Wait for the next key
.GetKey:
  push    ax
  mov     ah,0x10
  int     0x16
  cmp     ax,0x48E0     ; Up
  je      .KeyUp
  cmp     ax,0x50E0     ; Down
  je      .KeyDown
  cmp     ax,0x4BE0     ; Left
  je      .KeyLeft
  cmp     ax,0x4DE0     ; Right
  je      .KeyRight
  cmp     ax,0x1C0D     ; Enter
  je      NEAR .Apply
  cmp     ax,0xe00D     ; Keypad enter
  je      .Apply
  cmp     ah,0x01       ; Escape
  je      NEAR .Skip
  cmp     ax,0x3F00     ; F5
  je      NEAR .ResetSelection
%ifidni FID_SET,'cmos'
  cmp     ax,0x4400     ; F10
  je      NEAR .SaveAndApply
  cmp     ax,0x53E0     ; Del
  je      NEAR .DisableBOOTFID
  cmp     ax,0x0E08     ; Backspace
  je      NEAR .DisableBOOTFID
%endif
  pop     ax
  jmp     .GetKey

.KeyUp:
  pop     ax
  cmp     ah,8
  jb      .GetKey
  sub     ah,8
  movzx   di,ah
  add     di,FIDVals
  mov     al,[di]
  jmp     .FIDFound

.KeyDown:
  pop     ax
  cmp     ah,24
  jae     .GetKey
  add     ah,8
  movzx   di,ah
  add     di,FIDVals
  mov     al,[di]
  jmp     .FIDFound

.KeyLeft:
  pop     ax
  test    ah,7
  jz      .GetKey
  dec     ah
  movzx   di,ah
  add     di,FIDVals
  mov     al,[di]
  jmp     .FIDFound

.KeyRight:
  pop     ax
  mov     dh,ah
  and     dh,7
  cmp     dh,7
  je      .GetKey
  inc     ah
  movzx   di,ah
  add     di,FIDVals
  mov     al,[di]
  jmp     .FIDFound

.Apply:
  pop     ax
%ifdef CONFIRMATION_THRESHOLD_INT
  push    .ApplyConfirmationOk
  jmp     .ConfirmMultiplier
%endif
.ApplyConfirmationOk:
  mov     [fs:DAT_TARGET_FID],al
  mov     BYTE [fs:DAT_BOOTFID_ENABLED],1
  jmp     .ExitEditScreen

.Skip:
  pop     ax
  mov     BYTE [fs:DAT_BOOTFID_ENABLED],0
  jmp     .ExitEditScreen

.ResetSelection:
  pop     ax
  jmp     .ResetEditScreen

%ifidni FID_SET,'cmos'
.SaveAndApply:
  pop     ax
%ifdef CONFIRMATION_THRESHOLD_INT
  push    .SaveAndApplyConfirmationOk
  jmp     .ConfirmMultiplier
%endif
.SaveAndApplyConfirmationOk:
  mov     [fs:DAT_TARGET_FID],al
  mov     BYTE [fs:DAT_BOOTFID_ENABLED],1
  call    SetCMOSFID
  jmp     .ExitEditScreen

.DisableBOOTFID:
  pop     ax
  mov     BYTE [fs:DAT_BOOTFID_ENABLED],0
  call    SetCMOSFID
  jmp     .ExitEditScreen
%endif

.ExitEditScreen:
  popa
  ret

%ifdef CONFIRMATION_THRESHOLD_INT
; ah contains the position of the multiplier and the stack
; contains the address to jump to in case of success (ugly)
.ConfirmMultiplier:
  push    ax
  cmp     ah,CONFIRMATION_THRESHOLD_INT
  jb      .ConfirmationOK

  ; if a multiplier at least as big was previously enabled, no need to confirm again
  mov     cl,[fs:DAT_PREV_MULT_POS]
  cmp     ah,cl
  jng     .ConfirmationOK

  SHOWMSG16 MSG_Confirm

  mov     ah,0x10
  int     0x16
  cmp     ah,0x15       ; Y key
  je      .ConfirmationY

  ; everything else than Y is considered a no
  pop     ax
  pop     cx
  jmp     .ResetEditScreen

.ConfirmationY:
  mov     al,[fs:DAT_CURSOR_X]
  dec     al
  mov     [fs:DAT_CURSOR_X],al
  SHOWMSG16 MSG_Confirm_Y

.ConfirmationOK:
  pop     ax
  pop     cx
  jmp     cx
%endif

%ifidni FID_SET,'cmos'
MSG_EditIntro   db VID_LT_WHITE, 0x1B, 0x18, 0x19, 0x1a, VID_WHITE, ': Change selection      ',
                db VID_LT_WHITE, 'Enter', VID_WHITE, ': Apply               ', VID_LT_WHITE,
                db 'Escape', VID_WHITE, ': Skip', 13, 10
                db VID_LT_WHITE, 'F5', VID_WHITE, '  : Reset selection       ', VID_LT_WHITE
                db 'F10', VID_WHITE, '  : Save and apply      ', VID_LT_WHITE, 'Delete'
                db VID_WHITE, ': Disable', 13, 10
                db 13, 10, 0
%else
MSG_EditIntro   db VID_LT_WHITE, 0x1B, 0x18, 0x19, 0x1a, VID_WHITE, ': Change selection     '
                db VID_LT_WHITE, 'F5', VID_WHITE, ': Reset selection     ', VID_LT_WHITE
                db 'Enter', VID_WHITE, ': Apply     ', VID_LT_WHITE, 'Escape', VID_WHITE
                db ': Skip'
                db 13, 10, 0
%endif

%ifdef CONFIRMATION_THRESHOLD_INT
MSG_Confirm     db VID_LT_WHITE, 'Beware: by increasing the multiplier, you may damage your '
                db 'CPUs permanently.', 13, 10
                db 'Do you confirm the multiplier setting (Y/N)? ', VID_LT_WHITE | VID_BLINK, '_', 0
MSG_Confirm_Y   db VID_LT_WHITE, 'Y', 13, 10
                db 13, 10, 0
%endif

; 8 bytes for each multiplier, the multiplier display occupies the first 5 bytes
; the 3 remaining bytes are for spacing, padding and EOL
MSG_Multipliers db ' 3.0x    4.0x    5.0x    5.5x    6.0x    6.5x    7.0x    7.5x ', 13, 10
                db ' 8.0x    8.5x    9.0x    9.5x   10.0x   10.5x   11.0x   11.5x ', 13, 10
                db '12.0x   12.5x   13.0x   13.5x   14.0x   15.0x   16.0x   16.5x ', 13, 10
                db '17.0x   18.0x   19.0x   20.0x   21.0x   22.0x   23.0x   24.0x ', 13, 10
                db 13, 10, 0

;                       0       1       2       3       4       5       6       7
;                       8       9      10      11      12      13      14      15
;                      16      17      18      19      20      21      22      23
;                      24      25      26      27      28      29      30      31

FIDVals         db   0x10,   0x12,   0x04,   0x05,   0x06,   0x07,   0x08,   0x09
                db   0x0A,   0x0B,   0x0C,   0x0D,   0x0E,   0x0F,   0x00,   0x01
                db   0x02,   0x03,   0x14,   0x15,   0x16,   0x18,   0x1A,   0x1B
                db   0x1C,   0x1D,   0x11,   0x13,   0x17,   0x19,   0x1E,   0x1F

SMPBOOT_End:
