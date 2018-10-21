COMMENT &
/*****************************************************************
           ****** IGRICA ZMIJICE ******

Napisana koristeci Irvine32.inc biblioteku i Irvine-ove
preporuke za modele koji se koriste i velicinu steka za rad
u VS2017.
Na samom pocetku korisnika docekuje interaktivni WELCOME meni
u kom se vrsi izbor brzine kretanja zmijice, prilika da se 
pokrene igra sa default vrednoscu brzine i opcija za napustanje
igrice.
U bilo kom trenutku tokom igranja moguce je napustiti igricu
pritiskom na ESC dugme, cime se korisnik vraca na WELCOME meni
gde se moze izabrati opcija za konacan izlazak iz igre.

Kod i logika igrice su isparcani na najsitnije logicke celine
grupisane u labele i procedure, kako bi krajnje upravljanje bilo
jednostavno. Svaka procedura odradjuje pipav deo posla koji joj
je prepusten, tako da je detaljisanje u main proceduri minimalno,
bez guzve i necitkosti.
*****************************************************************/&

include Irvine32.inc
include macros.inc

.386
.model flat, stdcall
.stack 4096
ExitProcess proto, dwExitCode:dword

.const
	;// Definisanje velicine prozora 
	xmin = 0	;// leva ivica
	xmax = 79	;// desna ivica
	ymin = 0	;// gornja ivica
	ymax = 24	;// donja ivica

	;// Oznake za levo, desno, gore, dole, ESC, ASCII
	LEFT_KEY = 025h        
	UP_KEY = 026h
	RIGHT_KEY = 027h
	DOWN_KEY = 028h
	ESC_KEY = 01Bh
	
	;// Definisanje pocetnih koordinata zmijice i pocetnog smera kretanja
	;// Valja blago prepraviti kod u initSnake kako bi se zmija postavila
	;// vertikalno, umesto horizontalno, kao sto je trenutno.
	headX_default = 40d
	headY_default = 12d
	tailX_default = 37d
	tailY_default = 12d
	direction_default = 'R'		;// R-right, U-up, D-down, L-left

.data
	;// Stringovi za ispis WELCOME screena i izbor brzine zmijice

	T1 byte  "  _______            _    _     _               _  ", 0dh, 0ah, 0
	T2 byte  " |_____  |          (_)  (_)   (_)             | | ", 0dh, 0ah, 0
	T3 byte  "      / / _ __  __   _  ______  _   ____  __ _ | | ", 0dh, 0ah, 0
	T4 byte  "     / / | '_ \/_ \ | ||____  || | / __/ / _` || | ", 0dh, 0ah, 0
	T5 byte  "    / /  | | | | | || |     | || || (__ | (_| || | ", 0dh, 0ah, 0
	T6 byte  "   / /   |_| |_| |_||_| _   | ||_| \___\ \__,_|| | ", 0dh, 0ah, 0
	T7 byte  "  |  |________________ | |__/ /_______________ |_| ", 0dh, 0ah, 0
	T8 byte  "  |___________________\\_____//_______________|(_) ", 0dh, 0ah, 0


	welcomeString byte  " ", 0dh, 0ah,
						"1. Pocetak igre", 0dh, 0ah,
						"2. Izbor brzine", 0dh, 0ah,
						"3. Izlaz", 0dh, 0ah, 0
						;//"4. Izbor igralista", 0dh, 0ah,0

	copyright byte " ", 0dh, 0ah, " ", 0dh, 0ah, " ", 0dh, 0ah, " ", 0dh, 0ah,
				   " ", 0dh, 0ah, " ", 0dh, 0ah, " ", 0dh, 0ah, " ", 0dh, 0ah,
				   " ", 0dh, 0ah, 
				   "					Copyleft by Dragan Bozinovic 211/2015", 0dh, 0ah,
				   "						    Kristijan Mitrovic 214/2015", 0dh, 0ah, 0
						

	levelString  byte "Izbor nivoa:", 0dh, 0ah,
					  "1. Beskonacno ", 236, 0dh, 0ah,
					  "           __ ", 0dh, 0ah,
					  "2. Kutija |__|", 0dh, 0ah,0

	speedString  byte "Izbor brzine:", 0dh, 0ah,
					  "1. Decije -.-", 0dh, 0ah,
					  "2. Normalno O.O", 0dh, 0ah,
					  "3. Napredno \0.0/", 0dh, 0ah,
					  "4. Ludiloooo!", 0dh, 0ah, 0

	gameOverString byte "Game Over!", 0

	scoreString  byte "Score: 0", 0

	yourScoreString byte "GAME OVER! Vas score je ", 0

	;// Promenljive koriscene u programu
	frameBuffer word 1920 dup(0)	;// Frejmbafer u kom se pamte stanja svakog od
									;// 24*80 polja u konzoli, medju kojima su prazna
									;// polja predstavljena nulama, sama zmijica i 
									;// hrana i eventualni zidovi

	headY byte headY_default        ;// Y koordinata glave zmije
	headX byte headX_default        ;// X koordinata glave zmije
	tailY byte tailY_default        ;// Y koordinata repa zmije
	tailX byte tailX_default        ;// X koordinata repa zmije
	foodY byte ?					;// Y koordinata hrane
	foodX byte ?					;// X koordinata hrane

	currDirection byte direction_default	;// Trenutni smer kretanja zmije
	newDirection byte direction_default		;// Zeljeni smer kretanja koji je uneo igrac
	snakeSpeed dword 100					;// Brzina zmijice koja je zapravo period sa kojim se osvezava iscrtavanje na ekranu

	tempY byte 0         ;// Pomocna promenljiva za smestanje Y koordinate
	tempX byte 0         ;// Pomocna promenljiva za smestanje X koordinate

	Yabove byte 0d          ;// Red iznad trenutnog
	Xleft byte 0d           ;// Kolona levo od trenutne
	Ybelow byte 0d          ;// Red ispod trenutnog
	Xright byte 0d          ;// Kolona desno od trenutne

	flag_tail byte 1d		;// Fleg koji oznacava da li rep treba da bude obrisan ili ne
	search word 0d			;// Vrednost sledeceg segmenta zmijice koji se iscrtava
	flag_endTheGame byte 0d ;// Fleg koji oznacava da li igra treba da se prekine
	playerScore dword 0d	;// Total score
	welcomeDelay dword 100

	windowRect SMALL_RECT <xmin, ymin, xmax, ymax>      ;// Velicina prozora
	winTitle byte "Zmijica", 0							;// Naslov programa
	cursorInfo CONSOLE_CURSOR_INFO <>					;// Informacije o kursoru


