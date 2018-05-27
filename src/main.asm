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
      include \masm32\include\winmm.inc
      includelib \masm32\lib\winmm.lib

; #########################################################################

        WinMain PROTO :DWORD, :DWORD, :DWORD, :DWORD
        WndProc PROTO :DWORD, :DWORD, :DWORD, :DWORD
        TopXY PROTO   :DWORD, :DWORD
        Animation PROTO
        Frame PROTO
        SetUp PROTO

        BORDER_SIZE equ 9

        WINDOW_W equ 550
        WINDOW_H equ 800

        COLUMN_SIZE equ 50
        COLUMN_COUNT equ 11

        INVADERS_COUNT equ 55
        INVADERS_ROWS equ 5

        SHOT_HEIGHT equ 10
        SHOT_SPEED equ 5
        APPROACH_RATE equ 14

        ICON equ 1
        PLAYER_SPRITESET equ 2
        INVADERS_SPRITESET equ 3
        INITIAL_SCREEN equ 4
        END_SCREEN equ 5

; #########################################################################

.data
    ; Handlers and window variables
    szDisplayName db "Space Invaders", 0
    CommandLine   dd 0
    hWnd          dd 0
    hInstance     dd 0

    ; Sounds
    bgMusic        db "../sounds/bg.wav", 0
    explosionSound db "../sounds/explosion.wav", 0

    ; Pagination variables
    startMenu db 1
    gameRunning db 0

    ; Game variables
    actualRow dd 0
    spritesState dd 0

    shotExists db 0
    shotX dd 0
    shotY dd 0

    playerX dd 0
    playerY dd 0
    
.data?
    ; Position variables
    invaders DWORD 55 dup(?)

    ; Sprites variables
    invadersSpriteset dd ?
    playerSpriteset dd ?
    initialScreen dd ?
    endScreen dd ?

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

        .if gameRunning == 0 && wParam == VK_RETURN
            invoke SetUp

            mov startMenu, 0
            mov gameRunning, 1
        .else
            .if wParam == VK_LEFT || wParam == VK_RIGHT
                mov eax, playerX
                dec eax
                imul eax, COLUMN_SIZE
                mov region.left, eax

                mov ebx, COLUMN_SIZE
                imul ebx, 3
                add eax, ebx
                mov region.right, eax
                
                mov eax, playerY
                mov region.top, eax
                add eax, COLUMN_SIZE
                mov region.bottom, eax
                
                .if wParam == VK_LEFT && playerX != 0
                    dec playerX
                    sub region.right, COLUMN_SIZE
                .elseif wParam == VK_RIGHT && playerX != COLUMN_COUNT - 1
                    inc playerX
                    add region.left, COLUMN_SIZE
                .endif

                invoke InvalidateRect, hWnd, addr region, FALSE
            .elseif wParam == VK_SPACE && shotExists == 0
                ; Shot start position
                mov ebx, playerY
                sub ebx, SHOT_HEIGHT
                mov shotY, ebx

                mov ebx, playerX
                mov shotX, ebx

                mov shotExists, 1

                ; Area to invalidate
                mov eax, shotX
                imul eax, COLUMN_SIZE
                mov region.left, eax

                add eax, COLUMN_SIZE
                mov region.right, eax
                
                mov eax, shotY
                mov region.top, eax
                add eax, SHOT_HEIGHT
                mov region.bottom, eax

                invoke InvalidateRect, hWnd, addr region, FALSE
            .endif
        .endif
        
        return 0

    .elseif uMsg == WM_PAINT

        invoke BeginPaint, hWin, addr Ps
        mov hdc, eax

        ; Clear the screen
        invoke Clear, hdc, 2

        invoke CreateCompatibleDC, hdc
        mov hMemDC, eax

        .if startMenu == 1
            invoke SelectObject, hMemDC, initialScreen

            ; Draw the initial screen
            mov eax, spritesState
            imul eax, WINDOW_W
            invoke BitBlt, hdc, 0, 0, WINDOW_W, WINDOW_H, hMemDC, eax, 0, MERGECOPY
        .else
            .if gameRunning == 1
                invoke SelectObject, hMemDC, invadersSpriteset

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

                        ; edx represents the actual x
                        mov edx, invaders[esi * 4]
                        cmp edx, -1
                        je  continue

                        imul edx, 50

                        ; eax represents the actual sprite being used
                        push eax
                        mov eax, ecx
                        imul eax, COLUMN_SIZE * 2

                        ; ecx represents the actual y
                        push ecx
                        add ecx, actualRow
                        imul ecx, COLUMN_SIZE

                        ; Draw the invaders based on actual state
                        .if spritesState == 1
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
                invoke SelectObject, hMemDC, playerSpriteset
                .if shotExists == 1
                    mov ebx, shotX
                    imul ebx, COLUMN_SIZE
                    invoke BitBlt, hdc, ebx, shotY, COLUMN_SIZE, SHOT_HEIGHT, hMemDC, COLUMN_SIZE, 0, MERGECOPY
                .endif

                mov ebx, playerX
                imul ebx, COLUMN_SIZE
                invoke BitBlt, hdc, ebx, playerY, COLUMN_SIZE, COLUMN_SIZE, hMemDC, 0, 0, MERGECOPY
            .else
                ; Draw the game over screen
                invoke SelectObject, hMemDC, endScreen

                mov eax, spritesState
                imul eax, WINDOW_W
                invoke BitBlt, hdc, 0, 0, WINDOW_W, WINDOW_H, hMemDC, eax, 0, MERGECOPY
            .endif
        .endif

        invoke DeleteDC, hMemDC

        invoke EndPaint, hWin, addr Ps
        return  0

    .elseif uMsg == WM_CREATE

        ; Loads the sprite resources
        invoke LoadBitmap, hInstance, PLAYER_SPRITESET
        mov playerSpriteset, eax

        invoke LoadBitmap, hInstance, INVADERS_SPRITESET
        mov invadersSpriteset, eax

        invoke LoadBitmap, hInstance, INITIAL_SCREEN
        mov initialScreen, eax

        invoke LoadBitmap, hInstance, END_SCREEN
        mov endScreen, eax

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

