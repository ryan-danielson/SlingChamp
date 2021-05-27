%include "/usr/local/share/asm_io.inc"


; the file that stores the initial state
%define BOARD_FILE 'board.txt'

; how to represent everything
%define WALL_CHAR       '#'
%define PLAYER_CHAR     "@"
%define HOOK            '*'


; the size of the game screen in characters
%define HEIGHT 20
%define WIDTH 40

; the player starting position.
; top left is considered (0,0)
%define STARTX 20
%define STARTY 10

; these keys do things
%define EXITCHAR 'x'
%define UPCHAR 'w'
%define LEFTCHAR 'a'
%define DOWNCHAR 's'
%define RIGHTCHAR 'd'
%define HOOKCHAR  0x20          ; space
%define HOOKUP 'i'
%define HOOKDOWN 'k'
%define HOOKLEFT 'j'
%define HOOKRIGHT 'l'

segment .data

	; used to fopen() the board file defined above
	board_file			db BOARD_FILE,0

	; used to change the terminal mode
	mode_r				db "r",0
	raw_mode_on_cmd		db "stty raw -echo",0
	raw_mode_off_cmd	db "stty -raw echo",0

	; called by system() to clear/refresh the screen
	clear_screen_cmd	db "clear",0

	; things the program will print
	help_str			db 13,10,"Controls: ", \
							LEFTCHAR,"=LEFT / ", \
							RIGHTCHAR,"=RIGHT / ", \
							UPCHAR,"=UP / ", \
                                                        DOWNCHAR,"=DOWN / ", \
                                                        EXITCHAR,"=EXIT",13,10,0
        help_str2                       db 13,10,"Hook controls: ", \
                                                        HOOKLEFT,"=LEFT HOOK / ", \
                                                        HOOKRIGHT,"=RIGHT HOOK / ", \
                                                        HOOKUP,"=UP HOOK / ", \
                                                        HOOKDOWN,"=DOWN HOOK / (double-tap for super-speed!)",13,10,0
        fmt_score               dd      "Score: %d",13,10,0
        death                   db      "Wipe out!", 13,10,0        
        win                     db      "You are a winner!", 13,10,0
        TICK                    dd      80000   

        hookx                   dd      0
        hooky                   dd      -1
        hookDirX                dd      0
        hookDirY                dd      -1
        hookCurrentPos          dd      0
	xpos    	        dd	20
	ypos	                dd	16
        
        active_hook             dd      0
        destroy_hook            dd      0
        ; color stuff
        color_default           db      27,"[0m",0
        green                   db      27,"[32m",0
        red                     db      27,"[31m",0
        yellow                  db      27,"[33m",0
        blue                    db      27,"[34m",0  
        light_magenta           db      27,"[105m",0
        blink                   db      27,"[5m",0
        
        playerup                db      1
        playerdown              db      0
        playerleft              db      0
        playerright             db      0      
segment .bss

	; this array stores the current rendered gameboard (HxW)
	board	        resb	(HEIGHT * WIDTH)
        last_move       resd    1
        last_hook       resb    1       ; up 1, down 2, left 3, right 4
        on_wall         resb    0
        last_color      resb    1       ; green 1, red 2, yellow 3, blue 4
        score           resd    1       ; keep track of points
	; these variables store the current player position

segment .text

	global	asm_main
	global  raw_mode_on
	global  raw_mode_off
	global  init_board
	global  render

	extern	system
	extern	putchar
	extern	getchar
	extern	printf
	extern	fopen
	extern	fread
	extern	fgetc
	extern	fclose
        extern  usleep
        extern  fcntl

