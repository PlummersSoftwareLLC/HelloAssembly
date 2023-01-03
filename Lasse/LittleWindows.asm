; //+--------------------------------------------------------------------------
; //
; // File:        LittleWindows.asm
; //
; // HelloWindows - (c) 2020 Plummer's Software LLC.  All Rights Reserved.
; //
; // This file is part of the Dave's Garage episode series.
; //
; //    This is an attempt to make a functional Windows app in as few bytes as
; //    possible.
; //
; //    HelloWindows is free software: you can redistribute it and/or modify
; //    it under the terms of the GNU General Public License as published by
; //    the Free Software Foundation, either version 3 of the License, or
; //    (at your option) any later version.
; //
; //    HelloWindows is distributed in the hope that it will be useful,
; //    but WITHOUT ANY WARRANTY; without even the implied warranty of
; //    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; //    GNU General Public License for more details.
; //
; //    You should have received a copy of the GNU General Public License
; //    along with Nightdriver.  It is normally found in copying.txt
; //    If not, see <https://www.gnu.org/licenses/>.
; //
; // History:     Mar-22-2021   Davepl
; //                              Created for HelloAssembly Episode
; //
; //              Dec-30-2022   Lasse Hauballe Jensen aka. Fenrik
; //                              Import table optimization
; //
; // Note: Please avoid assembler macros such as if-then or invoke so
; //       that the code remains fully transparent!
; //
; //---------------------------------------------------------------------------

; A shellcoders approach to creating the tiny Windows application. The shellcoding
; technique was learned from Offensive Security's Exploit Developer Course

; We need to dynamically load kernel32 (already loaded), user32, and gdi32
; We then need to obtain the address for the following functions:
;
; LoadLibraryA      ebp+10      (kernel32.dll)
; ExitProcess 	    ebp+14    	(kernel32.dll)
; GetModuleHandle   ebp+18    	(kernel32.dll)
; GetCommandLineA   ebp+1c    	(kernel32.dll)
; GetStartupInfoA   ebp+20    	(kernel32.dll)
; LoadIconA         ebp+24    	(user32.dll)
; LoadCursorA       ebp+28      (user32.dll)
; RegisterClassExA  ebp+2c    	(user32.dll)
; CreateWindowExA   ebp+30    	(user32.dll)
; UpdateWindow      ebp+34    	(user32.dll)
; GetMessageA       ebp+38    	(user32.dll)
; TranslateMessage  ebp+3c    	(user32.dll)
; DispatchMessageA  ebp+40    	(user32.dll)
; PostQuitMessage   ebp+44    	(user32.dll)
; BeginPaint	    ebp+48    	(user32.dll)
; GetClientRect     ebp+4c    	(user32.dll)
; DrawTextA         ebp+50    	(user32.dll)
; EndPaint          ebp+54    	(user32.dll)
; DefWindowProcA    ebp+58    	(user32.dll)
; SetBkMode         ebp+5c    	(gdi32.dll)

; Global variables and structures
; hInstance = ebp+60
; CommandLine = ebp+64
; StartupInfoA = ebp+68

; How to build
; ml /coff LittleWindows.asm
;  or, for example. if you need to specify include path to windows.inc:
; ml /coff /I c:\masm32\include LittleWindows.asm

; Compiler directives and includes

.386                            ; Full 80386 instruction set and mode
.model flat, stdcall            ; All 32-bit and later apps are flat. Used to include "tiny, etc"
option casemap:none             ; Preserve the case of system identifiers but not our own, more or less

; Include files
include windows.inc             ; Main windows header file (akin to Windows.h in C)

; Forward declarations - Our main entry point will call forward to WinMain, so we need to define it here

WinMain proto :DWORD, :DWORD, :DWORD, :DWORD	; Forward decl for MainEntry

; Uninitialized data - Basically just reserves address space
.DATA?

pEbp	        DWORD ?    	        ;  pEbp is a place on the stack that we save a lot of variables.

;-------------------------------------------------------------------------------------------------------------------
.CODE            ; Here is where the program itself lives
;-------------------------------------------------------------------------------------------------------------------
; Setting up our own stack frame
start proc
        mov ebp, esp
        add esp, 0ffffff10h                     ; 0xf0 (240 bytes) is more than enough space on the stack for our variables
        mov pEbp, ebp
start endp

; find the base address of kernel32 using the "PEB method": https://www.offensive-security.com/awe/AWEPAPERS/Skypher.pdf

find_kernel32:
        xor ecx, ecx                            ; ecx = 0
        ASSUME FS:NOTHING                       ; ml.exe doesn't like that we use the fs register, so we need to tell it to stop caring.
        mov esi, fs:[ecx+30h]                   ; Pointer to PEB
        ASSUME FS:ERROR
        mov esi, [esi+0Ch]                      ; PEB->LDR
        mov esi, [esi+1Ch]                      ; PEB->LDR->InInitOrder (a linked list)

; Loop through the loaded modules (ntdll, kernel32 and kernelbase will always be loaded)
next_module:
        mov ebx, [esi+8h]                       ; InInitOrder[X].base_address
        mov edi, [esi+20h]                      ; InInitOrder[X].module_name (unicode)
        mov esi, [esi]                          ; InInitOrder[X].flink (next module)
        cmp [edi+12*2], cx                      ; check if 12th char is \0
        jne next_module                         ; try next module
        jmp resolve_symbols_kernel32

find_function:                                  ; ebx = base address of the dll we are trying to find functions from
        pushad                                  ; push all the register onto the stack for safekeeping
        mov eax, [ebx+3ch]                      ; ebx + 0x3c = Offset to PE Signature
        mov edi, [ebx+eax+78h]                  ; edi = Export Table Directory RVA
        add edi, ebx                            ; edi = Export Table Directory VMA
        mov ecx, [edi+18h]                      ; ecx = Number of names (The number of functions in the dll)
        mov eax, [edi+20h]                      ; eax = AddressOfNames RVA
        add eax, ebx                            ; eax = AddressOfNames VMA
        mov [ebp-4h], eax                       ; Save eax for later

find_function_loop:
        jecxz find_function_finished            ; If ecx is zero, jump to find_function_finished
        dec ecx                                 ; decrement ecx
        mov eax, [ebp-4h]                       ; Restore AddressOfNames VMA
        mov esi, [eax+ecx*4h]                   ; ESI = RVA of the next function
        add esi, ebx                            ; ESI = VMA of the next function

; We start by hashing the function name
compute_hash:
        xor eax, eax                            ; eax = zero
        xor edx, edx                            ; edx = zero
        cld                                     ; clear direction flag

compute_hash_again:
        lodsb                                   ; Load next byte from ESI into AL
        test al, al                             ; Check if AL is zero (null terminator)
        jz find_function_compare                ; if zero, then we finished hashing and we will compare the hashes
        ror edx, 0dh                            ; Rotate edx by 13 bits to the right
        add edx, eax                            ; setup the next byte
        jmp compute_hash_again                  ; loop

; Once the function name is hashed, we can compare it to the hashed function name we are looking for
find_function_compare:
        cmp edx, [esp+24h]                      ; Compare the hash with the computed hash
        jnz find_function_loop                  ; If not equal, get the next function
        mov edx, [edi+24h]                      ; edx = AddressOfNameOrdinals RVA
        add edx, ebx                            ; edx = AddressOfNameOrdinals VMA
        mov cx, [edx+2h*ecx]                    ; Get the function's ordinal
        mov edx, [edi+1ch]                      ; edx = AddressOfFunctions RVA
        add edx, ebx                            ; edx = AddressOfFunctions VMA
        mov eax, [edx+4h*ecx]                   ; eax = Function RVA
        add eax, ebx                            ; eax = Function VMA (Base address of function)
        mov [esp+1ch], eax                      ; Overwrite the stack function of EAX, so this value is not lost when popad is used

