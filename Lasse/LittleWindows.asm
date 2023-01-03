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
; //              Jan-02-2023   Lasse Hauballe Jensen aka. Fenrik
; //                              Further optimization (No includes or variables needed. Only .code section left)
; //
; // Note: Please avoid assembler macros such as if-then or invoke so
; //       that the code remains fully transparent!
; //
; //---------------------------------------------------------------------------

; A shellcoders approach to creating the tiny Windows application. The shellcoding
; technique was learned from Offensive Security's Exploit Developer Course

; It now also includes a small egghunter for regaining access to the "ebp". The egg is called "DAVEDAVE"

; We need to dynamically load kernel32 (already loaded), user32, and gdi32
; We then need to obtain the address for the following functions:
;
; LoadLibraryA          ebp+10                  (kernel32.dll)
; ExitProcess 	        ebp+14			(kernel32.dll)
; GetModuleHandle       ebp+18			(kernel32.dll)
; GetCommandLineA 	ebp+1c			(kernel32.dll)
; GetStartupInfoA 	ebp+20			(kernel32.dll)
; LoadIconA 		ebp+24			(user32.dll)
; LoadCursorA 		ebp+28  		(user32.dll)
; RegisterClassExA 	ebp+2c			(user32.dll)
; CreateWindowExA 	ebp+30			(user32.dll)
; UpdateWindow 		ebp+34			(user32.dll)
; GetMessageA 		ebp+38			(user32.dll)
; TranslateMessage 	ebp+3c			(user32.dll)
; DispatchMessageA 	ebp+40			(user32.dll)
; PostQuitMessage 	ebp+44			(user32.dll)
; BeginPaint	        ebp+48			(user32.dll)
; GetClientRect 	ebp+4c			(user32.dll)
; DrawTextA 		ebp+50			(user32.dll)
; EndPaint      	ebp+54			(user32.dll)
; DefWindowProcA 	ebp+58			(user32.dll)
; SetBkMode 		ebp+5c			(gdi32.dll)

; Global variables
; hInstance             ebp+60
; CommandLine           ebp+64

; How to build
; ml /coff LittleWindows.asm -link /subsystem:windows
;  or, for example. if you need to specify include path to windows.inc:
; ml /coff /I c:\masm32\include LittleWindows.asm -link /subsystem:windows

; Compiler directives and includes

.386						; Full 80386 instruction set and mode
.model flat, stdcall				; All 32-bit and later apps are flat. Used to include "tiny, etc"
option casemap:none				; Preserve the case of system identifiers but not our own, more or less

;-------------------------------------------------------------------------------------------------------------------
.CODE						; Here is where the program itself lives
;-------------------------------------------------------------------------------------------------------------------
; Setting up our own stack frame
start proc
mov ebp, esp
        add esp, 0ffffff10h                     ; 0xf0 (240 bytes) is more than enough space on the stack for our variables
        mov eax, 045564144h                     ; DAVE spelled backward moved into eax
        mov [ebp+8h], eax                       ; DAVE placed in EBP
        mov [ebp+0ch], eax                      ; DAVE placed again, right thereafter spelling: DAVEDAVE. This will be our "egg" later
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
        mov [ebp-8h], eax                       ; Save eax for later

find_function_loop:
        jecxz find_function_finished            ; If ecx is zero, jump to find_function_finished
        dec ecx                                 ; decrement ecx
        mov eax, [ebp-8h]                       ; Restore AddressOfNames VMA
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

compute_hash_finished:

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
        mov [ebp+ecx], eax                      ;
        sub ecx, 0fffffffch                     ; increase ecx by 4 (size of dword), and avoid nullbytes
        ret

; An egghunter is a small bit of code, that we can use to brute-force search the stack for a given value: DAVEDAVE
egghunter:
        mov edi, ebp                            ; Our current ebp, which is not pointing correctly
        mov eax, 045564144h                     ; DAVE
find_egg:
        inc edi                                 ; increase address by 1
        cmp dword ptr ds:[edi], eax             ; cmp dword at edi with eax
        jne find_egg                            ; run again, if not found
        add edi, 4                              ; increase edi by 4
        cmp dword ptr ds:[edi], eax             ; cmp for the next instance of our egg
        jne find_egg                            ; run again, if not found
matched:
        mov ebx, edi                            ; move edi into ebx
        sub ebx, 0ch                            ; adjust ebx
        ret


; we use the ror13 hash for the name of the API functions to not push the whole string of the api onto the stack,
; example: https://medium.com/asecuritysite-when-bob-met-alice/ror13-and-its-linkage-to-api-calls-within-modules-c2191b35161d
resolve_symbols_kernel32:
        mov cl, 10h                             ; ECX will be used as an index to where on ebp the function address will be stored
        push 0ec0e4e8eh                         ; LoadLibararyA hash
        call find_function                      ; call find_function
        push 073e2d87eh                         ; ExitProcess hash
        call find_function
        push 0d3324904h                         ; GetModuleHandleA hash
        call find_function
        push 036ef7370h                         ; GetCommandLineA hash
        call find_function
        push 0867ae3d7h                         ; GetStartupInfoA hash
        call find_function

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
        push 0cba6c0cfh                         ; LoadCursorA hash
        call find_function
        push 051e20ccah                         ; RegisterClassExA hash
        call find_function
        push 084454941h                         ; CreateWindowExA hash
        call find_function
        push 0c2bfd83fh                         ; UpdateWindow hash
        call find_function
        push 07ac67bedh                         ; GetMessageA hash
        call find_function
        push 08fde2c7eh                         ; TranslateMessage hash
        call find_function
        push 0690a1701h                         ; DispatchMessageA hash
        call find_function
        push 04be0469dh                         ; PostQuitMessage hash
        call find_function
        push 02c1b37cch                         ; BeginPaint hash
        call find_function
        push 0157f8399h                         ; GetClientRect hash
        call find_function
        push 093296cbdh                         ; DrawTextA hash
        call find_function
        push 0c72d2386h                         ; EndPaint hash
        call find_function
        push 0b9a87723h                         ; DefWindowProcA hash
        call find_function

load_gdi32:                                     ; push gdi32.dll onto the stack in reverse order
        xor eax, eax                            ; set eax to zero (\0 byte)
        mov al, 6ch                             ; l
        push eax
        push 06c642e32h                         ; 2.dl
        push 033696447h                         ; gdi3
        push esp
        call dword ptr[ebp+10h]                 ; Call LoadLibraryA to load gdi32.dll

resolve_symbols_gdi32:
        mov ebx, eax                            ; ebx = base address of gdi32.dll
        push 0f1f6d8e6h                         ; SetBKMode hash
        call find_function                      ; Call find_function

MainEntry:
        ; GetModuleHandleA
        xor eax, eax                            ; eax = zero
        push eax                                ; Push eax to the stack
        call dword ptr[ebp+18h]                 ; Call GetModuleHandleA
        mov [ebp+60h], eax                      ; hInstance is saved

        ; GetCommandLineA
        call dword ptr[ebp+1ch]                 ; Call GetCommandLineA
        mov [ebp+64h], eax                      ; commandLineStr is saved

        ; GetStartupInfoA
        add esp,0FFFFFFBCh                      ; Setting up stack for STARTUPINFO structure of size
        push esp                                ; Pointer to struct
        call dword ptr[ebp+20h]                 ; Call GetStartupInfoA
        mov eax, [esp+30h]                      ; Save sui.dwFlags
        xor ecx, ecx                            ; ecx = zero
        inc ecx                                 ; ecx = 1
        test eax, ecx                           ; Find out if wShowWindow should be used
	jz @1
        mov eax, [esp+2ch]                      ; dwFlags is located at esp+0x2c
	push ax	                   		; If the show window flag bit was nonzero, we use wShowWindow
	jmp @2
@1:
	push 0ah			        ; Use the default
@2:
        sub esp,0FFFFFFBCh                      ; clean up stack
        push [ebp+64h]                          ; CommandlineStr
        xor eax, eax                            ; null
        push eax
        push [ebp+60h]                          ; hInstance

WinMain:
        ; LoadIconA
        push	7F00h				; Use the default application icon  IDI_APPLICATION = 7F00h
        xor eax, eax
        push	eax	                        ; null
        call 	dword ptr[ebp+24h]              ; Call LoadIconA
        mov [ebp+68h], eax                      ; Save handle

        ; LoadCursorA
        push 7F00h                              ; Use the default cursor
	xor eax, eax
        push	eax	                        ; null
        call dword ptr[ebp+28h]                 ; Call LoadCursorA
        mov [ebp+28h], eax                      ; Save handle

        ; MyWinClass String pushed in reverse order in hex
        xor eax, eax
        mov ax, 07373h
        push eax
        push 0616c436eh
        push 06957794dh
        mov [ebp+6ch], esp                      ; Save pointer to string

        ; Dave's Tiny App pushed in reverse order in hex
        xor eax, eax
        push eax
        push 0707041h
        push 020796e69h
        push 054207327h
        push 065766144h
        mov [ebp+70h], esp                      ; Save pointer to string

        ; Setting up structure and calling RegisterClassEx
        push [ebp+68h]                          ; hIconSm
        push [ebp+6ch]                          ; lpszClassName
        xor eax, eax
        push eax                                ; lpszMenuName
        push 16+1                               ; hbrBackground COLOR_BTNSHADOW (16) + 1 Default brush colors are color plus one
        push [ebp+28h]                          ; hCursor
        push [ebp+68h]                          ; hIcon
        push [ebp+60h]                          ; hInstance
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
        call dword ptr[ebp+2ch]                 ; Register the window class

        ; Setting up stack and calling CreateWindowExA
        xor eax, eax                            ; lpParam null
        push eax
        push [ebp+60h]                          ; hinstance
        push eax                                ; hMenu null
        push eax                                ; hWndParent
        push 480                                ; nWidth
        push 640                                ; nHeight
        push 080000000h                         ; Y using CW_USEDEFAULT
        push 080000000h                         ; X using CW_USEDEFAULT
        push 010CF0000h                         ; dwStyle using  WS_OVERLAPPEDWINDOW + WS_VISIBLE
        push [ebp+70h]                          ; The Window title
        push [ebp+6ch]                          ; The window ClassName
        push eax                                ; dwExStyle = null
        call dword ptr[ebp+30h]                 ; Call CreateWindowExA

        cmp eax, 0
        je WinMainRet
        mov [ebp+74h], eax                      ; Window handle returned
        push eax
        call dword ptr[ebp+34h]                 ; UpdateWindow is called

