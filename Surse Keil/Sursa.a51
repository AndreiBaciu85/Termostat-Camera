org 0000h
	ljmp on
org 0003h;INT0 +
	mov R6, #1
	ljmp modify_trigger
org 0013h;INT1 -
	mov R6, #0
	ljmp modify_trigger
org 0100h
tabel: ;tabel temperatura
	db 01h, 03h, 06h, 08h, 0Bh, 0Dh
	db 10h, 12h, 15h, 18h, 1Ah, 1Dh, 1Fh 
	db 22h, 24h, 27h, 29h, 2Ch, 2Fh
	db 31h, 34h, 36h, 39h, 3Bh, 3Eh 
	db 40h, 43h, 46h, 48h, 4Bh, 4Dh
	db 50h, 52h, 55h, 57h, 5Ah, 5Dh, 5Fh
	db 62h, 64h, 67h, 69h, 6Ch, 6Eh
	db 71h, 74h, 76h, 79h, 7Bh, 7Eh
	db 80h, 83h, 85h, 88h, 8Bh, 8Dh
	db 90h, 92h, 95h, 97h, 9Ah, 9Ch, 9Fh
	db 0A2h, 0A4h, 0A7h, 0A9h, 0ACh, 0AEh
	db 0B1h, 0B3h, 0B6h, 0B9h, 0BBh, 0BEh
	db 0C0h, 0C3h, 0C5h, 0C8h, 0CAh, 0CDh
	db 0D0h, 0D2h, 0D5h, 0D7h, 0DAh, 0DCh, 0DFh
	db 0E1h, 0E4h, 0E7h, 0E9h, 0ECh, 0EEh
	db 0F1h, 0F3h, 0F6h, 0F8h, 0FBh, 0FDh, 0FEh
temp: db 'Temp: ',00h ;text
temp2: db 'Temp set:', 00h
temps equ 40
org 0250h
on:
mov IE, #85h ;activare INT0 si INT1 si T0
mov TMOD, #01h
setb IT0 ;INT0 valid pe falling edge
setb IT1 ;INT1 valid pe falling edge
RS bit P1.0
RW bit P1.1
E bit P1.2
Centrala bit P1.3
Plus bit P3.2
Minus bit P3.3
mov P0, #0FFh ;ADC
mov P1, #00h  ;biti
mov P2, #00h  ;LCD
mov P3, #0FFh ;butoane
acall init ;initialisare display
mov R5, #0h
mov dptr, #temp ;dptr->adresa temp
acall text_disp ;afisare text
mov R5, #1h
mov dptr, #temp2 ;dptr->adresa temp set
acall text_disp ;afisare text
mov a, #temps
acall temp_disp ;afisare temperatura setata
mov R7, #temps
main:
mov R5, #0h
acall temp_disp ; afisare temperatura
acall compare; stare releu
hold:
mov a, P0 ;citire ADC
cjne a, 03h, main ;adc new out
sjmp hold
;----------------------------

lcd_send:
mov P2, a ;D7-D0
cjne R0, #01h, command ;R0=0 comanda	
setb RS ;data ;R0=1 data
send:
clr RW
setb E
acall delay_5ms 
clr E ;tranzitie H->L
sjmp out
command:
clr RS
sjmp send
out:
ret

init:
mov a, #3Ch; Function Set
mov R0, #0;Command
acall lcd_send
acall delay_30ms
mov a, #06h; Entry Mode Set
acall lcd_send
acall delay_30ms
mov a, #01h; Display Clear
acall lcd_send
acall delay_30ms
mov a, #0Ch; Display On
acall lcd_send
acall delay_30ms
ret

text_disp:
cjne R5, #01, first_line
mov R0, #0 ;pozitionare cursor a doua linie
mov a, #0C0h
acall lcd_send
acall delay_30ms
first_line:
mov a, #00h
movc a, @a+DPTR
mov R0, #1
acall lcd_send
acall delay_30ms
inc DPTR
cjne a, #00h, first_line ;Verificare sfarsit sir
cjne R5, #01, celsius_deg
mov a, #0CEh;pozitionare cursor pe a doua linie
sjmp disp_deg
celsius_deg:
mov a, #8Eh;pozitionare cursor pe prima linie
disp_deg:
mov R0, #0 ;pozitionare cursor 
acall lcd_send
acall delay_30ms
mov R0, #1 ;afisare grad C 
mov a, #0DFh
acall lcd_send
acall delay_30ms
mov a, #43h
acall lcd_send
acall delay_30ms
ret

