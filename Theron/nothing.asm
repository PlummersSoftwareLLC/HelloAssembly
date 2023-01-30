;-----------------------
; nothing.asm
; Useful for checking minimum size of header+importer
; Note that a valid Windows exe must be at least 268 bytes.
;-----------------------

%include "header_tiny.asm"
relrefstart:
importtable:
  pfnLoadLibraryA:
    dd 0x71761F00
importtable_end:
