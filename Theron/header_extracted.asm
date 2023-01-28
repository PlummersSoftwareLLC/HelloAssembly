;-----------------------
; header_extracted.asm
; Version of header_tiny.asm with program code taken out of the header fields;
; Hand-written PE32 format headers and hash-based function import;
; Heavily borrowing techniques from Crinkler,
;   https://github.com/runestubbe/Crinkler
;
; Given N imports and M libraries, the importer pushes O(N*M) items to stack
; which are never cleaned up.  This is not anticipated to cause overflow.
;
; 2023-01-27  Theron Tarigo
;
;-----------------------

bits 32

%macro ASSERTEQ 2
%%A equ %1
%%B equ %2
times %%A-%%B db 0
times %%B-%%A db 0
%endmacro

SECTALIGN equ 0x4
FILEALIGN equ 0x4
IMGBASE equ 0x400000
%define RVA(x) ((x)-IMGBASE)

section bin progbits start=0 vstart=IMGBASE

exefile:
doshdr:
  dw "MZ"
  dw "TT"
pehdr:
  dw "PE",0                                 ; Signature = "PE",0,0
  dw 0x014C                                 ; Machine = i386
  dw 0                                      ; NumberOfSections = 0

;execpart0:
  dd 0x90909090                             ; TimeDateStamp
  dd 0x90909090                             ; PointerToSymbolTable
  dd 0x90909090                             ; NumberOfSymbols

ASSERTEQ $-pehdr,0x14
  dw 0x0140                                 ; SizeOfOptionalHeader
  dw 0xD8DE                                 ; Characteristics

ASSERTEQ $-exefile,0x1C
opthdr:
  dw 0x010B                                 ; Magic = PE32
  db 0xDA                                   ; MajorLinkerVersion

;execpart1:
  db 0x90                                   ; MinorLinkerVersion
  dd 0x90909090                             ; SizeOfCode
  dd 0x90909090                             ; SizeOfInitializedData
  dd 0x90909090                             ; SizeOfUninitializedData

ASSERTEQ $-opthdr,0x10
  dd RVA(unpacked_entry)                    ; AddressOfEntryPoint

;execpart2:
  dd 0x90909090                             ; BaseOfCode
  dd 0x90909090                             ; BaseOfData

ASSERTEQ $-opthdr,0x1C
  dd IMGBASE                                ; ImageBase
ASSERTEQ $-exefile,0x3C                     ; (overlapped fields)
ASSERTEQ 0x4,pehdr-exefile                  ; { PE hdr offset
  dd 0x4                                    ;   SectionAlignment }
  dd 0x4                                    ; FileAlignment

;execpart3:
  dd 0x9090                                 ; MajorOperatingSystemVersion
  dd 0x9090                                 ; MinorOperatingSystemVersion

ASSERTEQ $-opthdr,0x30
  dw 0x4                                    ; MajorSubsystemVersion

;execpart4:
  dw 0x9090                                 ; MinorSubsystemVersion
  dd 0x90909090                             ; Win32VersionValue
  dd 0x25C93118                             ; SizeOfImage

ASSERTEQ $-opthdr,0x3C
  dd 0x0000002C                             ; SizeOfHeaders

;execpart5:
  dd 0x90909090                             ; Checksum

ASSERTEQ $-opthdr,0x44
  dw 0x0002                                 ; Subsystem = gui
  dw 0x8906                                 ; DllCharacteristics
  dd 0x134403D8                             ; SizeOfStackReserve
  dd 0x03DA8978                             ; SizeOfStackCommit
  dd 0x0F532450                             ; SizeOfHeapReserve
  dd 0x034A14B7                             ; SizeOfHeapCommit
  dd 0x90909090                             ; LoaderFlags

ASSERTEQ $-opthdr,0x5C
  dd 0                                      ; NumberOfRvaAndSizes

regrelref equ relrefstart+0x80
%define REFREL_REG(R,N) dword[byte R+((N)-regrelref)]
%define REFREL(N) REFREL_REG(ebp,N)
%macro CALLIMPORT 1
  call REFREL(pfn %+ %1)
