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

        WinMain PROTO :DWORD, :DWORD, :DWORD, :DWORD
        WndProc PROTO :DWORD, :DWORD, :DWORD, :DWORD
        TopXY PROTO   :DWORD, :DWORD
        Animation PROTO
        Frame PROTO

        BORDER_SIZE equ 9

        WINDOW_W equ 550
        WINDOW_H equ 800

        COLUMN_SIZE equ 50
        COLUMN_COUNT equ 11

        INVADERS_COUNT equ 55
        INVADERS_ROWS equ 5

        ICON equ 1
        PLAYER_SPRITESET equ 2
        INVADERS_SPRITESET equ 3

        SHOT_HEIGHT equ 10
        SHOT_SPEED equ 5

; #########################################################################

.data
    ; Handlers and window variables
    szDisplayName db "Space Invaders", 0
    CommandLine   dd 0
    hWnd          dd 0
    hInstance     dd 0

    ; Game Variables
    sprites_state dd 0

    shot_exists db 0
    shot_x dd 0
    shot_y dd 0

    player_x dd 0
    player_y dd 0
    
.data?
    ; Position variables
    invaders DWORD 55 dup(?)

    ; Sprites variables
    invaders_spriteset dd ?
    player_spriteset dd ?

; #########################################################################

.code
    start:
        invoke CreateThread, 0, 0, offset Animation, 0, 0, 0
        invoke CreateThread, 0, 0, offset Frame, 0, 0, 0

        invoke GetModuleHandle, NULL ; provides the instance handle
        mov hInstance, eax

        invoke GetCommandLine        ; provides the command line address
        mov CommandLine, eax

        invoke WinMain, hInstance, NULL, CommandLine, SW_SHOWDEFAULT
        
        invoke ExitProcess, eax       ; cleanup & return to operating system

; #########################################################################

Clear proc, hdc :HDC, brush :HBRUSH

    LOCAL rectangle :RECT

    mov eax, 0
    mov rectangle.left, eax
    add eax, WINDOW_W
    mov rectangle.right, eax
    
    mov eax, 0
    mov rectangle.top, eax
    add eax, WINDOW_H
    mov rectangle.bottom, eax
    
    invoke FillRect, hdc, addr rectangle, brush
    ret

Clear endp

; #########################################################################

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
    invoke LoadIcon, hInst, ICON
    m2m wc.hIcon,          eax
    m2m wc.hIconSm,        eax
    invoke LoadCursor,NULL,IDC_ARROW         ; system cursor
    mov wc.hCursor,        eax

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
    LOCAL region :RECT

    .if uMsg == WM_KEYDOWN
        .if wParam == VK_LEFT || wParam == VK_RIGHT
            mov eax, player_x
            dec eax
            imul eax, COLUMN_SIZE
            mov region.left, eax

            mov ebx, COLUMN_SIZE
            imul ebx, 3
            add eax, ebx
            mov region.right, eax
            
            mov eax, player_y
            mov region.top, eax
            add eax, COLUMN_SIZE
            mov region.bottom, eax
            
            .if wParam == VK_LEFT && player_x != 0
                dec player_x
                sub region.right, COLUMN_SIZE
            .elseif wParam == VK_RIGHT && player_x != COLUMN_COUNT - 1
                inc player_x
                add region.left, COLUMN_SIZE
            .endif

            invoke InvalidateRect, hWnd, addr region, FALSE
        .elseif wParam == VK_SPACE && shot_exists == 0
            ; Shot start position
            mov ebx, player_y
            sub ebx, SHOT_HEIGHT
            mov shot_y, ebx

            mov ebx, player_x
            mov shot_x, ebx

            mov shot_exists, 1

            ; Area to invalidate
            mov eax, shot_x
            imul eax, COLUMN_SIZE
            mov region.left, eax

            add eax, COLUMN_SIZE
            mov region.right, eax
            
            mov eax, shot_y
            mov region.top, eax
            add eax, SHOT_HEIGHT
            mov region.bottom, eax

            invoke InvalidateRect, hWnd, addr region, FALSE
        .endif

        return 0

    .elseif uMsg == WM_PAINT

        invoke BeginPaint, hWin, addr Ps
        mov hdc, eax

        ; Clear the screen
        invoke Clear, hdc, 2

        invoke CreateCompatibleDC, hdc
        mov hMemDC, eax

        invoke SelectObject, hMemDC, invaders_spriteset

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
                cmp edx, -1
                je  continue

                imul edx, 50

                push eax
                mov eax, ecx
                imul eax, COLUMN_SIZE * 2

                push ecx
                imul ecx, COLUMN_SIZE

                ; Draw the invaders based on actual state
                .if sprites_state == 1
                    add eax, COLUMN_SIZE
                .endif

                invoke BitBlt, hdc, edx, ecx, COLUMN_SIZE, COLUMN_SIZE, hMemDC, eax, 0, MERGECOPY

                pop ecx
                pop eax

                continue:
                    inc ebx
                    inc esi
                    jmp forx_draw
            end_forx_draw:

            inc ecx
            jmp fory_draw
        end_fory_draw:

        ; Draw the shot and player
        invoke SelectObject, hMemDC, player_spriteset
        .if shot_exists == 1
            mov ebx, shot_x
            imul ebx, COLUMN_SIZE
            invoke BitBlt, hdc, ebx, shot_y, COLUMN_SIZE, SHOT_HEIGHT, hMemDC, COLUMN_SIZE, 0, MERGECOPY
        .endif

        mov ebx, player_x
        imul ebx, COLUMN_SIZE
        invoke BitBlt, hdc, ebx, player_y, COLUMN_SIZE, COLUMN_SIZE, hMemDC, 0, 0, MERGECOPY

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

                ; Invaders array stores the invaders's x position
                mov invaders[esi * 4], edx

                inc edx
                inc esi
                jmp forx
            end_forx:

            inc al
            jmp fory
        end_fory:

        ; Loads the sprite resources
        invoke LoadBitmap, hInstance, PLAYER_SPRITESET
        mov player_spriteset, eax

        invoke LoadBitmap, hInstance, INVADERS_SPRITESET
        mov invaders_spriteset, eax

        ; Initializes the player position
        mov player_x, COLUMN_COUNT / 2
        mov player_y, WINDOW_H - 100

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

