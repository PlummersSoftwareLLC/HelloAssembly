; ---------------------------------------------------
;
; Variable offsets
;

; - global
hCursor                 equ 028h
hInstance               equ 060h
lpszCommandLine         equ 064h
hIcon                   equ 068h
lpszClassName           equ 06ch
lpszTitle               equ 070h
hWnd                    equ 074h
lpAddressOfNames        equ 008h

; - WndProc local
lpPaint                 equ 040h
lpRect                  equ 050h
hdc                     equ 054h

; - WndProc parameters
WP_hWnd                 equ 008h
WP_uMsg                 equ 00ch
WP_wParam               equ 010h
WP_lParam               equ 014h

; ---------------------------------------------------
;
; Functions
;

; - pointers
fn_LoadLibraryA         equ 010h
fn_ExitProcess          equ 014h
fn_GetModuleHandleA     equ 018h
fn_GetCommandLineA      equ 01ch
fn_GetStartupInfoA      equ 020h
fn_LoadIconA            equ 024h
fn_LoadCursorA          equ 028h
fn_RegisterClassExA     equ 02ch
fn_CreateWindowExA      equ 030h
fn_UpdateWindow         equ 034h
fn_GetMessageA          equ 038h
fn_TranslateMessage     equ 03ch
fn_DispatchMessageA     equ 040h
fn_PostQuitMessage      equ 044h
fn_BeginPaint           equ 048h
fn_GetClientRect        equ 04ch
fn_DrawTextA            equ 050h
fn_EndPaint             equ 054h
fn_DefWindowProcA       equ 058h
fn_SetBkMode            equ 05ch

; - hashes
hash_LoadLibraryA       equ 0ec0e4e8eh
hash_ExitProcess        equ 073e2d87eh
hash_GetModuleHandleA   equ 0d3324904h
hash_GetCommandLineA    equ 036ef7370h
hash_GetStartupInfoA    equ 0867ae3d7h
hash_LoadIconA          equ 016f8ba14h
hash_LoadCursorA        equ 0cba6c0cfh
hash_RegisterClassExA   equ 051e20ccah
hash_CreateWindowExA    equ 084454941h
hash_UpdateWindow       equ 0c2bfd83fh
hash_GetMessageA        equ 07ac67bedh
hash_TranslateMessage   equ 08fde2c7eh
hash_DispatchMessageA   equ 0690a1701h
hash_PostQuitMessage    equ 04be0469dh
hash_BeginPaint         equ 02c1b37cch
hash_GetClientRect      equ 0157f8399h
hash_DrawTextA          equ 093296cbdh
hash_EndPaint           equ 0c72d2386h
hash_DefWindowProcA     equ 0b9a87723h
hash_SetBkMode          equ 0f1f6d8e6h

; ---------------------------------------------------
;
; Header offsets
;

hdr_PEB                 equ 030h
PEB_LDR                 equ 00ch
LDR_InInitOrder         equ 01ch
IIO_base_address        equ 008h
IIO_module_name         equ 020h

hdr_PE                  equ 03ch
PE_ETD                  equ 078h
ETD_NumberOfNames       equ 018h
ETD_AddressOfNames      equ 020h
ETD_AONOrdinals         equ 024h
ETD_AddressOfFunctions  equ 01ch

; ---------------------------------------------------
;
; Text literals
;

txt_DAVE                equ 045564144h

txt_ll                  equ 000006c6ch
txt_32_d                equ 0642e3233h      ; 32.d
txt_user                equ 072657375h

txt_l                   equ 00000006ch
txt_2_dl                equ 06c642e32h      ; 2.dl
txt_gdi3                equ 033696447h

txt_ss                  equ 000007373h
txt_nCla                equ 0616c436eh
txt_MyWi                equ 06957794dh

txt_App                 equ 000707041h
txt_iny_                equ 020796e69h      ; iny 
txt__s_t                equ 054207327h      ; 's t
txt_Dave_               equ 065766144h      ; Dave

; ---------------------------------------------------
;
; Stack offsets
;

sp_main                 equ 240
sp_egg                  equ 008h
sp_EAX                  equ 01ch
sp_inv_STARTUPINFOA     equ 0ffffffbch      ; -68
sp_MSG                  equ 01ch
sp_WndProc              equ 84

; ---------------------------------------------------
;
; Windows defines
;

; - constants

IDI_APPLICATION         equ 07f00h
IDC_ARROW               equ 07f00h
COLOR_BTNSHADOW         equ 16

CS_HREDRAW              equ 00002h
CS_VREDRAW              equ 00001h

CW_USEDEFAULT           equ 080000000h

WS_OVERLAPPED           equ 0h
WS_VISIBLE              equ 10000000h
WS_CAPTION              equ 0C00000h
WS_SYSMENU              equ 80000h
WS_THICKFRAME           equ 40000h
WS_MINIMIZEBOX          equ 20000h
WS_MAXIMIZEBOX          equ 10000h
WS_OVERLAPPEDWINDOW     equ WS_OVERLAPPED OR WS_CAPTION OR WS_SYSMENU OR WS_THICKFRAME OR WS_MINIMIZEBOX OR WS_MAXIMIZEBOX

WM_DESTROY              equ 00002h
WM_PAINT                equ 0000fh

TRANSPARENT             equ 1

DT_CENTER               equ 1h
DT_VCENTER              equ 4h
DT_SINGLELINE           equ 20h

; - structs

STARTUPINFOA STRUCT
  cb              DWORD ?
  lpReserved      DWORD ?
  lpDesktop       DWORD ?
  lpTitle         DWORD ?
  dwX             DWORD ?
  dwY             DWORD ?
  dwXSize         DWORD ?
  dwYSize         DWORD ?
  dwXCountChars   DWORD ?
  dwYCountChars   DWORD ?
  dwFillAttribute DWORD ?
  dwFlags         DWORD ?
  wShowWindow     WORD ?
  cbReserved2     WORD ?
  lpReserved2     DWORD ?
  hStdInput       DWORD ?
  hStdOutput      DWORD ?
  hStdError       DWORD ?
STARTUPINFOA ENDS

POINT STRUCT
  x  DWORD ?
  y  DWORD ?
POINT ENDS

MSG STRUCT
  hwnd      DWORD      ?
  message   DWORD      ?
  wParam    DWORD      ?
  lParam    DWORD      ?
  time      DWORD      ?
  pt        POINT      <>
MSG ENDS

WNDCLASSEXA STRUCT
  cbSize            DWORD      ?
  style             DWORD      ?
  lpfnWndProc       DWORD      ?
  cbClsExtra        DWORD      ?
  cbWndExtra        DWORD      ?
  hInstance         DWORD      ?
  hIcon             DWORD      ?
  hCursor           DWORD      ?
  hbrBackground     DWORD      ?
  lpszMenuName      DWORD      ?
  lpszClassName     DWORD      ?
  hIconSm           DWORD      ?
WNDCLASSEXA ENDS
