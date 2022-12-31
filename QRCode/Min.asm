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

ClassName    	db "X", 0			; The name of our Window class
AppName		db "Dave's App", 0		; The name of our main window

WindowClass	WNDCLASSEX { SIZEOF WNDCLASSEX, CS_HREDRAW or CS_VREDRAW, WndProc, 0, 0, 0, IDI_APPLICATION, 0, COLOR_3DSHADOW + 1, 0, ClassName, IDI_APPLICATION };

;-------------------------------------------------------------------------------------------------------------------
.CODE						; Here is where the program itself lives
;-------------------------------------------------------------------------------------------------------------------

; 
; MainEntry - The traditional signature for the main entry point of a Windows programa
;
Start:

MainEntry proc

	LOCAL	msg:MSG
	LOCAL	hwnd:HWND
	LOCAL   hInst:HINSTANCE

	push	NULL				; Get the instance handle of our app (NULL means ourselves)
	call 	GetModuleHandle			; GetModuleHandle will return instance handle in EAX
	mov	WindowClass.hInstance, eax			; Our instance handle
	mov     eax, hInst
	    
	push	IDI_APPLICATION				; Use the default application icon
	push	NULL	
	call 	LoadIcon
	mov	WindowClass.hIcon, eax
	mov	WindowClass.hIconSm, eax

	push	IDC_ARROW				; Get the default "arrow" mouse cursor
	push	NULL
	call	LoadCursor
	mov	WindowClass.hCursor, eax

	lea	eax, WindowClass
	push	eax
	call	RegisterClassEx				; Register the window class 

	push	NULL					; Bonus data, but we have none, so null
	push	hInst				; Our app instance handle
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

	cmp		eax, 0					; When GetMessage returns 0, it's time to exit
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

MainEntry endp

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

	lea		eax, ps					; WM_PAINT received
	push	eax
	push	hWnd
	call	BeginPaint				; Go get a device context to paint into
	mov		hdc, eax

	push	TRANSPARENT
	push	hdc
	call	SetBkMode				; Make text have a transparent background

	lea		eax, rect				; Figure out how big the client area is so that we
	push	eax					;   can center our content over it
	push	hWnd
	call	GetClientRect

	mov		eax,80
	mov		rect.top, eax

	push	DT_CENTER + DT_WORDBREAK + DT_EDITCONTROL
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

	xor		eax, eax				; Return 0 as no further processing needed
	ret

NotWMPaint:
	
	push	lParam
	push	wParam
	push	uMsg
	push	hWnd
	call	DefWindowProc				; Forward message on to default processing and
	ret						;   return whatever it does

WndProc endp

END Start						; Specify entry point, else _WinMainCRTStartup is assumed
 