SetUp proc

    mov actualRow, 0

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

    ; Initializes the player position
    mov playerX, COLUMN_COUNT / 2
    mov playerY, WINDOW_H - 99

    ; Game's background music
    mov eax, SND_FILENAME
    or eax, SND_LOOP
    or eax, SND_ASYNC
    invoke PlaySound, addr bgMusic, 0, eax

    ret

SetUp endp

; ########################################################################

Animation proc

    LOCAL t :DWORD
    LOCAL count : byte

    mov count, 0

    ; 500ms timer
    animate:
        invoke GetTickCount
        mov t, eax
        add t, 500

        .while eax < t
            invoke GetTickCount
        .endw

        ; Alternates between 0 and 1
        xor spritesState, 1

        .if gameRunning == 1
            inc count

            .if count == APPROACH_RATE
                mov count, 0
                inc actualRow

                ; eax controls the actual line
                mov eax, INVADERS_ROWS
                dec eax
                reached:
                    cmp eax, 0
                    jb  end_reached

                    mov ebx, eax
                    inc ebx
                    add ebx, actualRow
                    imul ebx, COLUMN_SIZE

                    ; If the bottom of the actual row reached the player, check the invaders
                    cmp ebx, playerY
                    jb  end_reached

                    ; ebx is the first invader of the row
                    mov ebx, eax
                    imul ebx, COLUMN_COUNT

                    ; ecx is the first invader of the next row
                    mov ecx, ebx
                    add ecx, COLUMN_COUNT
                    row_check:
                        ; Check only the actual row
                        cmp ebx, ecx
                        jge end_row_check

                        ; If any invader in this row is alive, the player lost the game
                        mov edx, invaders[ebx * 4]
                        .if edx != -1
                            mov gameRunning, 0

                            mov edx, SND_FILENAME
                            or edx, SND_ASYNC
                            invoke PlaySound, addr explosionSound, 0, edx

                            jmp end_reached
                        .endif

                        inc ebx
                        jmp row_check
                    end_row_check:

                    dec eax
                    jmp reached
                end_reached:
            .endif
        .endif

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

        cmp shotExists, 0
        je frame

        ; Discover the index of actual invader
        mov edx, INVADERS_ROWS
        imul edx, COLUMN_COUNT

        mov ebx, COLUMN_COUNT
        sub ebx, shotX
        
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
            add ecx, actualRow
            imul ecx, COLUMN_SIZE
            add ecx, COLUMN_SIZE

            ; If the shot is below the invader, there is no reason to keep checking
            cmp shotY, ecx
            jg  end_check

            mov shotExists, 0
            mov invaders[edx * 4], -1

            ; When the shot hit a invader, the check is canceled
            invoke InvalidateRect, hWnd, NULL, FALSE
            jmp frame

            continue:
                sub edx, COLUMN_COUNT
                dec ebx
                jmp check
        end_check:

        sub shotY, SHOT_SPEED

        ; Only invalidates the shot area
        mov eax, shotX
        imul eax, COLUMN_SIZE
        mov region.left, eax

        add eax, COLUMN_SIZE
        mov region.right, eax
        
        mov eax, shotY
        mov region.top, eax
        add eax, SHOT_HEIGHT
        add eax, SHOT_SPEED
        mov region.bottom, eax
        invoke InvalidateRect, hWnd, addr region, FALSE

        cmp shotY, -SHOT_HEIGHT
        jg  frame

        mov shotExists, 0
        
        jmp frame

Frame endp

end start