; ########################################################################

Animation proc

    LOCAL t :DWORD

    ; 500ms timer
    animate:
        invoke GetTickCount
        mov t, eax
        add t, 500

        .while eax < t
            invoke GetTickCount
        .endw

        ; Alternates between 0 and 1
        xor sprites_state, 1

        invoke InvalidateRect, hWnd, NULL, FALSE
        jmp animate

Animation endp

; ########################################################################

Frame proc

    LOCAL t :DWORD
    LOCAL region :RECT

    ; 60fps timer
    frame:
        invoke GetTickCount
        mov t, eax
        add t, 16

        .while eax < t
            invoke GetTickCount
        .endw

        cmp shot_exists, 0
        je frame

        ; Discover the index of actual invader
        mov edx, INVADERS_ROWS
        imul edx, COLUMN_COUNT

        mov ebx, COLUMN_COUNT
        sub ebx, shot_x
        
        ; Inverse for to check from the last row to the first if the shot hit some invader
        sub edx, ebx

        ; Stores the actual row
        mov ebx, INVADERS_ROWS
        dec ebx
        check:
            cmp edx, 0
            jl  end_check

            ; If the invader equals -1, the invader is dead
            mov eax, invaders[edx * 4]
            cmp eax, -1
            je  continue

            ; Otherwise, check if the shot hit it
            mov ecx, ebx
            imul ecx, COLUMN_SIZE
            add ecx, COLUMN_SIZE

            ; If the shot is below the invader, there is no reason to keep checking
            cmp shot_y, ecx
            jg  end_check

            mov shot_exists, 0
            mov invaders[edx * 4], -1

            ; When the shot hit a invader, the check is canceled
            invoke InvalidateRect, hWnd, NULL, FALSE
            jmp frame

            continue:
                sub edx, COLUMN_COUNT
                dec ebx
                jmp check
        end_check:

        sub shot_y, SHOT_SPEED

        ; Only invalidates the shot area
        mov eax, shot_x
        imul eax, COLUMN_SIZE
        mov region.left, eax

        add eax, COLUMN_SIZE
        mov region.right, eax
        
        mov eax, shot_y
        mov region.top, eax
        add eax, SHOT_HEIGHT
        add eax, SHOT_SPEED
        mov region.bottom, eax
        invoke InvalidateRect, hWnd, addr region, FALSE

        cmp shot_y, -SHOT_HEIGHT
        jg  frame

        mov shot_exists, 0
        
        jmp frame

Frame endp

end start