.data?
	;// Promenljive koje su potrebne za hendlovanje podataka unetih u konzolu tj. interakciju sa korisnikom
	stdOutHandle handle ?
	stdInHandle handle ?		;// Promenljiva za kontrolu inputa u konzolu
	numInp dword ?				;// Broj bajtova u ulaznom baferu
	temp byte 16 dup(?)			;// Promenljiva koja sadrzi podatke tipa INPUT_RECORD
	bRead dword ?				;// Broj procitanih ulaznih bajtova


.code
;// -----------------------------------------------------------------------------------------------------------
;// main procedura koja postavlja WELCOME screen, hendluje izbor brzine zmijice
;// i prosledjuje podprocedurama inicijalizaciju ekrana za pocetak igre, postavljanje
;// pocetne zmijice na sredinu ekrana, generisanje hrane na nasumicnom mestu i poziva
;// najvazniju proceduru startGame koja prati komande koje zadaje korisnik i kontrolise
;// kretanje zmijice.
;// Zbog pozivanja silnih procedura koje svaka za sebe obavljaju deo posla, interfejs
;// u main proceduri je prilicno jednostavan, na stranu to sto je potreban veliki
;// broj komandi za obavljanje nekih jednostavnih funkcija, sto nije slucaj sa nekim
;// visim programskim jezikom.
;// -----------------------------------------------------------------------------------------------------------