find_function_finished:
        popad                                   ; restore all the registers again
        ret                                     ; return

; we use the ror13 hash for the name of the API functions to not push the whole string of the api onto the stack,
; example: https://medium.com/asecuritysite-when-bob-met-alice/ror13-and-its-linkage-to-api-calls-within-modules-c2191b35161d

resolve_symbols_kernel32:
        push 0ec0e4e8eh                         ; LoadLibararyA hash
        call find_function
        mov [ebp+10h], eax                      ; Save address of LoadLibraryA
        push 073e2d87eh                         ; ExitProcess hash
        call find_function
        mov [ebp+14h], eax                      ; Save ExitProcess
        push 0d3324904h                         ; GetModuleHandleA hash
        call find_function
        mov [ebp+18h], eax                      ; Save address of GetModuleHandleA
        push 036ef7370h                         ; GetCommandLineA hash
        call find_function
        mov [ebp+1ch], eax                      ; Save address of GetCommandLineA
        push 0867ae3d7h                         ; GetStartupInfoA hash
        call find_function
        mov [ebp+20h], eax                      ; Save address of GetStartupInfoA

load_user32:                                    ; Push the string of user32.dll onto the string in reverse order
        xor eax, eax                            ; \0
        mov ax, 06c6ch                          ; ll
        push eax
        push 0642e3233h                         ; 32.d
        push 072657375h                         ; user
        push esp
        call dword ptr[ebp+10h]                 ; Call LoadLibraryA to load user32.dll

resolve_symbols_user32:
        mov ebx, eax                            ; Load the base address of user32.dll into ebx
        push 016f8ba14h                         ; LoadIconA hash
        call find_function
        mov [ebp+24h], eax                      ; Save address of LoadIconA
        push 0cba6c0cfh                         ; LoadCursorA hash
        call find_function
        mov [ebp+28h], eax                      ; Save address of LoadCursorA
        push 051e20ccah                         ; RegisterClassExA hash
        call find_function
        mov [ebp+2ch], eax                      ; Save address of RegisterClassExA
        push 084454941h                         ; CreateWindowExA hash
        call find_function
        mov [ebp+30h], eax                      ; Save address of CreateWindowExA
        push 0c2bfd83fh                         ; UpdateWindow hash
        call find_function
        mov [ebp+34h], eax                      ; Save address of UpdateWindow
        push 07ac67bedh                         ; GetMessageA hash
        call find_function
        mov [ebp+38h], eax                      ; Save address of GetMessageA
        push 08fde2c7eh                         ; TranslateMessage hash
        call find_function
        mov [ebp+3ch], eax                      ; Save address of TranslateMessage
        push 0690a1701h                         ; DispatchMessageA hash
        call find_function
        mov [ebp+40h], eax                      ; Save address of DispatchMessageA
        push 04be0469dh                         ; PostQuitMessage hash
        call find_function
        mov [ebp+44h], eax                      ; Save address of PostQuitMessage
        push 02c1b37cch                         ; BeginPaint hash
        call find_function
        mov [ebp+48h], eax                      ; Save address of BeginPaint
        push 0157f8399h                         ; GetClientRect hash
        call find_function
        mov [ebp+4ch], eax                      ; Save address of GetClientRect
        push 093296cbdh                         ; DrawTextA hash
        call find_function
        mov [ebp+50h], eax                      ; Save address of DrawTextA
        push 0c72d2386h                         ; EndPaint hash
        call find_function
        mov [ebp+54h], eax                      ; Save address of EndPaint
        push 0b9a87723h                         ; DefWindowProcA hash
        call find_function
        mov [ebp+58h], eax                      ; Save address of DefWindowProcA