main:
	enter	0,0
	pusha
	;***************CODE STARTS HERE***************************

	; put the terminal in raw mode so the game works nicely
	call	raw_mode_on

	; read the game board file into the global variable
	call	init_board

	; set the player at the proper start position
	mov		DWORD [xpos], STARTX
	mov		DWORD [ypos], STARTY
        mov             DWORD [score], 0
	mov             eax, playerup
        mov             [last_move], eax
        ;
        ; the game happens in this loop
	; the steps are...
	;   1. render (draw) the current board
	;   2. get a character from the user
	;	3. store current xpos,ypos in esi,edi
	;	4. update xpos,ypos based on character from user
	;	5. check what's in the buffer (board) at new xpos,ypos
	;	6. if it's a wall, reset xpos,ypos to saved esi,edi
	;	7. otherwise, just continue! (xpos,ypos are ok)
	game_loop:
                push    DWORD [TICK]
                call    usleep
                add     esp, 4

		; draw the game board
		call	render

		; get an action from the user
                call    nonblocking_getchar
                cmp     al, -1
		; store the current position
		; we will test if the new position is legal
		; if not, we will restore these
		mov		esi, [xpos]
		mov		edi, [ypos]

	; choose what to do
		cmp		eax, EXITCHAR
		je		game_loop_end
		cmp		eax, UPCHAR
		je 		move_up
		cmp		eax, LEFTCHAR
		je		move_left
		cmp		eax, DOWNCHAR
		je		move_down
		cmp		eax, RIGHTCHAR
		je		move_right
                cmp             eax, HOOKUP
                je              hook_up
                cmp             eax, HOOKDOWN
                je              hook_down
                cmp             eax, HOOKLEFT
                je              hook_left
                cmp             eax, HOOKRIGHT
                je              hook_right
		jmp		input_end			; or just do nothing

		; move the player according to the input character
		move_up:
                        mov             eax, DWORD [active_hook]
                        cmp             eax, 1
                        jge             input_end
                        mov             al, BYTE [playerup]
                        cmp             al, 1
                        je              input_end
                        mov             al, BYTE [playerdown]
                        cmp             al, 1
                        je              UP_up
                        mov             al, BYTE [playerleft]
                        cmp             al, 1
                        je              UP_up_right
                        mov             al, BYTE [playerright]
                        cmp             al, 1
                        je              UP_up_left
                        UP_up:
                                sub     DWORD [ypos], 2
                                jmp     UP_set_flags
                        UP_up_right:
                                add     DWORD [xpos], 1
                                sub     DWORD [ypos], 1
                                jmp     UP_set_flags
                        UP_up_left:
                                sub     DWORD [ypos], 1
                                sub     DWORD [xpos], 1
                                jmp     UP_set_flags
                        UP_set_flags:
                                mov             BYTE [playerdown], 0
                                mov             BYTE [playerup], 1
                                mov             BYTE [playerright], 0
                                mov             BYTE [playerleft], 0 
                                jmp             input_end
		move_left:
                        mov             eax, DWORD [active_hook]
                        cmp             eax, 1
                        jge             input_end
                        mov             al, BYTE [playerleft]
                        cmp             al, 1
                        je              input_end
                        mov             al, BYTE [playerup]
                        cmp             al, 1
                        je              LEFT_down_left
                        mov             al, BYTE [playerdown]
                        cmp             al, 1
                        je              LEFT_up_left
                        mov             al, BYTE [playerright]
                        cmp             al, 1
                        je              LEFT_left
                        LEFT_down_left:
                                sub     DWORD [xpos], 1
                                add     DWORD [ypos], 1
                                jmp     LEFT_set_flags
                        LEFT_up_left:
                                sub     DWORD [xpos], 1
                                sub     DWORD [ypos], 1
                                jmp     LEFT_set_flags
                        LEFT_left:
                                sub     DWORD [xpos], 2
                                jmp     LEFT_set_flags
                        LEFT_set_flags:
		        	mov             BYTE [playerleft], 1
                                mov             BYTE [playerup], 0
                                mov             BYTE [playerright], 0
                                mov             BYTE [playerdown], 0
                                jmp             input_end
		move_down:
                        mov             eax, DWORD [active_hook]
                        cmp             eax, 1
                        jge             input_end
                        mov             al, BYTE [playerdown]
                        cmp             al, 1
                        je              input_end
                        mov             al, BYTE [playerup]
                        cmp             al, 1
                        je              DOWN_down
                        mov             al, BYTE [playerleft]
                        cmp             al, 1
                        je              DOWN_down_right
                        mov             al, BYTE [playerright]
                        cmp             al, 1
                        je              DOWN_down_left
                        DOWN_down_left:
                                sub     DWORD [xpos], 1
                                add     DWORD [ypos], 1
                                jmp     DOWN_set_flags
                        DOWN_down_right:
                                add     DWORD [xpos], 1
                                add     DWORD [ypos], 1
                                jmp     DOWN_set_flags
                        DOWN_down:
                                add     DWORD [ypos], 2
                                jmp     DOWN_set_flags
                        DOWN_set_flags:
                                mov             BYTE [playerdown], 1
                                mov             BYTE [playerup], 0
                                mov             BYTE [playerright], 0
                                mov             BYTE [playerleft], 0 
                                jmp             input_end
		move_right: 
                        mov             eax, DWORD [active_hook]
                        cmp             eax, 1
                        jge             input_end
                        mov             al, BYTE [playerright]
                        cmp             al, 1
                        je              input_end
                        mov             al, BYTE [playerup]
                        cmp             al, 1
                        je              RIGHT_down_right
                        mov             al, BYTE [playerleft]
                        cmp             al, 1
                        je              RIGHT_right
                        mov             al, BYTE [playerdown]
                        cmp             al, 1
                        je              RIGHT_up_right
                        RIGHT_down_right:
                                add     DWORD [xpos], 1
                                add     DWORD [ypos], 1
                                jmp     RIGHT_set_flags
                        RIGHT_right:
                                add     DWORD [xpos], 2
                                jmp     RIGHT_set_flags
                        RIGHT_up_right:
                                add     DWORD [xpos], 1
                                sub     DWORD [ypos], 1
                                jmp     RIGHT_set_flags
                        RIGHT_set_flags:
                                mov             BYTE [playerdown], 0
                                mov             BYTE [playerup], 0
                                mov             BYTE [playerright], 1
                                mov             BYTE [playerleft], 0 
                                jmp             input_end
                hook_up:
                        mov             eax, DWORD [active_hook]
                        cmp             eax, 1
                        je              check_up
                        jmp             hook_up_end
                        check_up:
                                cmp     BYTE [last_hook], 1
                                je      fast_forward
                                jmp     input_end 
                        hook_up_end:
                                mov             DWORD [hookDirY], -1
                                mov             DWORD [hookDirX], 0        
			        mov             BYTE [last_hook], 1
                                jmp		launch_hook
                hook_down:
                        mov             eax, DWORD [active_hook]
                        cmp             eax, 1
                        je              check_down
                        jmp             hook_down_end
                        check_down:
                                cmp     BYTE [last_hook], 2
                                je      fast_forward
                                jmp     input_end
                        hook_down_end:
                                mov             DWORD [hookDirY], 1
                                mov             DWORD [hookDirX], 0
                                mov             BYTE [last_hook], 2
			        jmp		launch_hook	
                hook_left:
                        mov             eax, DWORD [active_hook]
                        cmp             eax, 1
                        je              check_left
                        jmp             hook_left_end
                        check_left:
                                cmp     BYTE [last_hook], 3
                                je      fast_forward
                                jmp     input_end
                        hook_left_end:
                                mov             DWORD [hookDirX], -1
                                mov             DWORD [hookDirY], 0
                                mov             BYTE [last_hook], 3
			        jmp		launch_hook
	
                hook_right:
                        mov             eax, DWORD [active_hook]
                        cmp             eax, 1
                        je              check_right
                        jmp             hook_right_end
                        check_right:
                                cmp     BYTE [last_hook], 4
                                je      fast_forward
                                jmp     input_end
                        hook_right_end:
                                mov             DWORD [hookDirX], 1
                                mov             DWORD [hookDirY], 0 
                                mov             BYTE [last_hook], 4
                                jmp             launch_hook
                 launch_hook:
                        mov     eax, DWORD [active_hook]
                        cmp     eax, 1
                        jge     input_end
                        jmp      inc_hook      
                
                fast_forward:
                        mov     DWORD [TICK], 10000  
		input_end:

		; (W * y) + x = pos

		; compare the current position to the wall character
		mov		eax, WIDTH
		mul		DWORD [ypos]
		add		eax, [xpos]
		lea		eax, [board + eax]
		cmp		BYTE [eax], WALL_CHAR
		je		wall
                cmp             BYTE [eax], 'Y'
                je              wall
                cmp             BYTE [eax], 'B'
                je              wall
                cmp             BYTE [eax], 'G'
                je              wall
                cmp             BYTE [eax], 'R'
                je              wall
		; opps, that was an invalid move, reset
                mov             BYTE [on_wall], 0
                jmp             valid_move
		wall:
                        mov             BYTE [on_wall], 1
                	mov		DWORD [xpos], esi
			mov		DWORD [ypos], edi
                        jmp             valid_move
	                                      
		valid_move:
                move_hook:
                        mov     eax, DWORD [active_hook]
                        cmp     eax, 0
                        je      game_loop                                
                        
                        mov     eax, WIDTH                         
                        mov     ebx, DWORD [hooky]
                        add     ebx, DWORD [hookDirY]
                        mov     DWORD [hooky], ebx
                        imul     eax, ebx
                        mov     ebx, DWORD [hookx]
                        add     ebx, DWORD [hookDirX]
                        mov     DWORD [hookx], ebx
                        add     eax, ebx  
                        lea     eax, [board + eax]
                        mov     DWORD [hookCurrentPos], eax
                        cmp     DWORD [hookx], 0
                        je      set_x40
                        cmp     DWORD [hookx], 40
                        je      set_x0
                        cmp     DWORD [hooky], 1
                        je      set_y20 
                        cmp     DWORD [hooky], 19
                        je      set_y0
                        cmp     BYTE [eax],  '#'
                        je      remove_hook
                        cmp     BYTE [eax], 'Y'
                        je      yellow_hook
                        cmp     BYTE [eax], 'G'
                        je      green_hook
                        cmp     BYTE [eax], 'B'
                        je      blue_hook
                        cmp     BYTE [eax], 'R'
                        je      red_hook
                        cmp     BYTE [eax], ' '
                        je      place_hook
                        
                        ; check if hook has hit player

                        mov     eax, DWORD [ypos]
                        cmp     eax, DWORD [hooky]
                        jne     game_loop
                        mov     eax,  DWORD [xpos]
                        cmp     eax, DWORD [hookx]
                        je      dead
                        
                        
                        jmp     game_loop
                        
                        set_x40:
                                cmp     DWORD [hookDirX],-1
                                jne     place_hook 
                                mov     DWORD [hookx], 40
                                jmp     place_hook
                        set_x0:
                                cmp     DWORD [hookDirX], 1
                                jne     place_hook
                                mov     DWORD [hookx], 0
                                jmp     place_hook
                        set_y20:
                                cmp     DWORD [hookDirY], -1
                                jne     place_hook
                                mov     DWORD [hooky], 20
                                jmp     place_hook
                        set_y0:
                                cmp     DWORD [hookDirY], 1
                                jne     place_hook
                                mov     DWORD [hooky], 0
                                jmp     place_hook
                        yellow_hook:
                                mov     BYTE [last_color], 3
                                inc     DWORD [score]
                                jmp     place_hook
                        green_hook:
                                mov     BYTE [last_color], 1
                                inc     DWORD [score]
                                jmp     place_hook
                        blue_hook:
                                mov     BYTE [last_color], 4
                                inc     DWORD [score]
                                jmp     place_hook
                        red_hook:
                                mov     BYTE [last_color], 2
                                inc     DWORD [score]
                                jmp     place_hook
                        place_hook:            
                                mov     BYTE [eax], HOOK
                                cmp     DWORD [score], 284
                                je      winner
                                jmp     game_loop

                move_hook_end:
                remove_hook:
                        mov     DWORD [destroy_hook], 1
                        mov     DWORD [active_hook], 0
	                mov     eax, DWORD [hookx]
                        mov     ebx, DWORD [hooky]
                        mov     DWORD [xpos], eax
                        mov     DWORD [ypos], ebx
                        mov     eax, DWORD [hookDirY]
                        mov     ebx, DWORD [hookDirX]
                        sub     DWORD [xpos], ebx
                        sub     DWORD [ypos], eax
                       
                        mov     DWORD [TICK], 80000     ; set the clock back
                        
                        set_player_location:
                        cmp     BYTE [wall], 1
                        je      game_loop 
                        mov     al, BYTE [last_hook]
                        cmp     al, 1
                        je      set_flags_1
                        cmp     al, 2
                        je      set_flags_2
                        cmp     al, 3
                        je      set_flags_3
                        cmp     al, 4
                        je      set_flags_4
                        jmp     game_loop
                        set_flags_1:
                                mov     BYTE [playerup], 0
                                mov     BYTE [playerdown], 1
                                mov     BYTE [playerleft], 0
                                mov     BYTE [playerright], 0
                                jmp     game_loop
                        set_flags_2:
                                mov     BYTE [playerup], 1
                                mov     BYTE [playerdown], 0
                                mov     BYTE [playerleft], 0
                                mov     BYTE [playerright], 0
                                jmp     game_loop
                        set_flags_3:
                                mov     BYTE [playerup], 0
                                mov     BYTE [playerdown], 0
                                mov     BYTE [playerleft], 0
                                mov     BYTE [playerright], 1
                                jmp     game_loop
                        set_flags_4:
                                mov     BYTE [playerup], 0
                                mov     BYTE [playerdown], 0
                                mov     BYTE [playerleft], 1
                                mov     BYTE [playerright], 0
                                jmp     game_loop
	jmp		game_loop

        dead:
                push    clear_screen_cmd
                call    system
                add     esp, 4
                push    death
                call    printf
                add     esp, 4
                push    800000
                call    usleep
                add     esp, 4
                jmp     game_loop_end
        winner: 
                push    clear_screen_cmd
                call    system
                add     esp, 4
                push    win
                call    printf
                add     esp, 4
                push    800000
                call    usleep
                add     esp, 4
                jmp     game_loop_end

	game_loop_end: 

                ; restore old terminal functionality
	call raw_mode_off

	;***************CODE ENDS HERE*****************************
	popa
	mov		eax, 0
	leave
	ret