main PROC

	invoke GetStdHandle, STD_OUTPUT_HANDLE							 ;// Postavlja handle za ispis podataka
    mov  stdOutHandle, eax

    invoke GetConsoleCursorInfo, stdOutHandle, addr cursorInfo       ;// Cita trenutno stanje kursora
    mov  cursorInfo.bVisible, 0										 ;// Postavlja vidljivost kursora na nevidljiv
    invoke SetConsoleCursorInfo, stdOutHandle, addr cursorInfo       ;// Postavlja novo stanje kursora

    invoke SetConsoleTitle, addr winTitle							 ;// Postavlja title prozora
    invoke SetConsoleWindowInfo, stdOutHandle, TRUE, addr windowRect ;// Dimenzije prozora
    mov eax, green + (black * 16)									 ;// Boja interfejsa i prozora. Upisuju se u al i ah registre, zato je zapis ovakav
    call SetTextColor      

    menu:
    call Randomize						;// Postavlja seme za randomizaciju, slicno C-ovskoj logici
    call clrscr							;// Brise ekran konzole	
	call welcomeZmijica					;// Ispis velikog stilizovanog ZMIJICA
    mov edx, offset welcomeString       
    call WriteString					;// Ispis menija
	mov edx, offset copyright
	call WriteString

    welcomeLoop:                    ;// Loopovanje kroz WELCOME meni dok se ne unese
								    ;// pravilan izbor
		call ReadChar

		cmp al, '1'                 ;// 1. Pocni igricu
		je initializeGame

		cmp al, '2'                 ;// 2. Izbor brzine
		je speed

		;//cmp al, '4'                 ;// 4. Izbor tipa igralista
		;//je level

		cmp al, '3'                 ;// 3. Izlazak iz programa
		jne welcomeLoop             ;// Ili se vrti dok se ne unese ispravan izbor
                               
		EXIT

	
    level:							;// Meni za izbor nivoa, tj. tipa igralista
		call clrscr                 
		mov edx, offset levelString      
		call WriteString            ;// Ispis menija za izbor nivoa

		loopLevel:                      ;// Loopovanje kroz meni za izbor nivoa
			call ReadChar

			cmp al, '1'                 ;// 1. Beskonacno igraliste bez granica
			je levelBeskonacno

			cmp al, '2'                 ;// 2. Ogradjeno igraliste
			je levelKutija

			jmp loopLevel                   

		levelBeskonacno:                     
			call clearMem               ;// Brise frejmbafer i resetuje sve flegove
			mov al, 1                   ;// Postavlja fleg za generisanje nivoa u al i skace
			call generateLevel          ;// na proceduru koja generise nivo
			jmp menu

		levelKutija:                    
			call clearMem               
			mov al, 2                   
			call generateLevel              
			jmp menu
		
	


    speed:							;// Meni za izbor brzine
		call clrscr                 
		mov edx, offset speedString      
		call WriteString            ;// Ispis menija za izbor brzine

		loopSpeed:                      ;// Loopovanje kroz meni za izbor brzine
			call ReadChar

			cmp al, '1'                 ;// Decije
			je speed1

			cmp al, '2'                 ;// Normalno
			je speed2

			cmp al, '3'                 ;// Napredno
			je speed3

			cmp al, '4'                 ;// Ludilo
			je speed4

			jmp loopSpeed

		speed1:                     ;// Brzina zmijice odredjena je refresh rate-om
			mov snakeSpeed, 150
			jmp menu

		speed2:                     
			mov snakeSpeed, 100
			jmp menu

		speed3:
			mov snakeSpeed, 50             
			jmp menu

		speed4:
			mov snakeSpeed, 35            
			jmp menu                    ;// Povratak na glavni meni po izboru brzine


    initializeGame:                     ;// Postavlja flegove potrebne za generisanje
										;// zmijice i hrane i poziva glavnu proceduru
										;// startGame koja hendluje samu igru
		mov eax, 0						;// Ciscenje registara
		mov edx, 0
		call clrscr						
		call initSnake					;// Postavlja zmiju na pocetnu poziciju
		call Paint						;// Iscrtava igraliste na kom se nalazi zmija
		call createFood					;// Postavlja hranu na nasumicno mesto na ekranu
		call startGame					;// Poziv glavne funkcije za pokretanje igre

		mov eax, green + (black * 16)	;// Ako je procedura startGame zavrsila posao, to znaci
		call SetTextColor				;// da je iz nekog razloga (sudar ili ESC) kraj igre
		jmp menu						;// i igrac se vraca na pocetni meni

main ENDP
;// --------------------------------------------------------------------------------------------

welcomeZmijica PROC			;// Iscrtava veliko stilizovano Zmijica na WELCOME screen

	mov edx, offset T1
	call WriteString
	mov eax, welcomeDelay
	call delay
	mov edx, offset T2
	call WriteString
	mov eax, welcomeDelay
	call delay
	mov edx, offset T3
	call WriteString
	mov eax, welcomeDelay
	call delay
	mov edx, offset T4
	call WriteString
	mov eax, welcomeDelay
	call delay
	mov edx, offset T5
	call WriteString
	mov eax, welcomeDelay
	call delay
	mov edx, offset T6
	call WriteString
	mov eax, welcomeDelay
	call delay
	mov edx, offset T7
	call WriteString
	mov eax, welcomeDelay
	call delay
	mov edx, offset T8
	call WriteString
	mov eax, welcomeDelay
	call delay

	RET
welcomeZmijica ENDP


initSnake PROC USES ebx edx	   ;// Postavlja zmijicu duzine 4 polja na koordinate definisane sa headX/Y_default
								
    mov dh, headY_default      ;// Y pozicija glave
    mov dl, headX_default      ;// X pozicija glave
    mov bx, 1				   ;// To je prvi segment zmijice (glava) koji se upisuje u bx 
    call saveIndex			   ;// a potom pamti u frejmbaferu preko saveIndex procedure

    mov dh, headY_default	   ;// Y pozicija vratnog dela
    mov dl, headX_default - 1  ;// X pozicija vratnog dela
    mov bx, 2				   ;// Drugi segment zmije (vrat)
    call saveIndex  

    mov dh, headY_default	   ;// Y pozicija kicmenog dela
    mov dl, headX_default - 2  ;// X pozicija kicmenog dela
    mov bx, 3				   ;// Treci segment zmije (kicma)
    call saveIndex 

    mov dh, headY_default	   ;// Y pozicija repa
    mov dl, headX_default - 3  ;// X pozicija repa
    mov bx, 4				   ;// Cetvrti segment zmije (rep)
    call saveIndex 

    RET

