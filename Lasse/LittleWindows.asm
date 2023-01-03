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
; We then need to obtain the address for the Windows API functions we need.

; How to build:
;
; ml /c /coff LittleWindows.asm
; link /merge:.rdata=.text /merge:.data=.text /align:16 /subsystem:windows LittleWindows.obj

; Compiler directives and includes

include LittleWindows.inc

.386                                            ; Full 80386 instruction set and mode
.model flat, stdcall                            ; All 32-bit and later apps are flat. Used to include "tiny, etc"
option casemap:none                             ; Preserve the case of system identifiers but not our own, more or less

;-------------------------------------------------------------------------------------------------------------------
.CODE                                           ; Here is where the program itself lives
;-------------------------------------------------------------------------------------------------------------------
; Setting up our own stack frame
start proc
        mov ebp, esp
        add esp, sp_inv_main                    ; this gives 240 bytes, more than enough for our variables
        mov eax, txt_DAVE                       ; DAVE spelled backward moved into eax
        mov [ebp + sp_egg], eax                 ; DAVE placed in EBP
        mov [ebp + sp_egg + 4], eax             ; DAVE placed again, right thereafter spelling: DAVEDAVE. This will be our "egg" later
start endp

; find the base address of kernel32 using the "PEB method": https://www.offensive-security.com/awe/AWEPAPERS/Skypher.pdf
find_kernel32:
        xor ecx, ecx                            ; ecx = 0
        ASSUME FS:NOTHING                       ; ml.exe doesn't like that we use the fs register, so we need to tell it to stop caring.
        mov esi, fs:[ecx + hdr_PEB]             ; Pointer to PEB
        ASSUME FS:ERROR
        mov esi, [esi + PEB_LDR]                ; PEB->LDR
        mov esi, [esi + LDR_InInitOrder]        ; PEB->LDR->InInitOrder (a linked list)

; Loop through the loaded modules (ntdll, kernel32 and kernelbase will always be loaded)
next_module:
        mov ebx, [esi + IIO_base_address]       ; InInitOrder[X].base_address
        mov edi, [esi + IIO_module_name]        ; InInitOrder[X].module_name (unicode)
        mov esi, [esi]                          ; InInitOrder[X].flink (next module)
        cmp [edi + 12 * 2], cx                  ; check if 12th char is \0
        jne next_module                         ; try next module
        jmp resolve_symbols_kernel32

find_function:                                  ; ebx = base address of the dll we are trying to find functions from
        pushad                                  ; push all the register onto the stack for safekeeping
        mov eax, [ebx + hdr_PE]                 ; ebx + 0x3c = Offset to PE Signature
        mov edi, [ebx + eax + PE_ETD]           ; edi = Export Table Directory RVA
        add edi, ebx                            ; edi = Export Table Directory VMA
        mov ecx, [edi + ETD_NumberOfNames]      ; ecx = Number of names (The number of functions in the dll)
        mov eax, [edi + ETD_AddressOfNames]     ; eax = AddressOfNames RVA
        add eax, ebx                            ; eax = AddressOfNames VMA
        mov [ebp - lpAddressOfNames], eax

find_function_loop:
        jecxz find_function_finished            ; If ecx is zero, jump to find_function_finished
        dec ecx                                 ; decrement ecx
        mov eax, [ebp - lpAddressOfNames]
        mov esi, [eax + ecx * 4]                ; ESI = RVA of the next function
        add esi, ebx                            ; ESI = VMA of the next function

; We start by hashing the function name
compute_hash:
        xor eax, eax
        xor edx, edx
        cld                                     ; clear direction flag

compute_hash_again:
        lodsb                                   ; Load next byte from ESI into AL
        test al, al                             ; Check if AL is zero (null terminator)
        jz find_function_compare                ; if zero, then we finished hashing and we will compare the hashes
        ror edx, 13                             ; Rotate edx by 13 bits to the right
        add edx, eax                            ; setup the next byte
        jmp compute_hash_again                  ; loop

compute_hash_finished:

; Once the function name is hashed, we can compare it to the hashed function name we are looking for
find_function_compare:
        cmp edx, [esp + 24h]                    ; Compare the hash with the computed hash
        jnz find_function_loop                  ; If not equal, get the next function
        mov edx, [edi + ETD_AONOrdinals]        ; edx = AddressOfNameOrdinals RVA
        add edx, ebx                            ; edx = AddressOfNameOrdinals VMA
        mov cx, [edx + 2 * ecx]                 ; Get the function's ordinal
        mov edx, [edi + ETD_AddressOfFunctions] ; edx = AddressOfFunctions RVA
        add edx, ebx                            ; edx = AddressOfFunctions VMA
        mov eax, [edx + 4 * ecx]                ; eax = Function RVA
        add eax, ebx                            ; eax = Function VMA (Base address of function)
        mov [esp + sp_EAX], eax                 ; Overwrite the stack value of EAX, so this value is not lost when popad is used

