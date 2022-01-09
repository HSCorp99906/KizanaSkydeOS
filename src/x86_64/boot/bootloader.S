[ORG 0x7C00]  ; Set offset to 0x7C00 to where boot sector is
			  ; loaded into memory.

%define KERNEL_OFFSET 0x1000
%define DRIVE_MAGIC_OFFSET 0x9000


xor ax, ax  ; Set ax to 0.
mov ds, ax  ; Set data segment to 0.
mov ss, ax  ; Set stack segment to 0.
cld         ; ???

_start:
	mov [BOOT_DRIVE], dl 			; Moving the boot drive into BOOT_DRIVE memory location.

	mov si, start_msg				; Moving the start message into SI.
	call puts						; Calling puts.

	mov bp, 0x8000					; Set base to safe location.
	mov sp, bp						; Setup SP to base.

	mov si, disk_check_msg  		; Announces disk check.
	call puts						; Prints message.

	mov bx, DRIVE_MAGIC_OFFSET		; Load second sector into DRIVE_MAGIC_OFFSET. 
	mov dh, 1						; Load one sector.
	mov dl, [BOOT_DRIVE]			; Read from this drive.
	mov [READ_FROM], byte 0x02		; Start reading at sector 2.
	call disk_load

	mov si, got_msg					; Prepares the results.
	call puts						; Prints message.

	mov dx, [DRIVE_MAGIC_OFFSET] 	; Move to DX the value at address 0x9000.
	call print_hex 					; Print the value at the beginning the the memory block.
	call disk_check

	mov si, ok_msg					; Prep the OK message.
	call puts						; Print it out.

	jmp $							; Infinite loop.

; Start message.
start_msg: db 0x0D, 0x0A, 0x0D, 0x0A, "Booting KizanaSkydeOS..", 0x0D, 0x0A, "Made by Ian Marco Moffett.", 0x0D, 0x0A, 0
disk_error_msg: db 0x0D, 0x0A, "Failed to read from disk (System Halted).", 0x0D, 0x0A, 0 	; Message in case we fail to read from disk.
disk_check_msg: db 0x0D, 0x0A, "Checking disk, expecting 0xFFFF..", 0x0D, 0x0A, 0
got_msg: db "Got: ", 0
ok_msg: db 0x0D, 0x0A, "OK", 0x0D, 0x0A, 0
disk_check_failed_msg: db 0x0D, 0x0A, "Failed to verify disk (System Halted).", 0x0D, 0x0A, 0

BOOT_DRIVE: db 0   							; Boot drive goes here.
DISK_MAGIC: dw 0xFFFF   					; Disk magic to make sure the disk is loading right.
DISK_MAGIC_STR: db "0xFFFF", 0	; Disk magic with null terminator.
READ_FROM: db 0		  						; Sector to read from.  


; Checks disk and makes sure it can read corrently.
disk_check:
	mov si, DISK_MAGIC_STR		; Moves DISK_MAGIC_STR to si.
	mov ecx, hexString			; Moves DISK_MAGIC loaded to ecx.

disk_check_loop:
	mov al, [si]			; Move into AL the current value SI is pointing to.
	or al, al				; Check if AL is zero.
	jz return				; If AL is zero return.
	cmp [ecx], al			; Check if ECX is equal to AL.
	jne disk_check_failed	; If ECX != AL => disk_check_failed.
	inc si					; Get the next value.
	inc ecx					; Get the next value.
	jmp disk_check_loop		; Continue.

puts:
	mov ah, 0x0e    ; BIOS print subroutine.
	lodsb			; Loads byte from SI into AL and increments SI.
	or al, al		; If al is zero a zero flag will be set.
	jz return		; If zero we will return.
	int 0x10		; BIOS video interrupt.
	jmp puts  		; If not zero, continue.

return: ret			; Return label.

; Disk load label.
; Loads DH sectors into the memory address at BX.
disk_load:
	push dx 				; Save DX on stack so we do not change DH if modified.
	mov ah, 0x02 			; BIOS read sectors routine.
	mov al, dh				; Read DH sectors.
	mov ch, 0x00			; Select cylinder 0.
	mov dh, 0x00 			; Select head 0.
	mov cl, [READ_FROM] 	; Start reading after sector 2.
	int 0x13				; BIOS interrupt.

	jc disk_error   		; If an oopsie happens then we jump to this label.

	pop dx
	cmp dh, al				; AL (sectors read), DH sectors expected. DH is most significant byte of DX.
	jne disk_error			; Error message & halt CPU.
	ret

; If we fail to read disk we jump to here.
disk_error:
	mov si, disk_error_msg		; Move disk error message into SI.
	call puts					; Print to screen.
	cli							; Clear interrupts so we can't go back to this address.
	hlt 						; Halt the CPU from executing from this address.


disk_check_failed:
	mov si, disk_check_failed_msg
	call puts
	cli		; Clear interrupts.
	hlt		; Halt the CPU from executing from this address.


print_hex:
    pusha               ; save all registers to the stack
    mov cx, 0           ; initialize loop counter
    
hex_loop:
    cmp cx, 4           ; are we at end of loop?
    je end_hexloop		; Ends loop.

    ;; Convert DX hex values to ascii
    mov ax, dx
    and ax, 0x000F      ; turn 1st 3 hex to 0, keep final digit to convert
    add al, 0x30        ; get ascii number or letter value
    cmp al, 0x39        ; is hex value 0-9 (<= 0x39) or A-F ( > 0x39)
    jle move_intoBX		; Does what the label says.
    add al, 0x07        ; to get ascii 'A'-'F'

move_intoBX:
    mov bx, hexString + 5   ; base address of hexString + length of string
    sub bx, cx              ; subtract loop counter
    mov [bx], al 
    ror dx, 4               ; rotate right by 4 bits,
                            ; 0x12AB -> 0xB12A -> 0xAB12 -> 0x2AB1 -> 0x12AB
    add cx, 1               ; increment counter
    jmp hex_loop            ; loop for next hex digit in DX

end_hexloop:
    mov si, hexString
    call puts

    popa                ; restore all registers from the stack
    ret                 ; return to caller


hexString:  db "0x0000", 0   ; Hex converted to string goes here.


times 510-($-$$) db 0	; Sector padding.
db 0x55		; Magic.
db 0xAA		; Magic.

times 256 dw 0xFFFF		; This is for a check during boot, we will fill up sector 2 with 0xFFFF.