initSnake ENDP


clearMem PROC				;// Brise frejmbafer, resetuje poziciju zmije i duzinu
							;// i postavlja sve flegove na njihovu default vrednost
    mov dh, 0               ;// Postavja registar kojim se krece kroz Y koordinate na 0
    mov bx, 0               ;// Postavlja data registar na 0

    rowLoop:                ;// Obilazak matrice po redovima
        cmp dh, 24          ;// Broji dok ne dostigne 24 (poslednji red) i iskace
        je endRowLoop

        mov dl, 0           ;// Postavlja registar kojim se krece kroz X koordinate na 0

        columnLoop:              ;// Obilazak kolona unutar trenutnog reda
            cmp dl, 80			 ;// Kada dodje do 80 (poslednja kolona), iskace
            je endColumnLoop     

            call saveIndex		 ;// Poziva proceduru za upis u frejmbafer na osnovu dh i dl
								 
            INC dl				 ;// Petlja se nastavlja u sledecoj koloni
            jmp columnLoop       

    endColumnLoop:           ;// Kraj unutrasnje petlje
        INC dh				 ;// Povecava broj reda i nastavlja petlju u njemu
        jmp rowLoop           

endRowLoop:								  ;// Kraj spoljasnje petlje
    mov tailY, tailY_default              ;// Resetuje koordinate glave i repa na default
    mov tailX, tailX_default             
    mov headY, headY_default              
    mov headX, headX_default			  

    mov flag_endTheGame, 0					;// Brise fleg koji oznacava kraj igre (dakle, nije kraj igre jos)
    mov flag_tail, 1						;// Postavlja fleg za brisanje repa (nikakva hrana nije pojedena, vraca zmijicu na 4 polja)
    mov currDirection, direction_default    ;// Trenutni i sledeci smer kretanja vraceni na default
    mov newDirection, direction_default    
	mov snakeSpeed, 100
    mov playerScore, 0						;// Resetuje score igraca

    RET
clearMem ENDP