;------------------------------------------------
;cy=0 valoarea hexa a temperaturii nu a fost gasita
;in tabel, temperatura de pe display nu se schimba
;Functionalitate pentru increment de 0.5 grade
;Caz special pentru temperatura [0, 10) grade
;------------------------------------------------
temp_disp:
cjne R5, #00h, temp_set
mov a, P0 ;citire ADC
mov R3, a ;exemplar pentru verificare temperatura noua
temp_set:
acall convert 
jnc no_temp_disp
cjne R1, #30h, disp_two_digit_temp
mov R1, ' ' ;valabil pentru t [0, 10)
disp_two_digit_temp:
cjne R5, #01, choose_line
mov a, #0CAh;pozitionare cursor pe a doua linie
sjmp disp_temperature
choose_line:
mov a, #8Ah ;pozitionare cursor pe prima linie
disp_temperature:
mov R0, #0 ;comanda
acall lcd_send
acall delay_30ms
mov R0, #1 ;date
mov a, R1
acall lcd_send
acall delay_30ms
mov a, R2
acall lcd_send
acall delay_30ms
cjne R4, #00h, half_degree_disp ;verificare rest addr mod 2
mov a, ' ' ;"stergere" .5
acall lcd_send
acall delay_30ms
acall lcd_send
acall delay_30ms
jmp no_temp_disp
half_degree_disp: ;afisare .5
mov a, #2Eh
acall lcd_send
acall delay_30ms
mov a, #35h
acall lcd_send
acall delay_30ms
no_temp_disp:
ret


convert:
cjne R5, #00h, skip
acall bin_search ;conversie hexa->adresa [0,100] zecimal 
jnc no_disp ;cy=0 valoarea hexa a temperaturii nu a fost gasita
			;in tabel, temperatura de pe display nu se schimba
skip:
mov b, #02h
div ab
mov R4, b ;salvare rest addr mod 2
mov b, #0Ah
div ab
add a, #30h ;cifra-> ascii
mov R1, a ;cifra zecilor
mov a, b
add a, #30h ;cifra-> ascii
mov R2, a ;cifra unitatilor
setb c; "flag" pentru conversie reusita
no_disp:
ret

bin_search:
mov R4,#0 ;stanga
mov R5, #100 ;dreapta
start_search:
mov dptr, #tabel ;adresa tabel
clr c ;clear cy
mov a, R5
subb a, R4 ;verificare stanga>dreapta
jc not_found
mov a, R4
add a, R5
clr c
rrc a ;a=(stanga+dreapta)>>1
mov b, a ;exemplar mijloc
mov dpl, a
mov a, #0
movc a, @a+dptr ;incarcare element din mijloc
cjne a, 03h, decide ;verificare daca am gasit elementul
jmp found
decide:
subb a, R3 ;similar cu ja si jb
jc right_pivot
left_pivot:
mov a, b
jz not_found ;addr=0 si elementul nu a fost gasit
dec a 
mov R5, a
jmp start_search ;bin_search(left, mid-1)
right_pivot:
inc b
mov R4, b
jmp start_search ;bin_search(mid+1, right)
not_found:
clr c ;"flag"
jmp fin
found:
mov a, dpl ;salvare adresa in acc [0h, 64h]
setb c
fin:
ret

delay_5ms:
clr TR0
mov TH0, #0EEh
mov TL0, #2Ah
setb TR0
check: jnb TF0, check
clr TR0
clr TF0
ret

delay_30ms:
clr TR0
mov TH0, #94h
mov TL0, #0FBh
setb TR0
check1: jnb TF0, check1
clr TR0
clr TF0
ret

compare:
mov DPTR, #tabel
mov a, DPL
add a, R7
dec a
mov DPL, a
mov a, #00h
movc a, @a+DPTR ;conversie temp_set in valoare posibila de la adc
mov b, R3
subb a, b ;determinare relatie intre temp set si temp actuala
jc heat_off
mov a, #10
implement:
acall delay_30ms
djnz acc, implement
setb Centrala
sjmp compare_end
heat_off:
acall delay_30ms
clr Centrala
compare_end:
ret

modify_trigger:
push 05h
push acc
mov a, b
push acc
cjne R6, #1, decrease ;flag
inc R7
sjmp change
decrease:
dec R7
change: ;temp set limit 10-28
cjne R7, #19, upper_limit
inc R7
upper_limit:
cjne R7, #57, ok
dec R7
ok:
mov R5, #1
mov a, R7
acall temp_disp ;afisare temp set
acall compare ;stare releu
pop acc
mov b, a
pop acc
pop 05h
reti

end