load_gdi32:                                     ; push gdi32.dll onto the stack in reverse order
        xor eax, eax                            ; set eax to zero (\0 byte)
        mov ax, 6ch                             ; l
        push eax
        push 06c642e32h                         ; 2.dl
        push 033696447h                         ; gdi3
        push esp
        call dword ptr[ebp+10h]                 ; Call LoadLibraryA to load gdi32.dll

resolve_symbols_gdi32:
        mov ebx, eax                            ; ebx = base address of gdi32.dll
        push 0f1f6d8e6h                         ; SetBKMode hash
        call find_function
        mov [ebp+5ch], eax                      ; Save address of SetBKmode

MainEntry proc
        LOCAL	sui:STARTUPINFOA
        mov ebx, [pEbp]                         ; The pointer to our stack frame

        ; GetModuleHandleA
        xor eax, eax                            ; eax = zero
        push eax                                ; Push eax to the stack
        call dword ptr[ebx+18h]                 ; Call GetModuleHandleA
        mov [ebx+60h], eax                      ; hInstance is saved

        ; GetCommandLineA
        call dword ptr[ebx+1ch]                 ; Call GetCommandLineA
        mov [ebx+64h], eax                      ; commandLineStr is saved

        ; GetStartupInfoA
        lea eax, sui                            ; Get the STARTUPINFO for this process
        push eax
        call dword ptr[ebx+20h]                 ; call GetStartupInfoA
        test sui.dwFlags, 1                     ; Find out if wShowWindow should be used
    jz @1
        push sui.wShowWindow	                ; If the show window flag bit was nonzero, we use wShowWindow
    jmp @2
@1:
    push 0ah                     	        	; Use the default
@2:
        push [ebx+64h]                          ; CommandlineStr
        xor eax, eax                            ; null
        push eax
        push [ebx+60h]                          ; hInstance

    call	WinMain

        ;Terminate process
        xor eax, eax
        push eax                                ; Exit Code
        call dword ptr[ebx+14h]                 ; Call ExitProcess

MainEntry endp

WinMain proc hInst:DWORD, hPrevInst:DWORD, CmdLine:DWORD, CmdShow:DWORD

        LOCAL msg:MSG
        mov ebx, [pEbp]                         ; ebx = pEbp, our address space for variables

        ; LoadIconA
        push	7F00h                    ; Use the default application icon  IDI_APPLICATION = 7F00h
        xor eax, eax
        push	eax	                           ; null
        call 	dword ptr[ebx+24h]              	; Call LoadIconA
        mov [ebx+68h], eax                      ; Save handle
        ; LoadCursorA
        push 7F00h                              ; Use the default cursor
        xor eax, eax
        push	eax	                        	; null
        call dword ptr[ebx+28h]                 ; Call LoadCursorA
        mov [ebx+28h], eax                      ; Save handle

        ; MyWinClass String pushed in reverse order in hex
        xor eax, eax
        mov ax, 07373h
        push eax
        push 0616c436eh
        push 06957794dh
        mov [ebx+6ch], esp                      ; Save pointer to string

        ; Dave's Tiny App pushed in reverse order in hex

        xor eax, eax
        push eax
        push 0707041h
        push 020796e69h
        push 054207327h
        push 065766144h
        mov [ebx+70h], esp                      ; Save pointer to string

        ; Setting up structure and calling RegisterClassEx

        push [ebx+68h]                          ; hIconSm
        push [ebx+6ch]                          ; lpszClassName
        xor eax, eax
        push eax                                ; lpszMenuName
        push 16+1                               ; hbrBackground COLOR_BTNSHADOW (16) + 1 Default brush colors are color plus one
        push [ebx+28h]                          ; hCursor
        push [ebx+68h]                          ; hIcon
        push [ebx+60h]                          ; hInstance
        push eax                                ; cbWndExtra = null
        push eax                                ; cbClsExtra = null
        mov eax, OFFSET WndProc                 ; lpfnWndProc
        push eax
        mov eax, 00002h OR 00001h               ; style
        push eax
        mov eax, 30h                            ; cbSize, WNDCLASSEXA size is 48 = 0x30
        push eax
        lea eax, [esp]
        push eax
        call dword ptr[ebx+2ch]                 ; Register the window class

        ; Setting up stack and calling CreateWindowExA

        xor eax, eax                            ; lpParam null
        push eax
        push [ebx+60h]                          ; hinstance
        push eax                                ; hMenu null
        push eax                                ; hWndParent
        push 480                                ; nWidth
        push 640                                ; nHeight
        push 080000000h                         ; Y using CW_USEDEFAULT
        push 080000000h                         ; X using CW_USEDEFAULT
        push 010CF0000h                         ; dwStyle using  WS_OVERLAPPEDWINDOW + WS_VISIBLE
        push [ebx+70h]                          ; The Window title
        push [ebx+6ch]                          ; The window ClassName
        push eax                                ; dwExStyle = null
        call dword ptr[ebx+30h]                 ; Call CreateWindowExA

        cmp eax, 0
        je WinMainRet
        mov [ebx+74h], eax                      ; Window handle returned
        push eax
        call dword ptr[ebx+34h]                 ; UpdateWindow is called