startGame PROC USES eax ebx ecx edx
COMMENT &/*
Ova procedura je zapravo glavna, zaduzena je za obavljanje glavnog posla, a to
je upravljanje zmijicom, reagovanje na kontrole koje zadaje korisnik, i zavisno
od trenutnog smera kretanja menja ili ne menja kretanje zmije.
Procedura takodje vrsi kontrolu vremenskog razmaka izmedju iscrtavanja, cime se 
prividno kontrolise brzina zmije.
Izvrsava se beskonacna petlja iz koje se iskace kada korisnik pritisne ESC ili
dodje do sudara zmije sa samom sobom ili sa zidom (ako ga ima), i pri izlasku
se resetuju flegovi i cisti frejmbafer.
*/&

        mov eax, green + (black * 16)       
        call SetTextColor
        mov dh, 24                          ;// Ispisivanje skora u donjem levom uglu
        mov dl, 0                           
        call GotoXY                         
        mov edx, offset scoreString
        call WriteString

        ;// Uzima input iz konzole i smesta u memoriju
        invoke getStdHandle, STD_INPUT_HANDLE
        mov stdInHandle, eax
        mov ecx, 10
        ;// Cita dva dogadjaja iz bafera
        invoke ReadConsoleInput, stdInHandle, addr temp, 1, addr bRead
        invoke ReadConsoleInput, stdInHandle, addr temp, 1, addr bRead

       
    mainGameLoop:		;// Glavna beskonacna petlja

        ;// Broj dogadjaja u baferu
        invoke GetNumberOfConsoleInputEvents, stdInHandle, addr numInp
        mov ecx, numInp

        cmp ecx, 0                          ;// Provera da li je input bafer prazan
        je done                             ;// Ako jeste, to znaci da nije bilo interakcije korisnika
											;// sa programom i preskace se hendlovanje bilo kakvog inputa
											;// i nastavlja sa kretanjem zmijice u smeru u kom je zapocela kretanje

        ;// Cita jedan event iz bafera i smesta u temp
        invoke ReadConsoleInput, stdInHandle, addr temp, 1, addr bRead
        mov dx, word PTR temp               ;// Samo u slucaju da je event tipa KEY_EVENT,
        cmp dx, 1                           ;// sto su ugradjeni tipovi za dogadjaje koji se signaliziraju
        jne mainGameLoop                    ;// operativnom sistemu kada se desi input na tastaturi, onda se procesira dalje taj dogadjaj

            mov dl, byte PTR [temp+4]       ;// Posto se signal generise i u slucaju da se dugme pritisne i otpusti
            cmp dl, 0						;// biti koji znace otpustanje se preskacu
            je mainGameLoop
                mov dl, byte PTR [temp+10]  ;// a pritisnuti koji vracaju hexa kod dugmeta koje je pritisnuto se procesiraju

                cmp dl, ESC_KEY                 ;// Ako je ESC pritisnut, vraca se na pocetni meni
                je quit                     

                cmp currDirection, 'U'      ;// Samo u slucaju da se zmija krece navise ili nanize, moze se izvrsiti
                je handleHorMovement        ;// promena smera kretanja u levo ili desno, zavisno od pritisnutog tastera
                cmp currDirection, 'D'                  
                je handleHorMovement                   

                jmp handleVerMovement       ;// Ako se ne prodju gornje dve provere, to znaci da je trenutno kretanje zmije
                                            ;// horizontalno, pa se mogu procesirati samo promene smera u vertikalnom pravcu
                handleHorMovement:
                    cmp dl, LEFT_KEY              ;// Ukoliko je pritisnuta strelica ulevo
                    je handleHorMovement1

                    cmp dl, RIGHT_KEY             ;// Ukoliko je pritisnuta strelica udesno
                    je handleHorMovement2

                    jmp mainGameLoop          
                                            
                    handleHorMovement1:
                        mov newDirection, 'L'       
                        jmp mainGameLoop

                    handleHorMovement2:
                        mov newDirection, 'R'       
                        jmp mainGameLoop

                handleVerMovement:
                    cmp dl, UP_KEY             ;// Pritisnuta strelica navise
                    je handleVerMovement1

                    cmp dl, DOWN_KEY           ;// Nanize
                    je handleVerMovement2

                    jmp mainGameLoop           
												
                    handleVerMovement1:
                        mov newDirection, 'U'       
                        jmp mainGameLoop
                    handleVerMovement2:
                        mov newDirection, 'D'       
                        jmp mainGameLoop

  
    done:

        mov bl, newDirection                ;// Postavlja novi smer kretanja za smer kretanja zmije
		mov currDirection, bl				;// Mora ovako preko registra, jer nije dozvoljeno 
											;// dodeljivanje iz promenljive u promenljivu

        call MoveSnake                      ;// Poziva se procedura koja kontrolise kretanje zmije
        mov eax, snakeSpeed                 ;// Uvodi se kasnjenje u iscrtavanju koje daje utisak kretanja
        call Delay                          

        mov bl, currDirection                 
        mov newDirection, bl                        

        cmp flag_endTheGame, 1              ;// Ako je se desio sudar, fleg je to zapamtio
        je quit                             ;// pa se izlazi iz igre

        jmp mainGameLoop                    ;// U suprotnom se vraca na glavni loop

    quit:	
		mov eax, green + (black * 16)									 
		call SetTextColor 
		call clrscr
		push eax
		push edx
		mov dh, 12             
		mov dl, 24
		call GotoXY
		mov edx, offset yourScoreString
		call writeString
		mov eax, playerScore
		call writedec
		mov eax, 2500
		call delay
		pop edx
		pop eax
        call clearMem                       ;// Ispisuje postignut skor, vraca podesavanja na default i ide na glavni meni
		                                            
    RET

startGame ENDP


MoveSnake PROC USES ebx edx

