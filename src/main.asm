      .386
      .model flat, stdcall
      option casemap :none

; #########################################################################

      include \masm32\include\windows.inc
      include \masm32\include\user32.inc
      include \masm32\include\kernel32.inc
      include \masm32\include\gdi32.inc
      include \masm32\macros\macros.asm
      include \masm32\include\masm32.inc

      includelib \masm32\lib\user32.lib
      includelib \masm32\lib\kernel32.lib
      includelib \masm32\lib\gdi32.lib
      includelib \masm32\lib\masm32.lib
      
; #########################################################################

      szText MACRO Name, Text:VARARG
        LOCAL lbl
          jmp lbl
            Name db Text,0
          lbl:
        ENDM

; #########################################################################

        WinMain PROTO :DWORD,:DWORD,:DWORD,:DWORD
        WndProc PROTO :DWORD,:DWORD,:DWORD,:DWORD
        TopXY PROTO   :DWORD,:DWORD

        BORDER_SIZE equ 9

        WINDOW_W equ 550
        WINDOW_H equ 800

        COLUMN_SIZE equ 50
        COLUMN_COUNT equ 11

        INVADERS_COUNT equ 55
        INVADERS_ROWS equ 5

        SPRITESET equ 1

; #########################################################################

.data
    szDisplayName db "Space Invaders", 0
    CommandLine   dd 0
    hWnd          dd 0
    hInstance     dd 0
    
.data?
    invaders DWORD 55 dup(?)
    posAux POINT<>
    position POINT<>
    spriteSet dd ?

; #########################################################################

.code
    start:
        invoke GetModuleHandle, NULL ; provides the instance handle
        mov hInstance, eax

        invoke GetCommandLine        ; provides the command line address
        mov CommandLine, eax

        invoke WinMain, hInstance, NULL, CommandLine, SW_SHOWDEFAULT
        
        invoke ExitProcess, eax       ; cleanup & return to operating system

; #########################################################################

BuildRect proc, x :DWORD, y :DWORD, w :DWORD, h :DWORD, hdc :HDC, brush :HBRUSH
    LOCAL rectangle :RECT

    mov eax, x
    mov rectangle.left, eax
    add eax, w
    mov rectangle.right, eax
    
    mov eax, y
    mov rectangle.top, eax
    add eax, h
    mov rectangle.bottom, eax
    
    invoke FillRect, hdc, addr rectangle, brush
    ret
BuildRect endp

WinMain proc hInst     :DWORD,
             hPrevInst :DWORD,
             CmdLine   :DWORD,
             CmdShow   :DWORD

    LOCAL wndcls :WNDCLASSA
    LOCAL wc   :WNDCLASSEX
    LOCAL msg  :MSG

    LOCAL Wwd  :DWORD
    LOCAL Wht  :DWORD
    LOCAL Wtx  :DWORD
    LOCAL Wty  :DWORD

    szText szClassName, "Class"

    mov wc.cbSize,         sizeof WNDCLASSEX
    mov wc.style,          CS_HREDRAW or CS_VREDRAW \
                            or CS_BYTEALIGNWINDOW
    mov wc.lpfnWndProc,    offset WndProc      ; address of WndProc
    mov wc.cbClsExtra,     NULL
    mov wc.cbWndExtra,     NULL
    m2m wc.hInstance,      hInst               ; instance handle
    mov wc.hbrBackground,  COLOR_BTNFACE       ; system color
    mov wc.lpszMenuName,   NULL
    mov wc.lpszClassName,  offset szClassName  ; window class name
    invoke LoadIcon, hInst, 500    ; icon ID   ; resource icon
    mov wc.hIcon,          eax
    invoke LoadCursor,NULL,IDC_ARROW         ; system cursor
    mov wc.hCursor,        eax
    mov wc.hIconSm,        0

    invoke RegisterClassEx, addr wc     ; register the window class

    ; Centre window at following size
    mov Wwd, WINDOW_W + BORDER_SIZE
    mov Wht, WINDOW_H

    invoke GetSystemMetrics, SM_CXSCREEN ; get screen width in pixels
    invoke TopXY, Wwd, eax
    mov Wtx, eax

    invoke GetSystemMetrics,SM_CYSCREEN ; get screen height in pixels
    invoke TopXY, Wht, eax
    mov Wty, eax

    ; Create the main application window
    invoke CreateWindowEx, WS_EX_OVERLAPPEDWINDOW,
                           addr szClassName,
                           addr szDisplayName,
                           WS_SYSMENU,
                           Wtx, Wty, Wwd, Wht,
                           NULL, NULL,
                           hInst, NULL

    mov   hWnd, eax  ; copy return value into handle DWORD

    invoke ShowWindow, hWnd, SW_SHOWNORMAL     ; display the window
    invoke UpdateWindow, hWnd                  ; update the display

    StartLoop:
      invoke GetMessage, addr msg, NULL, 0, 0     ; get each message
      cmp eax, 0                                  ; exit if GetMessage()
      je ExitLoop                                 ; returns zero
      invoke TranslateMessage, addr msg           ; translate it
      invoke DispatchMessage,  addr msg           ; send it to message proc
      jmp StartLoop
    ExitLoop:

      return msg.wParam