MessageLoop:
        xor ecx, ecx                            ; ecx = Null
        push ecx
        push ecx
        push ecx
        lea eax, [ebp-1ch]                      ; pointer to MSG struct
        push eax
        call dword ptr[ebp+38h]                 ; Call GetMessageA

        cmp eax, 0                              ; cmp result from GetMessageA with zero
        je DoneMessages                         ; If 0, go to DoneMessages

        lea eax, [ebp-1ch]                      ; pointer to MSG struct
        push eax
        call dword ptr[ebp+3ch]                 ; Call TranslageMessage

        lea eax, [ebp-1ch]                      ; pointer to MSG struct
        push eax
        call dword ptr[ebp+40h]                 ; Call dispatchMessage

        jmp MessageLoop

DoneMessages:
        mov eax, dword ptr [ebp-14h]            ; Set eax to address of wParam of Msg struct

; WinMainRet usually returns to MainEntry, where ExitProcess is called. Atm. we have lost our return address, so exit is just called from here.
WinMainRet:
        ;Terminate process
        xor eax, eax
        push eax                                ; Exit Code
        call dword ptr[ebp+14h]                 ; Call ExitProcess

WndProc: ; hWnd:ebp+8, uMsg:ebp+0c, wParam:ebp+10, lParam:ebp+14
        call egghunter                          ; ebp is incorrect at this point. We call our egghunter function to reposition it, and place it into ebx
        push ebp                                ; We adheare to rules of stdcall.
        mov ebp, esp                            ; we setup a new stack frame
        add esp, 0FFFFFFACh                     ; We need 84 bytes of space

        cmp dword ptr[ebp+0ch], 00002h          ; cmp uMSG with WM_DESTROY = 0x0002
        jne NotWMDestroy

        push 0
        call dword ptr[ebx+44h]                 ; Call PostQuitMessage
        xor eax, eax
        leave                                   ; this cleans up our 4 arguments.
        ret 10h                                 ; We have to specify this, since the compiler won't do it for us.

NotWMDestroy: ; ps struct @ ebp-40 // rect struct @ ebp-50 // hdc @ edp-54
        cmp dword ptr[ebp+0ch], 0000Fh          ; cmp uMsg WM_PAINT
        jne NotWMPaint

        lea eax, [ebp-40h]                      ; pointer to ps struct
        push eax
        push [ebp+8h]                           ; hWnd
        call dword ptr[ebx+48h]                 ; call BeginPaint
        mov [ebp-54h], eax                      ; eax is moved into hdc
        push 1                                  ; TRANSPARENT
        push dword ptr[ebp-54h]                 ; hdc is pushed
        call dword ptr[ebx+5ch]                 ; Call setBkMode

        lea eax, [ebp-50h]                      ; rect
        push eax                                ;
        push dword ptr [ebp+8]                  ; push hWnd
        call dword ptr [ebx+4ch]                ; Call GetClientRect

        push 25h                                ; DT_SINGLELINE + DT_CENTER + DT_VCENTER
        lea eax, [ebp-50h]                      ; rect
        push eax                                ;
        push 0FFFFFFFFh                         ; -1
        push [ebx+70h]                          ; AppName
        push [ebp-54h]                          ; hdc
        call dword ptr [ebx+50h]                ; DrawText

        lea eax, [ebp-40h]                      ; pointer to ps struct
        push eax
        push [ebp+8h]                           ; hWnd
        call dword ptr[ebx+54h]                 ; Call endPaint

        xor eax, eax                            ; return code
        leave                                   ; this cleans up our 4 arguments.
        ret 10h                                 ; We have to specify this, since the compiler won't do it for us.

NotWMPaint:
        push [ebp+14h]                          ; lParam
        push [ebp+10h]                          ; wParam
        push [ebp+0ch]                          ; uMsg
        push [ebp+8h]                           ; hWnd
        call dword ptr[ebx+58h]                 ; call DefWindowProc
        leave
        ret 10h                                 ; this cleans up our 4 arguments, but causes null bytes. Should be fixed

END start				        ; Specify entry point, else _WinMainCRTStartup is assumed