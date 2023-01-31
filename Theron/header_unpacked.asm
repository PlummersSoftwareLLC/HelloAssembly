;-----------------------
; header_unpacked.asm
; Hand-written PE32 format headers and hash-based function import;
; All notes on header packing removed to better illustrate importer;
; Heavily borrowing techniques from Crinkler,
;   https://github.com/runestubbe/Crinkler
;
; See header_tiny.asm for history.
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
  dw 0x0158                                 ; SizeOfOptionalHeader
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
    ; upon entry, ebx points to the PEB
    mov eax,[ebx+0xC]  ; PEB->Ldr
    mov eax,[eax+0xC]  ; Ldr->InMemoryOrderModuleList

    mov ebp,regrelref   ; Set up base pointer for REFREL
    IMPTBLOFFSET equ importtable-regrelref
    lea edi,[ebp+IMPTBLOFFSET]; Ready for the first import hash

    add al,0x0                ; header constrained

    mov eax,[eax]             ; Flink to 1st module, NtDll
    mov eax,[eax]             ; Flink to 2nd module, Kernel32
    mov ebx,[eax+0x18]        ; Entry->DllBase (Kernel32 in ebx)
  importloop:                 ; iterate over imports
    xor ecx,ecx               ; start, namenumber = 0
  searchloop:                 ; iterate over names

    and eax,0x2C              ; header constrained, useful for next constraint

    mov edx,[ebx+0x3C]        ; PE signature offset

    add al,[fs:eax]           ; header constrained, eax<=0x2C
    push es                   ; header constrained
    mov eax,ebx               ; (module address base)

    add eax,[ebx+edx+0x78]    ; Export Table
    mov edx,ebx               ; (module address base)
    add edx,[eax+0x24]        ; AddressOfNameOrdinals

    push ebx                  ; (module address base)
    movzx edx,word[edx+2*ecx] ; NameOrdinals[namenumber](offset)
    add ebx,[eax+0x1C]        ; AddressOfFunctions(address)

    mov edx,[ebx+4*edx]       ; Functions[ordinal](offset)
    pop ebx                   ; (restore)
    mov eax,[eax+0x20]        ; AddressOfNames(offset)
    add eax,ebx               ; AddressOfNames(address)
    mov esi,[eax+4*ecx]       ; Names[namenumber](offset)
    pop eax                   ; header constrained, undoes constrained push es
    add esi,ebx               ; Names[namenumber](address)
    fmul dword[ebx]           ; header constrained
    add edx,ebx               ; Functions[ordinal](address)

    xor eax,eax               ; begin hashing
  hashloop:
    imul eax,5651
    lodsb
    test al,al
    jnz hashloop              ; done on null termination

    inc ecx                   ; next exported name
    cmp eax,[edi]             ; compare to hash in importtable
    jne searchloop            ; try again
    mov [edi],edx             ; replace hash with resolved address
    scasd                     ; next import (edi+=4)
    push edi                  ; try the next table entry as a library name
    CALLIMPORT LoadLibraryA
    test eax,eax
    jz nonextlib              ; not found => it wasn't a library name at all
    mov ebx,eax               ; found -> start importing from this module
    ; module will be page aligned, thus al=0
    mov cl,0xFF
    repne scasb               ; scan past end of library name
    dec edi                   ; move to null byte (first byte of hash)
    nonextlib:
    ; eax=0 unless a module was just loaded
    cmp eax,[edi] ; if next hash is zero (or by bad luck, coincides module)
    jne importloop            ; more hashes to import

    ; END OF HASH LOADER
    ; eax = 0