find_function_finished:
        popad                                   ; restore all the registers again
        mov [ebp + ecx], eax                    ; save the funtion address in our table
        sub ecx, 0fffffffch                     ; increase ecx by 4 (size of dword), and avoid nullbytes
        ret

; An egghunter is a small bit of code, that we can use to brute-force search the stack for a given value: DAVEDAVE
egghunter:
        mov edi, ebp                            ; Our current ebp, which is not pointing correctly
        mov eax, txt_DAVE
find_egg:
        inc edi                                 ; increase address by 1
        cmp dword ptr ds:[edi], eax             ; check for "DAVE"
        jne find_egg                            ; loop if not found
        add edi, 4                              ; move to next 4 bytes
        cmp dword ptr ds:[edi], eax             ; check for "DAVE" again
        jne find_egg                            ; loop if not found
matched:
        mov ebx, edi                            ; put the place we found in ebx...
        sub ebx, sp_egg+4                       ; ...and adjust it
        ret

; we use the ror13 hash for the name of the API functions to not push the whole string of the api onto the stack,
; example: https://medium.com/asecuritysite-when-bob-met-alice/ror13-and-its-linkage-to-api-calls-within-modules-c2191b35161d
resolve_symbols_kernel32:
        mov cl, 10h                             ; ecx will be used as an index to where on ebp the function address will be stored

        push hash_LoadLibraryA
        call find_function

        push hash_ExitProcess
        call find_function

        push hash_GetModuleHandleA
        call find_function

        push hash_GetCommandLineA
        call find_function

        push hash_GetStartupInfoA
        call find_function

load_user32:                                    ; Push the "user32.dll" onto the string in reverse order
        push txt_ll
        push txt_32_d
        push txt_user
        push esp
        call dword ptr[ebp + fn_LoadLibraryA]

resolve_symbols_user32:
        mov ebx, eax                            ; Load the base address of user32.dll into ebx

        push hash_LoadIconA
        call find_function

        push hash_LoadCursorA
        call find_function

        push hash_RegisterClassExA
        call find_function

        push hash_CreateWindowExA
        call find_function

        push hash_UpdateWindow
        call find_function

        push hash_GetMessageA
        call find_function

        push hash_TranslateMessage
        call find_function

        push hash_DispatchMessageA
        call find_function

        push hash_PostQuitMessage
        call find_function

        push hash_BeginPaint
        call find_function

        push hash_GetClientRect
        call find_function

        push hash_DrawTextA
        call find_function

        push hash_EndPaint
        call find_function

        push hash_DefWindowProcA
        call find_function

load_gdi32:                                     ; push "gdi32.dll" onto the stack in reverse order
        push txt_l
        push txt_2_dl
        push txt_gdi3
        push esp
        call dword ptr[ebp + fn_LoadLibraryA]

resolve_symbols_gdi32:
        mov ebx, eax                            ; ebx = base address of gdi32.dll

        push hash_SetBkMode
        call find_function

MainEntry:
        ; GetModuleHandleA
        push 0                                  ; Push null to the stack
        call dword ptr[ebp + fn_GetModuleHandleA]
        mov [ebp + hInstance], eax

        ; GetCommandLineA
        call dword ptr[ebp + fn_GetCommandLineA]
        mov [ebp + lpszCommandLine], eax

        ; GetStartupInfoA
        add esp,sp_inv_STARTUPINFOA             ; Setting up stack for STARTUPINFOA structure
        push esp                                ; Pointer to struct
        call dword ptr[ebp + fn_GetStartupInfoA]
        lea eax, (STARTUPINFOA ptr [esp]).wShowWindow
        mov ecx, 1
        test eax, ecx                           ; Find out if wShowWindow should be used
	jz @1
        lea eax, (STARTUPINFOA ptr [esp]).dwFlags
	push ax	                                ; If the show window flag bit was nonzero, we use wShowWindow
	jmp @2
@1:
	push 0ah                                ; Use the default
@2:
        sub esp,sp_inv_STARTUPINFOA             ; Clean up stack
        push [ebp + lpszCommandLine]
        push 0                                  ; null
        push [ebp + hInstance]