%endmacro

unpacked_entry:

execpart2:
    mov eax,[ebx+0xC]         ; 8B430C  [0:1] BaseOfCode
    mov eax,[eax+0xC]         ; 8B400C  [2:3]  ...
    jmp short execpart3       ; EBxx          BaseOfData

execpart3:
    mov ebp,regrelref       ; BDxxxx4000  [0:1/0:1/0] {Major/Minor}
    IMPTBLOFFSET equ importtable-regrelref          ; OperatingSystemVersion //
    lea edi,[ebp+IMPTBLOFFSET]  ; 8D7Dxx  [1/0:1]   {Major/Minor}ImageVersion

;opthdr+0x30:
    add al,0x0                ; 0400

execpart4:
    mov eax,[eax]             ; 8B00          MinorSubsystemVersion
    mov eax,[eax]             ; 8B00    [0:1] Win32VersionValue
    mov ebx,[eax+0x18]        ; 8B5818  [2:3/0] /// SizeOfImage
  importloop:
    xor ecx,ecx               ; 31C9    [1:2]  ...(SizeOfImage)
  searchloop:

;opthdr+0x3B:
    and eax,0x2C              ; 252C000000

execpart5:
    mov edx,[ebx+0x3C]        ; 8B533C  [0:2] Checksum

;opthdr+0x43
    add al,[fs:eax]           ; 640200  [3/0:1] Subsystem = gui
    push es                   ; 06      [0  ] DllCharacteristics
    mov eax,ebx               ; 89D8    [1/0]  /// SizeOfStackReserve

; EE: any value allowed
; ll: keep under 0x20

;  StacRes StacCom HeapRes HeapCom LdrFlag nRVA&sz
; EEEEEEllEEEEEEllEEEEEEllEEEEEEllEEEEJJJJ00000000
; D8
;   03441378
;           89DA
;               035024
;                     53
;                       0FB7144A
;                               03581C
;                                     EBxx

    add eax,[ebx+edx+0x78]    ; 03441378
    mov edx,ebx               ; 89DA  (add)
    add edx,[eax+0x24]        ; 035024

    push ebx                  ; 53
    movzx edx,word[edx+2*ecx] ; 0FB7144A
    add ebx,[eax+0x1C]        ; 03581C

    jmp short execpart0

execpart0:
    mov edx,[ebx+4*edx]       ; 8B1496  [0:2] TimeDateStamp
    pop ebx                   ; 5B      [  3] TimeDateStamp
    mov eax,[eax+0x20]        ; 8B4020  [0:2] PointerToSymbolTable
    add eax,ebx               ; 01D8    [3/0]     ///
    mov esi,[eax+4*ecx]       ; 033488  [1:3] NumberOfSymbols
;pehdr+0x14:
    inc eax                   ; 40      [0  ] SizeOfOptionalHeader
    add esi,ebx               ; 01DE    [1/0] Characteristics ///
    fmul dword[ebx]           ; D80B    [1/0] Magic ///
    add edx,ebx               ; 01DA    [1/0] MajorLinkerVersion

execpart1:
    xor eax,eax               ; 31C0    [0/0] MinorLinkerVersion ///
  hashloop:
    imul eax,5651       ; 69C013160000  [1:3/0:2] SizeOfCode ///
    lodsb                     ; AC      [  3] SizeOfInitializedData
    test al,al                ; 84C0    [0:1] SizeOfUninitializedData
    jmp short execpartB       ; EBxx    [2:3]  ...

execpartB:
    jnz hashloop
    inc ecx
    cmp eax,[edi]
    jne searchloop
    mov [edi],edx
    add edi,4
    push edi
    CALLIMPORT LoadLibraryA
    test eax,eax
    jz nonextlib
    mov ebx,eax
    add edi,8
    nonextlib:
    cmp di,importtable_end&0xFFFF
    jnz importloop

    ; END OF HASH LOADER
    ; eax = 0