inc_hook:
        mov     DWORD [destroy_hook], 0
        inc     DWORD [active_hook] 
        mov     eax, DWORD [ypos]
        mov     ebx, DWORD [xpos]
        mov     DWORD [hooky], eax
        mov     DWORD [hookx], ebx
        mov     eax, WIDTH
                         
                        mov     ebx, DWORD [hooky]
                        add     ebx, DWORD [hookDirY]
                        mov     DWORD [hooky], ebx
                        imul     eax, ebx
                        mov     ebx, DWORD [hookx]
                        add     ebx, DWORD [hookDirX]
                        mov     DWORD [hookx], ebx
                        add     eax, ebx  
                        lea     eax, [board + eax]
                        mov     ebx, DWORD [hookDirY]
                        add     ebx, DWORD [hookDirX]
                        mov     DWORD [hookCurrentPos], eax
                        add     DWORD [hookCurrentPos], ebx            
                        cmp     BYTE [eax], '#'
                        je      against_wall      
                        mov     BYTE [eax], HOOK
                        
        jmp     game_loop
        against_wall:
        dec     DWORD [active_hook]
        jmp     game_loop

        
; === FUNCTION ===
raw_mode_on:

	push	ebp
	mov		ebp, esp

	push	raw_mode_on_cmd
	call	system
	add		esp, 4

	mov		esp, ebp
	pop		ebp
	ret