WinMain endp

; #########################################################################

WndProc proc hWin   :DWORD,
             uMsg   :DWORD,
             wParam :DWORD,
             lParam :DWORD

    LOCAL hdc :DWORD
    LOCAL hMemDC :HDC
    LOCAL Ps  :PAINTSTRUCT
    LOCAL brush :HBRUSH

    .if uMsg == WM_KEYDOWN
        .if wParam == VK_LEFT && position.x != 0
            sub position.x, COLUMN_SIZE
        .elseif wParam == VK_RIGHT && position.x != WINDOW_W - COLUMN_SIZE
            add position.x, COLUMN_SIZE
        .endif

        invoke InvalidateRect, hWnd, NULL, FALSE
        return 0

    .elseif uMsg == WM_PAINT

        invoke BeginPaint, hWin, addr Ps
        mov hdc, eax

        invoke BuildRect, 0, 0, WINDOW_W, WINDOW_H, hdc, 2

        invoke CreateCompatibleDC, hdc
        mov hMemDC, eax

        invoke SelectObject, hMemDC, spriteSet

        ; Draw the invaders
        mov esi, 0
        mov ecx, 0
        fory_draw:
            cmp ecx, INVADERS_ROWS
            jge end_fory_draw

            mov ebx, 0
            forx_draw:
                cmp ebx, COLUMN_COUNT
                jge end_forx_draw

                mov edx, invaders[esi * 4]
                imul edx, 50

                push ecx
                imul ecx, 50
                invoke BitBlt, hdc, edx, ecx, COLUMN_SIZE, COLUMN_SIZE, hMemDC, 50, 0, MERGECOPY
                pop ecx

                inc ebx
                inc esi
                jmp forx_draw
            end_forx_draw:

            inc ecx
            jmp fory_draw
        end_fory_draw:

        invoke SelectObject, hMemDC, spriteSet

        ; Draw the player
        invoke BitBlt, hdc, position.x, position.y, COLUMN_SIZE, COLUMN_SIZE, hMemDC, 0, 0, MERGECOPY

        invoke DeleteDC, hMemDC
        invoke EndPaint, hWin, addr Ps
        return  0

    .elseif uMsg == WM_CREATE

        mov esi, 0
        mov al, 0
        fory:
            cmp al, INVADERS_ROWS
            jge end_fory

            mov edx, 0
            forx:
                cmp edx, COLUMN_COUNT
                jge end_forx

                mov invaders[esi * 4], edx

                inc edx
                inc esi
                jmp forx
            end_forx:

            inc al
            jmp fory
        end_fory:

        invoke LoadBitmap, hInstance, SPRITESET
        mov spriteSet, eax

        mov position.x, (COLUMN_COUNT / 2) * COLUMN_SIZE
        mov position.y, WINDOW_H - 100

    .elseif uMsg == WM_DESTROY

        invoke PostQuitMessage, NULL
        return 0 

    .endif

    invoke DefWindowProc, hWin, uMsg, wParam, lParam
    ret
WndProc endp

; ########################################################################

TopXY proc wDim :DWORD, sDim :DWORD

    shr sDim, 1      ; divide screen dimension by 2
    shr wDim, 1      ; divide window dimension by 2
    mov eax, wDim    ; copy window dimension into eax
    sub sDim, eax    ; sub half win dimension from half screen dimension

    return sDim

TopXY endp

end start