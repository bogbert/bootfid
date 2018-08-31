; ==============================================================================
; This is the bootsector loader for the main code. it generates a 1.44MB disk
; image.
; Copyright 2004 Emboss, all rights reserved
; See licence.txt for details.
; ==============================================================================

%define LOAD_DRIVE 0x80

ORG 0x7C00
BITS 16

  jmp   0:Start

%ifndef LOAD_DRIVE
TmpSS:  dw  0
TmpSP:  dw  0
%endif

Start:
%ifndef LOAD_DRIVE
  mov   [cs:TmpSS],ss
  mov   [cs:TmpSP],sp
%endif

  ; Set up a few things
  push  cs
  pop   ss
  mov   sp,0x7C00

%ifdef LOAD_DRIVE
  push  cs
  pop   ds
  ; Relocate to 0x1000:0x7C00
  mov   si,0x7C00
  mov   ax,0x1000
  mov   es,ax
  mov   di,si
  cld
  mov   cx,512
  rep   movsb

  jmp   0x1000:FDDDataLoad
%else
  pushfd
  pushad
  push  ds
  push  es

  push  cs
  pop   ds
%endif

  ; Load the next <n> sectors into 0x3000:0x0000
FDDDataLoad:
  mov   cl,3
  push  cx
.RetryLoop:
  mov   ax,0x3000
  mov   es,ax
  xor   bx,bx
  mov   ax,0x0200 | NUMSECTORS
  mov   cx,0x0002
  xor   dx,dx
  int   0x13
  jnc   .LoadDone
  pop   cx
  dec   cl
  push  cx
  jz    .LoadFailed
  mov   ah,0
  mov   dh,0
  int   0x13
  jmp   .RetryLoop

.LoadFailed:
  ; Load failed
  mov   si,HDDFailMsg
  call  ShowMsg
  jmp   HDDBootLoad

.LoadDone:
  ; Call the loaded code
  call  0x3000:0000

HDDBootLoad:
%ifdef LOAD_DRIVE
  ; Load the first HDD sector into 0x0000:0x7C00
  mov   cl,3
.RetryLoop:
  push  cx
  xor   ax,ax
  mov   es,ax
  mov   bx,0x7C00
  mov   ax,0x0201
  mov   cx,0x0001
  mov   dx,LOAD_DRIVE
  int   0x13
  jnc   .LoadDone
  pop   cx
  dec   cl
  jnz   .RetryLoop

  ; Load failed
  mov   si,HDDFailMsg
  call  ShowMsg
.Die:
  cli
  hlt
  jmp   .Die

.LoadDone:
  jmp   0x0000:0x7C00
%else
  pop   es
  pop   ds
  popad
  popfd
  mov   ss,[cs:TmpSS]
  mov   sp,[cs:TmpSP]
  retf
%endif

ShowMsg:
  lodsb
  or    al,al
  jz    .Exit
  mov   ah,0x0E
  mov   bx,0x0007
  int   0x10
  jmp   ShowMsg
.Exit:
  ret

FDDFailMsg      db  'Could not load data from floppy disk!', 13, 10, 0
HDDFailMsg      db  'Could not load boot sector from hard disk!', 13, 10, 0

; pad with NOPs to offset 510
times (510 + $$ - $) nop
; 2-byte magic bootsector signature
db 55h, 0AAh

loaddatastart:
incbin "smpboot"
NUMSECTORS EQU ($-loaddatastart + 511)/512

%ifdef SMALL_IMG
  times (1024*16 + $$ - $) db 0
%else
  times (2880*512 + $$ - $) db 0
%endif