; === FUNCTION ===
raw_mode_off:

	push	ebp
	mov		ebp, esp

	push	raw_mode_off_cmd
	call	system
	add		esp, 4

	mov		esp, ebp
	pop		ebp
	ret

; === FUNCTION ===
init_board:

	push	ebp
	mov		ebp, esp

	; FILE* and loop counter
	; ebp-4, ebp-8
	sub		esp, 8

	; open the file
	push	mode_r
	push	board_file
	call	fopen
	add		esp, 8
	mov		DWORD [ebp-4], eax

	; read the file data into the global buffer
	; line-by-line so we can ignore the newline characters
	mov		DWORD [ebp-8], 0
	read_loop:
	cmp		DWORD [ebp-8], HEIGHT
	je		read_loop_end

		; find the offset (WIDTH * counter)
		mov		eax, WIDTH
		mul		DWORD [ebp-8]
		lea		ebx, [board + eax]

		; read the bytes into the buffer
		push	DWORD [ebp-4]
		push	WIDTH
		push	1
		push	ebx
		call	fread
		add		esp, 16

		; slurp up the newline
		push	DWORD [ebp-4]
		call	fgetc
		add		esp, 4

	inc		DWORD [ebp-8]
	jmp		read_loop
	read_loop_end:

	; close the open file handle
	push	DWORD [ebp-4]
	call	fclose
	add		esp, 4

	mov		esp, ebp
	pop		ebp
	ret

