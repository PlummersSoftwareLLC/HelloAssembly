;-------------------------------------------------------------------------------------------------------------------
; Hello, Windows!  in x86 ASM - (c) 2021 Dave's Garage - Use at your own risk, no warranty!
;-------------------------------------------------------------------------------------------------------------------

; Compiler directives and includes

.386						; Full 80386 instruction set and mode
.model flat, stdcall				; All 32-bit and later apps are flat. Used to include "tiny, etc"
option casemap:none				; Preserve the case of system identifiers but not our own, more or less


; Include files - headers and libs that we need for calling the system dlls like user32, gdi32, kernel32, etc
include \masm32\include\windows.inc		; Main windows header file (akin to Windows.h in C)
include \masm32\include\user32.inc		; Windows, controls, etc
include \masm32\include\kernel32.inc		; Handles, modules, paths, etc
include \masm32\include\gdi32.inc		; Drawing into a device context (ie: painting)

; Libs - information needed to link ou binary to the system DLL callss

includelib \masm32\lib\kernel32.lib		; Kernel32.dll
includelib \masm32\lib\user32.lib		; User32.dll
includelib \masm32\lib\gdi32.lib		; GDI32.dll

; Forward declarations - Our main entry point will call forward to WinMain, so we need to define it here

WinMain proto :DWORD, :DWORD, :DWORD, :DWORD	; Forward decl for MainEntry 

; Constants and Datra

WindowWidth	equ 640				; How big we'd like our main window
WindowHeight	equ 480

.DATA

ClassName    	db "MyWinClass", 0		; The name of our Window class
AppName		db "Dave's Tiny App", 0		; The name of our main window

.DATA?						; Uninitialized data - Basically just reserves address space

hInstance	HINSTANCE ?			; Instance handle (like the process id) of our application
CommandLine	LPSTR	  ?                     ; Pointer to the command line text we were launched with

;-------------------------------------------------------------------------------------------------------------------
.CODE						; Here is where the program itself lives
;-------------------------------------------------------------------------------------------------------------------

MainEntry proc

	LOCAL	sui:STARTUPINFOA		; Reserve stack space so we can load and inspect the STARTUPINFO

	push	NULL				; Get the instance handle of our app (NULL means ourselves)
	call 	GetModuleHandle			; GetModuleHandle will return instance handle in EAX
	mov	hInstance, eax			; Cache it in our global variable

	call	GetCommandLineA			; Get the command line text ptr in EAX to pass on to main
	mov	CommandLine, eax

	; Call our WinMain and then exit the process with whatever comes back from it

	lea	eax, sui			; Get the STARTUPINFO for this process
	push	eax
	call	GetStartupInfoA			; Find out if wShowWindow should be used
	test	sui.dwFlags, STARTF_USESHOWWINDOW   
	jz	@1
	push	sui.wShowWindow			; If the show window flag bit was nonzero, we use wShowWindow
	jmp	@2
@1:
	push	SW_SHOWDEFAULT			; Use the default 
@2:	
	push	CommandLine
	push	NULL
	push	hInstance
	call	WinMain

	push	eax
	call	ExitProcess

MainEntry endp

; 
; WinMain - The traditional signature for the main entry point of a Windows programa
;