WinMain:
        ; LoadIconA
        push IDI_APPLICATION                    ; Use the default application icon
        push 0                                  ; null
        call dword ptr[ebp + fn_LoadIconA]
        mov [ebp + hIcon], eax

        ; LoadCursorA
        push IDC_ARROW                          ; Use the default cursor
        push 0	                                ; null
        call dword ptr[ebp + fn_LoadCursorA]
        mov [ebp + hCursor], eax

        ; MyWinClass String pushed in reverse order in hex
        push txt_ss
        push txt_nCla
        push txt_MyWi
        mov [ebp + lpszClassName], esp

        ; Dave's Tiny App pushed in reverse order in hex
        push txt_App
        push txt_iny_
        push txt__s_t
        push txt_Dave_
        mov [ebp + lpszTitle], esp

        ; Setting up structure and calling RegisterClassEx
        push [ebp + hIcon]
        push [ebp + lpszClassName]
        xor eax, eax                            ; set to 0 - we'll reuse
        push 0                                  ; lpszMenuName = null
        push COLOR_BTNSHADOW+1                  ; hbrBackground - Default brush colors are color plus one
        push [ebp + hCursor]
        push [ebp + hIcon]
        push [ebp + hInstance]
        push eax                                ; cbWndExtra = 0
        push eax                                ; cbClsExtra = 0
        push OFFSET WndProc                     ; lpfnWndProc
        push CS_HREDRAW OR CS_VREDRAW           ; style
        push SIZEOF WNDCLASSEXA                 ; cbSize
        lea eax, [esp]
        push eax
        call dword ptr[ebp + fn_RegisterClassExA]

        ; Setting up stack and calling CreateWindowExA
        xor eax, eax                            ; set to 0 - we'll reuse
        push eax                                ; lpParam = null
        push [ebp + hInstance]
        push eax                                ; hMenu = null
        push eax                                ; hWndParent = null
        push 480                                ; nHeight
        push 640                                ; nWidth
        push CW_USEDEFAULT                      ; y
        push CW_USEDEFAULT                      ; x
        push WS_OVERLAPPEDWINDOW OR WS_VISIBLE  ; dwStyle
        push [ebp + lpszTitle]
        push [ebp + lpszClassName]
        push eax                                ; dwExStyle = 0
        call dword ptr[ebp + fn_CreateWindowExA]

        cmp eax, 0
        je WinMainRet
        mov [ebp + hWnd], eax
        push eax
        call dword ptr[ebp + fn_UpdateWindow]

MessageLoop:
        xor ecx, ecx                            ; set to 0
        push ecx                                ; wMsgFilterMax = 0
        push ecx                                ; wMsgFilterMin = 0
        push ecx                                ; hWnd = null
        lea eax, [ebp - sp_MSG]
        push eax
        call dword ptr[ebp + fn_GetMessageA]

        cmp eax, 0
        je DoneMessages                         ; if result was 0, we're done

        lea eax, [ebp - sp_MSG]
        push eax
        call dword ptr[ebp + fn_TranslateMessage]

        lea eax, [ebp - sp_MSG]
        push eax
        call dword ptr[ebp + fn_DispatchMessageA]

        jmp MessageLoop

DoneMessages:
        lea eax, (MSG ptr [ebp - sp_MSG]).wParam

; WinMainRet usually returns to MainEntry, where ExitProcess is called. Atm. we have lost our return address, so exit is just called from here.
WinMainRet:
        ;Terminate process
        push 0                                  ; Exit Code
        call dword ptr[ebp + fn_ExitProcess]

WndProc:
        call egghunter                          ; ebp is incorrect at this point. We call our egghunter function to reposition it, and place it into ebx
        push ebp                                ; we adheare to rules of stdcall
        mov ebp, esp                            ; we setup a new stack frame
        add esp, sp_inv_WndProc                 ; we need 84 bytes of space

        cmp dword ptr[ebp + WP_uMsg], WM_DESTROY
        jne NotWMDestroy

        push 0
        call dword ptr[ebx + fn_PostQuitMessage]
        xor eax, eax
        leave                                   ; this cleans up our 4 arguments.
        ret 10h                                 ; We have to specify this, since the compiler won't do it for us.

NotWMDestroy:
        cmp dword ptr[ebp + WP_uMsg], WM_PAINT
        jne NotWMPaint

        lea eax, [ebp - lpPaint]
        push eax
        push [ebp + WP_hWnd]
        call dword ptr[ebx + fn_BeginPaint]
        mov [ebp - hdc], eax

        push TRANSPARENT
        push dword ptr[ebp - hdc]
        call dword ptr[ebx + fn_SetBkMode]

        lea eax, [ebp - lpRect]
        push eax
        push dword ptr [ebp + WP_hWnd]
        call dword ptr [ebx + fn_GetClientRect]

        push DT_SINGLELINE OR DT_CENTER OR DT_VCENTER
        lea eax, [ebp - lpRect]
        push eax
        push 0FFFFFFFFh                         ; -1
        push [ebx + lpszTitle]
        push [ebp - hdc]
        call dword ptr [ebx + fn_DrawTextA]

        lea eax, [ebp - lpPaint]
        push eax
        push [ebp + WP_hWnd]
        call dword ptr[ebx + fn_EndPaint]

        xor eax, eax                            ; return code
        leave                                   ; this cleans up our 4 arguments.
        ret 10h                                 ; We have to specify this, since the compiler won't do it for us.

NotWMPaint:
        push [ebp + WP_lParam]
        push [ebp + WP_wParam]
        push [ebp + WP_uMsg]
        push [ebp + WP_hWnd]
        call dword ptr[ebx + fn_DefWindowProcA]
        leave
        ret 10h                                 ; this cleans up our 4 arguments, but causes null bytes. Should be fixed

END start				        ; Specify entry point, else _WinMainCRTStartup is assumed