; === FUNCTION ===
render:

	push	ebp
	mov		ebp, esp

	; two ints, for two loop counters
	; ebp-4, ebp-8
	sub		esp, 8

	; clear the screen
	push	clear_screen_cmd
	call	system
	add		esp, 4

	; print the help information
	push	help_str
	call	printf
	add		esp, 4

        ; print second help information
        push    help_str2
        call    printf
        add     esp, 4

        ; push score
        push    DWORD [score]
        push    fmt_score
        call    printf
        add     esp, 8

	; outside loop by height
	; i.e. for(c=0; c<height; c++)
	mov		DWORD [ebp-4], 0
	y_loop_start:
	cmp		DWORD [ebp-4], HEIGHT
	je		y_loop_end

		; inside loop by width
		; i.e. for(c=0; c<width; c++)
		mov		DWORD [ebp-8], 0
		x_loop_start:
		cmp		DWORD [ebp-8], WIDTH
		je 		x_loop_end

			; check if (xpos,ypos)=(x,y)
			mov		eax, [xpos]
			cmp		eax, DWORD [ebp-8]
			jne		print_board
			mov		eax, [ypos]
			cmp		eax, DWORD [ebp-4]
			jne		print_board
				; if both were equal, print the player
				push	PLAYER_CHAR
                                ;push    blink
                                ;push    light_magenta
                                push    blink
                                call    printf
                                add     esp, 4
				jmp		print_player
			print_board:
				; otherwise print whatever's in the buffer
                                
				mov		eax, [ebp-4]
				mov		ebx, WIDTH
				mul		ebx
				add		eax, [ebp-8]
				mov		ebx, 0
				mov		bl, BYTE [board + eax]
                                push            ebx      
                                cmp             bl, '#'
                                jne             not_wall
                                        push    light_magenta
                                        call    printf
                                        add     esp, 4
                                not_wall:
                                cmp             bl, 'Y'
                                jne             not_yellow
                                        push    yellow
                                        call    printf
                                        add     esp, 4
                                        jmp     print_end
                                not_yellow:
                                cmp             bl, 'R'
                                jne             not_red
                                        push    red
                                        call    printf
                                        add     esp, 4
                                        jmp     print_end
                                not_red:
                                cmp             bl, 'G'
                                jne             not_green
                                        push    green
                                        call    printf
                                        add     esp, 4
                                        jmp    print_end
                                not_green:
                                cmp             bl, 'B'
                                jne             hook_replace
                                        push    blue
                                        call    printf
                                        add     esp, 4	
                                        jmp     print_end
                                hook_replace:
                                cmp             DWORD [destroy_hook], 0
                                je              hook_color
                                cmp             bl, '*'
                                jne             print_end
                                mov             BYTE [board + eax], ' '
                                jmp             print_end
                                
                                hook_color:
                                cmp     bl, '*'
                                jne     print_end
                                        cmp     BYTE [last_color], 1
                                        je      hook_green
                                        cmp     BYTE [last_color], 2
                                        je      hook_red
                                        cmp     BYTE [last_color], 3
                                        je      hook_yellow
                                        cmp     BYTE [last_color], 4
                                        je      hook_blue
                                        
                                        hook_green:
                                                push    green
                                                jmp     print_hook_color
                                        hook_red:
                                                push    red
                                                jmp     print_hook_color
                                        hook_yellow:
                                                push    yellow
                                                jmp     print_hook_color
                                        hook_blue:
                                                push    blue
                                                jmp     print_hook_color
                                        print_hook_color:
                                                call    printf
                                                add     esp, 4
                                                jmp     print_end
                                
	                print_player:
                        call    putchar
                        add     esp, 4
                        push    color_default
                        call    printf
                        add     esp, 4
                        jmp     increment
        		print_end:
                       ; push	ebx
                        call putchar
			add		esp, 4
                        push    color_default
                        call    printf
                        add     esp, 4
                increment:        
		inc		DWORD [ebp-8]
		jmp		x_loop_start
		x_loop_end:

		; write a carriage return (necessary when in raw mode)
		push	0x0d
		call 	putchar
		add		esp, 4

		; write a newline
		push	0x0a
		call	putchar
		add		esp, 4

	inc		DWORD [ebp-4]
	jmp		y_loop_start
	y_loop_end:

	mov		esp, ebp
	pop		ebp
	ret

