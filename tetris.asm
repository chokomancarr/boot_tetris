[BITS 16]
[org 0x7C00]

start:
    cli
    ;create stack
    mov eax,0x00
    mov ss,ax           ;stack 0
    ;mov sp,0xffff       ;stack offset
    sti
    
    mov ah,0x00
    mov al,0x0D         ;320x200 16 color graphics (EGA,VGA)
    int 0x10
    
    mov ah,0x01
    mov cx,0x2000       ;disable cursor
    int 0x10
    
    ;init data
    ;mov bx,0x0a         ;10y
    ;.loopy:
    ;    mov ax,0x08     ;8x
    ;    .loopx:
    ;        push 0x0001
    ;        dec ax
    ;        test ax,ax
    ;        jnz .loopx
    ;    dec bx
    ;    test bx,bx
    ;    jnz .loopy
    
    mov sp,0xff4f
    push 0x41           ;current block location 0xXY
    push 0x42
    push 0x43
    push 0x53
    push 0x01
    mov sp,0xff2f
    
.draw
    call draw
    
.waitinput
    mov word[0xfe10],0x00   ;down command?
    call get_input
    cmp al,0x73 ;s
    je .down
    cmp al,0x61 ;a
    je .left
    cmp al,0x64 ;d
    je .right
    jmp .waitinput
    
.check
    ;jmp .apply
    call is_colliding
    test al,al
    jnz .hit
.apply
    mov bx,0xff3f
    mov dx,0xff4f
    mov cl,0x04
    .loopapply
        call movsim1
        call movsim2
        jnz .loopapply
    jmp .draw

.hit
    mov si,word[0xfe10]
    test si,si
    jz .waitinput
    ;jmp .waitinput
    ;apply block
    call setactbcd
    .loophitapply
        call movsim1 ;id in al
        push bx
        mov bx,0xff4f
        push ax
        shr al,0x04
        shl al,0x01
        add bl,al
        pop ax
        shl al,0x04
        add bl,al
        mov si,[0xff45]
        mov word[bx], si
        pop bx
        call dc
        jnz .loophitapply
    call newblock
    jmp .draw

.down
    mov word[0xfe10], 0x10
    call setactbcd
    .loopdown
        call movsim1
        inc al
        call movsim2
        jnz .loopdown
    jmp .check
.left
    call setactbcd
    .loopleft
        call movsim1
        sub al,0x10
        call movsim2
        jnz .loopleft
    jmp .check
.right
    call setactbcd
    .looprght
        call movsim1
        add al,0x10
        ;mov [bx],ax
        call movsim2
        jnz .looprght
    jmp .check

movsim1:
    sub bl,0x02
    sub dl,0x02
    mov ax,[bx]
    retn
movsim2:
    push bx
    mov bx,dx
    mov [bx],ax
    pop bx
    call dc
    retn
;.check_clear:

draw:
    mov bx,0xffff           ;stack index
    mov dx,0x000a           ;10y
    .loopy
        mov cx,0x0008       ;8x
        .loopx
            ;mov bx,0xffff
            sub bl,0x02
            mov ax,[bx]
            push bx
            
            mov ah,0x0c ;draw pixel
            ;mov al,0x0f
            mov bh,0x00
            int 0x10
            
            pop bx
            call dc
            jnz .loopx
        dec dl
        test dl,dl
        jnz .loopy
    
    ;active block
    call setactbcd ;dx will be overridden anyway
    .loopcb
        sub bl,0x02
        mov ax,[bx]
        
        push cx
        push bx
        mov cx,ax
        shr cx,0x04
        mov dx,ax
        and dx,0x000f
        
        mov ah,0x0c
        mov al,0x0f
        mov bh,0x00
        int 0x10
        
        pop bx
        pop cx
        call dc
        jnz .loopcb
    retn

newblock:
    mov [0xfe00],sp
    mov sp,0xff4f
    push 0x41           ;current block location 0xXY
    push 0x42
    push 0x43
    push 0x53
    push 0x02
    mov sp,[0xfe00]
    retn

has_input:              ; call has_input jz [ ]
    mov ah,0x0b
    int 0x21
    or al,al
    retn

get_input:              ; key in AL
    call has_input
    jz .end
    ;cmp al,0x19         ;do not read control chars
    ;jle .cancel
    mov ah,0x00
    int 0x16
.end
    retn

is_colliding:               ;al = 0xff when colliding
    mov [0xfe00],sp
    mov bx,0xffff           ;stack index
    mov dl,0x0a           ;10y
    .loopy
        mov cl,0x08       ;8x
        .loopx
            sub bl,0x02
            mov ax,[bx]
            ;test ax,ax
            ;jz .emptycheck
            push cx
            push dx
            push bx
            
            shl cl,0x04
            or cl,dl
            mov bx,0xff3f
            mov dl,0x04
            .loopCol
                sub bl,0x02
                test ax,ax
                jz .emptycheck
                cmp word[bx],cx
                je .colld
                .emptycheck
                    ;outside bounds?
                    push dx
                    mov dx,[bx]
                    push dx
                    shr dl,0x04
                    ;and dl,0x0f
                    test dl,dl
                    jz .colld
                    cmp dl,0x09
                    je .colld
                    pop dx
                    and dl,0x0f
                    cmp dl,0x0b
                    je .colld
                    pop dx
                    dec dl
                    test dl,dl
                    jnz .loopCol
            pop bx
            pop dx
            pop cx
            call dc
            jnz .loopx
        dec dl
        test dl,dl
        jnz .loopy
        
    mov sp,[0xfe00]
    xor al,al
    retn
    .colld
        mov sp,[0xfe00]
        mov al,0xff
        retn

setactbcd:
    mov bx,0xff4f
    mov dx,0xff3f
    mov cl,0x04
    retn

dc:
    dec cl
    test cl,cl
    retn

TIMES 510 - ($ - $$) db 0
DW 0xAA55