COMMENT &/*
Ova procedura osvezava frejmbafer, cime se efektivno vrsi pomeranje zmije.
Pocevsi od repa, ova procedura trazi sledeci susedni segment. Svi segmenti
bivaju osvezeni premestanjem na nove pozicije, pri cemu se poslednji brise
ukoliko hrana nije pojedena i novi segment se dodaje na pocetak i postaje
glava, zavisno od toga u kom smeru se vrsi kretanje zmije.
Takodje se ovde vrsi provera da li je doslo do sudara i da li je eventualno
pojedena hrana.
*/&


		cmp flag_tail, 1          
		jne dontEraseTail       ;// Rep se ne brise ako fleg ne diktira tako

        mov dh, tailY           ;// Ucitavaju se koordinate repa
        mov dl, tailX          
        call accessIndex		;// Pristupa se frejmbaferu na zadatim koordinatama i po povratku
        dec bx					;// u bx imamo upisanu vrednost koju je vratio frejmbafer, cija
								;// vrednost se dekrementira, cime efektivno dobijamo vrednost sledeceg segmenta
        mov search, bx			;// Vrednost sledeceg segmenta se stavlja u search

        mov bx, 0				;// Iz frejmbafera se vrednost koja odgovara repu stavlja na 0, tj. brise
        call saveIndex      

        call GotoXY				;// kao i sa ekrana
        mov eax, green + (black * 16)
        call SetTextColor
        mov al, ' '
        call WriteChar

        push edx            ;// Kursor se postavlja u donji desni ugao
        mov dl, 79
        mov dh, 23
        call GotoXY
        pop edx

        mov al, dh          ;// Y koordinata repa se smesta u al
        dec al              
        mov Yabove, al      ;// Cuva se indeks reda iznad trenutnog 
        add al, 2           
        mov Ybelow, al      ;// Indeks reda ispod trenutnog

        mov al, dl          ;// X koordinata repa se smesta u al
        dec al              
        mov Xleft, al       ;// Cuva se indeks kolone levo od trenutne
        add al, 2           
        mov Xright, al      ;// Cuva se indeks kolone desno od trenutne

        cmp Ybelow, 24          ;// Ako indeks izlazi van okvira ekrana na donju stranu
        jne next1
        mov Ybelow, 0			;// vraca se na 0, tj. na gornju

        next1:
        cmp Xright, 80          ;// Ako indeks izlazi van okvira ekrana u desnu stranu
        jne next2
        mov Xright, 0			;// vraca se na 0, tj. na levu

        next2:
        cmp Yabove, 0           ;// Ako indeks izlazi van okvira ekrana u gornju stranu
        JGE next3
        mov Yabove, 23			;// vraca se na 23, tj. na donju

        next3:
        cmp Xleft, 0            ;// Ako indeks izlazi van okvira ekrana u levu stranu
        JGE next4
        mov Xleft, 79			;// vraca se na 79, tj. na desnu

        next4:
        mov dh, Yabove          ;// Y koordinata piksela iznad repa
        mov dl, tailX			;// X koordinata piksela iznad repa
        call accessIndex		;// Pristupa se pikselu u frejmbaferu
        cmp bx, search			;// Provera da li je piksel sledeci segment zmije
        jne melseif1
        mov tailY, dh			;// i pomera rep na novu lokaciju, ako jeste
        jmp mendif

        melseif1:
        mov dh, Ybelow          ;// Y koordinata piksela ispod repa
        call accessIndex		;// Pristupa se pikselu u frejmbaferu
        cmp bx, search			;// Provera da li je piksel sledeci segment zmije
        jne melseif2
        mov tailY, dh			;// i pomera rep na novu lokaciju, ako jeste
        jmp mendif

        melseif2:
        mov dh, tailY           ;// Y koordinata piksela levo od repa
        mov dl, Xleft           ;// X koordinata piksela levo od repa
        call accessIndex	    ;// Pristupa se pikselu u frejmbaferu
        cmp bx, search		    ;// Provera da li je piksel sledeci segment zmije
        jne melse
        mov tailX, dl			;// i pomera rep na novu lokaciju, ako jeste
        jmp mendif

        melse:
        mov dl, Xright			;// Pomera rep na piksel desno od repa
        mov tailX, dl

        mendif:

		dontEraseTail:
		mov flag_tail, 1        ;// Postavlja se fleg za brisanje repa
		mov dh, tailY            
		mov dl, tailX            
		mov tempY, dh           ;// Pamti se indeks reda u promenljivu
		mov tempX, dl           ;// Pamti se indeks kolone u promenljivu

		whileTrue:              ;// Prolazak kroz sve segmente zmijice i podesavanje vrednosti svakog
        mov dh, tempY           
        mov dl, tempX        
        call accessIndex		;// Vrednost piksela izvadjena iz frejmbafera
        dec bx					;// U bx se smesta vrednost sledeceg segmenta							
        mov search, bx			

        push ebx				;// Vrednost trenutnog segmenta refresuje se vrednoscu prethodnog segmenta
        add bx, 2				;// (zbog kretanja zmije, segmenti se krecu)
        call saveIndex			
        pop ebx

        cmp bx, 0				;// Provera da li je trenutni segment glava zmije
        je break				

        mov al, dh				;// Indeks reda trenutnog segmenta 
        dec al					;// Indeks reda iznad trenutnog
        mov Yabove, al          
        add al, 2				;// Indeks reda ispod trenutnog
        mov Ybelow, al          

        mov al, dl				;// Indeks kolone trenutnog segmenta
        dec al					;// Indeks kolone levo od trenutne
        mov Xleft, al           
        add al, 2				;// Indeks kolone desno od trenutne
        mov Xright, al          

        cmp Ybelow, 24          ;// Ako novi indeks izlazi van granica, vrati ga
        jne next21
        mov Ybelow, 0	        

        next21:
        cmp Xright, 80          ;// Ako novi indeks izlazi van granica, vrati ga
        jne next22
        mov Xright, 0	        

        next22:
        cmp Yabove, 0           ;// Ako novi indeks izlazi van granica, vrati ga
        JGE next23
        mov Yabove, 23          

        next23:
        cmp Xleft, 0            ;// Ako novi indeks izlazi van granica, vrati ga
        JGE next24
        mov Xleft, 79		    

        next24:
        mov dh, Yabove          ;// Indeks reda piksela iznad trenutnog segmenta
        mov dl, tempX			;// Indeks kolone piksela iznad trenutnog segmenta
        call accessIndex	    ;// Pristup pikselu u frejmbaferu
        cmp bx, search          ;// Provera da li je piksel sledeci segment zmije
        jne elseif21
        mov tempY, dh           ;// pomeri indeks na novu lokaciju, ako jeste
        jmp endif2

        elseif21:
        mov dh, Ybelow          ;// Indeks reda piksela ispod trenutnog segmenta
        call accessIndex		;// Pristup pikselu u frejmbaferu
        cmp bx, search			;// Provera da li je piksel sledeci segment zmije
        jne elseif22
        mov tempY, dh			;// pomeri indeks na novu lokaciju, ako jeste
        jmp endif2

        elseif22:
        mov dh, tempY			;// Indeks reda piksela levo od trenutnog segmenta
        mov dl, Xleft           ;// Indeks kolone piksela levo od trenutnog segmenta
        call accessIndex		;// Pristup pikselu u frejmbaferu
        cmp bx, search			;// Provera da li je piksel sledeci segment zmije
        jne else2
        mov tempX, dl			;// pomeri indeks na novu lokaciju, ako jeste
        jmp endif2

        else2:
        mov dl, Xright		    ;// Pomeri indeks na piksel desno od segmenta
        mov tempX, dl

        endif2:
        jmp whileTrue           ;// Nastavlja se petlja dok se ne dodje do glave zmije

    break:

    mov al, headY               ;// Y koordinata glave
    dec al						
    mov Yabove, al              ;// Indeks reda iznad
    add al, 2					
    mov Ybelow, al              ;// Indeks reda ispod

    mov al, headX               
    dec al						
    mov Xleft, al               
    add al, 2					
    mov Xright, al              

    cmp Ybelow, 24              ;// Ako prelazi granice, vrati ga
    jne next31
        mov Ybelow, 0           

    next31:
    cmp Xright, 80              
    jne next32
        mov Xright, 0           

    next32:
    cmp Yabove, 0               
    JGE next33
        mov Yabove, 23          

    next33:
    cmp Xleft, 0               
    JGE next34
        mov Xleft, 79          

    next34:

    cmp currDirection, 'U'              ;// Ako je smer kretanja navise, Y koordinata glave
    jne elseif3							;// se penje u red iznad
        mov al, Yabove          
        mov headY, al          
        jmp endif3

    elseif3:
    cmp currDirection, 'D'              ;// Ako je nanize, ispod
    jne elseif32
        mov al, Ybelow          
        mov headY, al          
        jmp endif3

    elseif32:
    cmp currDirection, 'L'              ;// Ako je levo, onda levo
    jne else3
        mov al, Xleft          
        mov headX, al          
        jmp endif3

    else3:
        mov al, Xright					;// Desno, onda desno
        mov headX, al          

    endif3:

    mov dh, headY              
    mov dl, headX              

    call accessIndex        ;// Pristupa se poziciji gde bi trebalo da je nova glava
    cmp bx, 0               ;// Ako je prazan piksel, onda nije doslo do sudara
    je NoHit                
                            
    mov eax, 2000           ;// Ako jeste, ispisuje se poruka i izlazi iz procedure
    mov dh, 24              
    mov dl, 11              
    call GotoXY
    mov edx, offset gameOverString
    call WriteString

    call Delay              
    mov flag_endTheGame, 1            

    RET                     

    NoHit:                  ;// Ako nije bilo sudara
    mov bx, 1               
    call saveIndex          

    mov cl, foodX              
    mov ch, foodY              

    cmp cl, dl              ;// Ako se koordinate glave i hrane ne poklapaju,
    jne foodNotGobbled      ;// hrana nije pojedena
    cmp ch, dh              
    jne foodNotGobbled      

    call createFood         ;// Ako je pojedena, pravi se nova 
    mov flag_tail, 0            
                            

    mov eax, green + (black * 16)
    call SetTextColor       

    push edx                

    mov dh, 24              ;// Apdejtuje se skor
    mov dl, 7
    call GotoXY
    mov eax, playerScore         
    INC eax
    call WriteDec
    mov playerScore, eax         

    pop edx                 

    foodNotGobbled:         
    call GotoXY             
    mov eax, blue + (green * 16)
    call setTextColor       
    mov al, ' '             
    call WriteChar
    mov dh, 24              
    mov dl, 79
    call GotoXY

    RET                     

