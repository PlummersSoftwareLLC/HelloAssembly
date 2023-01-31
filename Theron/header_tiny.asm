;-----------------------
; header_tiny.asm
; Hand-written PE32 format headers and hash-based function import;
; Program code is packed into sections of headers which are found to be unused
; according to various published materials.
; Heavily borrowing techniques from Crinkler,
;   https://github.com/runestubbe/Crinkler
;
; SizeOfOptionalHeader has two possibilities:
;   0x0158  pop eax / add...  Requires minimum file size 0x0158+0x1C = 372
;     Importer frees its own usage of the stack.
;   0x0140  inc eax / add...  Requires minimum file size 0x0140+0x1C = 348
;     Given N imports and M exports per imported library,
;     the importer pushes O(N*M) items to the stack which are never popped.
;     This is not anticipated to cause overflow for the tiny number of imports
;     in any 348-371 bytes small executable.
;     (20KB stack consumed for the 15 imports of HelloWindows)
;
; Sizes: header+importer+LoadLibraryA hash
; 2023-01-27  160  Theron Tarigo
;                    First publication
; 2023-01-29  157  (from suggestion by qkumba)
;             (-3)   add edi,4*n -> times n scasd
;
;-----------------------

bits 32

%macro ASSERTEQ 2
%%A equ %1
%%B equ %2
times %%A-%%B db 0
times %%B-%%A db 0
%endmacro

IMGBASE equ 0x400000
%define RVA(x) ((x)-IMGBASE)

section bin progbits start=0 vstart=IMGBASE

; Overlapped data/executable notation:
;   Values ignored by PE loader:  written instructions, bytes in comments
; Values significant to loader:   written bytes, disassembly in comments

exefile:
doshdr:
  dw "MZ"
  dw "TT"
pehdr:
  dw "PE",0                                 ; Signature = "PE",0,0
  dw 0x014C                                 ; Machine = i386
  dw 0                                      ; NumberOfSections = 0

execpart0:
    mov edx,[ebx+4*edx]       ; 8B1496  [0:2] TimeDateStamp
    pop ebx                   ; 5B      [  3] TimeDateStamp
    mov eax,[eax+0x20]        ; 8B4020  [0:2] PointerToSymbolTable
    add eax,ebx               ; 01D8    [3/0]     ///
    mov esi,[eax+4*ecx]       ; 033488  [1:3] NumberOfSymbols

ASSERTEQ $-pehdr,0x14
  dw 0x0158   ; pop eax / add...              SizeOfOptionalHeader
  dw 0xD8DE   ; esi,ebx / fmul...             Characteristics

ASSERTEQ $-exefile,0x1C
opthdr:
  dw 0x010B   ; dword[ebx] / add...           Magic = PE32
  db 0xDA     ; edx,ebx                       MajorLinkerVersion
execpart1:
    xor eax,eax               ; 31C0    [0/0] MinorLinkerVersion ///
  hashloop:
    imul eax,5651       ; 69C013160000  [1:3/0:2] SizeOfCode ///
    lodsb                     ; AC      [  3] SizeOfInitializedData
    test al,al                ; 84C0    [0:1] SizeOfUninitializedData
    jmp short execpartB       ; EBxx    [2:3]  ...

ASSERTEQ $-opthdr,0x10
  dd RVA(execpart2)                         ; AddressOfEntryPoint

execpart2:
    mov eax,[ebx+0xC]         ; 8B430C  [0:1] BaseOfCode
    mov eax,[eax+0xC]         ; 8B400C  [2:3]  ...
    jmp short execpart3       ; EBxx          BaseOfData

ASSERTEQ $-opthdr,0x1C
  dd IMGBASE                                ; ImageBase
ASSERTEQ $-exefile,0x3C                     ; (overlapped fields)
ASSERTEQ 0x4,pehdr-exefile                  ; { PE hdr offset
  dd 0x4                                    ;   SectionAlignment }
  dd 0x4                                    ; FileAlignment

execpart3:
    mov ebp,regrelref       ; BDxxxx4000  [0:1/0:1/0] {Major/Minor}
    IMPTBLOFFSET equ importtable-regrelref          ; OperatingSystemVersion //
    lea edi,[ebp+IMPTBLOFFSET]  ; 8D7Dxx  [1/0:1]   {Major/Minor}ImageVersion

ASSERTEQ $-opthdr,0x30
  dw 0x4      ; add al,0x0                    MajorSubsystemVersion

execpart4:
    mov eax,[eax]             ; 8B00          MinorSubsystemVersion
    mov eax,[eax]             ; 8B00    [0:1] Win32VersionValue
    mov ebx,[eax+0x18]        ; 8B5818  [2:3/0] /// SizeOfImage
  importloop:
    xor ecx,ecx               ; 31C9    [1:2]  ...(SizeOfImage)
  searchloop:

  db 0x25       ; and eax,              [  3]  ...(SizeOfImage)
ASSERTEQ $-opthdr,0x3C
  dd 0x0000002C ;         0x2C                SizeOfHeaders

execpart5:
    mov edx,[ebx+0x3C]        ; 8B533C  [0:2] Checksum
  db 0x64    ; fs:                      [  3]  ...

ASSERTEQ $-opthdr,0x44
  dw 0x0002  ; add al,[:::eax]                Subsystem = gui
  dw 0x8906  ; push es / mov..                DllCharacteristics
  dd 0x134403D8 ;.. eax,ebx / add eax,[ebx+edx+...        SizeOfStackReserve
  dd 0x03DA8978 ;.. 0x78] / mov edx,ebx / add...          SizeOfStackCommit
  dd 0x0F532450 ;.. edx,[eax+0x24] / push ebx / movzx...  SizeOfHeapReserve
  dd 0x034A14B7 ;.. edx,word[edx+2*ecx] / add..           SizeOfHeapCommit
  dw 0x1C58     ;.. ebx,[eax+0x1C]                  [0:1] LoaderFlags
    jmp short execpart0       ; EBxx                [2:3]  ..
ASSERTEQ $-opthdr,0x5C
  dd 0                                      ; NumberOfRvaAndSizes

regrelref equ relrefstart+0x80
%define REFREL_REG(R,N) dword[byte R+((N)-regrelref)]
%define REFREL(N) REFREL_REG(ebp,N)
%macro CALLIMPORT 1
  call REFREL(pfn %+ %1)
%endmacro

execpartB:
    jnz hashloop
    inc ecx
    cmp eax,[edi]
    jne searchloop
    mov [edi],edx
    scasd
    push edi
    CALLIMPORT LoadLibraryA
    test eax,eax
    jz nonextlib
    mov ebx,eax
    times 2 scasd
    nonextlib:
    cmp di,importtable_end-IMGBASE
    jnz importloop

    ; END OF HASH LOADER
    ; eax = 0