MessageLoop:

        xor ecx, ecx                            ; ecx = Null
        push ecx
        push ecx
        push ecx
        lea eax, msg                            ; pointer to MSG struct
        push eax
        call dword ptr[ebx+38h]                 ; Call GetMessageA

        cmp eax, 0                              ; cmp result from GetMessageA with zero
        je DoneMessages                         ; If 0, go to DoneMessages

        lea eax, msg                            ; pointer to MSG struct
        push eax
        call dword ptr[ebx+3ch]                 ; Call TranslageMessage

        lea eax, msg                            ; pointer to MSG struct
        push eax
        call dword ptr[ebx+40h]                 ; call dispatchMessage

    jmp	MessageLoop

DoneMessages:

        mov eax, msg.wParam                     ; Set eax to address of msg struct

WinMainRet:

    ret

WinMain endp


WndProc proc hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD

    LOCAL 	ps:PAINTSTRUCT            ; Local stack variables
    LOCAL	rect:RECT
    LOCAL	hdc:HDC

        mov ebx, pEbp
        cmp uMsg, 0002h                         ; cmp uMSG with WM_DESTROY = 0x0002
        jne NotWMDestroy

        push 0
        call dword ptr[ebx+44h]                 ; Call PostQuitMessage
        xor eax, eax
        ret


NotWMDestroy:

        cmp uMsg, 0000Fh                        ; cmp uMsg WM_PAINT
        jne NotWMPaint

        lea eax, ps                             ; ps
        push eax
        push hWnd                               ; hWnd
        call dword ptr[ebx+48h]                 ; call BeginPaint
        mov hdc, eax                            ; eax is moved into hdc

        push 1                                  ; TRANSPARENT
        push hdc                                ; hdc
        call dword ptr[ebx+5ch]                 ; Call setBkMode

        lea eax, rect                           ; rect
        push eax
        push hWnd
        call dword ptr[ebx+4ch]                 ; Call GetClientRect

        push 25h                                ; DT_SINGLELINE + DT_CENTER + DT_VCENTER
        lea eax, rect
        push eax
        push -1
        push [ebx+70h]                          ; AppName (Daves tiny app)
        push hdc                                ; hdc
        call dword ptr[ebx+50h]                 ; DrawText

        lea eax, ps                             ; ps
        push eax
        push hWnd                               ; hWnd
        call dword ptr[ebx+54h]                 ; call endPaint

        xor eax, eax
        ret

NotWMPaint:
        push lParam
        push wParam
        push uMsg
        push hWnd
        call dword ptr[ebx+58h]                 ; call DefWindowProc
        ret


WndProc endp

END start                        ; Specify entry point, else _WinMainCRTStartup is assumed