MoveSnake ENDP


createFood PROC USES eax ebx edx

;// Na random poziciji se generise hrana, ukoliko je ta pozicija prazna, kako
;// ne bi dolazilo do preklapanja zmijice i hrane prilikom generisanja

    redo:                       
    mov eax, 24                 
    call RandomRange            
    mov dh, al

    mov eax, 80                 
    call RandomRange            
    mov dl, al

    call accessIndex            ;// Sadrzaj lokacije se smesta u bx

    cmp bx, 0                   ;// I ako nije prazan, loopuje se dok se ne potrefi prazna pozicija
    jne redo                    

    mov foodY, dh                  
    mov foodX, dl                  

    mov eax, white + (white * 16);
    call setTextColor
    call GotoXY
	mov al, ' '  
    call WriteChar

    RET

createFood ENDP

accessIndex PROC USES eax esi edx

;// Procedura pristupa fremjbaferu i vraca vrednost na poziciji Y=dh, X=dl u registar bx

    mov bl, dh      ;// Indeks reda u bl
    mov al, 80      
    mul bl          ;// Indeks reda se mnozi sa 80 kako bi se dobio potreban segment frejmbafera
    push dx         
    mov dh, 0       ;// U dh ostaje samo indeks kolone
    add ax, dx      ;// Dodaje se ofset kolone na segment reda kako bi se dobila adresa piksela
    pop dx          
    mov esi, 0      
    mov si, ax      ;// Generisana adresa se kopira u indeksni registar
    shl si, 1       ;// Koji se siftuje za jedan posto su elementi tipa word

    mov bx, frameBuffer[si]   ;// U bx se upisuje vrednost celije

    RET

