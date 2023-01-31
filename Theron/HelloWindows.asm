;-----------------------
; HelloWindows.asm
; "Dave's Tiny App" rewritten for maximal utilization of PE header format,
;   https://github.com/PlummersSoftwareLLC/HelloAssembly
;
; Assemble with yasm, https://yasm.tortall.net/
;   yasm -fbin -o HelloWindows.exe HelloWindows.asm
;   yasm -fbin -o HelloCompat.exe HelloWindows.asm -DWINECOMPAT
;
; 2023-01-27  396  Theron Tarigo
;                    First publication
; 2023-01-29  393  (-3 from header_tiny)
;                    Remove alignment
; 2023-01-29  391  Theron Tarigo
;             (-2)   Use wndproc arg for hWnd
; 2023-01-30  388  (-3 from header_tiny)
;
;-----------------------

%include "header_tiny.asm"

    ; header loader leaves eax = 0

    ; We don't need our own window class, we can just use STATIC
    ; and override the window's properties and wndproc.

%ifdef WINECOMPAT
    ; WINE doesn't implement the builtin classname atoms
    ; https://bugs.winehq.org/show_bug.cgi?id=49195
    ; Define it on stack instead.
    push 0x00004349
    push 0x54415453
    mov ecx,esp
%endif
    ; ARGS OF  CreateWindowExA
    push eax                  ; lpParam
    push eax                  ; hInstance
    push eax                  ; hMenu
    push eax                  ; hWndParent
    cdq
    mov dl,160
    lea ebx,[edx*3] ; 160*3
    push ebx                  ; nHeight       = 480
    add ebx,edx ; 480+160 = 0x280
    push ebx                  ; nWidth        = 640
    shl ebx,24 ; 0x80000000
    push ebx                  ; Y             = CW_USEDEFAULT
    push ebx                  ; X             = CW_USEDEFAULT
    push 0x10CF0000           ; dwStyle       = WS_VISIBLE|WS_OVERLAPPEDWINDOW
    lea edx,REFREL(AppName)
    push edx                  ; lpWindowName
%ifdef WINECOMPAT
    push ecx                  ; lpClassName
%else
    push 0xC019
%endif
    push eax                  ; dwExStyle
    ; END ARGS CreateWindowExA

    CALLIMPORT CreateWindowExA

    ; ARGS OF  UpdateWindow
    push eax                  ; hWnd
    ; END ARGS UpdateWindow

    ; ARGS OF  SetWindowLongA
    lea edx,REFREL(wndproc)
    push edx                  ; dwNewLong
    push -4                   ; nIndex = GWL_WNDPROC
    push eax                  ; hWnd
    ; END ARGS SetWindowLongA

    CALLIMPORT SetWindowLongA

    CALLIMPORT UpdateWindow

    sub esp,0x20 ; allocate 0x20 for MSG

  msgloop:
    mov edx,esp ; msg
    xor eax,eax
    push eax                  ; wMsgFilterMax
    push eax                  ; wMsgFilterMin
    push eax                  ; hWnd
    push edx                  ; lpMsg
    CALLIMPORT GetMessageA
    test eax,eax ; return value 0 means WM_QUIT
    jnz noquit
  quit:
    ; Let whatever is on the stack be the exit status.
    CALLIMPORT ExitProcess
  noquit:

    ; TranslateMessage's effects aren't used in the simple app.
    ; push esp                  ; lpMsg
    ; CALLIMPORT TranslateMessage
    push esp                  ; lpMsg
    CALLIMPORT DispatchMessageA

    jmp msgloop

relrefstart: ; 256b from here onwards are [ebp+byte] addressable

  wndproc:
    mov eax,regrelref
    pushad ; regrelref restored to eax upon popad
    mov ebp,eax
    mov eax,[esp+0x28] ; uMsg
    cmp eax,0x000F ; WM_PAINT
    ; Handles also WM_SIZE.
    ; Everything below 0x000F is also reasonable time to paint.
    ja nopaint
    cmp al,0x02 ; 0x0002 = WM_DESTROY
    je quit

    mov ebx,[esp+0x24] ; hWnd
    lea esi,REFREL(rect)

    ; ARGS OF  GetDC
    push ebx                  ; hWnd
    ; END ARGS GetDC
    CALLIMPORT GetDC

    ; Push all args ahead before calling functions.
    ; Saves from needing to save hdc from eax.

    ; ARGS OF  ReleaseDC
    push eax                  ; hDC
    push ebx                  ; hWnd
    ; END ARGS ReleaseDC

    ; ARGS OF  DrawTextA
    push 0x25                 ; format = DT_SINGLELINE|DT_CENTER|DT_VCENTER
    push esi                  ; lprc = the RECT
    push -1                   ; cchText
    lea edx,REFREL(AppName)
    push edx                  ; lpchText
    push eax                  ; hdc
    ; END ARGS DrawTextA

    ; ARGS OF  FillRect
    push 17                   ; hbr
    push esi                  ; lprc = the RECT
    push eax                  ; hDC
    ; END ARGS DrawTextA

    ; ARGS OF  GetClientRect
    push esi                  ; lpRect
    push ebx                  ; hWnd
    ; END ARGS GetClientRect

    ; ARGS OF  SetBkMode
    push 1                    ; mode = TRANSPARENT
    push eax                  ; hdc
    ; END ARGS SetBkMode

    CALLIMPORT SetBkMode

    CALLIMPORT GetClientRect

    CALLIMPORT FillRect

    CALLIMPORT DrawTextA

    CALLIMPORT ReleaseDC

    ; Fall through to DefWindowProc which will validate the rect.
  nopaint:
    popad ; Restore context, relref in eax
    ; Tail call
    jmp REFREL_REG(eax,pfnDefWindowProcA)

AppName: db "Dave's Tiny App",0

; Import table rules
;   Table must be followed by end of file, or by 4 null bytes.
;   Library name must occupy 8 bytes, zero-padded as needed.
;   Each library name must be followed by at least one hash.
;     (remember this when debugging)

importtable:
; kernel32
  pfnLoadLibraryA:
    dd 0x71761F00
  pfnExitProcess:
    dd 0x32955300

db "user32",0,0
  pfnCreateWindowExA:
    dd 0xF9C6B200
  pfnSetWindowLongA:
    dd 0x0B616900
  pfnUpdateWindow:
    dd 0x03687B00
  pfnGetMessageA:
    dd 0x83311D00
; pfnTranslateMessage:
;   dd 0xEA661C00
  pfnDispatchMessageA:
    dd 0x2EFBB200
  pfnDefWindowProcA:
    dd 0xB9C56D00
  pfnGetDC:
    dd 0x59D3C300
  pfnReleaseDC:
    dd 0xF2749D00
  pfnGetClientRect:
    dd 0x63EE0600
  pfnFillRect:
    dd 0x04AAE600
  pfnDrawTextA:
    dd 0xA18D6B00

db "gdi32",0,0,0
  pfnSetBkMode:
    dd 0xE1789D00

section bss nobits vfollows=bin

rect: resd 4