nonblocking_getchar:

; returns -1 on no-data
; returns char on succes

; magic values
%define F_GETFL 3
%define F_SETFL 4
%define O_NONBLOCK 2048
%define STDIN 0

	push	ebp
	mov		ebp, esp

	; single int used to hold flags
	; single character (aligned to 4 bytes) return
	sub		esp, 8

	; get current stdin flags
	; flags = fcntl(stdin, F_GETFL, 0)
	push	0
	push	F_GETFL
	push	STDIN
	call	fcntl
	add		esp, 12
	mov		DWORD [ebp-4], eax

	; set non-blocking mode on stdin
	; fcntl(stdin, F_SETFL, flags | O_NONBLOCK)
	or		DWORD [ebp-4], O_NONBLOCK
	push	DWORD [ebp-4]
	push	F_SETFL
	push	STDIN
	call	fcntl
	add		esp, 12

	call	getchar
	mov		DWORD [ebp-8], eax

	; restore blocking mode
	; fcntl(stdin, F_SETFL, flags ^ O_NONBLOCK
	xor		DWORD [ebp-4], O_NONBLOCK
	push	DWORD [ebp-4]
	push	F_SETFL
	push	STDIN
	call	fcntl
	add		esp, 12

	mov		eax, DWORD [ebp-8]

	mov		esp, ebp
	pop		ebp
	ret