accessIndex ENDP


saveIndex PROC USES eax esi edx

;// Procedura slicna accessIndex, samo sto se sad upisuje vrednost piksela na datoj poziciji

    push ebx        
    mov bl, dh      
    mov al, 80      
    mul bl          
    push dx         
    mov dh, 0       
    add ax, dx      
    pop dx          
    mov esi, 0      
    mov si, ax      
    pop ebx         
    shl si, 1       
                    
    mov frameBuffer[si], bx   

    RET

saveIndex ENDP


Paint PROC USES eax edx ebx esi

;// Procedura cita vrednosti iz frejmbafera piksel po piksela i stampa ih u konzolu.

    mov eax, blue + (green * 16)    
    call SetTextColor

    mov dh, 0                      

    loop1:                          ;// Loopuje se kroz redove
        cmp dh, 24                  
        JGE endLoop1                

        mov dl, 0                   

        loop2:                      ;// Loopuje se kroz kolone
            cmp dl, 80              
            JGE endLoop2            
            call GOTOXY            

            mov bl, dh              ;// Naredne linije dohvataju vrednost piksela
            mov al, 80              ;// iz frejmbafera na zadatim koordinatama (dl, dh)
            mul bl
            push dx                
            mov dh, 0               
            add ax, dx              
            pop dx                  
            mov esi, 0              
            mov si, ax              
            shl si, 1               
                                    
            mov bx, frameBuffer[si]           

            cmp bx, 0               ;// Ako je piksel prazan, ne stampa se nista u konzolu
            je NoPrint              

            cmp bx, 0FFFFh          ;// Ako je deo zida, skace se na labelu za iscrtavanje zida
            je printWall          

            mov al, ' '             ;// Inace je deo zmije pa se stampa whitespace u beloj boji
            call WriteChar          
            jmp noPrint             

            printWall:              ;// Iscrtava zidove
            mov eax, blue + (gray * 16) 
            call SetTextColor

            mov al, ' '             
            call WriteChar

            mov eax, blue + (green * 16)    
            call SetTextColor               

            NoPrint:
            INC dl                  
            jmp loop2               ;// Nastavlja se dalje loopovanje kroz kolone

    endLoop2:                       
        INC dh                      
        jmp loop1                   ;// I redove

endLoop1:                           

RET

Paint ENDP


generateLevel PROC

;// Procedura koja se brine za iscrtavanje igralista. Moze biti beskonacno ili sa zidovima.
;// Zidovi se u bafer upisuju kao 0FFFFh vrednosti.

    cmp al, 1               ;// Beskonacan, to je dafault
    jne nextL                

	izlaz:
    RET                     ;// Izlazi se, ne generisu se nikakve prepreke

    nextL:                  ;// Kutija
    cmp al, 2
	jne izlaz

    mov dh, 0               ;// Indeks reda na 0
    mov bx, 0FFFFh          ;// U frejmbafer se upisuje FFFFh koji simbolizuje zid

    rLoop:                  ;// Petlja za generisanje vertikalnih zidova
        cmp dh, 24          
        je endRLoop         

        mov dl, 0           ;// Ide se na levi deo ekrana
        call saveIndex      ;// U frejmbafer se sacuvava vrednost zida
        mov dl, 79          ;// Na desni deo ekrana
        call saveIndex		;// U frejmbafer se sacuvava vrednost zida
        INC dh              ;// Sledeci red
        jmp rLoop           ;// Nastavlja se petlja
    endRLoop:

    mov dl, 0               

    cLoop:                  ;// Petlja za generisanje horizontalnih zidova
        cmp dl, 80          
        je endCLoop         

        mov dh, 0           ;// Na vrh ekrana
        call saveIndex      
        mov dh, 23          ;// Na dno ekrana
        call saveIndex      
        INC dl              
        jmp cLoop           

        endCLoop:

    RET

generateLevel ENDP

END main
