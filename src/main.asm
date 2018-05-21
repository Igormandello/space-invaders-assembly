      .386
      .model flat, stdcall
      option casemap :none

; #########################################################################

      include \masm32\include\windows.inc
      include \masm32\include\user32.inc
      include \masm32\include\kernel32.inc
      include \masm32\include\gdi32.inc
      
      includelib \masm32\lib\user32.lib
      includelib \masm32\lib\kernel32.lib
      includelib \masm32\lib\gdi32.lib
      
; #########################################################################

      szText MACRO Name, Text:VARARG
        LOCAL lbl
          jmp lbl
            Name db Text,0
          lbl:
        ENDM

      m2m MACRO M1, M2
        push M2
        pop  M1
      ENDM
      
      return MACRO arg
        mov eax, arg
        ret
      ENDM

; #########################################################################

        WinMain PROTO :DWORD,:DWORD,:DWORD,:DWORD
        WndProc PROTO :DWORD,:DWORD,:DWORD,:DWORD
        TopXY PROTO   :DWORD,:DWORD

; #########################################################################

.data
    szDisplayName db "Space Invaders", 0
    CommandLine   dd 0
    hWnd          dd 0
    hInstance     dd 0

    header_format db "Valor Hex e : %d , %d",0
    buffer        db 256 dup(?) 
    
.data?
    txt         DB  ?
    val1  	DWORD ?
    val2  	DWORD ?
    position POINT<>

; #########################################################################

.code
    start:
        invoke GetModuleHandle, NULL ; provides the instance handle
        mov hInstance, eax

        invoke GetCommandLine        ; provides the command line address
        mov CommandLine, eax

        invoke WinMain,hInstance,NULL,CommandLine,SW_SHOWDEFAULT
        
        invoke ExitProcess,eax       ; cleanup & return to operating system

; #########################################################################

WinMain proc hInst     :DWORD,
             hPrevInst :DWORD,
             CmdLine   :DWORD,
             CmdShow   :DWORD

    LOCAL wc   :WNDCLASSEX
    LOCAL msg  :MSG

    LOCAL Wwd  :DWORD
    LOCAL Wht  :DWORD
    LOCAL Wtx  :DWORD
    LOCAL Wty  :DWORD

    szText szClassName, "Class"

    ; Fill WNDCLASSEX structure with required variables
    mov wc.cbSize,         sizeof WNDCLASSEX
    mov wc.style,          CS_HREDRAW or CS_VREDRAW \
                            or CS_BYTEALIGNWINDOW
    mov wc.lpfnWndProc,    offset WndProc      ; address of WndProc
    mov wc.cbClsExtra,     NULL
    mov wc.cbWndExtra,     NULL
    m2m wc.hInstance,      hInst               ; instance handle
    mov wc.hbrBackground,  COLOR_BTNFACE+1     ; system color
    mov wc.lpszMenuName,   NULL
    mov wc.lpszClassName,  offset szClassName  ; window class name
        invoke LoadIcon,hInst,500    ; icon ID   ; resource icon
    mov wc.hIcon,          eax
        invoke LoadCursor,NULL,IDC_ARROW         ; system cursor
    mov wc.hCursor,        eax
    mov wc.hIconSm,        0

    invoke RegisterClassEx, ADDR wc     ; register the window class

    ; Centre window at following size
    mov Wwd, 500
    mov Wht, 350

    invoke GetSystemMetrics,SM_CXSCREEN ; get screen width in pixels
    invoke TopXY,Wwd,eax
    mov Wtx, eax

    invoke GetSystemMetrics,SM_CYSCREEN ; get screen height in pixels
    invoke TopXY,Wht,eax
    mov Wty, eax

    ; Create the main application window
    invoke CreateWindowEx,WS_EX_OVERLAPPEDWINDOW,
                            ADDR szClassName,
                            ADDR szDisplayName,
                            WS_OVERLAPPEDWINDOW,
                            Wtx,Wty,Wwd,Wht,
                            NULL,NULL,
                            hInst,NULL

    mov   hWnd,eax  ; copy return value into handle DWORD

    invoke LoadMenu,hInst,600                 ; load resource menu
    invoke SetMenu,hWnd,eax                   ; set it to main window

    invoke ShowWindow,hWnd,SW_SHOWNORMAL      ; display the window
    invoke UpdateWindow,hWnd                  ; update the display

    StartLoop:
      invoke GetMessage,ADDR msg,NULL,0,0         ; get each message
      cmp eax, 0                                  ; exit if GetMessage()
      je ExitLoop                                 ; returns zero
      invoke TranslateMessage, ADDR msg           ; translate it
      invoke DispatchMessage,  ADDR msg           ; send it to message proc
      jmp StartLoop
    ExitLoop:

      return msg.wParam

WinMain endp

; #########################################################################

WndProc proc hWin   :DWORD,
             uMsg   :DWORD,
             wParam :DWORD,
             lParam :DWORD

  LOCAL hDC    :DWORD
    LOCAL Ps     :PAINTSTRUCT

    .if uMsg == WM_COMMAND
    .elseif uMsg == WM_LBUTTONDOWN
    .elseif uMsg == WM_LBUTTONUP
    .elseif uMsg == WM_PAINT
    .elseif uMsg == WM_CREATE
    .elseif uMsg == WM_CLOSE
    .elseif uMsg == WM_DESTROY
        invoke PostQuitMessage, NULL
        return 0 
    .endif

    invoke DefWindowProc, hWin, uMsg, wParam, lParam
    ret
WndProc endp

; ########################################################################

TopXY proc wDim:DWORD, sDim:DWORD

    shr sDim, 1      ; divide screen dimension by 2
    shr wDim, 1      ; divide window dimension by 2
    mov eax, wDim    ; copy window dimension into eax
    sub sDim, eax    ; sub half win dimension from half screen dimension

    return sDim

TopXY endp

end start