WinMain proc hInst:HINSTANCE, hPrevInst:HINSTANCE, CmdLine:LPSTR, CmdShow:DWORD

	LOCAL	wc:WNDCLASSEX			; Create these vars on the stack, hence LOCAL
	LOCAL	msg:MSG
	LOCAL	hwnd:HWND

	mov	wc.cbSize, SIZEOF WNDCLASSEX		; Fill in the values in the members of our windowclass
	mov	wc.style, CS_HREDRAW or CS_VREDRAW	; Redraw if resized in either dimension
	mov	wc.lpfnWndProc, OFFSET WndProc		; Our callback function to handle window messages
	mov	wc.cbClsExtra, 0			; No extra class data
	mov	wc.cbWndExtra, 0			; No exttra window data
	mov	eax, hInstance
	mov	wc.hInstance, eax			; Our instance handle
	mov	wc.hbrBackground, COLOR_3DSHADOW+1	; Default brush colors are color plus one
	mov	wc.lpszMenuName, NULL			; No app menu
	mov	wc.lpszClassName, OFFSET ClassName	; The window's class name

	push	IDI_APPLICATION				; Use the default application icon
	push	NULL	
	call 	LoadIcon
	mov	wc.hIcon, eax
	mov	wc.hIconSm, eax

	push	IDC_ARROW				; Get the default "arrow" mouse cursor
	push	NULL
	call	LoadCursor
	mov	wc.hCursor, eax

	lea	eax, wc
	push	eax
	call	RegisterClassEx				; Register the window class 

	push	NULL					; Bonus data, but we have none, so null
	push	hInstance				; Our app instance handle
	push	NULL					; Menu handle
	push	NULL					; Parent window (if we were a child window)
	push	WindowHeight				; Our requested height
	push	WindowWidth				; Our requested width
	push	CW_USEDEFAULT				; Y
	push	CW_USEDEFAULT				; X
	push	WS_OVERLAPPEDWINDOW + WS_VISIBLE	; Window stytle (normal and visible)
	push	OFFSET AppName				; The window title (our application name)
	push	OFFSET ClassName			; The window class name of what we're creating
	push	0					; Extended style bits, if any
	call 	CreateWindowExA
	cmp	eax, NULL
	je	WinMainRet				; Fail and bail on NULL handle returned
	mov	hwnd, eax				; Window handle is the result, returned in eax

	push	eax					; Force a paint of our window
	call	UpdateWindow

MessageLoop:

	push	0
	push 	0
	push	NULL
	lea	eax, msg
	push	eax
	call	GetMessage				; Get a message from the application's message queue

	cmp	eax, 0					; When GetMessage returns 0, it's time to exit
	je	DoneMessages

	lea	eax, msg				; Translate 'msg'
	push	eax
	call	TranslateMessage

	lea	eax, msg				; Dispatch 'msg'
	push	eax
	call	DispatchMessage

	jmp	MessageLoop

DoneMessages:
	
	mov	eax, msg.wParam				; Return wParam of last message processed

WinMainRet:
	
	ret

WinMain endp

;
; WndProc - Our Main Window Procedure, handles painting and exiting
;

WndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM

	LOCAL 	ps:PAINTSTRUCT				; Local stack variables
	LOCAL	rect:RECT
	LOCAL	hdc:HDC

	cmp	uMsg, WM_DESTROY
	jne	NotWMDestroy

	push	0					; WM_DESTROY received, post our quit msg
	call	PostQuitMessage				; Quit our application
	xor	eax, eax				; Return 0 to indicate we handled it
	ret

NotWMDestroy:

	cmp	uMsg, WM_PAINT
	jne	NotWMPaint

	lea	eax, ps					; WM_PAINT received
	push	eax
	push	hWnd
	call	BeginPaint				; Go get a device context to paint into
	mov	hdc, eax

	push	TRANSPARENT
	push	hdc
	call	SetBkMode				; Make text have a transparent background

	lea	eax, rect				; Figure out how big the client area is so that we
	push	eax					;   can center our content over it
	push	hWnd
	call	GetClientRect

	push	DT_SINGLELINE + DT_CENTER + DT_VCENTER
	lea	eax, rect
	push	eax
	push	-1
	push	OFFSET AppName
	push	hdc
	call	DrawText				; Draw text centered vertically and horizontally

	lea	eax, ps
	push	eax
	push	hWnd
	call	EndPaint				; Wrap up painting

	xor	eax, eax				; Return 0 as no further processing needed
	ret

NotWMPaint:
	
	push	lParam
	push	wParam
	push	uMsg
	push	hWnd
	call	DefWindowProc				; Forward message on to default processing and
	ret						;   return whatever it does

WndProc endp

END MainEntry						; Specify entry point, else _WinMainCRTStartup is assumed
 
