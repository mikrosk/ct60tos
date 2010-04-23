;**********************************************************************
;	Filename:	    Eiffel.asm
;	Date:           18 Juillet 2001
;	Update:         10 Juillet 2006
;
;	Authors:		Favard Laurent, Didier Mequignon
;
;  This program is free software; you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation; either version 2 of the License, or
;  (at your option) any later version.
;
;  This program is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License
;  along with this program; if not, write to the Free Software
;  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
;
;**********************************************************************
;	HARDWARE DESCRIPTION:
;
;	Processor:		16F876 / 18F242 / 18F258
;	Crystal:		4/8MHz / 16MHz  / 16MHz
;	WDT:			Disable
;	RS-232C:		MAX 232A converter, TxD/RxD wired
;	Alimentation:	Via RJ-11 cable/TxD,RxD
;	Revision soft:	2.0
;	Revision board:	C	
;
;**********************************************************************
;   Remarque logicielle:
;
;   - Compatible avec le pilote realise par la societe Oxo.
;
;   - Compatible par defaut avec le protocole souris atari. Le PIC
;     transforme les trames souris PS/2 en trames normales souris Atari,
;     quelque soit la souris branchee.
;
;   - Ajout des scan-codes supplementaires pour Atari pour les nouvelles
;     touches PS/2 et fonctions nouvelles souris.
;
;   Voir le fichier /Docs/ExtensionAtari.txt
;
;**********************************************************************
;
;   Ce programme permet de traduires les scan-codes du jeu 3 (ou 2 
;   depuis la version 1.0.5) d'un clavier PS/2 vers les scan-codes 
;   Atari IKBD et de gerer une souris PS/2 standard ou Intellimouse
;   a roulette 3 boutons et double roulette 5 boutons. Les boutons
;   4 et 5 sont affectes a des scan-codes.
;
;   Les 2 joysticks prevus d'origine dans l'IKBD de l'Atari peuvent egalement
;   etre connectes (depuis la version 1.0.4) :
;     Le Joystick 0 est branche sur le port A du PIC:
;       RA1: Haut
;       RA2: Bas
;       RA3: Gauche
;       RA4: Droite
;       RA5: Tir
;    Le Joystick 1 est branche sur le port C du PIC:
;       RC0: Haut
;       RC1: Bas
;       RC2: Gauche
;       RC3: Droite
;       RC4: Tir
;
;   La commande d'un ventilateur est egalement possible (depuis la version
;   1.0.4) :
;       RC5: commande moteur courant continu en tout ou rien via un MOSFET.
;       RA0: entree analogique temperature AN0, une CTN 10Kohms a 25
;            deg C est raccordee entre AN0 et Vss (0V) avec un rappel a
;            Vdd (+4,3V) de 10Kohms. Soit VAN0 = (4.3 * RCTN)/(10E3+RCTN).
;            Val_AN0 = valeur ADC sur AN0 soit 0 pour 0V et 255 pour 4,3V soit :
;             Val_AN0 = (256 * RCTN)/(10E3+RCTN)
;
;   Le soft permet la connection de la carte a un port serie RS-232C
;   ou directement a un ordinateur type Atari ST (RJ-12 ou HE-14).
;
;   Si le programme est compile avec LCD (depuis la version 1.0.9), le 
;   SERIAL_DEBUG est supprime et un afficheur LCD prend sa place en RB4/5 
;   compatible HD44780 pilote par 2 bits RB4 et RB5 via un 74LS174. Dans ce
;   cas les jumpers de debug qui suivent sont inutilisables.
;
;   Dans le cas de l'utilisation de CAN comme interface au lieu de l'UART
;   RC6/RC7 sont invers‚s avec RB2/RB3 pour la souris. CAN ‚tant connect‚ en
;   RB2/RB3 sur le 18F258. CAN permet de se connecter sur un Coldfire.
;
;                       _______  _______
;                      |   ____\/       |
;                Vcc --+ 1 MCLR  RB7 28 +-- led mouse
;                      |                |
;                CTN --+ 2 RA0   RB6 27 +-- led keyboard
;                      |                |
;      up joystick 0 --+ 3 RA1   RB5 26 +-- LCD clock
;                      |                |
;    down joystick 0 --+ 4 RA2   RB4 25 +-- LCD data
;                      |                |
;    left joystick 0 --+ 5 RA3   RB3 24 +-- mouse clock / RXD CAN 18F258
;                      |                |
;   right joystick 0 --+ 6 RA4   RB2 23 +-- mouse data / TXD CAN 18F258
;                      |                |
;          Vsync out --+ 7 RA5   RB1 22 +-- keyboard clock 
;                      |                |
;                Vss --+ 8 VSS   RB0 21 +-- keyboard data
;                      |                |
;             Quartz --+ 9 OSC1  VCC 20 +-- Vcc
;                      |                |
;             Quartz --+ 10 OSC2 VSS 19 +-- Vss
;                      |                |
;      up joystick 1 --+ 11 RC0  RC7 18 +-- serial RX / mouse clock 18F258
;                      |                |
;    down joystick 1 --+ 12 RC1  RC6 17 +-- serial TX / mouse data 18F258
;                      |                |
;    left joystick 1 --+ 13 RC2  RC5 16 +-- cmd FAN
;                      |                |
;   right joystick 1 --+ 14 RC3  RC4 15 +-- fire joystick 1
;                      |                |
;                      +----------------+
;
;   Les deux jumpers permettent (uniquement si compilation sans LCD):
;
;   Jumper 4, permettant d'activer ou non:
;
;   5V sur PORTB4: Mode Atari  (Translation des scan-codes clavier/souris)
;   0V sur PORTB4: Mode direct (Pas de translation, Scan-codes PS/2 direct)
;
;   Jumper 5, permettant d'activer ou non:
;
;   5V sur PORTB5: Mode normal (Connexion a un Atari)
;   0V sur PORTB5: Mode debug  (Connexion RS-232C)
;
;                                       debug          normal
;
;La frequence de transmission serie     9600 bps       7812.5 bps.
;La transmission des octets clavier      ASCII          binaires.
;La transmission des octets souris       ASCII          binaires.
;L'emission de la chaine texte          'debug'        non
;**********************************************************************
;	Notes:
;	Crystal 4/8 Mhz, Bps rate for Atari = 7812.5
;	                 Bps rate for RS232 = 9600
;
;	Serial frame:  1 Start bit, 8 bits Data, 1 bit Stop
;
;	Jumper4 	=	Pin 4 Port B	(Disable state at 5V with pull-up)
;	Jumper5 	=	Pin 5 Port B	(Disable state at 5V with pull-up)
;	LED green	=	Pin 6 Port B	(Enable state at 0V)
;	LED yellow	=	Pin 7 Port B	(Enable state at 0V)
;**********************************************************************
; Voir le fichier technik.txt et evolution.txt
;**********************************************************************

;----- Flags compilation -------------------------------------------------

#ifdef PIC18F258
_18F_                        EQU     1; si 1, 18F242/258 au lieu du 16F876
LOAD_18F                     EQU     0; si 1, .HEX charge via EIFFELCF en 0x2000-0x3FFF
_CAN_                        EQU     1; si 1, CAN au lieu de l'UART (18F)
#endif
#ifdef PIC18F242
_18F_                        EQU     1; si 1, 18F242/258 au lieu du 16F876
LOAD_18F                     EQU     0; si 1, .HEX charge via EIFFELCF en 0x2000-0x3FFF
_CAN_                        EQU     0; si 1, CAN au lieu de l'UART (18F)
#endif
#ifdef PIC18F242CF
_18F_                        EQU     1; si 1, 18F242/258 au lieu du 16F876
LOAD_18F                     EQU     1; si 1, .HEX charge via EIFFELCF en 0x2000-0x3FFF
_CAN_                        EQU     0; si 1, CAN au lieu de l'UART (18F)
#endif
#ifdef PIC16F876
_18F_                        EQU     0; si 1, 18F242/258 au lieu du 16F876
LOAD_18F                     EQU     0; si 1, .HEX charge via EIFFELCF en 0x2000-0x3FFF
_CAN_                        EQU     0; si 1, CAN au lieu de l'UART (18F)
#endif
_8MHZ_                       EQU     0; si 1, 8MHz
SERIAL_DEBUG                 EQU     0; si 0, PORTB4 & PORTB5 enleves, mode Atari seulement
                                      ;       laisser a 0 pour les cartes a Lyndon 
SCROOL_LOCK_ERR              EQU     0; si 1, utilise pour afficher les erreurs parite souris PS/2
                                      ;       sur la led Scroll Lock du clavier
NON_BLOQUANT                 EQU     1; si 1, routines PS/2 non bloquantes (time-out)
PS2_ALTERNE                  EQU     1; si 1, gestion alternee clavier et souris PS/2 
LCD                          EQU     1; si 1, afficheur LCD a la place du joystick 0 compatible HD44780
LCD_SCANCODE                 EQU     1; si 1, affiche sur le LCD le scan-code clavier PS/2
LCD_DEBUG                    EQU     0; si 1, afficheur LCD utilise pour voir les codes clavier PS/2
LCD_DEBUG_ATARI              EQU     0; si 1, afficheur LCD utilise pour voir les codes envoyes a l'Atari
INTERRUPTS                   EQU     1; si 1, timer 2 gere par interruptions -> besoin d'un residant 1.10
REMOTE_MOUSE                 EQU     0; si 0, experimental souris PS/2 en mode remote tous les 20 mS
                                      ;       ne fonctionne pas avec certains KVM

	IF _18F_

#ifdef PIC18F258

		PROCESSOR p18f258
		RADIX dec
		
		LIST      P=18F258			; list directive to define processor

#include <p18f258.inc>					; processor specific variable definitions

#else
		
		PROCESSOR p18f242
		RADIX dec
		
		LIST      P=18F242			; list directive to define processor

#include <p18f242.inc>					; processor specific variable definitions

#endif

#define INDF INDF0
#define FSR  FSR0L
#define rrf  rrcf
#define rlf  rlcf

#include <eiffel.inc>					; macros

#ifdef PIC18F258 ; Quartz 16 MHz
		__CONFIG _CONFIG1H, _OSCS_OFF_1H & _HS_OSC_1H
		__CONFIG _CONFIG2L, _BOR_ON_2L & _BORV_25_2L & _PWRT_OFF_2L
#else            ; Quartz 4 MHz * 4
		__CONFIG _CONFIG1H, _OSCS_OFF_1H & _HSPLL_OSC_1H
		__CONFIG _CONFIG2L, _BOR_ON_2L & _BORV_20_2L & _PWRT_OFF_2L
#endif
		__CONFIG _CONFIG2H, _WDT_OFF_2H & _WDTPS_128_2H
		__CONFIG _CONFIG4L, _DEBUG_OFF_4L & _LVP_OFF_4L & _STVR_ON_4L
		__CONFIG _CONFIG5L, _CP0_OFF_5L & _CP1_OFF_5L & _CP2_OFF_5L & _CP3_OFF_5L
		__CONFIG _CONFIG5H, _CPB_OFF_5H & _CPD_OFF_5H
		__CONFIG _CONFIG6L, _WRT0_OFF_6L & _WRT1_OFF_6L & _WRT2_OFF_6L & _WRT3_OFF_6L
		__CONFIG _CONFIG6H, _WRTB_OFF_6H & _WRTC_OFF_6H & _WRTD_OFF_6H
		__CONFIG _CONFIG7L, _EBTR0_OFF_7L & _EBTR1_OFF_7L & _EBTR2_OFF_7L & _EBTR3_OFF_7L
		__CONFIG _CONFIG7H, _EBTRB_OFF_7H

	ELSE

		PROCESSOR p16f876
		RADIX dec
		
		LIST      P=16F876			; list directive to define processor

#include <p16f876.inc>					; processor specific variable definitions

#define bra goto
#define rcall call

#include <eiffel.inc>					; macros

		IF _8MHZ_
		__CONFIG _CP_OFF & _DEBUG_OFF & _WRT_ENABLE_ON & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _PWRTE_ON & _WDT_OFF & _HS_OSC
		ELSE
		__CONFIG _CP_OFF & _DEBUG_OFF & _WRT_ENABLE_ON & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _PWRTE_ON & _WDT_OFF & _XT_OSC
		ENDIF
	
	ENDIF

;----- Variables ---------------------------------------------------------

; page 0 (utilisable a partir de 0x20)
Status_Boot                  EQU    0x20; remis a 0 lors de la mise sous tension ou reset hard
Info_Boot                    EQU    0x21; mis a 0xFF si le programme demarre sur la page 2 en Flash
Val_AN0                      EQU    0x22; lecture CTN sur AN0
BUTTONS                      EQU    0x23; etat des boutons souris
OLD_BUTTONS                  EQU    0x24; ancien etat des boutons souris
OLD_BUTTONS_ABS              EQU    0x25; ancien etat des boutons souris en mode absolu
JOY0                         EQU    0x26; lecture joystick 0
JOYB                         EQU    0x26; = JOY0, juste pour tester eventuellement avec JOY1
JOY1                         EQU    0x27; lecture joystick 1
BUTTON_ACTION                EQU    0x28; mode button action IKBD
MState_Temperature           EQU    0x29; machine d'etat lecture temperature (reduction charge CPU)
RCTN                         EQU    0x2A; valeur resistance CTN / 100
Idx_Temperature              EQU    0x2B; index lecture tableau temperature par interpolation
Counter_LOAD                 EQU    0x2C; compteur octets recus par commande LOAD dans boucle principale
Counter_Debug_Lcd            EQU    0x2E; debug uniquement
OldScanCode                  EQU    0x2F; memorisation pour supprimer repetition du jeu 2
Save_PCLATH                  EQU    0x30; inter, affectation a conserver depuis Eiffel 2.0
ValueK                       EQU    0x31; inter clavier, affectation a conserver depuis Eiffel 2.0
ParityK                      EQU    0x32; inter clavier, affectation a conserver depuis Eiffel 2.0
CounterInterK                EQU    0x33; inter clavier, affectation a conserver depuis Eiffel 2.0
CounterInterK2               EQU    0x34; inter clavier, affectation a conserver depuis Eiffel 2.0
CounterValueK                EQU    0x35; inter clavier, affectation a conserver depuis Eiffel 2.0

Counter_Sec                  EQU    0x37; compteur secondes
DEB_INDEX_EM                 EQU    0x38; index courant donnee a envoyer buffer circulaire liaison serie
FIN_INDEX_EM                 EQU    0x39; fin index donnee a envoyer buffer circulaire liaison serie
PTRL_LOAD                    EQU    0x3A; poids fort adresse commande LOAD
PTRH_LOAD                    EQU    0x3B; poids faible commande LOAD
TEMP5                        EQU    0x3C
TEMP6                        EQU    0x3D
Flags4                       EQU    0x3E  
Flags5                       EQU    0x3F
HEADER_IKBD                  EQU    0x40; entete trame envoyee au host IKBD
KEY_MOUSE_WHEEL              EQU    0x41; scan-code movement des molettes (Wheel&Wheel+)
KEY2_MOUSE_WHEEL             EQU    0x42; octet supplementaire: Scan-code bouton 4 ou 5 (Wheel+)
CLIC_MOUSE_WHEEL             EQU    0x43; octet supplementaire: Scan-code bouton central
Value_0                      EQU    0x44; 1er octet reception trame souris PS/2
Value_X                      EQU    0x45; 2eme octet reception trame souris PS/2
Value_Y                      EQU    0x46; 3eme octet reception trame souris PS/2
Value_Z                      EQU    0x47; 4eme octet eventuel reception trame souris PS/2
MState_Mouse                 EQU    0x48; machine d'etat reception trame souris PS/2
Temperature                  EQU    0x49; lecture temperature CTN sur AN0
Rate_Joy                     EQU    0x4A; temps monitoring joystick IKBD
Counter_5MS                  EQU    0x4B; prediviseur horloge et base de temps 5 mS
Counter_10MS_Joy_Monitor     EQU    0x4C; compteur delais envoi monitoring joysticks
Counter3                     EQU    0x4D; compteur boucles
Counter_10MS_Joy             EQU    0x4E; prediviseur envoi mode keycode joystick 0 (pas de 100 mS)
Counter_100MS_Joy            EQU    0x4F; compteur 100 mS mode keycode joystick 0
                                        ; conserver cet ordre pour les 6 variables XX_JOY
RX_JOY                       EQU    0x50; temps RX mode keycode joystick 0 IKBD
RY_JOY                       EQU    0x51; temps RY mode keycode joystick 0 IKBD
TX_JOY                       EQU    0x52; temps TX mode keycode joystick 0 IKBD
TY_JOY                       EQU    0x53; temps TY mode keycode joystick 0 IKBD
VX_JOY                       EQU    0x54; temps VX mode keycode joystick 0 IKBD
VY_JOY                       EQU    0x55; temps VY mode keycode joystick 0 IKBD
Status_Joy                   EQU    0x56; flags joystick 0 mode keycode
OLD_JOY                      EQU    0x57; ancien etat boutons joystick 0 mode keycode
START_RX_JOY                 EQU    0x58; valeur de demarrage tempo RX mode keycode joystick 0
START_RY_JOY                 EQU    0x59; valeur de demarrage tempo RY mode keycode joystick 0
START_TX_JOY                 EQU    0x5A; valeur de demarrage tempo TX mode keycode joystick 0
START_TY_JOY                 EQU    0x5B; valeur de demarrage tempo TY mode keycode joystick 0
X_SCALE                      EQU    0x5C; facteur d'echelle en X souris mode absolu
Y_SCALE                      EQU    0x5D; facteur d'echelle en Y souris mode absolu
X_POSH                       EQU    0x5E; position X absolue souris poids fort
X_POSL                       EQU    0x5F; position X absolue souris poids faible
Y_POSH                       EQU    0x60; position Y absolue souris poids fort
Y_POSL                       EQU    0x61; position Y absolue souris poids faible
                                        ; conserver cet ordre pour les 4 variables XX_POSX_SCALED
X_POSH_SCALED                EQU    0x62; position X absolue souris avec facteur d'echelle poids fort
X_POSL_SCALED                EQU    0x63; position X absolue souris avec facteur d'echelle poids faible
Y_POSH_SCALED                EQU    0x64; position Y absolue souris avec facteur d'echelle poids fort
Y_POSL_SCALED                EQU    0x65; position Y absolue souris avec facteur d'echelle poids faible
                                        ; conserver cet ordre pour les 4 variables X_MAX_POSX
X_MAX_POSH                   EQU    0x66; position X absolue maximale souris poids fort
X_MAX_POSL                   EQU    0x67; position X absolue maximale souris poids faible
Y_MAX_POSH                   EQU    0x68; position Y absolue maximale souris poids fort
Y_MAX_POSL                   EQU    0x69; position Y absolue maximale souris poids faible
X_MOV                        EQU    0x6A; deplacement relatif souris en X
Y_MOV                        EQU    0x6B; deplacement relatif souris en Y
X_INC_KEY                    EQU    0x6C; increment en X mode keycode souris
Y_INC_KEY                    EQU    0x6D; increment en X mode keycode souris
DELTA_X                      EQU    0x6E; deltax mode keycode souris IKBD
DELTA_Y                      EQU    0x6F; deltay mode keycode souris IKBD

; communes a toutes les pages
TEMP3                        EQU    0x70
TEMP4                        EQU    0x71
Counter                      EQU    0x72; compteur boucles
Value                        EQU    0x73; octet recu
TEMP1                        EQU    0x74
Counter2                     EQU    0x75; compteur boucles
PARITY                       EQU    0x76; parite ecriture/lecture PS/2 et Flashage
TEMP2                        EQU    0x77
Flags                        EQU    0x78
Flags2                       EQU    0x79
Flags3                       EQU    0x7A
Counter_5MS_Inter            EQU    0x7B; inter, affectation a conserver depuis Eiffel 1.10
Save_STATUS                  EQU    0x7C; inter, affectation a conserver depuis Eiffel 1.10
Save_W                       EQU    0x7D; inter, affectation a conserver depuis Eiffel 1.10
		IF _18F_
BUFFER_FLASH                 EQU    0x08; buffer 8 octets
		ELSE
BUFFER_FLASH                 EQU    0x7E; buffer 2 octets
		ENDIF

		IF _18F_
; zone non remise a 0 au reset par Start_Flash si <= Status_Boot 
BUF_CAN                      EQU    0x00; buffer de reception, 8 octets

YEAR                         EQU    0x10; annee, conserver cet ordre pour les 6 variables horloge
MONTH                        EQU    0x11; mois
DAY                          EQU    0x12; jour
HRS                          EQU    0x13; heures
MIN                          EQU    0x14; minutes
SEC                          EQU    0x15; secondes
YEAR_BCD                     EQU    0x16; annee, conserver cet ordre pour les 6 variables BCD
MONTH_BCD                    EQU    0x17; mois
DAY_BCD                      EQU    0x18; jour
HRS_BCD                      EQU    0x19; heures
MIN_BCD                      EQU    0x1A; minutes
SEC_BCD                      EQU    0x1B; secondes

DLC_CAN                      EQU    0x1C; CAN
Counter_CAN                  EQU    0x1E
Data_CAN                     EQU    0x1F
		ELSE
; page 2 en zone non remise a 0 au reset par Start_Flash si < 0x120
YEAR                         EQU    0x110; annee, conserver cet ordre pour les 6 variables horloge
MONTH                        EQU    0x111; mois
DAY                          EQU    0x112; jour
HRS                          EQU    0x113; heures
MIN                          EQU    0x114; minutes
SEC                          EQU    0x115; secondes
YEAR_BCD                     EQU    0x116; annee, conserver cet ordre pour les 6 variables BCD
MONTH_BCD                    EQU    0x117; mois
DAY_BCD                      EQU    0x118; jour
HRS_BCD                      EQU    0x119; heures
MIN_BCD                      EQU    0x11A; minutes
SEC_BCD                      EQU    0x11B; secondes
		ENDIF
USER_LCD                     EQU    0x120; message 8 caracteres LCD

;page 3 en zone non remise a 0 au reset par Start_Flash si < 0x1A0
TAMPON_EM                    EQU    0x190; buffer circulaire liaison serie (TAILLE_TAMPON_EM dans eiffel.inc)

;----- Programme ---------------------------------------------------------

		IF _18F_ && LOAD_18F
		
		ORG 0x2000
		
		ELSE
		
		ORG	0x000
		
		ENDIF
		
		clrf Status_Boot; remise a 0 lors de la mise sous tension ou reset hard 
Reset_Prog
		IF _18F_
		IF LOAD_18F
		goto Start_Flash-0x2000
		ELSE
		goto Start_Flash; saute au programme de lancement de la page 0 ou 2
		ENDIF
		nop
		ELSE
		bsf PCLATH,3; page 1 (0x800 - 0xFFF)
		bcf PCLATH,4
		goto Start_Flash; saute au programme de lancement de la page 0 ou 2
		ENDIF

Inter
		btfss INTCON,PEIE; Peripheral Interrupt Enable est a 1 lors de l'interruption
		                 ; donc on saute le goto
;-----------------------------------------------------------------------------
;       Startup, initialisation (saut ici apres le boot !)
;       passage oblige pour les interruptions depuis Eiffel 1.10
;-----------------------------------------------------------------------------
Startup
			bra Startup2		
		IF _18F_
		btfsc INTCON,INT0IF
			bra InterKeyb		
		bcf PIR1,TMR2IF; acquitte timer 2
		incf Counter_5MS_Inter,F
		retfie FAST
		ELSE
		movwf Save_W; sauvegarde de W
		swapf STATUS,W
		clrf STATUS; page 0
		movwf Save_STATUS; sauvegarde de STATUS
		movf PCLATH,W
		movwf Save_PCLATH; sauvegarde de PCLATH
		bcf PCLATH,3; page 0 ou 2
		btfsc INTCON,INTF
			bra InterKeyb		
		bcf PIR1,TMR2IF; acquitte timer 2
		incf Counter_5MS_Inter,F
End_Inter
		movf Save_PCLATH,W; restitution de PCLATH
		movwf PCLATH
		swapf Save_STATUS,W; restitution de W et STATUS
		movwf STATUS
		swapf Save_W,F
		swapf Save_W,W
		retfie
		ENDIF
		
Startup2
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call Init
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		bra Init_Flags
		
;-----------------------------------------------------------------------------
;       Interruption clavier (en page 0 ou 2) RB0/INT0
;-----------------------------------------------------------------------------

InterKeyb
		IF INTERRUPTS
;		ENABLEKEYB_DISABLEMOUSE; debloque le clavier au cas ou il vient juste d'etre bloque
        DISABLEMOUSE
		clrf ParityK; used for parity calc
		movlw 9; 8 bits + start
		movwf CounterInterK; set counter to 8 bits to read
InterKGetLoop
			IF !_18F_
			bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
			ENDIF
			call KPSGetBit; get a bit from keyboard -> carry
			IF !_18F_
			bcf PCLATH,3; page 0 ou 2
			ENDIF
			rrf ValueK,F; rotate to right to get a shift
			movf ValueK,W
			xorwf ParityK,F; parity calc
			decfsz CounterInterK,F; check if we should get another one
		bra InterKGetLoop
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call KPSGetBit; get parity bit -> carry
		rrf CounterInterK,W
		xorwf ParityK,F
		call KPSGetBit; get stop bit
		IF !_18F_	
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		btfss STATUS,C
			clrf ParityK; stop bit = 0 -> erreur
;		btfss ParityK,7
;			clrf ValueK; erreur
		incf CounterValueK,F
		IF _18F_
		bcf INTCON,INT0IF; acquitte RB0/INT
		ELSE
		bcf INTCON,INTF; acquitte RB0/INT
		ENDIF
		ENDIF ; INTERRUPTS
		IF _18F_
		retfie FAST
		ELSE
		bra End_Inter
		ENDIF
	
;-----------------------------------------------------------------------------
;       Chaine de caracteres de bienvenue ! (testee sur la CT60)
;-----------------------------------------------------------------------------

WelcomeText	
		addwf PCL,F
		DT "Eiffel 2.0"
		IF INTERRUPTS
		DT "i"
		ENDIF
		DT" 07/2006"
		DT 0
		
;------------------------------------------------------------------------------
;       Boucle principale d'attente de donnees:
;       On regarde si une donnee clavier arrrive, puis souris
;------------------------------------------------------------------------------

Main
		;--------------------------------------------------------------
		;   Boucle d'attente sur les horloges: Polling sur KCLC ET MCLK
		;   puis bloquage oppose et appel au traitement de l'element
		IF PS2_ALTERNE
		movf Counter_5MS,W
		andlw 3 	
		btfss STATUS,Z; gestion alternee toutes les 5 mS clavier et 15 mS souris PS/2
			bra EnableMouse
		ENABLEKEYB
		bra Main_Loop
EnableMouse
		ENABLEMOUSE
		ELSE
		ENABLEPS2; autorise transferts clavier et souris en meme temps
		ENDIF
Main_Loop
			IF PS2_ALTERNE	
			movf Counter_5MS,W
			andlw 3 	
			btfss STATUS,Z; gestion alternee toutes les 5 mS clavier et 15 mS souris PS/2
				bra TstMouse; gestion souris
			ENDIF
			IF INTERRUPTS
			movf CounterValueK,W
			btfsc STATUS,Z
			ELSE
			btfsc PORTB,KCLOCK; front descendant de CLK
			ENDIF
			IF PS2_ALTERNE
				bra TstAtariSend
			ELSE
				bra TstMouse; le clavier ne se manifeste pas, on passe a la souris
			ENDIF
			IF INTERRUPTS
			movf ParityK,W
			movwf PARITY
			movf ValueK,W; on recupere l'octet clavier
			movwf Value
			ELSE
			DISABLEMOUSE; bloque souris
			call KPSGet2; -> Value, on recupere l'octet clavier
			ENDIF
			bra doKeyboard; On appel le traitement Clavier complet
TstMouse
			btfsc PORTM,MCLOCK; front descendant de CLK
				bra TstAtariSend; le souris ne se manifeste pas, on passe en controle commande Atari
Mouse
			IF INTERRUPTS
			bcf INTCON,GIE; interdit interruptions
			ENDIF
			IF PS2_ALTERNE
			ENABLEMOUSE_DISABLEKEYB; bloque clavier
			ELSE
			DISABLEKEYB; bloque clavier
			ENDIF
			call MPSGet2; -> Value, on recupere l'octet souris
			bra doMouse; On appel le traitement Souris complet
TstAtariSend
			movf MState_Mouse,W
			btfsc STATUS,Z
				bra TstAtariSend2; <> transmission trame souris en cours
			sublw 4
			btfsc STATUS,C
				bra Main_Loop; transmission trame souris en cours
TstAtariSend2
			btfss Flags2,DATATOSEND
				bra TstAtariReceive; rien a envoyer par la liaison serie
			IF _18F_ && _CAN_
;			btfsc TXB0CON,TXREQ; Transmit Buffer 0 vide
;				bra TstAtariReceive; registre d'emission plein
			ELSE
	 		btfss PIR1,TXIF; check that buffer is empty 
				bra TstAtariReceive; registre d'emission plein
	 		ENDIF
			DISABLEPS2; bloque clavier et souris
			movf DEB_INDEX_EM,W; teste buffer circulaire
			subwf FIN_INDEX_EM,W
			btfss STATUS,Z
				bra SendData; FIN_INDEX_EM <> DEB_INDEX_EM
			bcf Flags2,DATATOSEND
			bra Main
SendData
			IF _18F_ && _CAN_
			call Send_CAN
			ELSE
			IF _18F_
			movlw HIGH TAMPON_EM
			movwf FSR0H
			ELSE
			bsf STATUS,IRP; page 3
			ENDIF ; _18F_
			incf DEB_INDEX_EM,W; incremente buffer cirulaire donnees envoyees
			movwf FSR; pointeur index		
			movlw TAILLE_TAMPON_EM
			subwf FSR,W
			btfsc STATUS,C
				clrf FSR; buffer circulaire
			movf FSR,W
			movwf DEB_INDEX_EM
			movlw LOW TAMPON_EM
			addwf FSR,F; pointeur index
			movf INDF,W; lecture dans le tampon 
			movwf TXREG; transmit byte
			ENDIF ; _18F_ && _CAN_
			bra Main
TstAtariReceive
			IF _18F_ && _CAN_
			movf DLC_CAN,W
			btfss STATUS,Z
				bra ReceiveCAN; octets recus main non traites
			btfss PIR3,RXB0IF; reception trame CAN (commande Atari) dans Receive Buffer 0
				bra TstTimer
ReceiveCAN
			DISABLEPS2; bloque clavier et souris
			call Receive_CAN
			movwf Data_CAN
			ELSE
			btfss PIR1,RCIF; Controle commande atari arrivee
				bra TstTimer
			DISABLEPS2; bloque clavier et souris
			btfss RCSTA,OERR
				bra FramingErrorTest
			bcf RCSTA,CREN; acquitte erreur Overrun
			bsf RCSTA,CREN; enable reception
			bra Main
FramingErrorTest
			btfss RCSTA,FERR 
				bra ReceiveOK
			movf RCREG,W; acquitte erreur Framing Error
			bra Main
ReceiveOK
			movf RCREG,W; get received data into W
			ENDIF ; _18F_ && _CAN_
			movwf Value; -> Value, on teste les commandes clavier Atari
			btfss Flags3,RE_TIMER_IKBD
				bra doAtariCommand; Traiter la commande Atari clavier recue
			call Receive_Bytes_Load
			bra Main
TstTimer
		IF !INTERRUPTS
			btfss PIR1,TMR2IF
		ELSE
			movf Counter_5MS_Inter,W
			subwf Counter_5MS,W
			btfsc STATUS,Z
		ENDIF
				bra Main_Loop
				
;-----------------------------------------------------------------------------
;               Gestion sous Timer 2 a 5 mS
;-----------------------------------------------------------------------------

doTimer
		DISABLEPS2; bloque clavier et souris
		IF !INTERRUPTS
		bcf PIR1,TMR2IF; acquitte timer 2
		incf Counter_5MS,F
		movlw 200
		subwf Counter_5MS,W		
		btfss STATUS,Z
			bra NotIncClock
		clrf Counter_5MS
		ELSE
		bcf INTCON,GIE; interdit interruptions
		movlw 200
		subwf Counter_5MS_Inter,W; Counter_5MS_Inter - 200
		btfss STATUS,C
			bra NotIncClockInt; Counter_5MS_Inter < 200
		movwf Counter_5MS_Inter
		movwf Counter_5MS			
		bsf INTCON,GIE; autorise interruptions
		ENDIF ; INTERRUPTS
		IF _18F_ && _CAN_
		btfss Flags5,CAN_BUS_OFF
			bra Bus_CAN_OK
		bsf CANCON,ABAT; abort transmissions
		call Init_CAN
		movf FIN_INDEX_EM,W
		movwf DEB_INDEX_EM
		bcf Flags2,DATATOSEND; supprime ce qu'il faut envoyer
		bcf Flags5,CAN_BUS_OFF
		IF LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI
		call Init_Message_User_Lcd
		ENDIF ; _18F_ && _CAN_
Bus_CAN_OK
		ENDIF
		incf Counter_Sec,F
		movf Counter_Sec,W
		andlw 3; si clavier/souris non connecte, tente un reset clavier/souris toutes les 4 secondes
		btfss STATUS,Z
			bra StartTemperature; 1-3
		movf MState_Mouse,W		
		sublw 4
		btfsc STATUS,C
			bra TestNotConnect; <> initialisation si 0-3
		clrf MState_Mouse; time-out si MState_Mouse > 4, souris non connecte
		bcf Status_Boot,CONNECTED_MOUSE; etat deconnecte suite initialisation trop longue (bloquee ?)
TestNotConnect
		btfss Status_Boot,CONNECTED_MOUSE
			bsf Flags2,RESET_MOUSE; valide reset souris
		btfss Status_Boot,CONNECTED_KEYB
			bsf Flags2,RESET_KEYB; valide reset clavier
StartTemperature
		movlw 1
		movwf MState_Temperature; lance la lecture de la temperature
		IF INTERRUPTS    
NotIncClockInt
		movf Counter_5MS_Inter,W
		movwf Counter_5MS		
		bsf INTCON,GIE; autorise interruptions
		ENDIF
NotIncClock
		movf MState_Mouse,W
		btfss STATUS,Z
			bra Main; transmission trame souris en cours
Test10mS
		btfss Counter_5MS,0
			bra Main
		btfsc Counter_5MS,1
			bra Joysticks_10MS

;-----------------------------------------------------------------------------
;       Gestion toutes les 20 mS
;-----------------------------------------------------------------------------

		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call Read_Temperature; lecture temperature toutes les secondes via MState_temperature
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		IF LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI
		btfss Flags4,LCD_ENABLE; gestion timer LCD inhibe
			bra End_20MS
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call Message_User_Lcd
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		ENDIF
End_20MS
		btfss Flags2,RESET_KEYB
			bra TestResetMouse
		bcf Flags2,RESET_KEYB; flag demande reset clavier remis a 0	
		rcall KbBAT; preferable a cmdResetKey + BAT avec certains claviers
		movlw 0xF0; code de retour reset clavier
		call SerialTransmit_Host
TestResetMouse
		btfss Flags2,RESET_MOUSE
		IF REMOTE_MOUSE
			bra RemoteMouse
		ELSE
			bra Joysticks_10MS
		ENDIF
		bcf Flags2,RESET_MOUSE; flag demande reset souris remis a 0
		call MsBAT
		IF REMOTE_MOUSE
RemoteMouse
		btfss Status_Boot,CONNECTED_MOUSE
			bra Joysticks_10MS 
		movf MState_Mouse,W
		btfsc STATUS,Z
			rcall cmdReadMouse; remote lecture souris
		ENDIF

;-----------------------------------------------------------------------------
;       Gestion sous Timer 2 toutes les 10 mS des joysticks
;-----------------------------------------------------------------------------

Joysticks_10MS		
		btfss Flags,JOY_ENABLE; gestion par timer joysticks
			bra Main; pas de gestion des joysticks
		btfsc Flags2,JOY_MONITOR
			bra Joy_Monitoring; monitoring des joysticks	
		btfsc Flags2,JOY_EVENT
			bra Not_100MS; evenements joysticks
		btfss Flags2,JOY_KEYS; envoi touches fleches
			bra Main; rien a gerer sous le timer au niveau des joysticks
		decfsz Counter_10MS_Joy,F
			bra Not_100MS
		movlw 10
		movwf Counter_10MS_Joy
		incf Counter_100MS_Joy,F
		call SendAtariJoysticks_Fleches; mode keycode du joystick 0
Not_100MS
		comf PORTA,W; gestion evenements joysticks ou keycode action sur fire
		movwf TEMP1
		rrf TEMP1,W
		andlw 0x1F; 000FDGBH (Fire, Droite, Gauche, Bas, Haut)
		movwf TEMP1
		subwf JOY0,W; lecture joystick 0
		btfsc STATUS,Z
			bra Not_Joy0_Change; pas de changement joystick 0
		movf TEMP1,W		
		movwf JOY0; lecture joystick 0
		movlw HEADER_JOYSTICK0; header joystick 0
		bra SerialTransmit_Joy
Not_Joy0_Change
		comf PORTC,W
		andlw 0x1F; 000FDGBH (Fire, Droite, Gauche, Bas, Haut)
		movwf TEMP1
		subwf JOY1,W; lecture joystick 1
		btfsc STATUS,Z
			bra Main; pas de changement joystick 1
		movf TEMP1,W	
		movwf JOY1; lecture joystick 1
		movlw HEADER_JOYSTICK1; header joystick 1
SerialTransmit_Joy
		movwf HEADER_IKBD
		call Leds_Eiffel_On
		call SendAtariJoysticks
		bra End_Read
		
;-----------------------------------------------------------------------------
;       Gestion sous Timer 2 toutes les 10 mS envoi trames Joystick en continu
;-----------------------------------------------------------------------------

Joy_Monitoring
		decfsz Counter_10MS_Joy_Monitor,F
			bra Main
		movf Rate_Joy,W
		movwf Counter_10MS_Joy_Monitor
		call Leds_Eiffel_On
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call Read_Joysticks
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		clrf TEMP1
		btfsc JOY0,4; bouton joytick 0
			bsf TEMP1,1
		btfsc JOY1,4; bouton joytick 1
			bsf TEMP1,0
		movf TEMP1,W; 000000xy avec y pour fire joystick 1 et x pour fire joystick 0
		call SerialTransmit_Host
		swapf JOY0,W; lecture joystick 0
		andlw 0xF0; 4 bits de poids fort
		movwf TEMP1
		movf JOY1,W; lecture joystick 1
		andlw 0x0F;    DGBHDGBH (Droite, Gauche, Bas, Haut)
		iorwf TEMP1,W; nnnnmmmm  avec m pour le joystick 1 et n pour le joystick 0
		call SerialTransmit_Host
		bra End_Read
	
;-----------------------------------------------------------------------------
;       Commande clavier Atari recue
;-----------------------------------------------------------------------------

doAtariCommand
		bsf Flags,IKBD_ENABLE; transferts IKBD autorises	
		bcf Flags2,JOY_MONITOR; monitoring joysticks desactive
		movf Value,W
		sublw IKBD_LCD+1
		btfss STATUS,C
			bra Test_Reset; Value > IKBD_LCD
		IF _18F_
		rlcf Value,F
		ENDIF
		movlw LOW Table_Ikbd
		addwf Value,F
		movlw HIGH Table_Ikbd
		btfsc STATUS,C
			addlw 1
		movwf PCLATH
		IF !_18F_
		btfsc Info_Boot,7
			bsf PCLATH,4; page 2-3 (0x1000 - 0x1FFF)
		ENDIF
		movf Value,W
		movwf PCL
Table_Ikbd
		bra Test_Reset
		bra Test_Reset
		bra Test_Reset
		bra Get_Temperature;        IKBD_GETTEMP	
		bra Prog_Temperature;       IKBD_PROGTEMP
		bra Prog_Keyb;              IKBD_PROGKB
		bra Prog_Mouse;             IKBD_PROGMS		
		bra Set_Mouse_Button_Action;IKBD_SET_MOUSE_BUTTON_ACTION
		bra Rel_Mouse;              IKBD_REL_MOUSE_POS_REPORT
		bra Abs_Mouse;              IKBD_ABS_MOUSE_POSITIONING		
		bra Mouse_KeyCode;          IKBD_SET_MOUSE_KEYCODE_CODE
		bra Receive2Bytes; non gere IKBD_SET_MOUSE_THRESHOLD X & Y seuil
		bra Mouse_Scale;            IKBD_SET_MOUSE_SCALE
		bra Mouse_Pos;              IKBD_INTERROGATE_MOUSE_POS
		bra Load_Mouse_Pos;         IKBD_LOAD_MOUSE_POS
		bra Y0_At_Bottom;           IKBD_SET_Y0_AT_BOTTOM
		bra Y0_At_Top;              IKBD_SET_Y0_AT_TOP
		bra Resume;                 IKDB_RESUME
		bra Disable_Mouse;          IKDB_DISABLE_MOUSE
		bra Pause;                  IKDB_PAUSE_OUTPUT
		bra Joy_On;                 IKBD_SET_JOY_EVNT_REPORT
		bra Joy_Off;                IKBD_SET_JOY_INTERROG_MODE
		bra Joy_Interrog;           IKBD_JOY_INTERROG
		bra Joy_Monitor;            IKBD_SET_JOY_MONITOR
		bra Fire_Button;   non gere IKBD_SET_FIRE_BUTTON_MONITOR
		bra Joy_KeyCode;            IKBD_SET_JOY_KEYCODE_MODE
		bra Disable_Joysticks;      IKDB_DISABLE_JOYSTICKS
		bra Time_Set;               IKBD_TIME_OF_DAY_CLOCK_SET
		bra Interrog_Time;          IKBD_INTERROG_TIME_OF_DAY
		bra Test_Reset
		bra Test_Reset
		bra Test_Reset
		bra Memory_Load;            IKBD_MEMORY_LOAD
		bra Memory_Read;            IKBD_MEMORY_READ
		bra Receive2Bytes; non gere IKBD_CONTROLLER_EXECUTE
		IF LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI
		bra Lcd;                    IKBD_LCD
		ELSE
		bra Test_Reset
		ENDIF
		;--------------------------------------------------------------
		;   Temperature
Get_Temperature
		; lecture temperature
		movlw HEADER_STATUS; header d'etat
		call SerialTransmit_Host
		movlw IKBD_GETTEMP
		call SerialTransmit_Host
		movf Temperature,W; temperature
		call SerialTransmit_Host
		movf Val_AN0,W; lecture CTN sur AN0
		call SerialTransmit_Host
		clrw
		btfsc PORTC,MOTORON
			movlw 1
		call SerialTransmit_Host
		movlw Tab_Temperature-EEProm+IDX_LEVELHTEMP
		call Lecture_EEProm
		call SerialTransmit_Host
		movlw Tab_Temperature-EEProm+IDX_LEVELLTEMP
		call Lecture_EEProm
		call SerialTransmit_Host
		movf RCTN,W; valeur resistance CTN / 100
		call SerialTransmit_Host		
		bra Main		
Prog_Temperature
		; programmation seuil temperature
		clrf Val_AN0; lecture CTN sur AN0 -> actualise la mesure et la commande du ventilateur
		call SerialReceive; code programmation temperature
		sublw IDX_TAB_CTN+24; soustraire l'offset MAX
		btfss STATUS,C; si carry =1 pas de problemes on passe
			bra Not_Prog_EEProm; ignore code > IDX_TAB_CTN+24
		movf Value,W
		addlw Tab_Temperature-EEProm; pour pointer le debut des octets temperature dans la table
		bra Prog_EEProm
		;--------------------------------------------------------------
		;   Programmation clavier et souris
Prog_Keyb
		; programmation clavier
		; Indiquer le mode programmation par allumages des trois LEDs
		call cmdLedOn
		call SerialReceive; code programmation clavier
		comf Value,W		
		btfsc STATUS,Z
			bra ChangeSet; 0xFF	
		movf Value,W		
		sublw MAX_VALUE_LOOKUP; soustraire l'offset MAX
		btfss STATUS,C; si carry =1 pas de problemes on passe
			bra Not_Prog_EEProm; ignore code > MAX_VALUE_LOOKUP
		movf Value,W
		addlw Tab_Scan_Codes-EEProm; pour pointer le debut des octets CLAVIER dans la table
		bra Prog_EEProm
Prog_Mouse
		; programmation souris
		; Indiquer le mode programmation par allumages des trois LEDs
		call cmdLedOn
		call SerialReceive; code programmation souris
		sublw IDX_WHREPEAT; soustraire l'offset MAX
		btfss STATUS,C; si carry =1 pas de problemes on passe
			bra Not_Prog_EEProm; ignore code > IDX_WHREPEAT
		movf Value,W
		addlw Tab_Mouse-EEProm; pour pointer le debut des octets souris dans la table
		bra Prog_EEProm
ChangeSet
		movlw Tab_Config-EEProm
Prog_EEProm
		movwf Counter
		call SerialReceive
		WREEPROM Counter,Value
		bra Main
		;--------------------------------------------------------------
		;   Mode de fonctionnement IKBD souris
Set_Mouse_Button_Action
		; mode boutons souris
		call SerialReceive
		movwf BUTTON_ACTION
		bra Main
Rel_Mouse		
		; souris mode relatif
		bcf Flags,MOUSE_ABS
		bra Not_Mouse_Keys
Abs_Mouse		
		; souris mode absolu
		movlw LOW X_MAX_POSH; X_MAX_POSL, Y_MAX_POSH, Y_MAX_POSL maxi
		movwf FSR
		IF _18F_
		movlw HIGH X_MAX_POSH
		movwf FSR0H
		ELSE
		bcf STATUS,IRP; page 0
		ENDIF
		movlw 4
		call SerialReceiveInd; XMSB, XLSB, YMSB, YLSB
		rcall Init_X_Y_Abs
		bsf Flags,MOUSE_ABS
Not_Mouse_Keys
		bcf Flags2,MOUSE_KEYS
		bra Mouse_Enable
Mouse_KeyCode
		; mode touches fleches souris
		call SerialReceive; deltax
		rcall Change_0_To_1
		movwf DELTA_X; deltax mode keycode souris IKBD
		call SerialReceive; deltay
		rcall Change_0_To_1
		movwf DELTA_Y; deltay mode keycode souris IKBD
		clrf X_INC_KEY; increment en X mode keycode souris
		clrf Y_INC_KEY; increment en Y mode keycode souris
		bsf Flags2,MOUSE_KEYS
		bra Mouse_Enable
Mouse_Scale
		; facteur d'echelle souris mode absolu
		call SerialReceive; X
		rcall Change_0_To_1
		movwf X_SCALE
		call SerialReceive; Y
		rcall Change_0_To_1
		movwf Y_SCALE
		bra Conv_Not_Scaled
Mouse_Pos
		; demande position absolue souris
		btfss Flags,MOUSE_ABS
			bra Main; <> mode absolu
		btfsc Flags2,JOY_MONITOR
			bra Main
		movlw HEADER_ABSOLUTE_MOUSE; header souris mode absolu
		movwf HEADER_IKBD
		bcf PORTB,LEDYELLOW; allume LED souris
		call SendAtariMouse
		bsf PORTB,LEDYELLOW; eteint LED souris			
		bra Main
Load_Mouse_Pos
		; initialisation coords souris absolue
		call SerialReceive; 0
		movlw LOW X_POSH_SCALED; X_POSL_SCALED, Y_POSH_SCALED, Y_POSL_SCALED 
		movwf FSR
		IF _18F_
		movlw HIGH X_POSH_SCALED
		movwf FSR0H
		ELSE
		bcf STATUS,IRP; page 0
		ENDIF
		movlw 4		
		call SerialReceiveInd; XMSB, XLSB, YMSB, YLSB
Conv_Not_Scaled
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call Conv_Inv_Scale_X
		call Conv_Inv_Scale_Y
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		bra Main
Y0_At_Bottom
		; 0 de Y souris en bas
		bsf Flags,SIGN_Y
		bra Main
Y0_At_Top
		; 0 de Y souris en haut (par defaut)
		bcf Flags,SIGN_Y
		bra Main
Resume
		; autorisation transferts
		bra Main
Disable_Mouse
		; inhibe la souris
		bcf Flags,MOUSE_ENABLE
		bra Main
Pause
		; arret transferts
		bcf Flags,IKBD_ENABLE
		bra Main
		;--------------------------------------------------------------
		;   Mode de fonctionnement IKBD joysticks
Joy_On
		; joystick transferts automatiques
		bsf Flags2,JOY_EVENT
		bra JoyOn
Joy_Off
		; arret transferts joystick automatiques
		bcf Flags2,JOY_EVENT
JoyOn
		bcf Flags2,JOY_KEYS
		bra Joy_Enable
Joy_Interrog
		; interroge joysticks
		btfss Flags,JOY_ENABLE
			bra Main; joysticks inhibes
		btfsc Flags2,JOY_KEYS
			bra Main; mode keycode joystick 0
		btfsc Flags2,JOY_MONITOR
			bra Main; mode monitoring joysticks
		comf PORTA,W
		movwf JOY0
		rrf JOY0,W
		andlw 0x1F
		movwf JOY0; 000FDGBH (Fire, Droite, Gauche, Bas, Haut) joystick 0
		comf PORTC,W
		andlw 0x1F
		movwf JOY1; 000FDGBH (Fire, Droite, Gauche, Bas, Haut) joystick 1
		movlw HEADER_JOYSTICKS; header joysticks
		bra SerialTransmit_Joy
Joy_Monitor
		; lecture joyticks en continu
		call SerialReceive; rate
		rcall Change_0_To_1
		movwf Rate_Joy
		movwf Counter_10MS_Joy_Monitor
		bsf Flags2,JOY_MONITOR
		bra Joy_Enable
Fire_Button		
		bra Main
Joy_KeyCode
		; mode touches fleches joystick 0
		movlw LOW RX_JOY; TX_JOY, TY_JOY, TX_JOY, VX_JOY, VY_JOY
		movwf FSR
		IF _18F_
		movlw HIGH RX_JOY
		movwf FSR0H
		ELSE
		bcf STATUS,IRP; page 0
		ENDIF
		movlw 6
		call SerialReceiveInd; RX, RY, TX, TY, VX, VY
		clrf Status_Joy
		IF _18F_
		setf OLD_JOY
		ELSE
		movlw 0xFF
		movwf OLD_JOY
		ENDIF
		bsf Flags2,JOY_KEYS
		bcf Flags2,JOY_EVENT
Joy_Enable
		bsf Flags,JOY_ENABLE
		bra Main
Disable_Joysticks
		; inhibe les joysticks
		bcf Flags,JOY_ENABLE
		bra Main
		;--------------------------------------------------------------
		;   Programmation horloge IKBD		
Time_Set
		; initialise l'horloge
		movlw LOW YEAR_BCD
		movwf FSR
		IF _18F_
		movlw HIGH YEAR_BCD
		movwf FSR0H
		ELSE
		bsf STATUS,IRP; page 2
		ENDIF
		movlw 6
		call SerialReceiveInd; YY, MM, DD, hh, mm, ss
		clrf Counter_5MS
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call Conv_Inv_Bcd_Time
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		bra Main
		;--------------------------------------------------------------
		;   Lecture horloge IKBD
Interrog_Time
		; demande horloge
		call Leds_Eiffel_On
		rcall SendAtariClock
		bra End_Read
		;--------------------------------------------------------------
		;   Chargement memoire possible de 
		;   $00A0 a $00EF, et de $0120 a $016F
		;   si l'adresse de base de la commande et le nbre d'octet sont a 0
		;   -> programmation Flash en page 2 ($1000 a $1FFF) format Motorola
Memory_Load
		; chargement memoire
		call SerialReceive
		movwf PTRH_LOAD; ADRMSB
		call SerialReceive
		movwf PTRL_LOAD; ADRLSB
		call SerialReceive
		movwf Counter_LOAD; NUM
		iorwf PTRL_LOAD,W; ADRLSB
		iorwf PTRH_LOAD,W; ADRMSB
		btfsc STATUS,Z
			bra Prog_Flash; adresse $0000 taille $00 -> programmation FLASH
		bsf Flags3,RE_TIMER_IKBD; flag reception donnees IKBD dans boucle principale
		bra Main
Prog_Flash
		; Indiquer le mode programmation par allumages des trois LEDs
		call cmdLedOn
		call cmdDisableKey
		call cmdDisableMouse
		clrf STATUS; corrige bug init_page ram avant Eiffel 1.10 (IRP=0)
		IF _18F_
		clrf FSR0H
		IF LOAD_18F
		goto Ecriture_Flash-0x2000
		ELSE
		goto Ecriture_Flash
		ENDIF
		ELSE
		bsf PCLATH,3; page 1 (0x800 - 0xFFF) programme Flashage
		bcf PCLATH,4
		goto Ecriture_Flash
		ENDIF
		;--------------------------------------------------------------
		;   Lecture memoire possible partout 
		;   de $0000 a $01FF (registres PIC et RAM)
		;   de $2100 a $20FF (EEPROM)
		;   de $8000 a $FFFF (pour voir toute la FLASH de $0000 a $1FFF pour un 16F
		;                                              ou $0000 a $3FFF pour un 18F
		;                     octet par octet au format Mororola)
Memory_Read
		; lecture memoire
		call SerialReceive
		movwf TEMP1; ADRMSB
		IF _18F_
		clrf FSR0H
		ELSE
		bcf STATUS,IRP; pages 0-1
		ENDIF
		btfsc Value,0; ADRMSB
			IF _18F_
			incf FSR0H
			ELSE
			bsf STATUS,IRP; pages 2-3
			ENDIF
		call SerialReceive
		movwf Counter2
		movwf FSR; ADRLSB
		call Leds_Eiffel_On
		movlw HEADER_STATUS; header d'etat
		call SerialTransmit_Host
		movlw IKBD_MEMORY_LOAD; memoire
		call SerialTransmit_Host
		btfsc TEMP1,7
			bra Dump_Flash; lecture FLASH si adresse >= 0x8000
		movlw 6; 6 octets
		movwf Counter
		movf TEMP1,W
		sublw 0x21
		btfsc STATUS,Z
			bra Dump_EEProm; lecture EEProm si adresse 0x21xx
Loop_Dump_Ram
			movf INDF,W
			call SerialTransmit_Host; data
			incf FSR,F
			btfsc STATUS,Z
				IF _18F_
				incf FSR0H
				ELSE
				bsf STATUS,IRP; pages 2-3
				ENDIF
			decfsz Counter,F
		bra Loop_Dump_Ram	
		bra End_Read
Dump_EEProm
			movf Counter2,W
			call Lecture_EEProm
			call SerialTransmit_Host; data
			incf Counter2,F
			decfsz Counter,F
		bra Dump_EEProm	
		bra End_Read
Dump_Flash
		bcf TEMP1,7; adresse FLASH poids fort
		movlw 3; 3 mots (6 octets)
		movwf Counter	
Loop_Dump_Flash
			READ_FLASH TEMP1,Counter2,BUFFER_FLASH; lecture 2 octets
			movf BUFFER_FLASH+1,W
			call SerialTransmit_Host; data poids faible
			movf BUFFER_FLASH,W
			call SerialTransmit_Host; data poids fort
			IF _18F_
			incf Counter2,F
			ENDIF
			incf Counter2,F
			btfsc STATUS,Z
				incf TEMP1,F
			decfsz Counter,F
		bra Loop_Dump_Flash
End_Read
		call Leds_Eiffel_Off
		bra Main
Receive2Bytes
		call SerialReceive; ADRMSB
		; ADRLSB
Not_Prog_EEProm
		call SerialReceive
		bra Main
		;--------------------------------------------------------------
		;   Afficheur Lcd
		IF LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI
Lcd
		; envoi commande ou donnees au LCD
		call SerialReceive
		btfss STATUS,Z
			bra Test_Data_Lcd; <> 0
		call SerialReceive
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call SendINS
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		bcf Flags4,LCD_ENABLE; inhibe gestion timer LCD	
		bra Main
Test_Data_Lcd
		movwf Counter_LOAD; nombre d'octets
		comf Counter_LOAD,W		
		btfss STATUS,Z
			bra Data_Lcd; <> 0xFF
		bsf Flags4,LCD_ENABLE; autorise gestion timer LCD	
		bra Not_Prog_EEProm; dernier octet
Data_Lcd
		bsf Flags4,RE_LCD_IKBD; flag reception donnees LCD
		bsf Flags3,RE_TIMER_IKBD; flag reception donnees IKBD dans boucle principale
		bra Main		
		ENDIF
Test_Reset
		bcf Value,7; enleve 0x80
		movf Value,W
		sublw 0x1B
		btfss STATUS,C
			bra Main; Value > IKDB_STATUS_DISABLE_JOY
		IF _18F_
		rlcf Value,F
		ENDIF
		movlw LOW Table_Ikbd_Status
		addwf Value,F
		movlw HIGH Table_Ikbd_Status
		btfsc STATUS,C
			addlw 1
		movwf PCLATH
		IF !_18F_
		btfsc Info_Boot,7
			bsf PCLATH,4; page 2-3 (0x1000 - 0x1FFF)
		ENDIF
		movf Value,W
		movwf PCL
Table_Ikbd_Status
		bra _Reset;                 IKBD_RESET
		bra Main
		bra Main
		bra Main
		bra Main
		bra Main
		bra Main
		bra Status_Mouse_Action;    IKBD_STATUS_MOUSE_BUT_ACTION
		bra Status_Mouse_Mode;      IKBD_STATUS_MOUSE_MODE_R
		bra Status_Mouse_Mode;      IKBD_STATUS_MOUSE_MODE_A
		bra Status_Mouse_Mode;      IKBD_STATUS_MOUSE_MODE_K
		bra Status_Threshold;       IKBD_STATUS_MOUSE_THRESHOLD
		bra Status_Mouse_Scale;     IKBD_STATUS_MOUSE_SCALE
		bra Main
		bra Main
		bra Status_Mouse_Y;         IKBD_STATUS_MOUSE_Y0_AT_B
		bra Status_Mouse_Y;         IKBD_STATUS_MOUSE_Y0_AT_T
		bra Main
		bra Status_Mouse_Enable;    IKDB_STATUS_DISABLE_MOUSE
		bra Main
		bra Status_Joy_Mode;        IKBD_STATUS_JOY_MODE_E
		bra Status_Joy_Mode;        IKBD_STATUS_JOY_MODE_I
		bra Main
		bra Main
		bra Main
		bra Status_Joy_Mode;        IKBD_STATUS_JOY_MODE_K
		bra Status_Joy_Enable;      IKDB_STATUS_DISABLE_JOY
		;--------------------------------------------------------------
		;  Commande RESET -> Reinitialise Eiffel
		;   - On annule l'indicateur CAPS dans le mot d'etat.
		;   - On arrete les evenements souris et clavier PS/2. 
		;   - On envoi la commande reset au clavier et a la souris PS/2.
		;   - On autorise les transferts IKBD, souris et joystick.
_Reset
		call SerialReceive
		sublw 1; code reset
		btfss STATUS,Z
			bra Main
		clrf Flags
		clrf Flags2
		clrf Flags3
		clrf Flags4
		clrf Flags5
		clrf Status_Joy
		clrf MState_Mouse; machine d'etat reception trame souris PS/2
		clrf MState_Temperature; machine d'etat lecture temperature (reduction charge CPU)
		clrf DEB_INDEX_EM; index courant donnee a envoyer buffer circulaire liaison serie
		clrf FIN_INDEX_EM; fin index donnee a envoyer buffer circulaire liaison serie
		bcf PORTC,MOTORON; arret ventilateur
		call Leds_Eiffel_On
		IF LCD
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call Init_Lcd
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		ENDIF
		btfsc Status_Boot,CONNECTED_MOUSE
			call cmdDisableMouse
		bsf Flags2,RESET_MOUSE; valide reset souris dans traitement timer
		btfss Status_Boot,CONNECTED_KEYB
			bra Init_Flags
		call cmdLedOn
		bsf Flags2,RESET_KEYB; valide reset clavier dans traitement timer
Init_Flags
		; branchement ici apres init reset
		rcall Init_X_Y_Abs; position absolue souris
		movlw Tab_Config-EEProm
		call Lecture_EEProm
		sublw 2; jeu 2 clavier demande
		btfsc STATUS,Z
			bsf Flags3,KEYB_SET_2
		IF LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call Init_Message_User_Lcd
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		bsf Flags4,LCD_ENABLE; autorise gestion timer LCD
		ENDIF ; LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI
		bsf Flags2,JOY_EVENT
		bsf Flags,JOY_ENABLE
		bsf Flags,IKBD_ENABLE
Mouse_Enable
		bsf Flags,MOUSE_ENABLE
		bra Main
		;--------------------------------------------------------------
		;  Commandes de status
Status_Mouse_Action
		movlw HEADER_STATUS; header d'etat
		call SerialTransmit_Host
		movlw IKBD_SET_MOUSE_BUTTON_ACTION
		call SerialTransmit_Host
		movf BUTTON_ACTION,W
		call SerialTransmit_Host
		movlw 5
		bra Send_Null_Bytes
Status_Mouse_Mode
		movlw HEADER_STATUS; header d'etat
		call SerialTransmit_Host
		btfsc Flags2,MOUSE_KEYS
			bra Mouse_Mode_Keys
		btfsc Flags,MOUSE_ABS
			bra Mouse_Mode_Abs
		movlw IKBD_REL_MOUSE_POS_REPORT
		bra Send_End_Status_6_Null
Mouse_Mode_Abs
	 	movlw IKBD_ABS_MOUSE_POSITIONING
		call SerialTransmit_Host
		movlw LOW X_MAX_POSH; X_MAX_POSL, Y_MAX_POSH, Y_MAX_POSL
		movwf FSR; pointe sur le 1er element envoye
		IF _18F_
		movlw HIGH X_MAX_POSH
		movwf FSR0H
		ELSE
		bcf STATUS,IRP; page 0
		ENDIF
		movlw 4; 4 octets
		rcall SerialSendInd; XMSB, XLSB, YMSB, YLSB maxi 
		movlw 2
		bra Send_Null_Bytes		
Mouse_Mode_Keys
		movlw IKBD_SET_MOUSE_KEYCODE_CODE
		call SerialTransmit_Host
		movf DELTA_X,W; deltax mode keycode souris IKBD
		call SerialTransmit_Host
		movf DELTA_Y,W; deltay mode keycode souris IKBD
		bra Send_End_Status_4_Null
Status_Threshold
		movlw HEADER_STATUS; header d'etat
		call SerialTransmit_Host
		movlw IKBD_SET_MOUSE_THRESHOLD
		call SerialTransmit_Host
		movlw 1
		call SerialTransmit_Host
		movlw 1
		bra Send_End_Status_4_Null
Status_Mouse_Scale
		movlw HEADER_STATUS; header d'etat
		call SerialTransmit_Host
		movlw IKBD_SET_MOUSE_SCALE
		call SerialTransmit_Host
		movf X_SCALE,W
		call SerialTransmit_Host
		movf Y_SCALE,W
Send_End_Status_4_Null
		call SerialTransmit_Host
		movlw 4
		bra Send_Null_Bytes
Status_Mouse_Y
		movlw HEADER_STATUS; header d'etat
		call SerialTransmit_Host
		movlw IKBD_SET_Y0_AT_BOTTOM
		btfss Flags,SIGN_Y
			movlw IKBD_SET_Y0_AT_TOP
		bra Send_End_Status_6_Null
Status_Mouse_Enable
		movlw HEADER_STATUS; header d'etat
		call SerialTransmit_Host
		clrw; enabled
		btfss Flags,MOUSE_ENABLE
			movlw IKDB_DISABLE_MOUSE
		bra Send_End_Status_6_Null
Status_Joy_Mode	
		movlw HEADER_STATUS; header d'etat
		call SerialTransmit_Host
		btfsc Flags2,JOY_KEYS
			bra Joy_Mode_Keys
		movlw IKBD_SET_JOY_EVNT_REPORT
		btfss Flags2,JOY_EVENT
			movlw IKBD_SET_JOY_INTERROG_MODE
		bra Send_End_Status_6_Null		
Joy_Mode_Keys	
		movlw IKBD_SET_JOY_KEYCODE_MODE
		call SerialTransmit_Host
		movlw LOW RX_JOY; RY_JOY, TX_JOY, TY_JOY, VX_JOY, VY_JOY
		movwf FSR; pointe sur le 1er element
		IF _18F_
		movlw HIGH RX_JOY
		movwf FSR0H
		ELSE
		bcf STATUS,IRP; page 0
		ENDIF
		movlw 6; 6 octets
		rcall SerialSendInd; RX, RY, TX, TY, VX, VY 
		bra Main
Status_Joy_Enable
		movlw HEADER_STATUS; header d'etat
		call SerialTransmit_Host
		clrw; enabled
		btfss Flags,JOY_ENABLE
			movlw IKDB_DISABLE_JOYSTICKS
Send_End_Status_6_Null
		call SerialTransmit_Host
		movlw 6
Send_Null_Bytes
		call TransmitNullBytes; end status
		bra Main

;-----------------------------------------------------------------------------
;				Erreurs CLAVIER
;-----------------------------------------------------------------------------

Error_Keyboard
		call Remove_Key_Forced
		call cmdResetKey
		bra Remove_Flags_Keyb
		
Error_Parity_Keyboard
		IF SCROOL_LOCK_ERR
		bcf PARITY,7
		call UpdateLedOnOff
		ENDIF
		call cmdResendKey
Remove_Flags_Keyb
		movlw ~FLAGS_CODES; toute la trame est envoyee de nouveau
		andwf Flags3,F
		bra ClearBreakCode

;-----------------------------------------------------------------------------
;				Donnees arrivees du CLAVIER
;-----------------------------------------------------------------------------

doKeyboard
		; Interdire toutes emissions des peripheriques PS/2 (Mouse and Keyboard)
		DISABLEKEYB
		IF INTERRUPTS
		movf CounterValueK,W
		clrf CounterValueK
		sublw 1
		btfss STATUS,Z
			bra Error_Parity_Keyboard; code non traite
		ENDIF
		btfss PARITY,7
			bra Error_Parity_Keyboard; erreur parite
		bsf Status_Boot,CONNECTED_KEYB; pour switchs KVM
		; l'octet de la commande BAT clavier ?
		movf Value,W
		sublw CMD_BAT; Self-test passed (keyboard controller init)
		btfsc STATUS,Z; W contient $AA ?
			bra OnKbBAT
		movf Value,W
		sublw BAT_ERROR; Erreur clavier
		btfsc STATUS,Z; W contient $FC ?
			bra Error_Keyboard
		movf Value,W
		sublw ACK_ERROR; Erreur clavier
		btfsc STATUS,Z; W contient $FE ?
			bra Error_Keyboard

		IF SERIAL_DEBUG
		btfsc PORTB,JUMPER4; si jumper4 (+5V): Mode ATARI
			bra ModeKeyAtari
;-----------------------------------------------------------------------------
;	Mode PC: Pas de translation, envoi direct des Scan-Codes en texte
;	ASCII (BCD) ou binaires directement

		bcf PORTB,LEDGREEN; allume LED clavier
		movf Value,W; code clavier
		call SerialTransmit_Host
		bsf PORTB,LEDGREEN; eteint LED clavier
		bra Main
		ENDIF
		
;-----------------------------------------------------------------------------
;	Mode Atari: Translation des Scan-Codes PC -> Scan-Codes ATARI

ModeKeyAtari
		btfss Flags3,KEYB_SET_2
			bra Set3
		btfsc Flags3,PAUSE_SET_2
			bra TraiterPause
		movf Value,W
		sublw ESCAPE; est ce que W contient $E0 ?
		btfss STATUS,Z; si oui on passe
			bra TestPauseSet2; cas special pause du jeu 2
		; $E0 [$F0] $XX
		bsf Flags3,NEXT_CODE; on doit traiter le code suivant
		bra Main
TestPauseSet2
		movf Value,W
		sublw ESCAPE1; est ce que W contient $E1 ?
		btfss STATUS,Z; si oui on passe
			bra TestSpecialCodeSet2
		; $E1 [$F0] $14 [$F0] $77
		bsf Flags3,NEXT_CODES; on doit traiter les codes suivants
		bsf Flags3,PAUSE_SET_2
		bra Main
TraiterPause
		btfsc Flags3,NEXT_CODES
			bra TraiterPause2
		movf Value,W
		sublw CMD_RELEASED; est ce que W contient $F0 ?
		btfsc STATUS,Z; si non on passe
			bra BreakCode2
		bcf Flags3,NEXT_CODES
		bsf Flags3,NEXT_CODE; on doit traiter le code suivant
		bra ClearBreakCode
TraiterPause2
		movf Value,W
		sublw CMD_RELEASED; est ce que W contient $F0 ?
		btfsc STATUS,Z; si non on passe
			bra BreakCode2
		movf Value,W
		sublw 0x77; est ce que W contient $77 ?
		btfss STATUS,Z; si oui on passe
			bra Not_SendKey
		btfsc Flags2,JOY_MONITOR
			bra Not_SendPause
		bcf PORTB,LEDGREEN; allume LED clavier
		movlw DEF_PAUSE; touche enfoncee
		btfsc Flags2,BREAK_CODE
			iorlw 0x80; relachement (BreakCode Bit7=1)
		call SerialTransmit_Host
		bsf PORTB,LEDGREEN; eteint LED clavier
Not_SendPause
		bcf Flags3,PAUSE_SET_2
		bra Not_SendKey
TestSpecialCodeSet2
		movf Value,W
		sublw CMD_RELEASED; est ce que W contient $F0 ?
		btfsc STATUS,Z
			bra BreakCode2
		btfss Flags3,NEXT_CODE
			bra TestBreakCode
		movf Value,W; recharge W avec la valeur
		sublw 0x12; code bidon jeu 2, traitement particulier
		btfsc STATUS,Z
			bra Not_SendKey
TestBreakCode
		btfsc Flags2,BREAK_CODE
			IF LCD && LCD_DEBUG
			bra Not_BreakCode2
			ELSE		
			bra Not_BreakCode
			ENDIF
		movf Value,W
		subwf OldScanCode,W
		btfsc STATUS,Z
			bra Not_SendKey; supprime la repetition du jeu 2
		movf Value,W
		movwf OldScanCode
		IF LCD && LCD_DEBUG
Not_BreakCode2
		btfss Flags3,NEXT_CODE
			bra NotNextCode
		movlw 0xE0
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call Send_Debug_Hexa_Lcd
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
NotNextCode
		btfss Flags2,BREAK_CODE
			bra NotBreakCode
		movlw 0xF0
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call Send_Debug_Hexa_Lcd
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
NotBreakCode
		movf Value,W
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call Send_Debug_Hexa_Lcd
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		ENDIF ; LCD && LCD_DEBUG
		bra Not_BreakCode
BreakCode2
		clrf OldScanCode
BreakCode
		; $F0 $XX
		bsf Flags2,BREAK_CODE; on doit traiter un break code (touche relachee)
		bra Main
Set3
		IF LCD && LCD_DEBUG
		movf Value,W
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call Send_Debug_Hexa_Lcd
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		ENDIF ; LCD && LCD_DEBUG
		movf Value,W
		sublw CMD_RELEASED; est ce que W contient $F0 ?
		btfsc STATUS,Z
			bra BreakCode
Not_BreakCode
		btfsc Flags2,JOY_MONITOR
			bra Not_SendKey
		IF LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI && LCD_SCANCODE
		btfss Flags4,LCD_ENABLE; gestion timer LCD inhibe
			bra Not_SendLcd
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call Send_ScanCode_Lcd; code set 2/3
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
Not_SendLcd
		ENDIF ; LCD && LCD_DEBUG
		bcf PORTB,LEDGREEN; allume LED clavier
		rcall SendAtariKeyboard
		bsf PORTB,LEDGREEN; eteint LED clavier
Not_SendKey
		bcf Flags3,NEXT_CODE; flag 2eme code apres $E0
ClearBreakCode
		bcf Flags2,BREAK_CODE; touche enfoncee par defaut
		bra Main

;-----------------------------------------------------------------------------
; Reception de la commande BAT CLAVIER
;-----------------------------------------------------------------------------

OnKbBAT
		rcall KbBAT
		bsf Status_Boot,POWERUP_KEYB
		bra Main

KbBAT
; Apres un reset delay: 500 mS, rate; 10.9 cps, set 2, typematic/make/break
		call cmdScanSet
		btfss Flags3,KEYB_SET_2
			call cmdMakeBreak
;		btfsc Flags3,KEYB_SET_2
;			call cmdTypeRate
		movlw CAPS_OFF; Allumer Verr.Num., pas de CAPS lock
		call cmdLedOnOff
		call cmdEnableKey
		IF LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI && LCD_SCANCODE
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call Send_KbBAT_Lcd
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		ENDIF
		bsf PORTB,LEDGREEN; Eteindre la LED VERTE pour montrer le onBAT
		return

;-----------------------------------------------------------------------------
;				Erreurs SOURIS
;-----------------------------------------------------------------------------

Error_Mouse
		rcall MsBAT; reset + init
		bra Main
		
Error_Parity_Mouse
		IF SCROOL_LOCK_ERR
		bcf PARITY,7
		call UpdateLedOnOff
		ENDIF
		call cmdResendMouse
		movf MState_Mouse,W		
		sublw 4
		btfsc STATUS,C
			bra Pb_Trame_Mouse; toute la trame est envoyee de nouveau
		bra Main; sauf si initialisation en cours

;-----------------------------------------------------------------------------
;				Donnees arrivees de la SOURIS
;-----------------------------------------------------------------------------
		
doMouse
		; Interdire toutes emissions des peripheriques PS/2 (Mouse and Keyboard)
		DISABLEMOUSE
		btfss PARITY,7
			bra Error_Parity_Mouse
		movf MState_Mouse,W
		btfss STATUS,Z
			bra Frame_Mouse
		bsf Status_Boot,CONNECTED_MOUSE; pour switchs KVM
		; Est ce l'octet de la commande BAT souris ?
		movf Value,W
		sublw CMD_BAT; Self-test passed
		btfsc STATUS,Z; Est ce que W contient $AA ?
			bra OnMsBAT
		movf Value,W
		sublw BAT_ERROR; Erreur souris
		btfsc STATUS,Z; W contient $FC ?
			bra Error_Mouse
;		movf Value,W
;		sublw ACK_ERROR; Erreur souris
;		btfsc STATUS,Z; W contient $FE ?
;			bra Error_Mouse
Frame_Mouse

		IF SERIAL_DEBUG
		btfsc PORTB,JUMPER4; si jumper4 (+5V): Mode ATARI
			bra ModeMsAtari
;-----------------------------------------------------------------------------
;	Mode souris PC: envoi direct des codes en texte ASCII (BCD) ou 
;	binaires directement

		bcf PORTB,LEDYELLOW; allume LED souris
		movf Value,W
		rcall SerialTransmit_Host
		bsf PORTB,LEDYELLOW; eteint LED souris
		bra Main
		ENDIF

;-----------------------------------------------------------------------------
;	Mode souris Atari: On convertie les paquets d'octets en trame Atari

ModeMsAtari
		movf MState_Mouse,W
		movwf TEMP1
		incf MState_Mouse,F; compteur pour traiter chaque octet recu via la boucle principale (Main)
		IF _18F_
		rlcf TEMP1,F
		ENDIF
		movlw LOW Table_Mouse
		addwf TEMP1,F
		movlw HIGH Table_Mouse
		btfsc STATUS,C
			addlw 1
		movwf PCLATH
		IF !_18F_
		btfsc Info_Boot,7
			bsf PCLATH,4; page 2-3 (0x1000 - 0x1FFF)
		ENDIF
		movf TEMP1,W 
		movwf PCL
Table_Mouse
		bra First_Byte;  1er octet
		bra Second_Byte; 2eme octet (X) 
		bra Third_Byte;  3eme octet (Y)
		bra Fourth_Byte; 4eme octet eventuel (Z)
		bra Main
		
;-----------------------------------------------------------------------------
;	Detection d'une souris IntelliMouse simple. On tente la detection et on
;	positionne le bit MSWHEEL a UN si a roulette.
;
;	Methode:	Emettre Set Sample Rate 200
;				Emettre Set Sample Rate 100
;				Emettre Set Sample Rate 80
;
;				Emettre Get Device ID
;				Si retourne 	0x03 -> Souris etendue a roulette
;				Sinon retourne	0x00 -> Souris PS/2 standard
;-----------------------------------------------------------------------------
		bra Main;              <- ACK suite RESET
		bra Main;              <- BAT suite RESET
		bra cmdReset;          <- ID  suite RESET
		bra Main;              <- ACK suite RESET
		bra Main;              <- BAT suite RESET
		bra cmdReset;          <- ID  suite RESET
		bra Main;              <- ACK suite RESET
		bra Main;              <- BAT suite RESET
		bra cmdSetSmpRate;     <- ID  suite RESET
		bra cmdSetSmpRate_200; <- ACK suite SET_SAMPLE_RATE
		bra cmdSetSmpRate;     <- ACK
		bra cmdSetSmpRate_100; <- ACK suite SET_SAMPLE_RATE
		bra cmdSetSmpRate;     <- ACK
		bra cmdSetSmpRate_80;  <- ACK suite SET_SAMPLE_RATE
		bra cmdGetDeviceID;    <- ACK
		bra Main;              <- ACK suite GET_DEVICE_ID
		bra GetDeviceID;       <- ID  suite GET_DEVICE_ID
		bra TryWheelEnd;       <- ACK suite SET_SAMPLE_RATE

;-----------------------------------------------------------------------------
;       Detection d'une souris IntelliMouse etendue, c'est a dire 5 boutons et
;       eventuellement avec deuxieme roulette. On tente la detection et on positionne
;       le bit MSWHEELPLUS a UN si a roulette.
;
;       Methode: Emettre Set Sample Rate 200
;                Emettre Set Sample Rate 200
;                Emettre Set Sample Rate 80
;
;                Emettre Get Device ID
;                Si retourne 0x04    -> Souris etendue a roulette
;                Sinon retourne	0x00 -> Souris PS/2 standard
;-----------------------------------------------------------------------------
		bra cmdSetSmpRate;     <- ACK
		bra cmdSetSmpRate_200; <- ACK suite SET_SAMPLE_RATE
		bra cmdSetSmpRate;     <- ACK
		bra cmdSetSmpRate_200; <- ACK suite SET_SAMPLE_RATE
		bra cmdSetSmpRate;     <- ACK
		bra cmdSetSmpRate_80;  <- ACK suite SET_SAMPLE_RATE	
		bra cmdGetDeviceID;    <- ACK
		bra Main;              <- ACK suite GET_DEVICE_ID
		bra GetDeviceID2;      <- ID  suite GET_DEVICE_ID
		bra cmdSetSmpRateUser; <- ACK suite SET_SAMPLE_RATE
		IF REMOTE_MOUSE
		bra cmdMouseRemote;    <- ACK, branchement ici si <> MSWHEEL
		ENDIF
		bra cmdMouseEnable;    <- ACK
		bra EndMsBat;          <- ACK suite ENABLE_DATA_REPORTING

cmdReset
		movlw _RESET
		bra SendMouseCmd
cmdSetSmpRate_200
		movlw 200
		bra SendMouseCmd
cmdSetSmpRate_100
		movlw 100
		bra SendMouseCmd
cmdSetSmpRate_80
		movlw 80; entre dans le mode Scrolling Wheel
		bra SendMouseCmd
cmdGetDeviceID
		movlw GET_DEVICE_ID; Envoyer la commande pour identification
		bra SendMouseCmd
		; Attendre maintenant la reponse d'IDENTIFICATION de la souris
GetDeviceID
		; Analyser l'octet de retour: 0x00 = PS/2 standard / 0x03 IntelliMouse 3 boutons
		bcf Flags,MSWHEEL
		bcf Flags,MSWHEELPLUS
		movf Value,W
		sublw MS_WHEEL; soustraire le code IntelliMouse 3 boutons
		btfsc STATUS,Z
			bsf Flags,MSWHEEL; MS scrolling mouse
		bra End_TryWheel
TryWheelEnd
		btfsc Flags,MSWHEEL; si c'est un souris a roulette		
			bra cmdSetSmpRateUser
		movlw 33; branchement sur enable mouse
		movwf MState_Mouse
cmdSetSmpRateUser
		; selectionne la frequence d'echantillonnage
		movlw 40
		bra SendMouseCmd
		; Attendre maintenant la reponse d'IDENTIFICATION de la souris
GetDeviceID2
		; Analyser l'octet de retour: 0x00 = PS/2 standard / 0x04 Etendue a roulette
		movf Value,W
		sublw MS_WHEELPLUS; soustraire le code IntelliMouse 5 boutons
		btfsc STATUS,Z
			bsf Flags,MSWHEELPLUS; MS Intelllimouse
End_TryWheel
		; JUST for test: si affichage BCD afficher le code ID de la souris
		IF SERIAL_DEBUG
		movf Value,W
		btfss PORTB,JUMPER5; si mode debug
			rcall SerialTransmit_Host
		ENDIF
		; remettre le taux d'echantillonnage initial
cmdSetSmpRate
		movlw SET_SAMPLE_RATE
		bra SendMouseCmd
		IF REMOTE_MOUSE
cmdMouseRemote
		movlw SET_REMOTE_MODE; mode remote
		bra SendMouseCmd
		ENDIF
cmdMouseEnable
		movlw ENABLE_DATA_REPORTING; enable mouse
SendMouseCmd
		rcall MPS2cmd; -> atente Value Acknowledge
		goto Main
EndMsBat
		IF LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI && LCD_SCANCODE
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call Send_MsBAT_Lcd
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		ENDIF ;  LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI && LCD_SCANCODE
		bsf PORTB,LEDYELLOW; Eteindre la LED JAUNE pour montrer le onBAT
		; init terminee
Pb_Trame_Mouse
		clrf MState_Mouse
		goto Main

;-----------------------------------------------------------------------------
;       Gestion trame souris
;-----------------------------------------------------------------------------
First_Byte		
		movf Value,W
		movwf Value_0; test de validite de Value_0
		andlw 0xC0; masque Y(B7)/X(B6) overflow
		btfss STATUS,Z
			bra Pb_Trame_Mouse; X/Y overflow
		btfsc Value_0,3
			goto Main
		; le bit 3 doit toujours etre a 1
		bra Pb_Trame_Mouse; decalage dans la lecture de la trame
Second_Byte
		movf Value,W
		movwf Value_X; Value X mouvement
		goto Main
Third_Byte		
		movf Value,W
		movwf Value_Y; Value Y mouvement
		btfss Flags,MSWHEEL
			bra Normal_Mouse
		clrf Value_Z
		goto Main
Fourth_Byte
		movf Value,W
		movwf Value_Z; Value Z mouvement (-8 a 7)
Normal_Mouse
		clrf MState_Mouse
		clrf BUTTONS; etat des boutons souris
		btfsc Value_0,PC_LEFT; tester si bouton gauche souris a 1
			bsf BUTTONS,AT_LEFT; si 1 mettre mettre celui Atari a 1
		btfsc Value_0,PC_RIGHT; tester si bouton droit souris a 1
			bsf BUTTONS,AT_RIGHT; si 1 mettre celui Atari a 1
		movf BUTTONS,W
		iorlw HEADER_RELATIVE_MOUSE; header souris mode relatif ($F8 - $FB)
		movwf HEADER_IKBD		

		;-------------------------------------------------------------
		;   Au lieu de simuler un appui droit et gauche, on genere un scan-code
		; on ecrit des 0 pour ne pas transmettre ensuite
		clrf CLIC_MOUSE_WHEEL; touche bouton 3
		clrf KEY_MOUSE_WHEEL; touche roulette bouton 3
		clrf KEY2_MOUSE_WHEEL; touche boutons 4 & 5
		btfss Value_0,PC_MIDDLE; tester si bouton central souris a 1
			bra Compteurs_Mouse
		movlw Tab_Mouse-EEProm+IDX_BUTTON3
		rcall Lecture_EEProm
		movwf CLIC_MOUSE_WHEEL
		;-------------------------------------------------------------
Compteurs_Mouse
		;-------------------------------------------------------------
		;   traiter le compteur X
		bcf Value_X,AT_SIGN; Ramener la valeur sur 7 bits
		btfsc Value_0,PC_SIGNX; tester le bit de signe PC pour X
			bsf Value_X,AT_SIGN; est leve alors on leve le signe Atari
		movf Value_X,W
		movwf X_MOV; ecrire le resultat dans le compteur X Atari
		btfss Flags,MOUSE_ABS
			bra Not_Max_X; <> mode absolu		
		clrf TEMP2; positif
		btfsc Value_X,7
			comf TEMP2,F; negatif
		addwf X_POSL,F; position X absolue souris poids faible
		movf TEMP2,W
		btfsc STATUS,C
			incfsz TEMP2,W
		addwf X_POSH,F; X_POS = X_POS + X_MOV
		btfsc X_POSH,7; signe position X absolue souris poids fort
			bra Dep_Min_X; si X_POS < 0 --> X_POS = 0
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call Conv_Scale_X
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		movf X_MAX_POSH,W; position X absolue maximale souris poids fort
		subwf X_POSH_SCALED,W; position X absolue souris avec facteur d'echelle poids fort
		btfsc STATUS,Z
			bra XCompl
		btfss STATUS,C
			bra Not_Max_X; X_POS < X_MAX_POS 
		bra Dep_Max_X; X_POS > X_MAX_POS 		
XCompl
		movf X_MAX_POSL,W; position X absolue maximale souris poids faible
		subwf X_POSL_SCALED,W; position X absolue souris avec facteur d'echelle poids faible
		btfsc STATUS,Z
			bra Dep_Max_X; X_POS = X_MAX_POS
		btfss STATUS,C
			bra Not_Max_X; X_POS < X_MAX_POS 	
Dep_Max_X
		movf X_MAX_POSL,W
		movwf X_POSL_SCALED
		movf X_MAX_POSH,W
		movwf X_POSH_SCALED; si X_POS >= X_MAX_POS --> X_POS = X_MAX_POS
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call Conv_Inv_Scale_X
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		bra Not_Max_X
Dep_Min_X
		rcall Init_X_Abs
Not_Max_X
		;-------------------------------------------------------------
		;   traiter le compteur Y 
		bcf Value_Y,AT_SIGN; Ramener la valeur sur 7 bits 
		btfsc Value_0,PC_SIGNY; tester le bit de signe PC pour Y
			bsf Value_Y,AT_SIGN; est leve alors on leve le signe Atari
		; Le mouvement PS/2 et Atari est inverse par defaut
		btfsc Flags,SIGN_Y
			bra Not_Inv_Y; inversion de sens Y IKBD
		;complement a deux pour inverser le mouvement Y: on ne traite que +127/-128
		;ex: $FF %11111111 d-1 -> $01 %00000001 d+1
		comf Value_Y,F
		incf Value_Y,F
Not_Inv_Y
		movf Value_Y,W
		movwf Y_MOV; ecrire le resultat dans le compteur Y Atari
		btfss Flags,MOUSE_ABS
			bra Not_Max_Y; <> mode absolu
		clrf TEMP2; positif
		btfsc Value_Y,7
			comf TEMP2,F; negatif
		addwf Y_POSL,F; position Y absolue souris poids faible
		movf TEMP2,W
		btfsc STATUS,C
			incfsz TEMP2,W
		addwf Y_POSH,F; Y_POS = Y_POS + Y_MOV
		btfsc Y_POSH,7; signe position Y absolue souris poids fort
			bra Dep_Min_Y; si Y_POS < 0 --> Y_POS = 0
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call Conv_Scale_Y
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		movf Y_MAX_POSH,W; position Y absolue maximale souris poids fort
		subwf Y_POSH_SCALED,W; position Y absolue souris avec facteur d'echelle poids fort
		btfsc STATUS,Z
			bra YCompl
		btfss STATUS,C
			bra Not_Max_Y; Y_POS < Y_MAX_POS 
		bra Dep_Max_Y; Y_POS > Y_MAX_POS 		
YCompl
		movf Y_MAX_POSL,W; position Y absolue maximale souris poids faible
		subwf Y_POSL_SCALED,W; position Y absolue souris avec facteur d'echelle poids faible
		btfsc STATUS,Z
			bra Dep_Max_Y; X_POS = Y_MAX_POS
		btfss STATUS,C
			bra Not_Max_Y; Y_POS < Y_MAX_POS 	
Dep_Max_Y
		movf Y_MAX_POSL,W
		movwf Y_POSL_SCALED
		movf Y_MAX_POSH,W
		movwf Y_POSH_SCALED; si Y_POS >= Y_MAX_POS --> Y_POS = Y_MAX_POS
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call Conv_Inv_Scale_Y
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		bra Not_Max_Y
Dep_Min_Y
		rcall Init_Y_Abs
Not_Max_Y
		;------------------------------------------------------------
		; On recoit le compteur Z, si c'est une souris a roulette
		btfss Flags,MSWHEEL
			bra TransmitHost; si bit souris a roulette a zero on transmet maintenant
		; Cas de l'IntelliMouse, traiter le compteur Z
		btfsc Value_Z,PC_SIGNZ; Est ce une valeur negative
			bra ZNegatif
		; tester si la valeur sur les 4bits [3-0] est egale a 0 ou pas
		movf Value_Z,W; charger W avec la valeur
		andlw 0x0F; masquer et traiter le compteur Z sur 4 bits
		btfsc STATUS,Z
			bra ZZero
		;-------------------------------------------------------------
		; Valeur positive: Molette verticale vers LE BAS
		; ou molette horizontale vers LA DROITE
		movlw Tab_Mouse-EEProm+IDX_WHEELLT; valeur positive donc A GAUCHE toute
		btfss Value_Z,PC_BITLSBZ; si le BIT 0 est a 1 on donc 0x1 -> Molette verticale
			bra ZZeroKey
		movlw Tab_Mouse-EEProm+IDX_WHEELDN; valeur positive donc EN BAS toute
		bra ZZeroKey
ZNegatif
		;-------------------------------------------------------------
		; Valeur negative: Molette verticale vers LE HAUT
		; ou molette horizontale vers LA GAUCHE
		movlw Tab_Mouse-EEProm+IDX_WHEELRT; valeur negative -2 donc A DROITE toute
		btfss Value_Z,PC_BITLSBZ;si le BIT 0 est a 1 on donc 0xF -> Molette verticale
			bra ZZeroKey
		movlw Tab_Mouse-EEProm+IDX_WHEELUP; valeur negative -1 donc EN HAUT toute
ZZeroKey
		rcall Lecture_EEProm
		movwf KEY_MOUSE_WHEEL
ZZero
		;-------------------------------------------------------------
		; Si la IntelliMouse ET 5 boutons tester l'etat
		btfss Flags,MSWHEELPLUS;si bit WheelPlus a zero on transmet maintenant, 
			bra TransmitHost; \ il n'y a pas de boutons 4 & 5 et 2eme molette
		btfss Value_Z,PC_BUTTON4; bouton 4 actif ?
			bra NextButton; tester le prochain bouton (le 5)
		movlw Tab_Mouse-EEProm+IDX_BUTTON4; Scan-code associe au bouton 4
		bra TransmitHostKey
NextButton
		btfss Value_Z,PC_BUTTON5; bouton 5 actif ?
			bra TransmitHost; on transmet maintenant
		movlw Tab_Mouse-EEProm+IDX_BUTTON5; Scan-code associe au bouton 5
TransmitHostKey
		rcall Lecture_EEProm
		movwf KEY2_MOUSE_WHEEL
TransmitHost
		;-------------------------------------------------------------
		; Envoyer enfin le paquet souris au host
		btfss Flags,MOUSE_ENABLE
			goto Main; pas d'autorisation de l'Atari
		btfsc Flags2,JOY_MONITOR
			goto Main; monitoring joysticks en cours demande par l'Atari
		bcf PORTB,LEDYELLOW; allume LED souris
		rcall SendAtariMouse; relative
		;-------------------------------------------------------------
		; Test mode IKBD button action
		btfss BUTTON_ACTION,0; bouton enfonce -> envoi position absolue
			bra Not_Action_0
		movf BUTTONS,W; etat des boutons souris
		xorwf OLD_BUTTONS,W; ancien etat des boutons souris
		andlw 1		
		btfsc STATUS,Z
			bra Not_Change_A
		btfsc BUTTONS,0
			bra Env_Action; bouton droit enfonce
Not_Change_A
		movf BUTTONS,W; etat des boutons souris
		xorwf OLD_BUTTONS,W; ancien etat des boutons souris
		andlw 2		
		btfsc STATUS,Z
			bra Not_Action_0
		btfsc BUTTONS,1
			bra Env_Action; bouton gauche enfonce
Not_Action_0
		btfss BUTTON_ACTION,1; bouton relache -> envoi position absolue
			bra Not_Action_1	
		movf BUTTONS,W; etat des boutons souris
		xorwf OLD_BUTTONS,W; ancien etat des boutons souris
		andlw 1		
		btfsc STATUS,Z
			bra Not_Change_B
		btfss BUTTONS,0
			bra Env_Action; bouton droit relache
Not_Change_B
		movf BUTTONS,W; etat des boutons souris
		xorwf OLD_BUTTONS,W; ancien etat des boutons souris
		andlw 2		
		btfsc STATUS,Z
			bra Not_Action_1
		btfsc BUTTONS,1; bouton gauche relache
			bra Not_Action_1
Env_Action
		comf BUTTONS,W; etat des boutons souris
		movwf OLD_BUTTONS_ABS; ancien etat -> force l'envoi des changements d'etat
		movlw HEADER_ABSOLUTE_MOUSE; header souris mode absolu
		movwf HEADER_IKBD
		rcall SendAtariMouse
Not_Action_1
		bsf PORTB,LEDYELLOW; eteint LED souris
		movf BUTTONS,W; etat des boutons souris
		movwf OLD_BUTTONS; ancien etat des boutons souris		
		goto Main

;-----------------------------------------------------------------------------
; Reception de la commande BAT SOURIS
;-----------------------------------------------------------------------------

OnMsBAT
		rcall MPSGet; mouse ID
		rcall MsBAT
		bsf Status_Boot,POWERUP_MOUSE
		goto Main
		
MsBAT
		movlw 5
		movwf MState_Mouse; gere par le Main
		movlw _RESET
		bra MPS2cmd; -> atente Value Acknowledge via Main
		
;=============================================================================
;                               PROCEDURES ET FONCTIONS
;=============================================================================

;-----------------------------------------------------------------------------
;               Forcage a 1 si 0
;-----------------------------------------------------------------------------
		
Change_0_To_1
		iorlw 0
		btfsc STATUS,Z
			movlw 1
		return
		
;-----------------------------------------------------------------------------
;               Remise a 0 variables 
;-----------------------------------------------------------------------------
		
Init_X_Y_Abs
		rcall Init_X_Abs

Init_Y_Abs
		clrf Y_POSL
		clrf Y_POSH
		clrf Y_POSL_SCALED; position Y absolue souris avec facteur d'echelle poids faible
		clrf Y_POSH_SCALED; position Y absolue souris avec facteur d'echelle poids fort
		return
		
Init_X_Abs	
		clrf X_POSL
		clrf X_POSH
		clrf X_POSL_SCALED; position X absolue souris avec facteur d'echelle poids faible
		clrf X_POSH_SCALED; position X absolue souris avec facteur d'echelle poids fort
		return

;-----------------------------------------------------------------------------
;	Procedure de transmission des octets a propos de l'horloge
;-----------------------------------------------------------------------------
		
SendAtariClock
		movlw HEADER_TIME_OF_DAY; header horloge
		rcall SerialTransmit_Host
		movlw LOW YEAR_BCD; YY, MM, DD, hh, mm, ss
		movwf FSR; pointe sur le 1er element envoye c'est a dire l'annee
		IF _18F_
		movlw HIGH YEAR_BCD
		movwf FSR0H
		ELSE
		bsf STATUS,IRP; page 2
		ENDIF
		movlw 6; 6 octets
		
;-----------------------------------------------------------------------------
;   Envoi USART de W octets
;-----------------------------------------------------------------------------		
		
SerialSendInd 
		movwf Counter
Loop_Send
			movf INDF,W
			rcall SerialTransmit_Host
			incf FSR,F
			decfsz Counter,F
		bra Loop_Send; element suivant
		return

;-----------------------------------------------------------------------------
;	Procedure de transmission des octets a propos du (ou des) joystick(s)
;-----------------------------------------------------------------------------
		
SendAtariJoysticks
		movf HEADER_IKBD,W
		sublw HEADER_JOYSTICKS; header joysticks
		btfss STATUS,Z
			bra Not_Joy01
		;-------------------------------------------------------------
		; TRANSMETTRE le paquet Atari (3 octets) des joysticks
		rcall SerialTransmit_Header_Host
	 	movf JOY0,W; lecture joystick 0
		rcall SerialTransmit_Host_Joy
	 	movf JOY1,W; lecture joystick 1
		bra SerialTransmit_Host_Joy
Not_Joy01
		movf HEADER_IKBD,W
		sublw HEADER_JOYSTICK0; header joystick 0
		btfss STATUS,Z
			bra Not_Joy0
		btfss Flags2,JOY_KEYS; envoi touches fleches
			bra Not_ButAct0
		;-------------------------------------------------------------
		; TRANSMETTRE button action joystick 0
		movlw 0x74; bouton joytick 0 enfonce
		btfss JOY0,4
			movlw 0xF4; bouton joytick 0 relache
		bra SerialTransmit_Host
Not_ButAct0
		;-------------------------------------------------------------
		; TRANSMETTRE le paquet standard Atari (2 octets) du joystick 0
		rcall SerialTransmit_Header_Host
		movf JOY0,W; lecture joystick 0
		bra SerialTransmit_Host_Joy
Not_Joy0
		btfss Flags2,JOY_KEYS; envoi touches fleches
			bra Not_ButAct1
		;-------------------------------------------------------------
		; TRANSMETTRE button action joystick 1
		movlw 0x75; bouton joytick 1 enfonce
		btfss JOY1,4
			movlw 0xF5; bouton joytick 1 relache
		bra SerialTransmit_Host
Not_ButAct1
		;-------------------------------------------------------------
		; TRANSMETTRE le paquet standard Atari (2 octets) du joystick 1
		rcall SerialTransmit_Header_Host
		movf JOY1,W; lecture joystick 1	
SerialTransmit_Host_Joy
		; deplacement du bit fire du joystick (4 -> 7)
		movwf TEMP1
		btfsc TEMP1,4
			bsf TEMP1,7; bouton fire
		bcf TEMP1,4
		movf TEMP1,W
		bra SerialTransmit_Host
		
;-----------------------------------------------------------------------------
;	Procedure de transmission des octets a propos de l'emulation
;	des fleches du clavier via le joystick 0 soit le mode IKBD
;	joystick keycodes
;	- Temps initial RX/RY declenche lors de l'appui sur une direction le
;	  scan-code de la fleche clavier est alors envoye une 1ere fois suivant
;	  la direction choisie sur le joystick 0
;	- Temps repetition TX/TY (X fois suivant VX/VY)
;	- Temps total VX/VY provoquant l'arret de l'envoi du scan-code de la 
;	  fleche du clavier (idem si relachement de la direction choisie du
;	  joystick 0)
;-----------------------------------------------------------------------------

SendAtariJoysticks_Fleches
		btfsc Status_Joy,RY_H
			bra Not_H
		movf JOYB,W; joystick 0
		xorwf OLD_JOY,W
		andlw 1		
		btfsc STATUS,Z
			bra Not_H; pas de changement d'etat
		btfss JOYB,0
			bra Not_H
		bsf Status_Joy,RY_H; bouton haut enfonce
		bcf Status_Joy,TY_H
		movf Counter_100MS_Joy,W
		movwf START_RY_JOY
		movf RY_JOY,W
		btfsc STATUS,Z
			bra Not_H; temps RY nul
		rcall SerialTransmit_Haut; 1er envoi
Not_H
		btfsc Status_Joy,RY_B
			bra Not_B
		movf JOYB,W
		xorwf OLD_JOY,W
		andlw 2		
		btfsc STATUS,Z
			bra Not_B; pas de changement d'etat
		btfss JOYB,1
			bra Not_B
		bsf Status_Joy,RY_B; bouton bas enfonce
		bcf Status_Joy,TY_B
		movf Counter_100MS_Joy,W
		movwf START_RY_JOY
		movf RY_JOY,W
		btfsc STATUS,Z
			bra Not_B; temps RY nul
		rcall SerialTransmit_Bas; 1er envoi
Not_B
		btfsc Status_Joy,RX_G
			bra Not_G
		movf JOYB,W
		xorwf OLD_JOY,W
		andlw 4		
		btfsc STATUS,Z
			bra Not_G; pas de changement d'etat
		btfss JOYB,2
			bra Not_G
		bsf Status_Joy,RX_G; bouton gauche enfonce
		bcf Status_Joy,TX_G
		movf Counter_100MS_Joy,W
		movwf START_RX_JOY
		movf RX_JOY,W
		btfsc STATUS,Z
			bra Not_G; temps RX nul
		rcall SerialTransmit_Gauche; 1er envoi
Not_G
		btfsc Status_Joy,RX_D
			bra Not_D
		movf JOYB,W
		xorwf OLD_JOY,W
		andlw 8		
		btfsc STATUS,Z
			bra Not_D; pas de changement d'etat
		btfss JOYB,3
			bra Not_D
		bsf Status_Joy,RX_D; bouton droit enfonce
		bcf Status_Joy,TX_D
		movf Counter_100MS_Joy,W
		movwf START_RX_JOY
		movf RX_JOY,W
		btfsc STATUS,Z
			bra Not_D; temps RX nul
		rcall SerialTransmit_Droite; 1er envoi
Not_D
		btfss Status_Joy,RY_H
			bra Not_H2
		btfss JOYB,0
			bra End_H; bouton haut relache
		movf START_RY_JOY,W
		subwf Counter_100MS_Joy,W
		subwf VY_JOY,W; VY - temps ecoule
		btfsc STATUS,C
			bra Not_H3
End_H
		bcf Status_Joy,RY_H; fin temps total
		bcf Status_Joy,TY_H
		bra Not_H2
Not_H3
		btfsc Status_Joy,TY_H
			bra Not_H4; temps repetition
		movf START_RY_JOY,W
		subwf Counter_100MS_Joy,W
		subwf RY_JOY,W; RY - temps ecoule
		btfsc STATUS,C
			bra Not_H2; <> fin 1er temps
		bra Delay_TY_H
Not_H4
		movf START_TY_JOY,W
		subwf Counter_100MS_Joy,W
		subwf TY_JOY,W; TY - temps ecoule
		btfsc STATUS,C
			bra Not_H2
Delay_TY_H
		bsf Status_Joy,RY_H
		bsf Status_Joy,TY_H
		movf Counter_100MS_Joy,W
		movwf START_TY_JOY
		rcall SerialTransmit_Haut; repetition		
Not_H2
		btfss Status_Joy,RY_B
			bra Not_B2
		btfss JOYB,1
			bra End_B; bouton bas relache
		movf START_RY_JOY,W
		subwf Counter_100MS_Joy,W
		subwf VY_JOY,W; VY - temps ecoule
		btfsc STATUS,C
			bra Not_B3
End_B
		bcf Status_Joy,RY_B; fin temps total
		bcf Status_Joy,TY_B
		bra Not_B2
Not_B3
		btfsc Status_Joy,TY_B
			bra Not_B4; temps repetition
		movf START_RY_JOY,W
		subwf Counter_100MS_Joy,W
		subwf RY_JOY,W; RY - temps ecoule
		btfsc STATUS,C
			bra Not_B2; <> fin 1er temps
		bra Delay_TY_B
Not_B4
		movf START_TY_JOY,W
		subwf Counter_100MS_Joy,W
		subwf TY_JOY,W; TY - temps ecoule
		btfsc STATUS,C
			bra Not_B2
Delay_TY_B
		bsf Status_Joy,RY_B
		bsf Status_Joy,TY_B
		movf Counter_100MS_Joy,W
		movwf START_TY_JOY
		rcall SerialTransmit_Bas; repetition
Not_B2
		btfss Status_Joy,RX_G
			bra Not_G2
		btfss JOYB,2
			bra End_G; bouton gauche relache
		movf START_RX_JOY,W
		subwf Counter_100MS_Joy,W
		subwf VX_JOY,W; VX - temps ecoule
		btfsc STATUS,C
			bra Not_G3
End_G
		bcf Status_Joy,RX_G; fin temps total
		bcf Status_Joy,TX_G
		bra Not_G2
Not_G3
		btfsc Status_Joy,TX_G
			bra Not_G4; temps repetition
		movf START_RX_JOY,W
		subwf Counter_100MS_Joy,W
		subwf RX_JOY,W; RX - temps ecoule
		btfsc STATUS,C
			bra Not_G2; <> fin 1er temps
		bra Delay_TX_G
Not_G4
		movf START_TX_JOY,W
		subwf Counter_100MS_Joy,W
		subwf TX_JOY,W; TX - temps ecoule
		btfsc STATUS,C
			bra Not_G2
Delay_TX_G
		bsf Status_Joy,RX_G
		bsf Status_Joy,TX_G
		movf Counter_100MS_Joy,W
		movwf START_TX_JOY
		rcall SerialTransmit_Gauche; repetition	
Not_G2
		btfss Status_Joy,RX_D
			bra Not_D2
		btfss JOYB,3
			bra End_D; bouton droit relache
		movf START_RX_JOY,W
		subwf Counter_100MS_Joy,W
		subwf VX_JOY,W; VX - temps ecoule
		btfsc STATUS,C
			bra Not_D3
End_D
		bcf Status_Joy,RX_D; fin temps total
		bcf Status_Joy,TX_D
		bra Not_D2
Not_D3
		btfsc Status_Joy,TX_D
			bra Not_D4; temps repetition
		movf START_RX_JOY,W
		subwf Counter_100MS_Joy,W
		subwf RX_JOY,W; RX - temps ecoule
		btfsc STATUS,C
			bra Not_D2; <> fin 1er temps
		bra Delay_TX_D
Not_D4
		movf START_TX_JOY,W
		subwf Counter_100MS_Joy,W
		subwf TX_JOY,W; TX - temps ecoule
		btfsc STATUS,C
			bra Not_D2
Delay_TX_D
		bsf Status_Joy,RX_D
		bsf Status_Joy,TX_D
		movf Counter_100MS_Joy,W
		movwf START_TX_JOY
		rcall SerialTransmit_Droite; repetition	
Not_D2
		movf JOYB,W
		movwf OLD_JOY	
		return

;-----------------------------------------------------------------------------
;	Procedure de transmission des octets a propos de la souris. On envoit
;	le paquet souris standard Atari, sur 3 octets puis si les octets sont non
;	nul, on envoit deux supplementaires qui contiennent des Scan-codes pour
;	les molettes et boutons 4 & 5.
;
;	Entrees:	HEADER, X_MOV, Y_MOV en mode IKBD souris relative
;	            HEADER, BUTTONS, X_POSH, X_POSL, Y_POSH, Y_POSL en absolu
;	Sorties:	W detruit
;-----------------------------------------------------------------------------

SendAtariMouse
		movf HEADER_IKBD,W
		sublw HEADER_ABSOLUTE_MOUSE; header souris mode absolu
		btfsc STATUS,Z
			bra SendAtariMouse_Abs; envoi mode absolu
		btfsc Flags,MOUSE_ABS
			bra Not_trame_Rel; souris en mode absolu
		btfsc Flags2,MOUSE_KEYS; envoi touches fleches
			bra Not_trame_Rel
		;-------------------------------------------------------------
		; TRANSMETTRE le paquet standard souris Atari (3 octets) mode relatif
		rcall SerialTransmit_Header_Host; envoyer l'octet commande vers le Host
		movf X_MOV,W; deplacement relatif souris en X
		rcall SerialTransmit_Host; envoyer l'octet compteur X vers le Host
		movf Y_MOV,W; deplacement relatif souris en Y
		rcall SerialTransmit_Host; envoyer l'octet compteur Y vers le Host
		;-------------------------------------------------------------
Not_trame_Rel
		;-------------------------------------------------------------
		; Test mode IKBD mouse keycodes
		btfss Flags2,MOUSE_KEYS; envoi touches fleches
			bra Not_Keys_Mouse
		movf X_MOV,W; deplacement relatif souris en X
		addwf X_INC_KEY,F; increment en X mode keycode souris
		btfsc X_INC_KEY,7
			bra Loop_Moins_H
Loop_Plus_H
			movf DELTA_X,W; deltax mode keycode souris IKBD
			subwf X_INC_KEY,W
			btfsc STATUS,C
				bra Not_Key_Mouse_H
			movwf X_INC_KEY
			rcall SerialTransmit_Droite
		bra Loop_Plus_H	
Loop_Moins_H
			movf DELTA_X,W; deltax mode keycode souris IKBD
			addwf X_INC_KEY,W
			btfsc STATUS,C
				bra Not_Key_Mouse_H
			movwf X_INC_KEY
			rcall SerialTransmit_Gauche
		bra Loop_Moins_H	
Not_Key_Mouse_H
		movf Y_MOV,W; deplacement relatif souris en Y
		addwf Y_INC_KEY,F; increment en Y mode keycode souris
		btfsc Y_INC_KEY,7
			bra Loop_Moins_V
Loop_Plus_V
			movf DELTA_Y,W; deltay mode keycode souris IKBD
			subwf Y_INC_KEY,W
			btfsc STATUS,C
				bra Not_Keys_Mouse
			movwf Y_INC_KEY
			btfss Flags,SIGN_Y	
				rcall SerialTransmit_Bas
			btfsc Flags,SIGN_Y	
				rcall SerialTransmit_Haut
		bra Loop_Plus_V	
Loop_Moins_V
			movf DELTA_Y,W; deltay mode keycode souris IKBD
			addwf Y_INC_KEY,W
			btfsc STATUS,C
				bra Not_Keys_Mouse
			movwf Y_INC_KEY
			btfss Flags,SIGN_Y	
				rcall SerialTransmit_Haut
			btfsc Flags,SIGN_Y	
				rcall SerialTransmit_Bas
		bra Loop_Moins_V
Not_Keys_Mouse
		;-------------------------------------------------------------
		; Test mode IKBD button action
		btfss BUTTON_ACTION,2; envoi touches boutons
			bra Not_Clic_Mouse
		movf BUTTONS,W; etat des boutons souris
		xorwf OLD_BUTTONS,W; ancien etat des boutons souris
		andlw 1		
		btfsc STATUS,Z
			bra Not_Change_C
		movlw 0x75; bouton droit enfonce
		btfss BUTTONS,0
			movlw 0xF5; bouton droit relache
		rcall SerialTransmit_Host
Not_Change_C
		movf BUTTONS,W; etat des boutons souris
		xorwf OLD_BUTTONS,W; ancien etat des boutons souris
		andlw 2		
		btfsc STATUS,Z
			bra Not_Clic_Mouse
		movlw 0x74; bouton gauche enfonce
		btfss BUTTONS,1
			movlw 0xF4; bouton gauche relache
		rcall SerialTransmit_Host
Not_Clic_Mouse
		;-------------------------------------------------------------
		; TRANSMETTRE le Scan-code pour le bouton central (si celui-ci est non nul)
		movf CLIC_MOUSE_WHEEL,W; Tester le scan-code eventuel a transmettre
		btfsc STATUS,Z
			bra Roulettes
		; TRANSMISSION EFFECTIVE: Envoi du scan-code pour le bouton central
		rcall SerialTransmit_KeyUpDown; envoyer l'octet Molette
Roulettes
		;-------------------------------------------------------------
		; TRANSMETTRE le Scan-code des Molettes (si celui-ci est non nul)
		movlw Tab_Mouse-EEProm+IDX_WHREPEAT
		rcall Lecture_EEProm; nbre repetitions touche Mouse Wheel
		movwf Counter
Repeat
			movf KEY_MOUSE_WHEEL,W; Tester le scan-code eventuel a transmettre
			btfsc STATUS,Z
				bra Buttons45
			; TRANSMISSION EFFECTIVE: Envoi du scan-code pour la molette
			rcall SerialTransmit_KeyUpDown; envoyer l'octet Molette
			decfsz Counter,F; repeter l'emision
		bra Repeat
Buttons45
		;-------------------------------------------------------------
		; TRANSMETTRE le Scan-code des boutons 4 & 5 (si celui-ci est non nul)
		movf KEY2_MOUSE_WHEEL,W; Tester le scan-code eventuel a transmettre
		btfsc STATUS,Z
			return
		bra SerialTransmit_KeyUpDown; envoyer l'octet bouton 4 & 5
		;-------------------------------------------------------------
SendAtariMouse_Abs
		;-------------------------------------------------------------
		; TRANSMETTRE le paquet souris Atari (5 octets) en mode absolu
		rcall SerialTransmit_Header_Host
		clrf TEMP1
		movf BUTTONS,W; etat des boutons souris
		; test changement d'etat du bouton droit
		xorwf OLD_BUTTONS_ABS,W; ancien etat des boutons souris en mode absolu
		andlw 1		
		btfsc STATUS,Z
			bra Not_Change_0
		btfsc BUTTONS,0
			bsf TEMP1,0; bouton droit enfonce
		btfss BUTTONS,0
			bsf TEMP1,1; bouton droit relache
Not_Change_0
		; test changement d'etat du bouton gauche
		movf BUTTONS,W; etat des boutons souris
		xorwf OLD_BUTTONS_ABS,W; ancien etat des boutons souris en mode absolu
		andlw 2		
		btfsc STATUS,Z
			bra Not_Change_1
		btfsc BUTTONS,1
			bsf TEMP1,2; bouton gauche enfonce
		btfss BUTTONS,1
			bsf TEMP1,3; bouton gauche relache
Not_Change_1
		; envoi de la trame mode IKBD souris absolue
		movf BUTTONS,W; etat des boutons souris
		movwf OLD_BUTTONS_ABS; ancien etat des boutons souris en mode absolu
		movf TEMP1,W
		rcall SerialTransmit_Host; changements boutons: B3/2: gauche relache/enfonce, B1/0: droit relache/enfonce
		movlw LOW X_POSH_SCALED; X_POSL_SCALED, Y_POSH_SCALED, Y_POSL_SCALED
		movwf FSR; pointe sur le 1er element envoye
		IF _18F_
		movlw HIGH X_POSH_SCALED
		movwf FSR0H
		ELSE
		bcf STATUS,IRP; page 0
		ENDIF
		movlw 4; 4 octets
		bra SerialSendInd; XMSB, XLSB, YMSB, YLSB 
	
;-----------------------------------------------------------------------------
;   Traduction des touches AT vers ATARI. Cette procedure traite les
;	Scan-codes du jeu 2 ou 3 du clavier PS/2.
;
;	Make code: 	<Octet touche>
;	Break code:	<$F0><Octet touche> pour le jeu 3
;
;   Entree: Value = Octet keyboard recu, et flag BREAK_CODE a 1 pour BreakCode
;   Sortie: W = detruit
;
;   Global: Value qui contient l'octet
;-----------------------------------------------------------------------------

SendAtariKeyboard
		; controller pour ne pas depasser la taille de la table
		; La bit carry pour un sublw positionne a ZERO le bit
		; si le soustraction donne un reste donc un depassement
		movf Value,W			
		sublw MAX_VALUE_LOOKUP; soustraire l'offset MAX
		btfss STATUS,C; si carry =1 pas de problemes on passe
			return; ignore code > MAX_VALUE_LOOKUP
		bcf Flags4,FORCE_ALT_SHIFT; pas de forcage ALT / SHIFT vers l'unite centrale
		btfss Flags3,KEYB_SET_2
			bra GetSet3
		; traitement jeu 2
		btfsc Flags3,NEXT_CODE
			bra SendNextCode
		movf Value,W; recharge W avec la valeur
		sublw 0x11; LEFT ALT code jeu 2, traitement particulier
		btfss STATUS,Z
			bra NoAltSet2
		bcf Flags3,ALT_PS2; relachement Alt
		btfss Flags2,BREAK_CODE
			bsf Flags3,ALT_PS2
		movlw DEF_ALTGR; Atari
		bra SaveValue
NoAltSet2
		IF _18F_
		movlw LOW Get_Set2_ScanCode_1
		addwf Value,W
		movwf TBLPTRL
		movlw HIGH Get_Set2_ScanCode_1
		btfsc STATUS,C
			addlw 1
		movwf TBLPTRH
		movlw UPPER Get_Set2_ScanCode_1
		movwf TBLPTRU
		tblrd*
		movf TABLAT,W
		ELSE		
		movlw HIGH Get_Set2_ScanCode_1
		movwf PCLATH
		btfsc Info_Boot,7
			bsf PCLATH,4; page 2-3 (0x1000 - 0x1FFF)
		movf Value,W; recharge W avec la valeur
		rcall Get_Set2_ScanCode_1
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		bra TestIdxEeprom
SendNextCode
		IF _18F_
		movlw LOW Get_Set2_ScanCode_2
		addwf Value,W
		movwf TBLPTRL
		movlw HIGH Get_Set2_ScanCode_2
		btfsc STATUS,C
			addlw 1
		movwf TBLPTRH
		movlw UPPER Get_Set2_ScanCode_2
		movwf TBLPTRU
		tblrd*
		movf TABLAT,W
		ELSE
		movlw HIGH Get_Set2_ScanCode_2
		movwf PCLATH
		btfsc Info_Boot,7
			bsf PCLATH,4; page 2-3 (0x1000 - 0x1FFF)
		movf Value,W; recharge W avec la valeur
		rcall Get_Set2_ScanCode_2
		bcf PCLATH,3; page 0 ou 2
		ENDIF
TestIdxEeprom
		movwf Value; scan-code Atari
		sublw MAX_VALUE_ATARI; soustraire l'offset MAX
		btfss STATUS,C; si carry =1 pas de problemes on passe
			bra TestCode; ignore code > MAX_VALUE_ATARI
		IF _18F_
		movlw LOW Search_Code_Set3
		addwf Value,W
		movwf TBLPTRL
		movlw HIGH Search_Code_Set3
		btfsc STATUS,C
			addlw 1
		movwf TBLPTRH
		movlw UPPER Search_Code_Set3
		movwf TBLPTRU
		tblrd*
		movf TABLAT,W
		ELSE		
		movlw HIGH Search_Code_Set3
		movwf PCLATH
		btfsc Info_Boot,7
			bsf PCLATH,4; page 2-3 (0x1000 - 0x1FFF)
		movf Value,W; recharge W avec la valeur
		rcall Search_Code_Set3
		bcf PCLATH,3; page 0 ou 2
		iorlw 0
		ENDIF
		btfsc STATUS,Z
			bra TestCode; scan-code EEPROM non trouve
		movwf Value; scan-code jeu 3
GetSet3		; traitement jeu 3
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call Test_Shift_Alt_AltGr
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		btfsc Flags3,ALT_PS2
			bra No_Modifier; Alt enfonce, utilise uniquement la table en EEPROM
		IF _18F_
		movlw LOW Get_Modifier
		addwf Value,W
		movwf TBLPTRL
		movlw HIGH Get_Modifier
		btfsc STATUS,C
			addlw 1
		movwf TBLPTRH
		movlw UPPER Get_Modifier
		movwf TBLPTRU
		tblrd*
		movf TABLAT,W
		ELSE
		movlw HIGH Get_Modifier
		movwf PCLATH
		btfsc Info_Boot,7
			bsf PCLATH,4; page 2-3 (0x1000 - 0x1FFF)
		movf Value,W
		rcall Get_Modifier
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		movwf Counter
		btfss Counter,7
			clrf Counter; pas de forcage ALT / SHIFT vers l'unite centrale
		btfsc Counter,7
			bsf Flags4,FORCE_ALT_SHIFT	
		btfss Flags5,ALTGR_PS2_BREAK
			bra NoAltGr
		IF _18F_
		movlw LOW Get_Scan_Codes_AltGr
		addwf Value,W
		movwf TBLPTRL
		movlw HIGH Get_Scan_Codes_AltGr
		btfsc STATUS,C
			addlw 1
		movwf TBLPTRH
		movlw UPPER Get_Scan_Codes_AltGr
		movwf TBLPTRU
		tblrd*
		movf TABLAT,W
		ELSE		
		movlw HIGH Get_Scan_Codes_AltGr
		movwf PCLATH
		btfsc Info_Boot,7
			bsf PCLATH,4; page 2-3 (0x1000 - 0x1FFF)
		movf Value,W
		rcall Get_Scan_Codes_AltGr
		bcf PCLATH,3; page 0 ou 2
		iorlw 0
		ENDIF
		btfsc STATUS,Z
			bra NoAltGr
		swapf Counter,F; bit 1: ALT, bit 0: SHIFT states for the AltGr table
		bcf Counter,6
		btfsc Counter,2
			bsf Counter,6; recopie forcage bit 6 CTRL eventuel
		bra SaveValue; code avec AltGr
NoAltGr
		btfss Flags5,SHIFT_PS2_BREAK
			bra No_Modifier
		IF _18F_
		movlw LOW Get_Scan_Codes_Shift
		addwf Value,W
		movwf TBLPTRL
		movlw HIGH Get_Scan_Codes_Shift
		btfsc STATUS,C
			addlw 1
		movwf TBLPTRH
		movlw UPPER Get_Scan_Codes_Shift
		movwf TBLPTRU
		tblrd*
		movf TABLAT,W
		ELSE
		movlw HIGH Get_Scan_Codes_Shift
		movwf PCLATH
		btfsc Info_Boot,7
			bsf PCLATH,4; page 2-3 (0x1000 - 0x1FFF)
		movf Value,W
		rcall Get_Scan_Codes_Shift
		bcf PCLATH,3; page 0 ou 2
		iorlw 0
		ENDIF
		btfsc STATUS,Z
			bra No_Modifier
		rrf Counter,F			
		rrf Counter,F; bit 1: ALT, bit 0: SHIFT states for the Shift table
		bcf Counter,6
		btfsc Counter,4
			bsf Counter,6; recopie forcage bit 6 CTRL eventuel 
		bra SaveValue; code avec Shift
No_Modifier
		movf Value,W
GetValueEEProm
		rcall Lecture_EEProm; scan-code EEPROM jeu 3 eventuellement modifie
SaveValue	; partie commune jeu 2 & 3
		movwf Value; sauvegarder le resultat dans Value
TestCode
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call Test_Shift_Alt_Ctrl_Host
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		btfsc Flags2,BREAK_CODE
			bra NoForceHostCtrlAltShift; relachement
		btfss Flags4,FORCE_ALT_SHIFT
			bra TestKeyForced; pas de forcage d'apres la table Modidier
		bsf Flags4,KEY_FORCED
		btfss Counter,6; CTRL
			bra NoForceHostCtrl
		movlw 0x1D; CTRL
		btfss Flags4,CTRL_HOST
			rcall SerialTransmit_Host
NoForceHostCtrl
		btfsc Counter,0; SHIFT
			bra ForceShiftOn
		movlw 0xAA; relachement LEFT SHIFT
		btfsc Flags4,LEFT_SHIFT_HOST
			rcall SerialTransmit_Host
		movlw 0xB6; relachement RIGHT SHIFT
		btfsc Flags4,RIGHT_SHIFT_HOST
			rcall SerialTransmit_Host
		bra TestAltHost
ForceShiftOn
		movlw 0x2A; LEFT SHIFT
		btfss Flags4,LEFT_SHIFT_HOST
			rcall SerialTransmit_Host
		movf Value,W
		sublw 0x60; <
		btfsc STATUS,Z
			bra TestAltHost
		movlw 0x36; RIGHT SHIFT
		btfss Flags4,RIGHT_SHIFT_HOST
			rcall SerialTransmit_Host
TestAltHost
		btfsc Counter,1; ALT
			bra ForceAltOn
		movlw 0xB8; relachement ALT
		btfsc Flags4,ALT_HOST
			rcall SerialTransmit_Host
		bra NoForceHostCtrlAltShift	
ForceAltOn
		movlw 0x38; ALT
		btfss Flags4,ALT_HOST
			rcall SerialTransmit_Host
		bra NoForceHostCtrlAltShift
TestKeyForced	
		rcall Remove_Key_Forced; cas anormal d'un CTRL, SHIFT ou ALT encore force
NoForceHostCtrlAltShift
		movf Value,W; tester si translation a donne 0
		btfsc STATUS,Z; Z=1 si W contient 0
			return; pas d'affectation
		btfss Value,7
			bra NoSpecialCodeWithStatus; code < 0x80
; >= $80 -> envoyes via $F6 $05 $00 $00 $00 $00 $00 $XX-$80
; ou $F6 $05 $00 $00 $00 $00 $00 $XX si relachement
		bcf Value,7
		movf Value,W
		sublw MAX_VALUE_ATARI; soustraire l'offset MAX
		btfss STATUS,C; si carry =1 pas de problemes on passe
			return; ignore code > MAX_VALUE_ATARI
		movlw HEADER_STATUS; header d'etat
		rcall SerialTransmit_Host
		movlw IKBD_PROGKB; code Eiffel
		rcall SerialTransmit_Host
		movlw 5
		rcall TransmitNullBytes
NoSpecialCodeWithStatus
		movf Value,W
		sublw MAX_VALUE_ATARI; soustraire l'offset MAX
		btfss STATUS,C; si carry =1 pas de problemes on passe
			return; ignore code > MAX_VALUE_ATARI
		movf Value,W
		btfsc Flags2,BREAK_CODE
			iorlw 0x80; relachement (BreakCode Bit7=1)
		movwf TEMP3
		; detecter si CAPS LOCK appuye pour allumer/eteindre la LED
		sublw KEY_CAPSLOCK; Caps Lock
		btfsc STATUS,Z
			rcall CapsLock
		movf TEMP3,W
		rcall SerialTransmit_Host; Atari scan-code
		btfss Flags2,BREAK_CODE
			return; enfoncement
		; relachement (break code)
		btfss Flags4,FORCE_ALT_SHIFT
			return; pas de forcage d'apres la table Modifier
		bcf Flags4,KEY_FORCED
		btfss Counter,6; CTRL
			bra NoForceHostCtrl2
		movlw 0x9D; relachement CTRL
		btfss Flags4,CTRL_HOST
			rcall SerialTransmit_Host
NoForceHostCtrl2
		btfsc Counter,0; SHIFT
			bra RestoreShift
		movlw 0x2A; LEFT SHIFT
		btfsc Flags4,LEFT_SHIFT_HOST
			rcall SerialTransmit_Host
		movlw 0x36; RIGHT SHIFT
		btfsc Flags4,RIGHT_SHIFT_HOST
			rcall SerialTransmit_Host
		bra TestAltHost2
RestoreShift
		movlw 0xAA; relachement LEFT SHIFT
		btfss Flags4,LEFT_SHIFT_HOST
			rcall SerialTransmit_Host
		movlw 0xB6; relachement RIGHT SHIFT
		btfss Flags4,RIGHT_SHIFT_HOST
			rcall SerialTransmit_Host
TestAltHost2
		btfsc Counter,1; ALT
			bra RestoreAlt
		movlw 0x38; ALT
		btfsc Flags4,ALT_HOST
			rcall SerialTransmit_Host
		return	
RestoreAlt
		movlw 0xB8; relachement ALT
		btfss Flags4,ALT_HOST
			rcall SerialTransmit_Host
		return

;-----------------------------------------------------------------------------
;  Cas anormal d'un CTRL, SHIFT ou ALT encore force
;-----------------------------------------------------------------------------	

Remove_Key_Forced
		btfss Flags4,KEY_FORCED
			return
		movf Flags4,W
		andlw FLAGS_HOST 
		btfsc STATUS,Z
			return; tous les bits a 0
		bcf Flags4,KEY_FORCED
		movlw 0x9D; relachement CTRL
		rcall SerialTransmit_Host
		movlw 0xAA; relachement LEFT SHIFT
		rcall SerialTransmit_Host
		movlw 0xB6; relachement RIGHT SHIFT
		rcall SerialTransmit_Host
		movlw 0xB8; relachement ALT
		bra SerialTransmit_Host

;-----------------------------------------------------------------------------
;  Reception USART octet par octet sur une commande LOAD
;-----------------------------------------------------------------------------		
		
Receive_Bytes_Load		
		IF LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI
		btfsc Flags4,RE_LCD_IKBD; fin reception donnees LCD
			bra Receive_Load_Lcd
		ENDIF
		; reception en cours des octets via la commande LOAD
		btfsc PTRH_LOAD,0
			bra Not_Page_0_1; pages 2-3
		IF _18F_
		clrf FSR0H
		ELSE
		bcf STATUS,IRP; pages 0-1
		ENDIF
		btfss PTRL_LOAD,7
			bra Not_Load; ignore page 0 (utilisee pour les variables)
		bra Load_Page
Not_Page_0_1
		IF _18F_
		movlw 1
		movwf FSR0H
		ELSE
		bsf STATUS,IRP; pages 2-3
		ENDIF
		btfsc PTRL_LOAD,7
			bra Not_Load; ignore page 3 (utilisee pour le tampon d'emission)
Load_Page
		movf PTRL_LOAD,W
		andlw 0x60
		btfsc STATUS,Z
			bra Not_Load; ignore adresse < 0x20 (registres)
		movf PTRL_LOAD,W
		movwf FSR	
		andlw 0x70
		sublw 0x70
		btfsc STATUS,Z
			bra Not_Load; ignore adresse >= 0x70 (variables communes aux 4 pages)
		movf Value,W
		movwf INDF
Not_Load
		incf PTRL_LOAD,F
		btfsc STATUS,Z
			incf PTRH_LOAD,F
		IF LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI
		bra Next_Byte_Load
Receive_Load_Lcd
		movf Value,W
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call SendCHAR
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
Next_Byte_Load
		ENDIF ; LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI
		decfsz Counter_LOAD,F
			return
		bcf Flags4,RE_LCD_IKBD; fin reception donnees LCD
		bcf Flags3,RE_TIMER_IKBD; fin reception donnees IKBD dans la boucle principale
		return

;-----------------------------------------------------------------------------
;  Reception USART de W octets
;-----------------------------------------------------------------------------		
		
SerialReceiveInd 
		movwf Counter
Loop_Receive
			rcall SerialReceive
			movwf INDF
			incf FSR,F
			decfsz Counter,F
		bra Loop_Receive
		return
		
		IF _18F_ && _CAN_

;-----------------------------------------------------------------------------
;   Wait for byte to be received in CAN and return with byte in Value
;-----------------------------------------------------------------------------
		
SerialReceive
		movf DLC_CAN,W
		btfss STATUS,Z
			bra ReceiveByteCAN
WaitCANReceive	
		btfss PIR3,RXB0IF; reception trame CAN dans Receive Buffer 0
			bra WaitCANReceive
ReceiveByteCAN
		call Receive_CAN
		movwf Value
		return

		ELSE

;-----------------------------------------------------------------------------
;   Wait for byte to be received in USART and return with byte in Value
;-----------------------------------------------------------------------------

SerialReceive
		btfss PIR1,RCIF ; check if data received
			bra SerialReceive; wait until new data
		btfss RCSTA,OERR
			bra TestFramingError
		bcf RCSTA,CREN; acquitte erreur Overrun
		bsf RCSTA,CREN; enable reception
		bra SerialReceive
FramingError
		movf RCREG,W; acquitte erreur Framing Error
		bra SerialReceive
TestFramingError
		btfsc RCSTA,FERR 
			bra FramingError
		movf RCREG,W; get received data into W
		movwf Value; put W into Value (result)
		return
		
		ENDIF ; _18F_ && _CAN_
		
;-----------------------------------------------------------------------------
;   Transmit HEADER_IKBD from USART
;
; Entree: Rien
; Sortie: Rien
;
; Global: HEADER_IKBD, TEMP2, TEMP3, TEMP4, TEMP5, TEMP6
;         DEB_INDEX_EM, FIN_INDEX_EM, TAMPON_EM utilises
;-----------------------------------------------------------------------------

SerialTransmit_Header_Host
		movf HEADER_IKBD,W

;-----------------------------------------------------------------------------
;   Transmit byte in W register from USART
;
; Entree: W = donnee binaire
; Sortie: Rien
;
; Global: TEMP2, TEMP3, TEMP4, TEMP5, TEMP6
;         DEB_INDEX_EM, FIN_INDEX_EM, TAMPON_EM utilises
;-----------------------------------------------------------------------------
		
SerialTransmit_Host
		IF SERIAL_DEBUG
		btfsc PORTB,JUMPER5
			bra Mode_Binaire; if jumper5 disable (5V) normal
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call SendHexa; if mode debug
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		return
Mode_Binaire
		ENDIF ; SERIAL_DEBUG
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call SerialTransmit; envoyer l'octet commande vers le Host
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		return
		
;-----------------------------------------------------------------------------
;   Transmit null bytes from USART
;
; Entree: W = nombre d'octets nuls a envoyer
; Sortie: Rien
;
; Global: Counter
;-----------------------------------------------------------------------------

TransmitNullBytes
		movwf Counter	
Loop_SerialTransmit_Status
			clrw
			rcall SerialTransmit_Host
			decfsz Counter,F
		bra Loop_SerialTransmit_Status
		return		

;-----------------------------------------------------------------------------
;   Envoi des fleches
;-----------------------------------------------------------------------------

SerialTransmit_Haut
		movlw 0x48; bouton fleche haut
		bra SerialTransmit_KeyUpDown
		
SerialTransmit_Bas
		movlw 0x50; bouton fleche bas
		bra SerialTransmit_KeyUpDown
		
SerialTransmit_Gauche
		movlw 0x4B; bouton fleche gauche
		bra SerialTransmit_KeyUpDown
		
SerialTransmit_Droite
		movlw 0x4D; bouton fleche droite

;-----------------------------------------------------------------------------
;   Envoi du code d'une touche et son relachement juste apres
;
; Entree: W = donnee binaire
; Sortie: Rien
;
; Global: Value utilise
;-----------------------------------------------------------------------------

SerialTransmit_KeyUpDown
		movwf Value
		rcall SerialTransmit_Host; touche enfonce
		movf Value,W
		iorlw 0x80; relachement
		bra SerialTransmit_Host

;-----------------------------------------------------------------------------
;   Changement d'etat led Caps Lock
;
; Entree: W = donnee binaire
; Sortie: Rien
;
; Global: Flags, Flags3
;-----------------------------------------------------------------------------
		
CapsLock
		IF SCROOL_LOCK_ERR
		bsf PARITY,7
		ENDIF
		movlw MASK_CAPS_LOCK
		xorwf Flags,F; inverse etat CapsLock 

UpdateLedOnOff
		movlw CAPS_OFF
		btfsc Flags,CAPS_LOCK
			movlw CAPS_ON
		IF SCROOL_LOCK_ERR
		btfss PARITY,7  	
			iorlw LED_SCROLL
		ENDIF
		bra cmdLedOnOff 

;-----------------------------------------------------------------------------
;   Allumer les 3 LEDs du clavier AT
;
;   Entree: rien
;   Sortie: W = detruit
;
;   Global: Var LED
;-----------------------------------------------------------------------------

cmdLedOn
		movlw LEDS_ON

;-----------------------------------------------------------------------------
;   Allumer LEDs clavier AT
;
;   Entree: Var LED contient le champ de bits
;   Sortie: W = detruit
;
;   Global: Var LED
;-----------------------------------------------------------------------------

cmdLedOnOff
		IF !SCROOL_LOCK_ERR
		btfsc Flags3,KEYB_SET_2
			iorlw LED_SCROLL; jeu no 2
		ENDIF
		movwf TEMP2
		movlw SET_RESET_LEDS; envoyer la commande d'allumage
		rcall KPSCmd
		movf TEMP2,W; Allumer LEDs choisies
		bra KPSCmd

;-----------------------------------------------------------------------------
;   Activer le mode Make/Break des scan-codes.
;   Ce mode doit etre selectionne car le delais et la repetition des touches
;   sont geres par le XBIOS de l'Atari.
;   Cette commande est ignoree par le jeu no 2 AT.
;
;   Entree: Rien
;   Sortie: W = detruit
;
;   Global: Aucune
;-----------------------------------------------------------------------------

cmdMakeBreak
		movlw SET_ALL_KEYS_MAKE_BREAK; envoyer la commande make/break
		bra KPSCmd

;-----------------------------------------------------------------------------
;   Envoi la commande Set Typematic Rate au clavier, pour fixer la 
;   vitesse de repetition
;
;   Entree: Rien
;   Sortie: W = detruit
;
;   Global: Aucune
;-----------------------------------------------------------------------------

;cmdTypeRate
;		movlw SET_TYPEMATIC_RATE_DELAY
;		rcall KPSCmd
;		movlw 0x20; delais 500 mS 30 caracteres par seconde
;		bra KPSCmd
 
;-----------------------------------------------------------------------------
;   Passage en scan-code jeu 2 ou 3 clavier
;
;   Entree: Rien
;   Sortie: W = detruit
;
;   Global: Aucune
;-----------------------------------------------------------------------------

cmdScanSet
		movlw SET_SCAN_CODE_SET; envoyer la commande de selection
		rcall KPSCmd
		movlw SCANCODESET3
		btfsc Flags3,KEYB_SET_2
			movlw SCANCODESET2
		bra KPSCmd

;-----------------------------------------------------------------------------
;   Envoi de la commande reset au CLAVIER
;
;   Entree: Rien
;   Sortie: W = detruit
;
;   Global: Aucune
;-----------------------------------------------------------------------------

cmdResetKey
		movlw _RESET
		bra KPSCmd

;-----------------------------------------------------------------------------
;   Envoi de la commande resend au CLAVIER
;
;   Entree: Rien
;   Sortie: W = detruit
;
;   Global: Aucune
;-----------------------------------------------------------------------------

cmdResendKey
		movlw RESEND
		bra KPS2cmd; pas d'acknowledge
		
;-----------------------------------------------------------------------------
;   Envoi de la commande enable au CLAVIER
;
;   Entree: Rien
;   Sortie: W = detruit
;
;   Global: Aucune
;-----------------------------------------------------------------------------

cmdEnableKey
		movlw ENABLE; envoyer la commande
		bra KPSCmd

;-----------------------------------------------------------------------------
;   Envoi de la commande disable au CLAVIER
;
;   Entree: Rien
;   Sortie: W = detruit
;
;   Global: Aucune
;-----------------------------------------------------------------------------

cmdDisableKey
		movlw DEFAULT_DISABLE
		bra KPSCmd

;-----------------------------------------------------------------------------
;   Envoi de la commande reset a la SOURIS
;
;   Entree: Rien
;   Sortie: W = detruit
;
;   Global: Aucune
;-----------------------------------------------------------------------------

;cmdResetMouse
;		movlw _RESET
;		bra MPSCmd

;-----------------------------------------------------------------------------
;   Envoi de la commande resend a la SOURIS
;
;   Entree: Rien
;   Sortie: W = detruit
;
;   Global: Aucune
;-----------------------------------------------------------------------------

cmdResendMouse
		movlw RESEND
		bra MPS2cmd; pas d'Acknowledge

;-----------------------------------------------------------------------------
;   Envoi de la commande enable a la SOURIS
;
;   Entree: Rien
;   Sortie: W = detruit
;
;   Global: Aucune
;-----------------------------------------------------------------------------

cmdEnableMouse
		movlw ENABLE_DATA_REPORTING
		bra MPSCmd

;-----------------------------------------------------------------------------
;   Envoi de la commande disable a la SOURIS
;
;   Entree: Rien
;   Sortie: W = detruit
;
;   Global: Aucune
;-----------------------------------------------------------------------------

cmdDisableMouse
		movlw DISABLE_DATA_REPORTING
		bra MPSCmd

;-----------------------------------------------------------------------------
;   Envoi de la commande de selection du mode remote a la SOURIS
;
;   Entree: Rien
;   Sortie: W = detruit
;
;   Global: Aucune
;-----------------------------------------------------------------------------

	IF REMOTE_MOUSE
;cmdSetRemoteMouse
;	movlw SET_REMOTE_MODE
;	bra MPSCmd		
	ENDIF
	
;-----------------------------------------------------------------------------
;   Envoi de la commande de lecture a la SOURIS (mode remote)
;
;   Entree: Rien
;   Sortie: W = detruit
;
;   Global: Aucune
;-----------------------------------------------------------------------------

	IF REMOTE_MOUSE
cmdReadMouse
	movlw READ_DATA
	bra MPSCmd
	ENDIF
		
;-----------------------------------------------------------------------------
;   Emission de la commande set sample rate sur la souris
;
;   Entree: Rien
;   Sortie: W = detruit
;
;   Global: Aucune
;-----------------------------------------------------------------------------

;cmdSetSmpRate
;		movwf TEMP2
;		movlw SET_SAMPLE_RATE
;		rcall MPSCmd
;		movf TEMP2,W
;		bra MPSCmd

;-----------------------------------------------------------------------------
;   Emission d'une commande sur le clavier
;
;   Entree: W
;   Sortie: W = detruit
;
;   Global: Aucune
;-----------------------------------------------------------------------------

KPSCmd
		rcall KPS2cmd; -> atente Value Acknowledge
		
;-----------------------------------------------------------------------------
;   KEYBOARD: Routine de lecture d'un octet du port DIN5 et MiniDIN6
;
;   Entree: Rien
;   Sortie: W = 1 si octet recu sinon 0
;           VAR Value = octet recu
;-----------------------------------------------------------------------------

KPSGet
		IF INTERRUPTS
		IF NON_BLOQUANT
		IF _8MHZ_
		movlw 4; ~ 2 secondes
		ELSE
		movlw 2
		ENDIF
		movwf Counter; time-out
		clrf Counter2
		clrf Counter3
LoopKPSGet
					movf CounterValueK,W; attente code clavier
					btfss STATUS,Z
						bra KPSGetInt
					decfsz Counter3,F
				bra LoopKPSGet
				decfsz Counter2,F
			bra LoopKPSGet
			decfsz Counter,F
		bra LoopKPSGet
		clrf ParityK
		clrf ValueK
KPSGetInt
		ELSE
LoopKPSGet
		movf CounterValueK,W; attente code clavier
		btfsc STATUS,Z
			bra LoopKPSGet
		ENDIF
		clrf CounterValueK
		movf ParityK,W
		movwf PARITY
		movf ValueK,W
		movwf Value
		return
		ELSE
		clrf PARITY
		; Test l'horloge, si etat bas, le clavier communique
		IF NON_BLOQUANT	
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call Wait_Kclock; utilise Counter, [Counter2, Counter3]
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		movf Counter,W
		btfsc STATUS,Z
			return; time-out
		ELSE
		WAIT_KCLOCK_L; attente front descendant de CLK
		ENDIF	
KPSGet2
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call _KPSGet2
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		return
		ENDIF

;-----------------------------------------------------------------------------
;This routine sends a byte in W to a PS/2 mouse or keyboard. TEMP1, TEMP2,
;and PARITY are general purpose registers. CLOCK and DATA are assigned to
;port bits, and "Delay" is a self-explainatory macro. DATA and CLOCK are
;held high by setting their I/O pin to input and allowing an external pullup
;resistor to pull the line high. The lines are brought low by setting the
;I/O pin to output and writing a "0" to the pin.
;-----------------------------------------------------------------------------

KPS2cmd
		IF INTERRUPTS
		bcf INTCON,GIE; interdit interruptions
		ENDIF
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call _KPS2cmd
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		IF INTERRUPTS
		bsf INTCON,GIE; autorise interruptions
		ENDIF
		return

;-----------------------------------------------------------------------------
;   Emission d'une commande sur la souris
;
;   Entree: W
;   Sortie: W = detruit
;
;   Global: Aucune
;----------------------------------------------------------------------------

MPSCmd
		rcall MPS2cmd; -> atente Value Acknowledge
		
;-----------------------------------------------------------------------------
;   Routine de lecture d'un octet sur le port SOURIS. Elle ATTEND qu'un paquet
;   soit disponible.
;
;   Entree: Rien
;   Sortie: W = 1 si octet recu sinon 0
;           VAR Value = octet recu
;-----------------------------------------------------------------------------

MPSGet
		clrf PARITY
		; Test l'horloge, si etat bas, la souris communique
		IF INTERRUPTS
		bcf INTCON,GIE; interdit interruptions
		ENDIF
		IF NON_BLOQUANT
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call Wait_Mclock; utilise Counter, [Counter2, Counter3]
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		movf Counter,W
		btfsc STATUS,Z
			bra EndMPSGet; time-out
		ELSE
		WAIT_MCLOCK_L; attente front descendant de CLK
		ENDIF
MPSGet2
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call _MPSGet2
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
EndMPSGet
		IF INTERRUPTS
		bsf INTCON,GIE; autorise interruptions
		ENDIF
		return
		
;-----------------------------------------------------------------------------
;This routine sends a byte in W to a PS/2 mouse
;-----------------------------------------------------------------------------

MPS2cmd
		IF INTERRUPTS
		bcf INTCON,GIE; interdit interruptions
		ENDIF
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call _MPS2cmd
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		IF INTERRUPTS
		bsf INTCON,GIE; autorise interruptions
		ENDIF
		return

;-----------------------------------------------------------------------------
;Some routine for reduce the code size
;-----------------------------------------------------------------------------

Lecture_EEProm
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		call Lecture_EEProm2
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		return
		
Leds_Eiffel_On
		bcf PORTB,LEDGREEN; allume les deux LEDs
		bcf PORTB,LEDYELLOW
		return

Leds_Eiffel_Off
		bsf PORTB,LEDGREEN; eteint les deux LEDs
		bsf PORTB,LEDYELLOW
		return

;-----------------------------------------------------------------------------

		IF !_18F_

		ORG 0x8C8; zone de 0x800 a 0x8C7 pour le programme de flashage

		ENDIF

;=============================================================================
;                               PROCEDURES ET FONCTIONS
;-----------------------------------------------------------------------------
; Zone en page 1 ou 3 pour des fonctions 
;
; du programme en page 0, appel: 
;		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
;		call fonction
;		bcf PCLATH,3; page 0 ou 2
; ou avec table avec PCL:
;		movlw HIGH fonction
;       movwf PCLATH
;		btfsc Info_Boot,7
;			bsf PCLATH,4; page 2-3 (0x1000 - 0x1FFF)
;		call fonction
;		bcf PCLATH,3; page 0 ou 2
; Si une fonction appelle une autre fonction dans la meme page un call est 
; suffisant sauf si c'est une fonction avec table PCL:
;		movlw HIGH fonction
;		movwf PCLATH
;		btfsc Info_Boot,7
;			bsf PCLATH,4; page 2-3 (0x1000 - 0x1FFF)
;		call fonction
;=============================================================================

;-----------------------------------------------------------------------------
;       Division Counter3:Counter2 / W (TEMP3) 
;		         resultat dans Counter3:Counter2
;                reste dans Value
;-----------------------------------------------------------------------------
	
Div_1608
		movwf TEMP3	
		UDIV1608L Counter3,Counter2,TEMP3,Value
		return	

;-----------------------------------------------------------------------------
;  Lecture des deux joysticks dans JOY0 et JOY1
;-----------------------------------------------------------------------------	

Read_Joysticks
		comf PORTA,W
		movwf JOY0
		rrf JOY0,W
		andlw 0x1F
		movwf JOY0; lecture joystick 0
		comf PORTC,W
		andlw 0x1F
		movwf JOY1; lecture joystick 1
		return

;-----------------------------------------------------------------------------
; Delais 4w+4 cycles (avec call,return, et movlw) (0=256)
;
;   Entree: W = delais en uS
;   Sortie: Rien
;
;-----------------------------------------------------------------------------

Delay_Routine
			addlw -1; Precise delays used in I/O
			btfss STATUS,Z
				bra Delay_Routine
		return
		
;-----------------------------------------------------------------------------

		IF _18F_
		
;-----------------------------------------------------------------------------
;   Implementation d'une table de correspondance pour donner le nombre de
;   jour dans le mois, W contient le mois et retourne le nombre de jours 
;
;   Entree: W = Mois
;   sortie: W = Nombre de jours du mois
;
;   Global: Aucune
;-----------------------------------------------------------------------------

Days_In_Month
		DB  0, 31; janvier
		DB 28, 31; fevrier, mars
		DB 30, 31; avril, mai
		DB 30, 31; juin, juillet
		DB 31, 30; aout, septembre
		DB 31, 30; octobre, novembre
		DB 31, 31; decembre
		DB 31, 31
		
;-----------------------------------------------------------------------------
;   Retoune le Scan-code pour le jeu 2
;
;   Entree: W = Scan-code jeut 2 a convertir si $E0 -> 2eme code
;   sortie: W = Scan-code Atari
;
;   Global: Aucune
;-----------------------------------------------------------------------------

Get_Set2_ScanCode_1
		DB 0x00, 0x43; offset + 0x00  jamais utilise, offset + 0x01 F9
		DB 0x00, 0x3F; offset + 0x02  jamais utilise, offset + 0x03 F5
		DB 0x3D, 0x3B; offset + 0x04 F3, offset + 0x05 F1
		DB 0x3C, DEF_F12; offset + 0x06 F2, offset + 0x07 F12 <= UNDO ATARI (Fr)
		DB 0x00, 0x44; offset + 0x08  jamais utilise, offset + 0x09 F10
		DB 0x42, 0x40; offset + 0x0A F8, offset + 0x0B F6
		DB 0x3E, 0x0F; offset + 0x0C F4, offset + 0x0D TABULATION
		DB DEF_RUSSE, 0x00; offset + 0x0E touche <2> (`) ( a cote de 1 ), offset + 0x0F  jamais utilise
		DB 0x00, DEF_ALTGR; offset + 0x10  jamais utilise, offset + 0x11 LEFT ALT (Atari en n'a qu'un)
		DB 0x2A, 0x00; offset + 0x12 LEFT SHIFT, offset + 0x13  jamais utilise
		DB 0x1D, 0x10; offset + 0x14 LEFT CTRL (Atari en n'a qu'un), offset + 0x15 A (Q)
		DB 0x02, 0x00; offset + 0x16 1, offset + 0x17  jamais utilise
		DB 0x00, 0x00; offset + 0x18  jamais utilise, offset + 0x19  jamais utilise
		DB 0x2C, 0x1F; offset + 0x1A W (Z), offset + 0x1B S
		DB 0x1E, 0x11; offset + 0x1C Q (A), offset + 0x1D Z (W)
		DB 0x03, 0x00; offset + 0x1E 2, offset + 0x1F  jamais utilise
		DB 0x00, 0x2E; offset + 0x20  jamais utilise, offset + 0x21 C
		DB 0x2D, 0x20; offset + 0x22 X, offset + 0x23 D
		DB 0x12, 0x05; offset + 0x24 E, offset + 0x25 4
		DB 0x04, 0x00; offset + 0x26 3, offset + 0x27  jamais utilise
		DB 0x00, 0x39; offset + 0x28  jamais utilise, offset + 0x29 SPACE BAR
		DB 0x2F, 0x21; offset + 0x2A V, offset + 0x2B F
		DB 0x14, 0x13; offset + 0x2C T, offset + 0x2D R
		DB 0x06, 0x00; offset + 0x2E 5, offset + 0x2F  jamais utilise
		DB 0x00, 0x31; offset + 0x30  jamais utilise, offset + 0x31 N		
		DB 0x30, 0x23; offset + 0x32 B, offset + 0x33 H
		DB 0x22, 0x15; offset + 0x34 G, offset + 0x35 Y
		DB 0x07, 0x00; offset + 0x36 6, offset + 0x37  jamais utilise
		DB 0x00, 0x00; offset + 0x38  jamais utilise, offset + 0x39  jamais utilise
		DB 0x32, 0x24; offset + 0x3A <,> (M), offset + 0x3B J
		DB 0x16, 0x08; offset + 0x3C U, offset + 0x3D 7
		DB 0x09, 0x00; offset + 0x3E 8, offset + 0x3F  jamais utilise
		DB 0x00, 0x33; offset + 0x40  jamais utilise, offset + 0x41 <;> (,)
		DB 0x25, 0x17; offset + 0x42 K, offset + 0x43 I
		DB 0x18, 0x0B; offset + 0x44 O, offset + 0x45 0 (chiffre ZERO)
		DB 0x0A, 0x00; offset + 0x46 9, offset + 0x47  jamais utilise
		DB 0x00, 0x34; offset + 0x48  jamais utilise, offset + 0x49 <:> (.)
		DB 0x35, 0x26; offset + 0x4A <!> (/), offset + 0x4B L
		DB 0x27, 0x19; offset + 0x4C M   (;), offset + 0x4D P
		DB 0x0C, 0x00; offset + 0x4E <)> (-), offset + 0x4F  jamais utilise
		DB 0x00, 0x00; offset + 0x50  jamais utilise, offset + 0x51  jamais utilise
		DB 0x28, 0x2B; offset + 0x52 <—> ('), offset + 0x53 <*> (\) touche sur COMPAQ
		DB 0x1A, 0x0D; offset + 0x54 <^> ([), offset + 0x55 <=> (=)
		DB 0x00, 0x00; offset + 0x56  jamais utilise, offset + 0x57  jamais utilise
		DB 0x3A, 0x36; offset + 0x58 CAPS, offset + 0x59 RIGHT SHIFT
		DB 0x1C, 0x1B; offset + 0x5A RETURN, offset + 0x5B <$> (])
		DB 0x00, 0x2B; offset + 0x5C  jamais utilise, offset + 0x5D <*> (\) touche sur SOFT KEY		
		DB 0x00, 0x00; offset + 0x5E  jamais utilise, offset + 0x5F  jamais utilise
		DB 0x00, 0x60; offset + 0x60  jamais utilise, offset + 0x61 ><
		DB 0x00, 0x00; offset + 0x62  jamais utilise, offset + 0x63  jamais utilise
		DB 0x00, 0x00; offset + 0x64  jamais utilise, offset + 0x65  jamais utilise
		DB 0x0E, 0x00; offset + 0x66 BACKSPACE, offset + 0x67  jamais utilise
		DB 0x00, 0x6D; offset + 0x68  jamais utilise, offset + 0x69 KP 1
		DB 0x00, 0x6A; offset + 0x6A  jamais utilise, offset + 0x6B KP 4	
		DB 0x67, 0x00; offset + 0x6C KP 7, offset + 0x6D  jamais utilise
		DB 0x00, 0x00; offset + 0x6E  jamais utilise, offset + 0x6F  jamais utilise
		DB 0x70, 0x71; offset + 0x70 KP 0 (ZERO), offset + 0x71 KP .
		DB 0x6E, 0x6B; offset + 0x72 KP 2, offset + 0x73 KP 5
		DB 0x6C, 0x68; offset + 0x74 KP 6, offset + 0x75 KP 8
		DB 0x01, DEF_VERRNUM; offset + 0x76 ESC, offset + 0x77 VERR NUM (unused on Atari before)
		DB 0x62, 0x4E; offset + 0x78 F11 <= HELP ATARI (Fr), offset + 0x79 KP +
		DB 0x6F, 0x4A; offset + 0x7A KP 3, offset + 0x7B KP - 
		DB 0x66, 0x69; offset + 0x7C KP *, offset + 0x7D KP 9
		DB DEF_SCROLL, 0x00; offset + 0x7E SCROLL, offset + 0x7F  jamais utilise
		DB 0x00, 0x00; offset + 0x80  jamais utilise, offset + 0x81  jamais utilise
		DB 0x00, 0x41; offset + 0x82  jamais utilise, offset + 0x83 F7
		DB DEF_PRINTSCREEN, 0x00; offset + 0x84 PRINT SCREEN + ALT, offset + 0x85  jamais utilise
		DB 0x00, 0x00; offset + 0x86  jamais utilise, offset + 0x87  jamais utilise
		DB 0x00, 0x00; offset + 0x88  jamais utilise, offset + 0x89  jamais utilise
		DB 0x00, 0x00; offset + 0x8A  jamais utilise, offset + 0x8B  jamais utilise
		DB 0x00, 0x00; offset + 0x8C  jamais utilise, offset + 0x8D  jamais utilise
		DB 0x00, 0x00; offset + 0x8E  jamais utilise, offset + 0x8F  jamais utilise	
		
		ELSE
		
		ORG 0x900

;-----------------------------------------------------------------------------
;   Implementation d'une table de correspondance pour donner le nombre de
;   jour dans le mois, W contient le mois et retourne le nombre de jours 
;
;   Entree: W = Mois
;   sortie: W = Nombre de jours du mois
;
;   Global: Aucune
;-----------------------------------------------------------------------------

Days_In_Month
		addwf PCL,F
		nop
		retlw 31; janvier
		retlw 28; fevrier
		retlw 31; mars
		retlw 30; avril
		retlw 31; mai
		retlw 30; juin
		retlw 31; juillet
		retlw 31; aout
		retlw 30; septembre
		retlw 31; octobre
		retlw 30; novembre
		retlw 31; decembre
		retlw 31
		retlw 31
		retlw 31
		
;-----------------------------------------------------------------------------
;   Retoune le Scan-code pour le jeu 2
;
;   Entree: W = Scan-code jeut 2 a convertir si $E0 -> 2eme code
;   sortie: W = Scan-code Atari
;
;   Global: Aucune
;-----------------------------------------------------------------------------

Get_Set2_ScanCode_1
		addwf PCL,F
		retlw 0x00; offset + 0x00  jamais utilise: "Error or Buffer Overflow"
		retlw 0x43; offset + 0x01 F9
		retlw 0x00; offset + 0x02  jamais utilise
		retlw 0x3F; offset + 0x03 F5
		retlw 0x3D; offset + 0x04 F3
		retlw 0x3B; offset + 0x05 F1
		retlw 0x3C; offset + 0x06 F2
		retlw DEF_F12; offset + 0x07 F12          <= UNDO ATARI (Fr)
		retlw 0x00; offset + 0x08  jamais utilise
		retlw 0x44; offset + 0x09 F10
		retlw 0x42; offset + 0x0A F8
		retlw 0x40; offset + 0x0B F6
		retlw 0x3E; offset + 0x0C F4
		retlw 0x0F; offset + 0x0D TABULATION
		retlw DEF_RUSSE; offset + 0x0E touche <2> (`) ( a cote de 1 )
		retlw 0x00; offset + 0x0F  jamais utilise
		retlw 0x00; offset + 0x10  jamais utilise
		retlw DEF_ALTGR; offset + 0x11 LEFT ALT (Atari en n'a qu'un)
		retlw 0x2A; offset + 0x12 LEFT SHIFT
		retlw 0x00; offset + 0x13  jamais utilise
		retlw 0x1D; offset + 0x14 LEFT CTRL (Atari en n'a qu'un)
		retlw 0x10; offset + 0x15 A (Q)
		retlw 0x02; offset + 0x16 1
		retlw 0x00; offset + 0x17  jamais utilise
		retlw 0x00; offset + 0x18  jamais utilise
		retlw 0x00; offset + 0x19  jamais utilise
		retlw 0x2C; offset + 0x1A W (Z)
		retlw 0x1F; offset + 0x1B S
		retlw 0x1E; offset + 0x1C Q (A) 
		retlw 0x11; offset + 0x1D Z (W)
		retlw 0x03; offset + 0x1E 2
		retlw 0x00; offset + 0x1F  jamais utilise
		retlw 0x00; offset + 0x20  jamais utilise
		retlw 0x2E; offset + 0x21 C
		retlw 0x2D; offset + 0x22 X
		retlw 0x20; offset + 0x23 D
		retlw 0x12; offset + 0x24 E
		retlw 0x05; offset + 0x25 4
		retlw 0x04; offset + 0x26 3
		retlw 0x00; offset + 0x27  jamais utilise
		retlw 0x00; offset + 0x28  jamais utilise
		retlw 0x39; offset + 0x29 SPACE BAR
		retlw 0x2F; offset + 0x2A V
		retlw 0x21; offset + 0x2B F
		retlw 0x14; offset + 0x2C T
		retlw 0x13; offset + 0x2D R
		retlw 0x06; offset + 0x2E 5
		retlw 0x00; offset + 0x2F  jamais utilise
		retlw 0x00; offset + 0x30  jamais utilise
		retlw 0x31; offset + 0x31 N		
		retlw 0x30; offset + 0x32 B
		retlw 0x23; offset + 0x33 H
		retlw 0x22; offset + 0x34 G
		retlw 0x15; offset + 0x35 Y
		retlw 0x07; offset + 0x36 6
		retlw 0x00; offset + 0x37  jamais utilise
		retlw 0x00; offset + 0x38  jamais utilise
		retlw 0x00; offset + 0x39  jamais utilise
		retlw 0x32; offset + 0x3A <,> (M)
		retlw 0x24; offset + 0x3B J
		retlw 0x16; offset + 0x3C U
		retlw 0x08; offset + 0x3D 7
		retlw 0x09; offset + 0x3E 8
		retlw 0x00; offset + 0x3F  jamais utilise
		retlw 0x00; offset + 0x40  jamais utilise
		retlw 0x33; offset + 0x41 <;> (,)
		retlw 0x25; offset + 0x42 K
		retlw 0x17; offset + 0x43 I
		retlw 0x18; offset + 0x44 O
		retlw 0x0B; offset + 0x45 0 (chiffre ZERO)
		retlw 0x0A; offset + 0x46 9
		retlw 0x00; offset + 0x47  jamais utilise
		retlw 0x00; offset + 0x48  jamais utilise
		retlw 0x34; offset + 0x49 <:> (.)
		retlw 0x35; offset + 0x4A <!> (/)
		retlw 0x26; offset + 0x4B L
		retlw 0x27; offset + 0x4C M   (;)
		retlw 0x19; offset + 0x4D P
		retlw 0x0C; offset + 0x4E <)> (-)
		retlw 0x00; offset + 0x4F  jamais utilise
		retlw 0x00; offset + 0x50  jamais utilise
		retlw 0x00; offset + 0x51  jamais utilise
		retlw 0x28; offset + 0x52 <—> (')
		retlw 0x2B; offset + 0x53 <*> (\) touche sur COMPAQ
		retlw 0x1A; offset + 0x54 <^> ([)
		retlw 0x0D; offset + 0x55 <=> (=)
		retlw 0x00; offset + 0x56  jamais utilise
		retlw 0x00; offset + 0x57  jamais utilise
		retlw 0x3A; offset + 0x58 CAPS
		retlw 0x36; offset + 0x59 RIGHT SHIFT
		retlw 0x1C; offset + 0x5A RETURN
		retlw 0x1B; offset + 0x5B <$> (])
		retlw 0x00; offset + 0x5C  jamais utilise
		retlw 0x2B; offset + 0x5D <*> (\) touche sur SOFT KEY		
		retlw 0x00; offset + 0x5E  jamais utilise
		retlw 0x00; offset + 0x5F  jamais utilise
		retlw 0x00; offset + 0x60  jamais utilise
		retlw 0x60; offset + 0x61 ><
		retlw 0x00; offset + 0x62  jamais utilise
		retlw 0x00; offset + 0x63  jamais utilise
		retlw 0x00; offset + 0x64  jamais utilise
		retlw 0x00; offset + 0x65  jamais utilise
		retlw 0x0E; offset + 0x66 BACKSPACE
		retlw 0x00; offset + 0x67  jamais utilise
		retlw 0x00; offset + 0x68  jamais utilise
		retlw 0x6D; offset + 0x69 KP 1
		retlw 0x00; offset + 0x6A  jamais utilise
		retlw 0x6A; offset + 0x6B KP 4	
		retlw 0x67; offset + 0x6C KP 7
		retlw 0x00; offset + 0x6D  jamais utilise
		retlw 0x00; offset + 0x6E  jamais utilise
		retlw 0x00; offset + 0x6F  jamais utilise
		retlw 0x70; offset + 0x70 KP 0 (ZERO)
		retlw 0x71; offset + 0x71 KP .
		retlw 0x6E; offset + 0x72 KP 2
		retlw 0x6B; offset + 0x73 KP 5
		retlw 0x6C; offset + 0x74 KP 6
		retlw 0x68; offset + 0x75 KP 8
		retlw 0x01; offset + 0x76 ESC
		retlw DEF_VERRNUM; offset + 0x77 VERR NUM     (unused on Atari before)		
		retlw 0x62; offset + 0x78 F11          <= HELP ATARI (Fr)
		retlw 0x4E; offset + 0x79 KP +
		retlw 0x6F; offset + 0x7A KP 3
		retlw 0x4A; offset + 0x7B KP - 
		retlw 0x66; offset + 0x7C KP *
		retlw 0x69; offset + 0x7D KP 9
		retlw DEF_SCROLL; offset + 0x7E SCROLL
		retlw 0x00; offset + 0x7F  jamais utilise
		retlw 0x00; offset + 0x80  jamais utilise
		retlw 0x00; offset + 0x81  jamais utilise
		retlw 0x00; offset + 0x82  jamais utilise
		retlw 0x41; offset + 0x83 F7
		retlw DEF_PRINTSCREEN; offset + 0x84 PRINT SCREEN + ALT
		retlw 0x00; offset + 0x85  jamais utilise
		retlw 0x00; offset + 0x86  jamais utilise
		retlw 0x00; offset + 0x87  jamais utilise
		retlw 0x00; offset + 0x88  jamais utilise
		retlw 0x00; offset + 0x89  jamais utilise
		retlw 0x00; offset + 0x8A  jamais utilise
		retlw 0x00; offset + 0x8B  jamais utilise
		retlw 0x00; offset + 0x8C  jamais utilise
		retlw 0x00; offset + 0x8D  jamais utilise
		retlw 0x00; offset + 0x8E  jamais utilise
		retlw 0x00; offset + 0x8F  jamais utilise
		
		ENDIF
		
;-----------------------------------------------------------------------------
; Initialisation registres et variables
;-----------------------------------------------------------------------------

Init
		IF _18F_
		movlb 0
		clrf PORTA
		clrf PORTB
		clrf PORTC
		clrf LATA
		clrf LATB
		clrf LATC
		ELSE
		bsf STATUS,RP0; page 1
		bcf STATUS,RP1
		ENDIF
		movlw 0x0E
		movwf ADCON1; entrees digitales sauf AN0
		IF _18F_
		setf TRISA; 6 entrees
		ELSE
		movlw 0xFF
		movwf TRISA; 6 entrees
		ENDIF
		IF _18F_ && _CAN_
		movlw 0x5F; RC7 / MCLOCK en sortie, RC5 / MOTORON en sortie
		ELSE
		movlw 0xDF; RC5 / MOTORON en sortie
		ENDIF
		movwf TRISC
		movlw KM_DISABLE; LEDYELLOW,LEDGREEN,MCLOCK,KCLOCK en sortie
		movwf TRISB
		IF _18F_
		IF _CAN_
		movlw 0x04
		movwf PORTB; RB2/CANTX a 1
		ENDIF
		movlw 125; timer 2 a 5 mS (4 MHz /16 /125 /10 )
		ELSE ; 16F876
		IF _8MHZ_
		movlw 250; timer 2 a 5 mS (2 MHz /4 /250 /10 )
		ELSE
		movlw 125; timer 2 a 5 mS (1 MHz /4 /125 /10 )
		ENDIF
		ENDIF
		movwf PR2
		IF !_18F_
		bcf STATUS,RP0; page 0
		ENDIF
		movlw 0xC5; RC osc, GO, ADON, lance la conversion A/D sur AN0
		movwf ADCON0
		clrf PORTA
		; set latchs B to 0 and set On LEDs
		clrf PORTB; allow to disable devices communications
		IF _18F_
		movlw 0x4A; timer 2 prediviseur par 16 et diviseur par 10		
		ELSE
		movlw 0x49; timer 2 prediviseur par 4 et diviseur par 10
		ENDIF
		movwf T2CON
		clrf TMR2
		bsf T2CON,TMR2ON; lance le timer 2
		IF _18F_ && _CAN_
		IF INTERRUPTS
		bcf INTCON2,INTEDG0; front descendant RB0/INT
		bsf INTCON,INT0IE; RB0/INT Interrupt Enable
		bsf PIE1,TMR2IE; Timer 2 Interrupt Enable
		ENDIF ; INTERRUPTS
		rcall Init_CAN
		ELSE ; _18F_ && _CAN_
		; setup RS-232 port at 9600 or 7812.
		IF SERIAL_DEBUG
		movlw BAUD_9600; set baud rate 9600 for 4/8Mhz clock (fosc/16*(X+1))
		btfsc PORTB,JUMPER5; if Jumper5 enable (0V) skip
		ENDIF ; SERIAL_DEBUG
		movlw BAUD_7812_5; else set baud rate 7812.5 for 4/8Mhz clock
		IF !_18F_
		bsf STATUS,RP0; page 1
		ENDIF ; _18F_
		movwf SPBRG
		IF INTERRUPTS
		IF _18F_
		bcf INTCON2,RBPU; pull-up port B
		bcf INTCON2,INTEDG0; front descendant RB0/INT
		bsf INTCON,INT0IE; RB0/INT Interrupt Enable
		ELSE
		bcf OPTION_REG,INTEDG; front descendant RB0/INT
		bsf INTCON,INTE; RB0/INT Interrupt Enable
		ENDIF ; _18F_
		bsf PIE1,TMR2IE; Timer 2 Interrupt Enable
		ENDIF ; INTERRUPTS
		bsf TXSTA,BRGH; baud rate high speed option, Asynchronous High Speed
		bsf TXSTA,TXEN; enable transmission
		IF !_18F_
		bcf STATUS,RP0; page 0
		ENDIF ; _18F_
		bsf RCSTA,CREN; enable reception
		bsf RCSTA,SPEN; enable serial port (RC6/7)
		ENDIF ; _18F_ && _CAN_
		clrf Flags
		clrf Flags2
		clrf Flags3
		clrf Flags4
		clrf Flags5
		rcall Read_Joysticks
		clrf Val_AN0; lecture CTN sur AN0
		clrf Temperature; lecture temperature CTN sur AN0
		clrf X_MAX_POSH; position X absolue maximale souris poids fort
		clrf X_MAX_POSL; position X absolue maximale souris poids faible
		clrf Y_MAX_POSH; position Y absolue maximale souris poids fort
		clrf Y_MAX_POSL; position Y absolue maximale souris poids faible
		movlw 1
		movwf X_SCALE; facteur d'echelle en X souris mode absolu
		movwf Y_SCALE; facteur d'echelle en Y souris mode absolu
		clrf DELTA_X; deltax mode keycode souris IKBD
		clrf DELTA_Y; deltay mode keycode souris IKBD
		clrf BUTTONS; etat des boutons souris
		clrf OLD_BUTTONS; ancien etat des boutons souris
		clrf OLD_BUTTONS_ABS; ancien etat des boutons souris mode absolu
		clrf BUTTON_ACTION; mode button action IKBD
		movlw 10
		movwf Counter_10MS_Joy; prediviseur envoi mode keycode joystick 0 (pas de 100 mS)
		clrf Counter_100MS_Joy; compteur 100 mS mode keycode joystick 0
		clrf MState_Mouse; machine d'etat reception trame souris PS/2
		clrf MState_Temperature; machine d'etat lecture temperature (reduction charge CPU)
		clrf OldScanCode; memorisation pour supprimer repetition du jeu 2
		clrf DEB_INDEX_EM; index courant donnee a envoyer buffer circulaire liaison serie
		clrf FIN_INDEX_EM; fin index donnee a envoyer buffer circulaire liaison serie
		IF SERIAL_DEBUG
		btfss PORTB,JUMPER5; if jumper5 disable (5V) no message
			call SerialWelcome; else send this string
		ENDIF
		; Le clavier et la souris PS/2 ont ete inhibes pendant le flashage
		; le reset a chaud envoi donc un reset clavier et a la souris.
		; En cas de demarrage a froid (mise sous tension), les commandes BAT
		; arrivent naturellement du clavier et de la souris PS/2.
		btfsc Status_Boot,POWERUP_LCD
			bra Clock_Ok
		IF !_18F_		
		bsf STATUS,RP1; page 2
		ENDIF
		clrf SEC; RAZ horloge a la mise sous tension
		clrf SEC_BCD
		clrf MIN
		clrf MIN_BCD
		clrf HRS
		clrf HRS_BCD
		movlw 1
		movwf DAY
		movwf DAY_BCD
		movwf MONTH
		movwf MONTH_BCD		
		clrf YEAR
		clrf YEAR_BCD
		IF !_18F_
		bcf STATUS,RP1; page 0
		ENDIF
		IF LCD
		call Init_Lcd
		ENDIF
		bsf Status_Boot,POWERUP_LCD
Clock_Ok
		IF LCD && (LCD_DEBUG || LCD_DEBUG_ATARI)
		clrf Counter_Debug_Lcd
		ENDIF
		btfsc Status_Boot,POWERUP_KEYB; mis a 1 des reception BAT clavier
			bsf Flags2,RESET_KEYB; valide reset clavier dans traitement timer
		btfsc Status_Boot,POWERUP_MOUSE; mis a 1 des reception BAT souris
			bsf Flags2,RESET_MOUSE; valide reset souris dans traitement timer
		bcf PIR1,TMR2IF; acquitte timer 2
		IF INTERRUPTS
		clrf CounterValueK
		bsf INTCON,PEIE; Peripheral Interrupt Enable
		bsf INTCON,GIE; Global Interrupt Enable, autorise interruptions
		ENDIF ; INTERRUPTS
		return
		
;-----------------------------------------------------------------------------
; CAN Initialisation
;-----------------------------------------------------------------------------

		IF _18F_ && _CAN_
Init_CAN
		bsf CANCON,REQOP2; mode configuration
wait_conf_mode
		btfss CANSTAT,OPMODE2
			bra wait_conf_mode
		movlw BAUD250K_1
		movwf BRGCON1
		movlw BAUD250K_2+0x80; + SEG2PHTS
		movwf BRGCON2
		movlw BAUD250K_3+0x40; + WAKFIL
		movwf BRGCON3
		movlw 0x20
		movwf RXB0CON; receive standard ID
		movwf RXB1CON; receive standard ID
		lfsr FSR0,RXM0SIDH
		setf POSTINC0; masques standard
		movlw 0xE0
		movwf POSTINC0; RXM0SIDL 
		lfsr FSR0,RXF0SIDH
		lfsr FSR1,RXF1SIDH
		movlw ID_CAN_RX_H
		movwf POSTINC0; filtres standard
		movwf POSTINC1
		movlw ID_CAN_RX_L
		movwf POSTINC0; RXF0SIDL
		movwf POSTINC1; RXF1SIDL
		clrf CANCON; fin configuration, WIN sur Receive Buffer 0
wait_normal_mode
		movf CANSTAT,W
		andlw 0xE0
		btfss STATUS,Z
			bra wait_normal_mode
		clrf DLC_CAN
		return
		ENDIF

;-----------------------------------------------------------------------------

		IF _18F_

;-----------------------------------------------------------------------------
;   Retoune le Scan-code pour le jeu 2
;
;   Entree: W = Scan-code jeu 2 a convertir si 0xE0 -> 2eme code
;   sortie: W = Scan-code Atari
;
;   Global: Aucune
;-----------------------------------------------------------------------------
		
Get_Set2_ScanCode_2
		DB 0x00, 0x00; offset + 0x00, 0x01  jamais utilise
		DB 0x00, 0x00; offset + 0x02, 0x03  jamais utilise
		DB 0x00, 0x00; offset + 0x04, 0x05  jamais utilise
		DB 0x00, 0x00; offset + 0x06, 0x07  jamais utilise
		DB 0x00, 0x00; offset + 0x08, 0x09  jamais utilise
		DB 0x00, 0x00; offset + 0x0A, 0x0B  jamais utilise
		DB 0x00, 0x00; offset + 0x0C, 0x0D  jamais utilise
		DB 0x00, 0x00; offset + 0x0E, 0x0F  jamais utilise
		DB DEF_WWW_SEARCH, DEF_ALTGR; offset + 0x10 WWW SEARCH, offset + 0x11 RIGHT ALT GR (Atari en n'a qu'un)
		DB 0x00, 0x00; offset + 0x12, 0x13  jamais utilise
		DB 0x1D, DEF_PREVIOUS_TRACK; offset + 0x14 RIGHT CTRL (Atari en n'a qu'un), offset + 0x15 PREVIOUS TRACK
		DB 0x00, 0x00; offset + 0x16, 0x17  jamais utilise
		DB DEF_WWW_FAVORITES, 0x00; offset + 0x18 WWW FAVORITES, offset + 0x19  jamais utilise
		DB 0x00, 0x00; offset + 0x1A, 0x1B  jamais utilise
		DB 0x00, 0x00; offset + 0x1C, 0x1D  jamais utilise
		DB 0x00, DEF_WINLEFT; offset + 0x1E  jamais utilise, offset + 0x1F LEFT WIN
		DB DEF_WWW_REFRESH, DEF_VOLUME_DOWN; offset + 0x20 WWW REFRESH, offset + 0x21 VOLUME DOWN
		DB 0x00, DEF_MUTE; offset + 0x22  jamais utilise, offset + 0x23 MUTE
		DB 0x00, 0x00; offset + 0x24, 0x25  jamais utilise
		DB 0x00, DEF_WINRIGHT; offset + 0x26  jamais utilise, offset + 0x27 RIGHT WIN
		DB DEF_WWW_STOP, 0x00; offset + 0x28 WWW STOP, offset + 0x29  jamais utilise
		DB 0x00, DEF_CACULATOR; offset + 0x2A  jamais utilise, offset + 0x2B CALCULATOR
		DB 0x00, 0x00; offset + 0x2C,  0x2D  jamais utilise
		DB 0x00, DEF_WINAPP; offset + 0x2E  jamais utilise, offset + 0x2F POPUP WIN
		DB DEF_WWW_FORWARD, 0x00; offset + 0x30 WWW FORWARD, offset + 0x31  jamais utilise
		DB DEF_VOLUME_UP, 0x00; offset + 0x32 VOLUME UP, offset + 0x33  jamais utilise
		DB DEF_PLAY_PAUSE, 0x00; offset + 0x34 PLAY/PAUSE, offset + 0x35  jamais utilise
		DB 0x00, DEF_POWER; offset + 0x36  jamais utilise, offset + 0x37 POWER
		DB DEF_WWW_BACK, 0x00; offset + 0x38 WWW BACK, offset + 0x39  jamais utilise
		DB DEF_WWW_HOME, DEF_STOP; offset + 0x3A WWW HOME, offset + 0x3B STOP
		DB 0x00, 0x00; offset + 0x3C, 0x3D  jamais utilise
		DB 0x00, DEF_SLEEP; offset + 0x3E  jamais utilise, offset + 0x3F SLEEP
		DB DEF_MY_COMPUTER, 0x00; offset + 0x40 MY COMPUTER, offset + 0x41  jamais utilise
		DB 0x00, 0x00; offset + 0x42, 0x43  jamais utilise
		DB 0x00, 0x00; offset + 0x44, 0x45  jamais utilise
		DB 0x00, 0x00; offset + 0x46, 0x47  jamais utilise
		DB DEF_EMAIL, 0x00; offset + 0x48 E-MAIL, offset + 0x49  jamais utilise
		DB 0x65, 0x00; offset + 0x4A KP /, offset + 0x4B  jamais utilise
		DB 0x00, DEF_NEXT_TRACK; offset + 0x4C  jamais utilise, offset + 0x4D NEXT TRACK
		DB 0x00, 0x00; offset + 0x4E, 0x04F  jamais utilise
		DB DEF_MEDIA_SELECT, 0x00; offset + 0x50 MEDIA SELECT, offset + 0x51  jamais utilise
		DB 0x00, 0x00; offset + 0x52, 0x53  jamais utilise
		DB 0x00, 0x00; offset + 0x54, 0x55  jamais utilise
		DB 0x00, 0x00; offset + 0x56, 0x57  jamais utilise
		DB 0x00, 0x00; offset + 0x58, 0x59  jamais utilise
		DB 0x72, 0x00; offset + 0x5A KP ENTER, offset + 0x5B  jamais utilise
		DB 0x00, 0x00; offset + 0x5C, 0x5D  jamais utilise
		DB DEF_WAKE, 0x00; offset + 0x5E WAKE, offset + 0x5F  jamais utilise
		DB 0x00, 0x00; offset + 0x60, 0x61  jamais utilise
		DB 0x00, 0x00; offset + 0x62, 0x63  jamais utilise
		DB 0x00, 0x00; offset + 0x64, 0x65  jamais utilise
		DB 0x00, 0x00; offset + 0x66, 0x67  jamais utilise
		DB 0x00, 0x55; offset + 0x68  jamais utilise, offset + 0x69 END
		DB 0x00, 0x4B; offset + 0x6A  jamais utilise, offset + 0x6B LEFT ARROW
		DB 0x47, 0x00; offset + 0x6C CLEAR HOME, offset + 0x6D  jamais utilise
		DB 0x00, 0x00; offset + 0x6E, 0x6F  jamais utilise
		DB 0x52, 0x53; offset + 0x70 INSERT, offset + 0x71 DELETE
		DB 0x50, 0x00; offset + 0x72 DOWN ARROW, offset + 0x73  jamais utilise
		DB 0x4D, 0x48; offset + 0x74 RIGHT ARROW, offset + 0x75 UP ARROW
		DB 0x00, 0x00; offset + 0x76, 0x77  jamais utilise
		DB 0x00, 0x00; offset + 0x78, 0x79  jamais utilise
		DB DEF_PAGEDN, 0x00; offset + 0x7A PAGE DOWN  (unused on Atari before), offset + 0x7B  jamais utilise
		DB DEF_PRINTSCREEN, DEF_PAGEUP; offset + 0x7C PRINT SCREEN, offset + 0x7D PAGE UP      (unused on Atari before)
		DB DEF_PAUSE, 0x00; offset + 0x7E PAUSE + CTRL, offset + 0x7F  jamais utilise
		DB 0x00, 0x00; offset + 0x80, 0x81  jamais utilise
		DB 0x00, 0x00; offset + 0x82, 0x83  jamais utilise
		DB 0x00, 0x00; offset + 0x84, 0x85  jamais utilise
		DB 0x00, 0x00; offset + 0x86, 0x87  jamais utilise
		DB 0x00, 0x00; offset + 0x88, 0x89  jamais utilise
		DB 0x00, 0x00; offset + 0x8A, 0x8B  jamais utilise
		DB 0x00, 0x00; offset + 0x8C, 0x8D  jamais utilise
		DB 0x00, 0x00; offset + 0x8E, 0x8F  jamais utilise
		
		ELSE

		ORG 0xA00
		
;------------------------------------------------------------------------
;   Retoune le Scan-code pour le jeu 2
;
;   Entree: W = Scan-code jeu 2 a convertir si 0xE0 -> 2eme code
;   sortie: W = Scan-code Atari
;
;   Global: Aucune
;------------------------------------------------------------------------
		
Get_Set2_ScanCode_2
		addwf PCL,F
		retlw 0x00; offset + 0x00  jamais utilise
		retlw 0x00; offset + 0x01  jamais utilise
		retlw 0x00; offset + 0x02  jamais utilise
		retlw 0x00; offset + 0x03  jamais utilise
		retlw 0x00; offset + 0x04  jamais utilise
		retlw 0x00; offset + 0x05  jamais utilise
		retlw 0x00; offset + 0x06  jamais utilise
		retlw 0x00; offset + 0x07  jamais utilise
		retlw 0x00; offset + 0x08  jamais utilise
		retlw 0x00; offset + 0x09  jamais utilise
		retlw 0x00; offset + 0x0A  jamais utilise
		retlw 0x00; offset + 0x0B  jamais utilise
		retlw 0x00; offset + 0x0C  jamais utilise
		retlw 0x00; offset + 0x0D  jamais utilise
		retlw 0x00; offset + 0x0E  jamais utilise
		retlw 0x00; offset + 0x0F  jamais utilise
		retlw DEF_WWW_SEARCH; offset + 0x10 WWW SEARCH
		retlw DEF_ALTGR; offset + 0x11 RIGHT ALT GR (Atari en n'a qu'un)
		retlw 0x00; offset + 0x12  jamais utilise
		retlw 0x00; offset + 0x13  jamais utilise
		retlw 0x1D; offset 000000000000+ 0x14 RIGHT CTRL   (Atari en n'a qu'un)
		retlw DEF_PREVIOUS_TRACK; offset + 0x15 PREVIOUS TRACK
		retlw 0x00; offset + 0x16  jamais utilise
		retlw 0x00; offset + 0x17  jamais utilise
		retlw DEF_WWW_FAVORITES; offset + 0x18 WWW FAVORITES
		retlw 0x00; offset + 0x19  jamais utilise
		retlw 0x00; offset + 0x1A  jamais utilise
		retlw 0x00; offset + 0x1B  jamais utilise
		retlw 0x00; offset + 0x1C  jamais utilise
		retlw 0x00; offset + 0x1D  jamais utilise
		retlw 0x00; offset + 0x1E  jamais utilise
		retlw DEF_WINLEFT;  offset + 0x1F LEFT WIN
		retlw DEF_WWW_REFRESH; offset + 0x20 WWW REFRESH
		retlw DEF_VOLUME_DOWN; offset + 0x21 VOLUME DOWN
		retlw 0x00; offset + 0x22  jamais utilise
		retlw DEF_MUTE; offset + 0x23 MUTE
		retlw 0x00; offset + 0x24  jamais utilise
		retlw 0x00; offset + 0x25  jamais utilise
		retlw 0x00; offset + 0x26  jamais utilise
		retlw DEF_WINRIGHT; offset + 0x27 RIGHT WIN
		retlw DEF_WWW_STOP; offset + 0x28 WWW STOP
		retlw 0x00; offset + 0x29  jamais utilise
		retlw 0x00; offset + 0x2A  jamais utilise
		retlw DEF_CACULATOR; offset + 0x2B CALCULATOR
		retlw 0x00; offset + 0x2C  jamais utilise
		retlw 0x00; offset + 0x2D  jamais utilise
		retlw 0x00; offset + 0x2E  jamais utilise
		retlw DEF_WINAPP;   offset + 0x2F POPUP WIN
		retlw DEF_WWW_FORWARD; offset + 0x30 WWW FORWARD
		retlw 0x00; offset + 0x31  jamais utilise
		retlw DEF_VOLUME_UP; offset + 0x32 VOLUME UP
		retlw 0x00; offset + 0x33  jamais utilise
		retlw DEF_PLAY_PAUSE; offset + 0x34 PLAY/PAUSE
		retlw 0x00; offset + 0x35  jamais utilise
		retlw 0x00; offset + 0x36  jamais utilise
		retlw DEF_POWER; offset + 0x37 POWER
		retlw DEF_WWW_BACK; offset + 0x38 WWW BACK
		retlw 0x00; offset + 0x39  jamais utilise
		retlw DEF_WWW_HOME; offset + 0x3A WWW HOME
		retlw DEF_STOP; offset + 0x3B STOP
		retlw 0x00; offset + 0x3C  jamais utilise
		retlw 0x00; offset + 0x3D  jamais utilise
		retlw 0x00; offset + 0x3E  jamais utilise
		retlw DEF_SLEEP; offset + 0x3F SLEEP
		retlw DEF_MY_COMPUTER; offset + 0x40 MY COMPUTER
		retlw 0x00; offset + 0x41  jamais utilise
		retlw 0x00; offset + 0x42  jamais utilise
		retlw 0x00; offset + 0x43  jamais utilise
		retlw 0x00; offset + 0x44  jamais utilise
		retlw 0x00; offset + 0x45  jamais utilise
		retlw 0x00; offset + 0x46  jamais utilise
		retlw 0x00; offset + 0x47  jamais utilise
		retlw DEF_EMAIL; offset + 0x48 E-MAIL
		retlw 0x00; offset + 0x49  jamais utilise
		retlw 0x65; offset + 0x4A KP /
		retlw 0x00; offset + 0x4B  jamais utilise
		retlw 0x00; offset + 0x4C  jamais utilise
		retlw DEF_NEXT_TRACK; offset + 0x4D NEXT TRACK
		retlw 0x00; offset + 0x4E  jamais utilise
		retlw 0x00; offset + 0x4F  jamais utilise
		retlw DEF_MEDIA_SELECT; offset + 0x50 MEDIA SELECT
		retlw 0x00; offset + 0x51  jamais utilise
		retlw 0x00; offset + 0x52  jamais utilise
		retlw 0x00; offset + 0x53  jamais utilise
		retlw 0x00; offset + 0x54  jamais utilise
		retlw 0x00; offset + 0x55  jamais utilise
		retlw 0x00; offset + 0x56  jamais utilise
		retlw 0x00; offset + 0x57  jamais utilise
		retlw 0x00; offset + 0x58  jamais utilise
		retlw 0x00; offset + 0x59  jamais utilise				
		retlw 0x72; offset + 0x5A KP ENTER
		retlw 0x00; offset + 0x5B  jamais utilise
		retlw 0x00; offset + 0x5C  jamais utilise
		retlw 0x00; offset + 0x5D  jamais utilise
		retlw DEF_WAKE; offset + 0x5E WAKE
		retlw 0x00; offset + 0x5F  jamais utilise
		retlw 0x00; offset + 0x60  jamais utilise
		retlw 0x00; offset + 0x61  jamais utilise
		retlw 0x00; offset + 0x62  jamais utilise
		retlw 0x00; offset + 0x63  jamais utilise
		retlw 0x00; offset + 0x64  jamais utilise
		retlw 0x00; offset + 0x65  jamais utilise
		retlw 0x00; offset + 0x66  jamais utilise
		retlw 0x00; offset + 0x67  jamais utilise
		retlw 0x00; offset + 0x68  jamais utilise		
		retlw 0x55; offset + 0x69 END
		retlw 0x00; offset + 0x6A  jamais utilise
		retlw 0x4B; offset + 0x6B LEFT ARROW
		retlw 0x47; offset + 0x6C CLEAR HOME
		retlw 0x00; offset + 0x6D  jamais utilise
		retlw 0x00; offset + 0x6E  jamais utilise
		retlw 0x00; offset + 0x6F  jamais utilise		
		retlw 0x52; offset + 0x70 INSERT
		retlw 0x53; offset + 0x71 DELETE
		retlw 0x50; offset + 0x72 DOWN ARROW
		retlw 0x00; offset + 0x73  jamais utilise
		retlw 0x4D; offset + 0x74 RIGHT ARROW
		retlw 0x48; offset + 0x75 UP ARROW
		retlw 0x00; offset + 0x76  jamais utilise
		retlw 0x00; offset + 0x77  jamais utilise
		retlw 0x00; offset + 0x78  jamais utilise
		retlw 0x00; offset + 0x79  jamais utilise
		retlw DEF_PAGEDN; offset + 0x7A PAGE DOWN    (unused on Atari before)
		retlw 0x00; offset + 0x7B  jamais utilise
		retlw DEF_PRINTSCREEN; offset + 0x7C PRINT SCREEN
		retlw DEF_PAGEUP; offset + 0x7D PAGE UP      (unused on Atari before)
		retlw DEF_PAUSE; offset + 0x7E PAUSE + CTRL
		retlw 0x00; offset + 0x7F  jamais utilise
		retlw 0x00; offset + 0x80  jamais utilise
		retlw 0x00; offset + 0x81  jamais utilise
		retlw 0x00; offset + 0x82  jamais utilise
		retlw 0x00; offset + 0x83  jamais utilise
		retlw 0x00; offset + 0x84  jamais utilise
		retlw 0x00; offset + 0x85  jamais utilise
		retlw 0x00; offset + 0x86  jamais utilise
		retlw 0x00; offset + 0x87  jamais utilise
		retlw 0x00; offset + 0x88  jamais utilise
		retlw 0x00; offset + 0x89  jamais utilise
		retlw 0x00; offset + 0x8A  jamais utilise
		retlw 0x00; offset + 0x8B  jamais utilise
		retlw 0x00; offset + 0x8C  jamais utilise
		retlw 0x00; offset + 0x8D  jamais utilise
		retlw 0x00; offset + 0x8E  jamais utilise
		retlw 0x00; offset + 0x8F  jamais utilise
		
		ENDIF

;-----------------------------------------------------------------------------
;               Lecture temperature CTN sur AN0
;-----------------------------------------------------------------------------

Read_Temperature
		movf MState_Temperature,W; machine d'etat lecture temperature (reduction charge CPU)
		movwf TEMP1
		IF _18F_
		rlcf TEMP1,F
		ENDIF
		movlw LOW Table_Temperature
		addwf TEMP1,F
		movlw HIGH Table_Temperature
		btfsc STATUS,C
			addlw 1
		movwf PCLATH
		IF !_18F_
		btfsc Info_Boot,7
			bsf PCLATH,4; page 2-3 (0x1000 - 0x1FFF)
		ENDIF
		movf TEMP1,W 
		movwf PCL
Table_Temperature; repartition de la charge CPU
		return;                     etape 0 => attente etape 1 toutes les secondes
		bra Inc_Time;               etape 1
		bra Display_Time;           etape 2
		bra Calcul_RCTN;            etape 3
		bra Find_Table_Temperature; etape 4
		bra Calcul_Temperature;     etape 5
		bra Display_Temperature;    etape 6
Inc_Time
		; Etape 1
		rcall Inc_Clock; increment horloge toutes les secondes
		bra Next_MState_Temperature
Display_Time
		; Etape 2
		IF LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI
		btfsc Flags4,LCD_ENABLE; gestion timer LCD inhibe
			call Time_Lcd
		ENDIF ; LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI
		bra Next_MState_Temperature
Calcul_RCTN
		; Etape 3
		movf ADRESH,W; 8 bits poids fort
		subwf Val_AN0,W; lecture CTN sur AN0
		btfsc STATUS,Z
			bra New_Temperature; pas de changement -> relance la mesure
		movf ADRESH,W; 8 bits poids fort
		movwf Val_AN0; lecture CTN sur AN0
		movwf Counter3
		movlw 100
		rcall Mul_0816; Counter3:Counter2 = Val_AN0 * 100
		comf Val_AN0,W; 255 - Val_AN0
		rcall Div_1608; Y_POS = (Val_AN0 * 100) / (255 - Val_AN0)
		movf Counter2,W; poids faible valeur CTN en ohms / 100
		movwf RCTN; valeur resistance CTN / 100
		bra Next_MState_Temperature
Find_Table_Temperature
		; Etape 4
		clrf Idx_Temperature
		movlw 12; nbre de valeurs du tableau
		movwf Counter3
Loop_Find_Rctn
			movlw Tab_CTN-EEProm
			rcall Lecture_EEProm3
			movwf TEMP3; tab_rctn = rctn(n)
			subwf RCTN,W; valeur resistance CTN / 100
			btfss STATUS,C
				bra Exit_Loop_Rctn; tab_rctn > RCTN
			incf Idx_Temperature,F
			incf Idx_Temperature,F
			decfsz Counter3,F
		bra Loop_Find_Rctn
		decf Idx_Temperature,F
		decf Idx_Temperature,F
End_Tab_Rctn
		movlw Tab_CTN-EEProm+1; temperature(n)
		rcall Lecture_EEProm3; valeur extreme du tableau
		incf MState_Temperature,F; saute Calcul_Temperature
		bra Cmd_Motor
Exit_Loop_Rctn
		movf Idx_Temperature,W
		btfsc STATUS,Z
			bra End_Tab_Rctn
		movf Counter3,W
		sublw 1
		btfsc STATUS,Z
			bra End_Tab_Rctn
		bra Next_MState_Temperature
Calcul_Temperature
		; Etape 5
		movlw Tab_CTN-EEProm+1
		rcall Lecture_EEProm3
		movwf TEMP4; tab_rctn+1 = temperature(n)
		movlw Tab_CTN-EEProm-2
		rcall Lecture_EEProm3
		movwf TEMP1; tab_rctn-2 = rctn(n-1)
		movlw Tab_CTN-EEProm-1
		rcall Lecture_EEProm3
		movwf TEMP5; tab_rctn-1 = temperature(n-1)
		;Temperature = TEMP5 - (RCTN-TEMP1) * (TEMP5-TEMP4)
		;                      ----------------------------
		;                              TEMP3-TEMP1
		movf TEMP1,W
		subwf RCTN,W; RCTN - TEMP1
		movwf Counter3
		movf TEMP4,W
		subwf TEMP5,W; TEMP5 - TEMP4
		rcall Mul_0816; Counter3:Counter2 = (RCTN-TEMP1) * (TEMP5-TEMP4)
		movf TEMP1,W
		subwf TEMP3,W; TEMP3 - TEMP1
		rcall Div_1608; Counter3:Counter2 = (rctn-TEMP1) * (TEMP5-TEMP4) / (TEMP3-TEMP1)
		movf Counter2,W
		subwf TEMP5,W; TEMP5 - Counter2
Cmd_Motor
		movwf Temperature
		movlw Tab_Temperature-EEProm+IDX_LEVELHTEMP
		rcall Lecture_EEProm2
		subwf Temperature,W; Temperature - IDX_LEVELHTEMP
		btfsc STATUS,C
			bsf PORTC,MOTORON; Temperature >= IDX_LEVELHTEMP -> marche ventilateur	
		movlw Tab_Temperature-EEProm+IDX_LEVELLTEMP
		rcall Lecture_EEProm2
		subwf Temperature,W; Temperature - IDX_LEVELLTEMP
		btfss STATUS,C
			bcf PORTC,MOTORON; Temperature < IDX_LEVELTEMP -> arret ventilateur	
Next_MState_Temperature
		incf MState_Temperature,F
		return
Display_Temperature
        ; etape 6
		IF LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI
		btfsc Flags4,LCD_ENABLE; gestion timer LCD inhibe
			call Temperature_Lcd
		ENDIF ; LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI		
New_Temperature
		bsf ADCON0,GO_DONE; relance la conversion
		clrf MState_Temperature
		return	

;-----------------------------------------------------------------------------

		IF _18F_
		
;------------------------------------------------------------------------
;   Retoune le Scan-code pour le jeu 3 a partir du Scan-Code Atari
;
;   Entree: W = Scan-code Atari
;   sortie: W = Scan-code jeu 3
;
;   Global: Aucune
;-----------------------------------------------------------------------------
Search_Code_Set3
		DB 0x00, 0x08; offset + 0x00  jamais utilise, offset + 0x01 ESC
		DB 0x16, 0x1E; offset + 0x02 1, offset + 0x03 2
		DB 0x26, 0x25; offset + 0x04 3, offset + 0x05 4
		DB 0x2E, 0x36; offset + 0x06 5, offset + 0x07 6
		DB 0x3D, 0x3E; offset + 0x08 7, offset + 0x09 8
		DB 0x46, 0x45; offset + 0x0A 9, offset + 0x0B 0 (ZERO)
		DB 0x4E, 0x55; offset + 0x0C <)> (-), offset + 0x0D <=> (=)
		DB 0x66, 0x0D; offset + 0x0E BACKSPACE, offset + 0x0F TABULATION
		DB 0x15, 0x1D; offset + 0x10 A (Q), offset + 0x11 Z (W)
		DB 0x24, 0x2D; offset + 0x12 E, offset + 0x13 R
		DB 0x2C, 0x35; offset + 0x14 T, offset + 0x15 Y
		DB 0x3C, 0x43; offset + 0x16 U, offset + 0x17 I
		DB 0x44, 0x4D; offset + 0x18 O, offset + 0x19 P
		DB 0x54, 0x5B; offset + 0x1A <^> ([), offset + 0x1B <$> (])
		DB 0x5A, 0x11; offset + 0x1C RETURN, offset + 0x1D LEFT CTRL (Atari en n'a qu'un)
		DB 0x1C, 0x1B; offset + 0x1E Q (A), offset + 0x1F S
		DB 0x23, 0x2B; offset + 0x20 D, offset + 0x21 F
		DB 0x34, 0x33; offset + 0x22 G, offset + 0x23 H
		DB 0x3B, 0x42; offset + 0x24 J, offset + 0x25 K
		DB 0x4B, 0x4C; offset + 0x26 L, offset + 0x27 M   (;)
		DB 0x52, 0x00; offset + 0x28 <—> ('), offset + 0x29 
		DB 0x12, 0x53; offset + 0x2A LEFT SHIFT, offset + 0x2B <*> (\) COMPAQ
		DB 0x1A, 0x22; offset + 0x2C W (Z), offset + 0x2D X
		DB 0x21, 0x2A; offset + 0x2E C, offset + 0x2F V
		DB 0x32, 0x31; offset + 0x30 B, offset + 0x31 N
		DB 0x3A, 0x41; offset + 0x32 <,> (M), offset + 0x33 <;> (,)
		DB 0x49, 0x4A; offset + 0x34 <:> (.), offset + 0x35 <!> (/)
		DB 0x59, 0x00; offset + 0x36 RIGHT SHIFT, offset + 0x37
		DB IDX_ALTGR, 0x29; offset + 0x38, offset + 0x39 SPACE BAR
		DB 0x14, 0x07; offset + 0x3A CAPS, offset + 0x3B F1
		DB 0x0F, 0x17; offset + 0x3C F2, offset + 0x3D F3
		DB 0x1F, 0x27; offset + 0x3E F4, offset + 0x3F F5
		DB 0x2F, 0x37; offset + 0x40 F6, offset + 0x41 F7
		DB 0x3F, 0x47; offset + 0x42 F8, offset + 0x43 F9
		DB 0x4F, IDX_PAGEUP; offset + 0x44 F10, offset + 0x45		
		DB IDX_PAGEDN, 0x6E; offset + 0x46, offset + 0x47 CLEAR HOME
		DB 0x63, IDX_PRNTSCREEN; offset + 0x48 UP ARROW, offset + 0x49
		DB 0x84, 0x61; offset + 0x4A KP -, offset + 0x4B LEFT ARROW
		DB IDX_SCROLL, 0x6A; offset + 0x4C, offset + 0x4D RIGHT ARROW
		DB 0x7C, IDX_PRNTSCREEN; offset + 0x4E KP +, offset + 0x4F
		DB 0x60, 0x00; offset + 0x50 DOWN ARROW, offset + 0x51
		DB 0x67, 0x64; offset + 0x52 INSERT, offset + 0x53 DELETE
		DB IDX_VERRN, IDX_END; offset + 0x54, offset + 0x55
		DB IDX_WLEFT, IDX_WRIGHT; offset + 0x56, offset + 0x57
		DB IDX_WAPP, 0x00; offset + 0x58, offset + 0x59
		DB 0x00, IDX_RUSSE; offset + 0x5A, offset + 0x5B
		DB 0x00, 0x00; offset + 0x5C, offset + 0x5D
		DB 0x00, 0x00; offset + 0x5E, offset + 0x5F
		DB 0x13, IDX_F12; ><; offset + 0x60, offset + 0x61
		DB IDX_F11, 0x00; offset + 0x62, offset + 0x63
		DB 0x00, 0x77; offset + 0x64, offset + 0x65 KP /
		DB 0x7E, 0x6C; offset + 0x66 KP *, offset + 0x67 KP 7
		DB 0x75, 0x7D; offset + 0x68 KP 8, offset + 0x69 KP 9
		DB 0x6B, 0x73; offset + 0x6A KP 4, offset + 0x6B KP 5
		DB 0x74, 0x69; offset + 0x6C KP 6, offset + 0x6D KP 1
		DB 0x72, 0x7A; offset + 0x6E KP 2, offset + 0x6F KP 3
		DB 0x70, 0x71; offset + 0x70 KP 0 (ZERO), offset + 0x71 KP .
		DB 0x79, IDX_POWER; offset + 0x72 KP ENTER, offset + 0x73		
		DB IDX_SLEEP, IDX_WAKE; offset + 0x74, offset + 0x75
		
		ELSE

		ORG 0xB00
		
;------------------------------------------------------------------------
;   Retoune le Scan-code pour le jeu 3 a partir du Scan-Code Atari
;
;   Entree: W = Scan-code Atari
;   sortie: W = Scan-code jeu 3
;
;   Global: Aucune
;-----------------------------------------------------------------------------
Search_Code_Set3
		addwf PCL,F
		retlw 0x00; offset + 0x00  jamais utilise
		retlw 0x08; offset + 0x01 ESC
		retlw 0x16; offset + 0x02 1
		retlw 0x1E; offset + 0x03 2
		retlw 0x26; offset + 0x04 3
		retlw 0x25; offset + 0x05 4
		retlw 0x2E; offset + 0x06 5
		retlw 0x36; offset + 0x07 6
		retlw 0x3D; offset + 0x08 7
		retlw 0x3E; offset + 0x09 8
		retlw 0x46; offset + 0x0A 9
		retlw 0x45; offset + 0x0B 0 (ZERO)
		retlw 0x4E; offset + 0x0C <)> (-)
		retlw 0x55; offset + 0x0D <=> (=)
		retlw 0x66; offset + 0x0E BACKSPACE
		retlw 0x0D; offset + 0x0F TABULATION
		retlw 0x15; offset + 0x10 A (Q)
		retlw 0x1D; offset + 0x11 Z (W)
		retlw 0x24; offset + 0x12 E
		retlw 0x2D; offset + 0x13 R
		retlw 0x2C; offset + 0x14 T
		retlw 0x35; offset + 0x15 Y
		retlw 0x3C; offset + 0x16 U
		retlw 0x43; offset + 0x17 I
		retlw 0x44; offset + 0x18 O
		retlw 0x4D; offset + 0x19 P
		retlw 0x54; offset + 0x1A <^> ([)	
		retlw 0x5B; offset + 0x1B <$> (])
		retlw 0x5A; offset + 0x1C RETURN
		retlw 0x11; offset + 0x1D LEFT CTRL (Atari en n'a qu'un)
		retlw 0x1C; offset + 0x1E Q (A)
		retlw 0x1B; offset + 0x1F S
		retlw 0x23; offset + 0x20 D
		retlw 0x2B; offset + 0x21 F
		retlw 0x34; offset + 0x22 G
		retlw 0x33; offset + 0x23 H
		retlw 0x3B; offset + 0x24 J
		retlw 0x42; offset + 0x25 K
		retlw 0x4B; offset + 0x26 L
		retlw 0x4C; offset + 0x27 M   (;)
		retlw 0x52; offset + 0x28 <—> (')		
		retlw 0x00; offset + 0x29 
		retlw 0x12; offset + 0x2A LEFT SHIFT
		retlw 0x53; offset + 0x2B <*> (\) COMPAQ
		retlw 0x1A; offset + 0x2C W (Z)
		retlw 0x22; offset + 0x2D X
		retlw 0x21; offset + 0x2E C
		retlw 0x2A; offset + 0x2F V
		retlw 0x32; offset + 0x30 B
		retlw 0x31; offset + 0x31 N
		retlw 0x3A; offset + 0x32 <,> (M)
		retlw 0x41; offset + 0x33 <;> (,)
		retlw 0x49; offset + 0x34 <:> (.)
		retlw 0x4A; offset + 0x35 <!> (/)
		retlw 0x59; offset + 0x36 RIGHT SHIFT
		retlw 0x00; offset + 0x37
		retlw IDX_ALTGR; offset + 0x38
		retlw 0x29; offset + 0x39 SPACE BAR
		retlw 0x14; offset + 0x3A CAPS
		retlw 0x07; offset + 0x3B F1
		retlw 0x0F; offset + 0x3C F2
		retlw 0x17; offset + 0x3D F3
		retlw 0x1F; offset + 0x3E F4
		retlw 0x27; offset + 0x3F F5
		retlw 0x2F; offset + 0x40 F6
		retlw 0x37; offset + 0x41 F7
		retlw 0x3F; offset + 0x42 F8	
		retlw 0x47; offset + 0x43 F9
		retlw 0x4F; offset + 0x44 F10
		retlw IDX_PAGEUP; offset + 0x45		
		retlw IDX_PAGEDN; offset + 0x46
		retlw 0x6E; offset + 0x47 CLEAR HOME
		retlw 0x63; offset + 0x48 UP ARROW
		retlw IDX_PRNTSCREEN; offset + 0x49
		retlw 0x84; offset + 0x4A KP -
		retlw 0x61; offset + 0x4B LEFT ARROW
		retlw IDX_SCROLL; offset + 0x4C
		retlw 0x6A; offset + 0x4D RIGHT ARROW
		retlw 0x7C; offset + 0x4E KP +
		retlw IDX_PAUSE; offset + 0x4F
		retlw 0x60; offset + 0x50 DOWN ARROW
		retlw 0x00; offset + 0x51
		retlw 0x67; offset + 0x52 INSERT
		retlw 0x64; offset + 0x53 DELETE
		retlw IDX_VERRN; offset + 0x54
		retlw IDX_END; offset + 0x55
		retlw IDX_WLEFT; offset + 0x56
		retlw IDX_WRIGHT; offset + 0x57
		retlw IDX_WAPP; offset + 0x58
		retlw 0x00; offset + 0x59
		retlw 0x00; offset + 0x5A
		retlw IDX_RUSSE; offset + 0x5B
		retlw 0x00; offset + 0x5C
		retlw 0x00; offset + 0x5D
		retlw 0x00; offset + 0x5E
		retlw 0x00; offset + 0x5F
		retlw 0x13; ><; offset + 0x60
		retlw IDX_F12; offset + 0x61
		retlw IDX_F11; offset + 0x62
		retlw 0x00; offset + 0x63
		retlw 0x00; offset + 0x64
		retlw 0x77; offset + 0x65 KP /
		retlw 0x7E; offset + 0x66 KP *
		retlw 0x6C; offset + 0x67 KP 7
		retlw 0x75; offset + 0x68 KP 8
		retlw 0x7D; offset + 0x69 KP 9
		retlw 0x6B; offset + 0x6A KP 4
		retlw 0x73; offset + 0x6B KP 5
		retlw 0x74; offset + 0x6C KP 6
		retlw 0x69; offset + 0x6D KP 1
		retlw 0x72; offset + 0x6E KP 2
		retlw 0x7A; offset + 0x6F KP 3
		retlw 0x70; offset + 0x70 KP 0 (ZERO)
		retlw 0x71; offset + 0x71 KP .
		retlw 0x79; offset + 0x72 KP ENTER
		retlw IDX_POWER; offset + 0x73		
		retlw IDX_SLEEP; offset + 0x74
		retlw IDX_WAKE; offset + 0x75
		
		ENDIF

Mul_0816
		movwf Value
		UMUL0808L Counter3,Counter2,Value
		return

;-----------------------------------------------------------------------------
;   Transmit byte in W register from USART
;
; Entree: W = donnee binaire
; Sortie: Rien
;
; Global: TEMP4, TEMP5, TEMP6, DEB_INDEX_EM, FIN_INDEX_EM, TAMPON_EM utilises
;-----------------------------------------------------------------------------
		
SerialTransmit
		btfss Flags,IKBD_ENABLE
			return
		movwf TEMP4
		IF LCD && LCD_DEBUG_ATARI
		IF !_18F_
		bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
		ENDIF
		rcall Send_Debug_Hexa_Lcd
		IF !_18F_
		bcf PCLATH,3; page 0 ou 2
		ENDIF
		ENDIF ; LCD && LCD_DEBUG_ATARI
		IF !_18F_ || !_CAN_
		btfss PIR1,TXIF; check that buffer is empty 
			bra TxReg_Full
		movf FIN_INDEX_EM,W
		subwf DEB_INDEX_EM,W
		btfss STATUS,Z
			bra TxReg_Full; FIN_INDEX_EM <> DEB_INDEX_EM -> caractere encore present dans le buffer circulaire
		movf TEMP4,W
		movwf TXREG; transmit byte
		bcf Flags2,DATATOSEND; flag rien a envoyer dans la boucle principale Main
		return
TxReg_Full
		ENDIF ; !_18F_ || !_CAN_
		IF _18F_
		movf FSR0H,W
		ELSE
		movf STATUS,W
		ENDIF
		movwf TEMP6; sauve IRP
		movf FSR,W
		movwf TEMP5; sauve FSR
		IF _18F_
		movlw HIGH TAMPON_EM
		movwf FSR0H
		ELSE
		bsf STATUS,IRP; page 3
		ENDIF
		incf FIN_INDEX_EM,W; incremente index buffer cirulaire donnees a envoyer
		movwf FSR; pointeur index
		movlw TAILLE_TAMPON_EM
		subwf FSR,W
		btfsc STATUS,C
			clrf FSR; buffer circulaire
		movf DEB_INDEX_EM,W
		subwf FSR,W
		btfsc STATUS,Z
			bra End_SerialTransmit; tampon plein
		movf FSR,W
		movwf FIN_INDEX_EM
		movlw LOW TAMPON_EM
		addwf FSR,F; pointeur index
		movf TEMP4,W
		movwf INDF; ecriture dans le tampon
		bsf Flags2,DATATOSEND; flag donnees a envoyer dans la boucle prinipale Main
End_SerialTransmit
		movf TEMP5,W
		movwf FSR; restitue FSR
		movf TEMP6,W
		IF _18F_
		movwf FSR0H
		ELSE
		movwf STATUS; restitue IRP
		ENDIF
		return	
		
;-----------------------------------------------------------------------------
;   Increment horloge
;              
;   SEC, MIN, HRS, DAY, MONTH, YEAR sont dans une zone en page 2 (sauf pour 18F)
;   non reinitialisee au Reset.
;   La fonction ne tient pas compte des annees bissextiles. 
;-----------------------------------------------------------------------------

Inc_Clock
		IF !_18F_
		bsf STATUS,RP1; page 2
		ENDIF
		incf SEC,F; seconde suivante
		movf SEC,W
		rcall Conv_Bcd_Value
		movwf SEC_BCD
		movlw 60
		subwf SEC,W
		btfss STATUS,C
			bra End_Inc_Clock
		clrf SEC
		clrf SEC_BCD
		incf MIN,F; minute suivante
		movf MIN,W
		rcall Conv_Bcd_Value
		movwf MIN_BCD
		movlw 60
		subwf MIN,W
		btfss STATUS,C
			bra End_Inc_Clock
		clrf MIN
		clrf MIN_BCD
		incf HRS,F; heure suivante
		movf HRS,W
		rcall Conv_Bcd_Value
		movwf HRS_BCD
		movlw 24
		subwf HRS,W
		btfss STATUS,C
			bra End_Inc_Clock
		clrf HRS
		clrf HRS_BCD
		incf DAY,F; jour suivant
		movf DAY,W
		rcall Conv_Bcd_Value
		movwf DAY_BCD
		IF _18F_
		movf MONTH,W
		andlw 0x0F
		addlw LOW Days_In_Month
		movwf TBLPTRL
		movlw HIGH Days_In_Month
		btfsc STATUS,C
			addlw 1
		movwf TBLPTRH
		movlw UPPER Days_In_Month
		movwf TBLPTRU
		tblrd*
		movf TABLAT,W; nombre de jours dans le mois
		ELSE
		bcf STATUS,RP1; page 0
		movlw HIGH Days_In_Month
		movwf PCLATH
		btfsc Info_Boot,7
			bsf PCLATH,4; page 2-3 (0x1000 - 0x1FFF)
		bsf STATUS,RP1; page 2
		movf MONTH,W
		andlw 0x0F
		rcall Days_In_Month; nombre de jours dans le mois
		ENDIF
		subwf DAY,W
		btfss STATUS,C
			bra End_Inc_Clock
		movlw 1
		movwf DAY
		movwf DAY_BCD
		incf MONTH,F; mois suivant
		movf MONTH,W
		rcall Conv_Bcd_Value
		movwf MONTH_BCD
		movlw 13
		subwf MONTH,W
		btfss STATUS,C
			bra End_Inc_Clock
		movlw 1
		movwf MONTH
		movwf MONTH_BCD
		incf YEAR,F; annes suivante
		movf YEAR,W
		rcall Conv_Bcd_Value
		movwf YEAR_BCD
		movlw 100
		subwf YEAR,W
		btfss STATUS,C
			bra End_Inc_Clock
		clrf YEAR
		clrf YEAR_BCD
End_Inc_Clock
		IF !_18F_
		bcf STATUS,RP1; page 0
		ENDIF
		return

;------------------------------------------------------------------------
; Conversion d'une valeur en BCD
;
; Entree: W
; Sortie: W
;
; Global: TEMP1, TEMP2 sont utilises
;------------------------------------------------------------------------
		
Conv_Bcd_Value
		movwf TEMP1;poids faible BCD
		clrf TEMP2; poids fort BCD
Loop_Bcd
			movlw 10
			subwf TEMP1,W
			btfss STATUS,C
				bra Exit_Bcd
			movwf TEMP1; poids faible BCD
			incf TEMP2,F; poids fort BCD
		bra Loop_Bcd
Exit_Bcd
		swapf TEMP2,W
		andlw 0xF0; 4 bits de poids fort
		iorwf TEMP1,W
		return

;------------------------------------------------------------------------
; Conversion BCD en binaire de l'horloge
; YEAR_BCD, MONTH_BCD, DAY_BCD, HRS_BCD, MIN_BCD, et SEC_BCD en page 2
; -> YEAR, MONTH, DAY, HRS, MIN, et SEC en page 2
;
; Global: TEMP1, Counter sont utilises
;------------------------------------------------------------------------

Conv_Inv_Bcd_Time
		movlw LOW YEAR
		movwf FSR
		IF _18F_
		movlw HIGH YEAR
		movwf FSR0H
		ELSE
		bsf STATUS,IRP; page 2
		ENDIF
		movlw 6
		movwf Counter
Loop_Bcd_Time
			movlw YEAR_BCD-YEAR
			addwf FSR,F
			movf INDF,W; valeur BCD
			movwf TEMP1
			movlw YEAR_BCD-YEAR
			subwf FSR,F
			clrw
			btfsc TEMP1,0
				addlw 1
			btfsc TEMP1,1
				addlw 2
			btfsc TEMP1,2
				addlw 4
			btfsc TEMP1,3
				addlw 8
			btfsc TEMP1,4
				addlw 10
			btfsc TEMP1,5
				addlw 20
			btfsc TEMP1,6
				addlw 40
			btfsc TEMP1,7
				addlw 80
			movwf INDF; valeur decimale
			incf FSR,F
			decfsz Counter,F	
		bra Loop_Bcd_Time
		return

;-----------------------------------------------------------------------------
;               Conversion inverse echelle souris en X mode absolu 
;               X_POS = X_POS_SCALED * X_SCALE
;-----------------------------------------------------------------------------

Conv_Inv_Scale_X
		clrf X_POSL; X_POS = X_POS_SCALED * X_SCALE
		clrf X_POSH
		movf X_SCALE,W
		movwf Counter
Loop_Inv_Scale_X
			movf X_POSL_SCALED,W; position X absolue souris avec facteur d'echelle poids faible
			addwf X_POSL,F
			movf X_POSH_SCALED,W; position X absolue souris avec facteur d'echelle poids fort
			btfsc STATUS,C
				incfsz X_POSH_SCALED,W
			addwf X_POSH,F
			decfsz Counter,F
		bra Loop_Inv_Scale_X
		return	

;-----------------------------------------------------------------------------
;               Conversion inverse echelle souris en Y mode absolu
;               Y_POS = Y_POS_SCALED * Y_SCALE  
;-----------------------------------------------------------------------------

Conv_Inv_Scale_Y
		clrf Y_POSL; Y_POS = Y_POS_SCALED * Y_SCALE
		clrf Y_POSH
		movf Y_SCALE,W
		movwf Counter
Loop_Inv_Scale_Y
			movf Y_POSL_SCALED,W; position Y absolue souris avec facteur d'echelle poids faible
			addwf Y_POSL,F
			movf Y_POSH_SCALED,W; position Y absolue souris avec facteur d'echelle poids fort
			btfsc STATUS,C
				incfsz Y_POSH_SCALED,W
			addwf Y_POSH,F
			decfsz Counter,F
		bra Loop_Inv_Scale_Y
		return		

;-----------------------------------------------------------------------------
;               Conversion echelle souris en X mode absolu
;               X_POS = X_POS_SCALED / X_SCALE
;-----------------------------------------------------------------------------
		
Conv_Scale_X
		movf X_POSL,W
		movwf Counter2
		movf X_POSH,W
		movwf Counter3
		movf X_SCALE,W
		rcall Div_1608; X_POS = X_POS_SCALED / X_SCALE
		movf Counter2,W
		movwf X_POSL_SCALED; position X absolue souris avec facteur d'echelle poids faible
		movf Counter3,W
		movwf X_POSH_SCALED; position X absolue souris avec facteur d'echelle poids fort
		return
		
;-----------------------------------------------------------------------------
;               Conversion echelle souris en Y mode absolu
;               Y_POS = Y_POS_SCALED / Y_SCALE
;-----------------------------------------------------------------------------

Conv_Scale_Y
		movf Y_POSL,W
		movwf Counter2
		movf Y_POSH,W
		movwf Counter3
		movf Y_SCALE,W
		rcall Div_1608; Y_POS = Y_POS_SCALED / Y_SCALE
		movf Counter2,W
		movwf Y_POSL_SCALED; position Y absolue souris avec facteur d'echelle poids faible
		movf Counter3,W
		movwf Y_POSH_SCALED; position Y absolue souris avec facteur d'echelle poids fort
		return

;-----------------------------------------------------------------------------
;   KEYBOARD: Routine de lecture d'un octet du port DIN5 et MiniDIN6
;
;   Entree: Rien
;   Sortie: W = 1 si octet recu sinon 0
;           VAR Value = octet recu
;-----------------------------------------------------------------------------

		IF !INTERRUPTS
_KPSGet2
		clrf PARITY; used for parity calc
		movlw 9; 8 bits + start
		movwf Counter; set counter to 8 bits to read
KGetLoop
			rcall KPSGetBit; get a bit from keyboard -> carry
			rrf Value,F; rotate to right to get a shift
			movf Value,W
			xorwf PARITY,F; parity calc
			decfsz Counter,F; check if we should get another one
		bra KGetLoop
		rcall KPSGetBit; get parity bit -> carry
		rrf Counter,W
		xorwf PARITY,F
		rcall KPSGetBit; get stop bit
		btfss STATUS,C
			clrf PARITY; stop bit = 0 -> erreur
;		btfss PARITY,7
;			clrf Value; erreur
		return
		ENDIF ; !INTERRUPTS
		
;-----------------------------------------------------------------------------
;This routine sends a byte in W to a PS/2 mouse or keyboard.  TEMP1, TEMP2,
;and PARITY are general purpose registers.  CLOCK and DATA are assigned to
;port bits, and "Delay" is a self-explainatory macro.  DATA and CLOCK are
;held high by setting their I/O pin to input and allowing an external pullup
;resistor to pull the line high.  The lines are brought low by setting the
;I/O pin to output and writing a "0" to the pin.
;-----------------------------------------------------------------------------

_KPS2cmd
		movwf TEMP1; store to-be-sent byte
		IF !NON_BLOQUANT
		movlw 8; 8 bits
		movwf Counter; initialize a counter		
		ENDIF
		clrf PARITY; used for parity calc
		IF !_18F_
		bsf STATUS,RP0; page 1
		ENDIF
		bcf TRISB,KCLOCK; en sortie
		IF !_18F_
		bcf STATUS,RP0; page 0
		ENDIF
		bcf PORTB,KCLOCK; inhibit communication
		Delay 100; for at least 100 microseconds
		IF !_18F_
		bsf STATUS,RP0; page 1
		ENDIF
		bcf TRISB,KDATA; en sortie
		IF !_18F_
		bcf STATUS,RP0; page 0
		ENDIF
		bcf PORTB,KDATA; valide l'ecriture, pull DATA low
		Delay 5
		IF !_18F_
		bsf STATUS,RP0; page 1
		ENDIF
		bsf TRISB,KCLOCK; en entree, release CLOCK
		IF !_18F_
		bcf STATUS,RP0; page 0
		ENDIF
		IF NON_BLOQUANT
		rcall Wait_Kclock; utilise Counter, [Counter2, Counter3]
		movf Counter,W
		btfsc STATUS,Z
			return; time-out
		movlw 8; 8 bits
		movwf Counter; initialize a counter
		ENDIF ; NON_BLOQUANT
KPS2cmdLoop
			movf TEMP1,W
			xorwf PARITY,F; parity calc
			rcall KPS2cmdBit; output 8 data bits
			rrf TEMP1,F
			decfsz Counter,F
		bra KPS2cmdLoop
		comf PARITY,W
		rcall KPS2cmdBit; output parity bit
		movlw 1
		rcall KPS2cmdBit; output stop bit (1)
		WAIT_KCLOCK_L; attente front descendant de CLK
		WAIT_KCLOCK_H; attente front montant de CLK (ACK)
		return

;-----------------------------------------------------------------------------
;   Routine de lecture d'un octet sur le port SOURIS. Elle ATTEND qu'un paquet
;   soit disponible.
;
;   Entree: Rien
;   Sortie: W = 1 si octet recu sinon 0
;           VAR Value = octet recu
;-----------------------------------------------------------------------------

_MPSGet2
		clrf PARITY; used for parity calc
		movlw 9; 8 bits + start
		movwf Counter; set counter to 8 bits to read
MGetLoop
			rcall MPSGetBit; get a bit from mouse -> carry
			rrf Value,F; rotate to right to get a shift
			movf Value,W
			xorwf PARITY,F; parity calc
			decfsz Counter,F; check if we should get another one
		bra MGetLoop
		rcall MPSGetBit; get parity bit -> carry
		rrf Counter,W
		xorwf PARITY,F
		rcall MPSGetBit; get stop bit
		btfss STATUS,C
			clrf PARITY; stop bit = 0 -> erreur
;		btfss PARITY,7
;			clrf Value; erreur
		return

;-----------------------------------------------------------------------------
;This routine sends a byte in W to a PS/2 mouse
;-----------------------------------------------------------------------------
		
_MPS2cmd
		movwf TEMP1; store to-be-sent byte
		IF !NON_BLOQUANT
		movlw 8; 8 bits
		movwf Counter; initialize a counter		
		ENDIF
		clrf PARITY; used for parity calc
		IF !_18F_
		bsf STATUS,RP0; page 1
		ENDIF
		bcf TRISM,MCLOCK; en sortie
		IF !_18F_
		bcf STATUS,RP0; page 0
		ENDIF
		bcf PORTM,MCLOCK; inhibit communication
		Delay 100; for at least 100 microseconds
		IF !_18F_
		bsf STATUS,RP0; page 1
		ENDIF
		bcf TRISM,MDATA; en sortie
		IF !_18F_
		bcf STATUS,RP0; page 0
		ENDIF
		bcf PORTM,MDATA; valide l'ecriture, pull DATA low
		Delay 5
		IF !_18F_
		bsf STATUS,RP0; page 1
		ENDIF
		bsf TRISM,MCLOCK; en entree, release CLOCK
		IF !_18F_
		bcf STATUS,RP0; page 0
		ENDIF
		IF NON_BLOQUANT
		rcall Wait_Mclock; utilise Counter, [Counter2, Counter3]
		movf Counter,W
		btfsc STATUS,Z
			return; time-out
		movlw 8; 8 bits
		movwf Counter; initialize a counter
		ENDIF ; NON_BLOQUANT
MPS2cmdLoop
			movf TEMP1,W
			xorwf PARITY,F; Parity calc
			rcall MPS2cmdBit; Output 8 data bits
			rrf TEMP1,F
			decfsz Counter,F
		bra MPS2cmdLoop
		comf PARITY,W
		rcall MPS2cmdBit; output parity bit
		movlw 1
		rcall MPS2cmdBit; output stop bit (1)
		WAIT_MCLOCK_L; attente front descendant de CLK
		WAIT_MCLOCK_H; attente front montant de CLK (ACK)
		return

;-----------------------------------------------------------------------------
; Init message utilisateur de 8 caracteres pour l'afficheur LCD
;
; Entree: Rien
; Sortie: Rien
;
; Global: Counter2
;-----------------------------------------------------------------------------	

		IF LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI
Init_Message_User_Lcd
		rcall Init_Message_User_Ptr
Loop_Init_Message_Lcd
			movlw ' '
			IF !_18F_
			bsf STATUS,IRP; page 2
			ENDIF
			movwf INDF
			incf FSR,F
			decfsz Counter2,F
		bra Loop_Init_Message_Lcd
		return
		
		ENDIF ; LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI
		
;-----------------------------------------------------------------------------
; Envoi d'un message utilisateur de 8 caracteres sur l'afficheur LCD
;
; Entree: Rien
; Sortie: Rien
;
; Global: Counter, Counter2, TEMP1, TEMP2
;-----------------------------------------------------------------------------	

		IF LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI
Message_User_Lcd
		movlw 0xC6; ligne 2, colonne 7
		rcall SendINS
		rcall Init_Message_User_Ptr
Loop_Message_Lcd
			IF _18F_
			movlw HIGH USER_LCD
			movwf FSR0H
			ELSE
			bsf STATUS,IRP; page 2
			ENDIF
			movf INDF,W
			rcall SendCHAR
			incf FSR,F
			decfsz Counter2,F
		bra Loop_Message_Lcd
		return
		ENDIF ; LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI

;-----------------------------------------------------------------------------
; Envoi de Value en hexa sur l'afficheur LCD
;
; Entree: W = position LCD + 0x80, Value
; Sortie: Rien
;
; Global: Counter, Counter2, TEMP1, TEMP2, TEMP3
;-----------------------------------------------------------------------------
		IF LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI
Send_Value_Lcd
		btfsc Flags2,BREAK_CODE
			bra Spaces_Lcd
		rcall SendINS
		movf Value,W
		bra Send_Hexa_Lcd
		ENDIF ; LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI

;-----------------------------------------------------------------------------
; Envoi du BAT clavier sur l'afficheur LCD
;
; Entree: Rien
; Sortie: Rien
;
; Global: Counter, Counter2, TEMP1, TEMP2, TEMP3
;-----------------------------------------------------------------------------
		IF LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI && LCD_SCANCODE
Send_KbBAT_Lcd
		movlw 0xCE; ligne 2, colonne 15
		rcall SendINS
		movlw 'K'
		bra SendCHAR
		ENDIF ; LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI && LCD_SCANCODE

;-----------------------------------------------------------------------------
; Envoi du BAT souris sur l'afficheur LCD
;
; Entree: Rien
; Sortie: Rien
;
; Global: Counter, Counter2, TEMP1, TEMP2, TEMP3
;-----------------------------------------------------------------------------
		IF LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI && LCD_SCANCODE
Send_MsBAT_Lcd
		movlw 0xCF; ligne 2, colonne 16
		rcall SendINS
		movlw 'M'
		bra SendCHAR
		ENDIF ; LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI && LCD_SCANCODE
		
;------------------------------------------------------------------------
;   Correspondance pour convertir en hexa le contenu du registre
;   W et l'envoyer vers la laison serie ou l'afficheur LCD
;
;   Entree: W = Quartet a convertir (LSB)
;   sortie: W = Code ASCII
;
;   Global: TEMP1
;------------------------------------------------------------------------
		
Conv_Hexa
		movwf TEMP1
		movlw 10
		subwf TEMP1,W
		btfsc STATUS,C
			addlw 7; A a F
		addlw '0'+10
		return
		
;-----------------------------------------------------------------------------
; Lecture EEPROM
;-----------------------------------------------------------------------------

Lecture_EEProm3
		addwf Idx_Temperature,W

Lecture_EEProm2
		RDEEPROM
		return
		
;-----------------------------------------------------------------------------
; Delais en 1/10 de mS
;
;   Entree: W = delais en 1/10 de mS
;   Sortie: Rien
;
;   Global: Counter
;-----------------------------------------------------------------------------
	
		IF LCD
Delay_Routine_Ms
		movwf Counter
Loop_Delay_Routine_Ms
			Delay 100; uS
			decfsz Counter,F
		bra Loop_Delay_Routine_Ms
		return
		ENDIF ; LCD
			
;-----------------------------------------------------------------------------
	
		IF _18F_
		
		IF LOAD_18F
		
		ORG 0x3700
		
		ELSE
		
		ORG 0x1700
		
		ENDIF

;-----------------------------------------------------------------------------
; Modifier CTRL, ALT, SHIFT table utilisateur
;-----------------------------------------------------------------------------	
		
Get_Modifier
		FILL 0x0000,MAX_VALUE_LOOKUP+1
		
		ELSE
	
		ORG 0xD00
		
;-----------------------------------------------------------------------------
; Modifier CTRL, ALT, SHIFT table utilisateur
;-----------------------------------------------------------------------------	
		
Get_Modifier
		addwf PCL,F
		FILL 0x3400,MAX_VALUE_LOOKUP+1; retlw 0x00
		
		ENDIF

;-----------------------------------------------------------------------------
; PS2 Keyboard subroutines
;-----------------------------------------------------------------------------	

KPSGetBit
		bcf STATUS,C
		IF INTERRUPTS
		WAIT_KCLOCK_INT_L; attente front descendant de CLK
		ELSE
		WAIT_KCLOCK_L; attente front descendant de CLK
		ENDIF
		btfsc PORTB,KDATA
			bsf STATUS,C
		IF INTERRUPTS
		WAIT_KCLOCK_INT_H; attente front montant de CLK
		ELSE
		WAIT_KCLOCK_H; attente front montant de CLK
		ENDIF
		return

KPS2cmdBit
		WAIT_KCLOCK_L; attente front descendant de CLK
		IF !_18F_
		bsf STATUS,RP0; page 1
		ENDIF
		andlw 1
		btfss STATUS,Z ; Set/Reset DATA line
			bsf TRISB,KDATA; en entree
		btfsc STATUS,Z
			bcf TRISB,KDATA; en sortie
		IF !_18F_
		bcf STATUS,RP0; page 0
		ENDIF
		WAIT_KCLOCK_H; attente front montant de CLK
		return

		IF NON_BLOQUANT
Wait_Kclock
		IF _18F_
		movlw 12
		ELSE
		IF _8MHZ_
		movlw 6; ~ 2 secondes
		ELSE
		movlw 3
		ENDIF
		ENDIF
		movwf Counter; time-out
		clrf Counter2
		clrf Counter3
WCK
					btfss PORTB,KCLOCK; attente front descendant de CLK
						return
					decfsz Counter3,F
				bra WCK
				decfsz Counter2,F
			bra WCK
			decfsz Counter,F
		bra WCK
		return
		ENDIF ; NON_BLOQUANT

;-----------------------------------------------------------------------------
; PS2 Mouse subroutines
;-----------------------------------------------------------------------------	

MPSGetBit
		bcf STATUS,C
		WAIT_MCLOCK_L; attente front descendant de CLK
		btfsc PORTM,MDATA
			bsf STATUS,C
		WAIT_MCLOCK_H; attente front montant de CLK
		return

MPS2cmdBit
		WAIT_MCLOCK_L; attente front descendant de CLK
		IF !_18F_
		bsf STATUS,RP0; page 1
		ENDIF
		andlw 1
		btfss STATUS,Z; Set/Reset DATA line
			bsf TRISM,MDATA; en entree
		btfsc STATUS,Z
			bcf TRISM,MDATA; en sortie
		IF !_18F_
		bcf STATUS,RP0; page 0
		ENDIF
		WAIT_MCLOCK_H; attente front montant de CLK
		return

		IF NON_BLOQUANT
Wait_Mclock
		IF _18F_
		movlw 8
		ELSE
		IF _8MHZ_
		movlw 4; ~ 1 seconde
		ELSE
		movlw 2
		ENDIF
		ENDIF
		movwf Counter; time-out
		clrf Counter2
		clrf Counter3
WCM
					btfss PORTM,MCLOCK; attente front descendant de CLK
						return
					decfsz Counter3,F
				bra WCM
				decfsz Counter2,F
			bra WCM
			decfsz Counter,F
		bra WCM
		return
		ENDIF ; NON_BLOQUANT

;------------------------------------------------------------------------
; Envoi le contenu de W en hexa sur la liaison serie
; C'est a dire: W = 0x41 -> Emission de l'ASCII '4' puis ASCII '1'
;
; Entree: W = valeur
; Sortie: Rien
;
; Global: TEMP3
;------------------------------------------------------------------------
		IF SERIAL_DEBUG
SendHexa
		movwf TEMP3; sauver la valeur a traiter
		; just to have 0x printed on screen
		movlw '$'
		rcall SerialTransmit; envoyer l'octet vers le Host
		swapf TEMP3,W
		andlw 0x0F; 4 bits de poids fort
		rcall Conv_Hexa; chercher le code ASCII
		rcall SerialTransmit
		movf TEMP3,W
		andlw 0x0F; 4 bits de poids faible
		rcall Conv_Hexa; chercher le code ASCII
		bra SerialTransmit
		ENDIF ; SERIAL_DEBUG
		
;------------------------------------------------------------------------
; Envoi le contenu de W en hexa vers l'afficheur LCD
; C'est a dire: W = 0x41 -> Emission de l'ASCII '4' puis ASCII '1'
;
; Entree: W = valeur
; Sortie: Rien
;
; Global: Counter, TEMP1, TEMP2, TEMP3
;------------------------------------------------------------------------
		IF LCD
Send_Hexa_Lcd
		movwf TEMP3; sauver la valeur a traiter
		swapf TEMP3,W
		andlw 0x0F; 4 bits de poids fort
		rcall Conv_Hexa; chercher le code ASCII
		rcall SendCHAR
		movf TEMP3,W
		andlw 0x0F; 4 bits de poids faible
		rcall Conv_Hexa; chercher le code ASCII
		bra SendCHAR
		ENDIF ; LCD
		
;-----------------------------------------------------------------------------
; Init variables pour message utilisateur de 8 caracteres sur l'afficheur LCD
;
; Entree: Rien
; Sortie: Rien
;
; Global: Counter2
;-----------------------------------------------------------------------------	

		IF LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI
Init_Message_User_Ptr
		movlw LOW USER_LCD
		movwf FSR
		IF _18F_
		movlw HIGH USER_LCD
		movwf FSR0H
		ENDIF
		movlw 8
		movwf Counter2
		return
		ENDIF ; LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI
		

		IF _18F_ && _CAN_
		
;-----------------------------------------------------------------------------
; Envoi message CAN
;
; Entree: TEMPON_EM
; Sortie: Rien
;
; Global: Counter_CAN, TEMP1, TEMP2, FSR0, FSR1
;-----------------------------------------------------------------------------	

Send_CAN
		btfss COMSTAT,TXBO; Bus-Off
			bra Send_CAN_Ok
		IF LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI
		call Message_Bus_Off_Lcd
		ENDIF ; LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI
		bsf Flags5,CAN_BUS_OFF
		return
Send_CAN_Ok
		movf CANCON,W
		movwf TEMP2; sauve bits WIN
		andlw 0xF1
		iorlw 0x08; Transmit Buffer 0
		movwf CANCON
		lfsr FSR1,RXB0D0
		clrf TEMP1; DLC
		movlw 8
		movwf Counter_CAN
Loop_Send_Bytes_CAN
			movf DEB_INDEX_EM,W; teste buffer circulaire
			subwf FIN_INDEX_EM,W	
			btfsc STATUS,Z
				bra Send_Bytes_CAN; FIN_INDEX_EM = DEB_INDEX_EM
			movlw HIGH TAMPON_EM
			movwf FSR0H
			incf DEB_INDEX_EM,W; incremente buffer cirulaire donnees envoyees
			movwf FSR; pointeur index		
			movlw TAILLE_TAMPON_EM
			subwf FSR,W
			btfsc STATUS,C
				clrf FSR; buffer circulaire
			movf FSR,W
			movwf DEB_INDEX_EM
			movlw LOW TAMPON_EM
			addwf FSR,F; pointeur index
			movf INDF,W; lecture dans le tampon 
			movwf POSTINC1
			incf TEMP1,F
			decfsz Counter_CAN,F
		bra Loop_Send_Bytes_CAN
Send_Bytes_CAN
		movlw ID_CAN_TX_H
		movwf RXB0SIDH
		movlw ID_CAN_TX_L
		movwf RXB0SIDL
		movf TEMP1,W; DLC
		movwf RXB0DLC
		bsf RXB0CON,3; message pret a transmettre
		movf TEMP2,W
		movwf CANCON; restitue bits WIN
		return

;-----------------------------------------------------------------------------
; Reception message CAN
;
; Entree: Rien
; Sortie: W
;
; Global: Counter_CAN, DLC_CAN, FSR1, FSR2
;-----------------------------------------------------------------------------	
		
Receive_CAN
		movf DLC_CAN,W
		btfss STATUS,Z
			bra Next_Byte_Received_CAN
		movf RXB0DLC,W
		andlw 0x0F
		movwf DLC_CAN
		movwf Counter_CAN
		btfsc STATUS,Z
			goto End_Receive_CAN
		lfsr FSR2,BUF_CAN
		lfsr FSR1,RXB0D0
Loop_Receive_CAN
			movf POSTINC1,W
			movwf POSTINC2
			decfsz Counter_CAN,F
		goto Loop_Receive_CAN
		rcall End_Receive_CAN
		lfsr FSR2,BUF_CAN
Next_Byte_Received_CAN
		decf DLC_CAN,F
		movf POSTINC2,W
		return
End_Receive_CAN
		bcf RXB0CON,RXFUL
		bcf PIR3,RXB0IF; acquitte RXB0
		return
	
		ENDIF ; _18F_ && _CAN_	
		
;-----------------------------------------------------------------------------
		
		IF _18F_
		
		IF LOAD_18F
		
		ORG 0x3900
		
		ELSE
		
		ORG 0x1900
		
		ENDIF

;-----------------------------------------------------------------------------
; Shift table utilisateur
;-----------------------------------------------------------------------------	
		
Get_Scan_Codes_Shift
		FILL 0x0000,MAX_VALUE_LOOKUP+1
		
		ELSE
		
		ORG 0xE00
		
;-----------------------------------------------------------------------------
; Shift table utilisateur
;-----------------------------------------------------------------------------	
		
Get_Scan_Codes_Shift
		addwf PCL,F
		FILL 0x3400,MAX_VALUE_LOOKUP+1; retlw 0x00

		ENDIF

;-----------------------------------------------------------------------------
;   Test changement d'etat touches Shifts, Alt & AltGr du set 3 
;
; Entree: Value = donnee binaire
; Sortie: Rien
;
; Global: Flags2, Flags3
;-----------------------------------------------------------------------------

Test_Shift_Alt_AltGr
		movf Value,W
		sublw 0x59; RIGHT SHIFT code set 3
		btfsc STATUS,Z
			bra Test_Shift
		movf Value,W
		sublw 0x12; LEFT SHIFT code set 3
		btfss STATUS,Z
			bra No_Shift
Test_Shift
		bcf Flags3,SHIFT_PS2; relachement Shift droit
		btfsc Flags2,BREAK_CODE
			return
		bsf Flags3,SHIFT_PS2
		bsf Flags5,SHIFT_PS2_BREAK
		return
No_Shift
		movf Value,W
		sublw 0x19; ALT code set 3
		btfss STATUS,Z
			bra No_Alt
		bcf Flags3,ALT_PS2; relachement Alt
		btfss Flags2,BREAK_CODE
			bsf Flags3,ALT_PS2
		return
No_Alt
		movf Value,W
		sublw 0x39; ALT GR code set 3
		btfss STATUS,Z
			bra No_AltGr
		bcf Flags3,ALTGR_PS2; relachement AltGr
		btfsc Flags2,BREAK_CODE
			return
		bsf Flags3,ALTGR_PS2
		bsf Flags5,ALTGR_PS2_BREAK
		return
No_AltGr
		btfsc Flags2,BREAK_CODE
			return; relachement
		btfss Flags3,ALTGR_PS2 		
			bcf Flags5,ALTGR_PS2_BREAK; si la touche AltGr est relachee
		btfss Flags3,SHIFT_PS2 		
			bcf Flags5,SHIFT_PS2_BREAK; si la touche Shift est relachee
		return

;-----------------------------------------------------------------------------
;  Test changement d'etat touches SHIFT, ALT & CTRL envoyes a l'unite centrale 
;
; Entree: Value = donnee binaire
; Sortie: Rien
;
; Global: Flags2, Flags4
;-----------------------------------------------------------------------------

Test_Shift_Alt_Ctrl_Host
		movf Value,W
		sublw 0x1D; CTRL
		btfss STATUS,Z
			bra No_CtrlHost
		bcf Flags4,CTRL_HOST; relachement CTRL		
		btfss Flags2,BREAK_CODE
			bsf Flags4,CTRL_HOST
		return
No_CtrlHost
		movf Value,W
		sublw 0x36; RIGHT SHIFT
		btfss STATUS,Z
			bra No_RightShiftHost
		bcf Flags4,RIGHT_SHIFT_HOST; relachement SHIFT droit
		btfss Flags2,BREAK_CODE
			bsf Flags4,RIGHT_SHIFT_HOST
		return
No_RightShiftHost	
		movf Value,W
		sublw 0x2A; LEFT SHIFT
		btfss STATUS,Z
			bra No_LeftShiftHost
		bcf Flags4,LEFT_SHIFT_HOST; relachement SHIFT gauche
		btfss Flags2,BREAK_CODE
			bsf Flags4,LEFT_SHIFT_HOST
		return
No_LeftShiftHost
		movf Value,W
		sublw 0x38; ALT
		btfss STATUS,Z
			return
		bcf Flags4,ALT_HOST; relachement ALT
		btfss Flags2,BREAK_CODE
			bsf Flags4,ALT_HOST
		return
		
;-----------------------------------------------------------------------------
; Envoi de la chaine de bienvenue sur la RS232
;
; Entree: Rien
; Sortie: Rien
;
; Global: Counter, TEMP4, TEMP5, TEMP6, DEB_INDEX_EM, FIN_INDEX_EM, TAMPON_EM
;-----------------------------------------------------------------------------

		IF SERIAL_DEBUG
SerialWelcome
		clrf Counter
Loop_SerialWelcome
			IF _18F_
			movf Counter,W
			addwf Counter,W
			ELSE
			movlw HIGH WelcomeText
			movwf PCLATH
			btfsc Info_Boot,7
				bsf PCLATH,4; page 2-3 (0x1000 - 0x1FFF)
			movf Counter,W
			ENDIF
			call WelcomeText
			IF !_18F_
			bsf PCLATH,3; page 1 ou 3 (0x800 - 0xFFF)
			ENDIF
			iorlw 0
			btfsc STATUS,Z
				return
			rcall SerialTransmit
			incf Counter,F
		bra Loop_SerialWelcome
		ENDIF ; SERIAL_DEBUG

;-----------------------------------------------------------------------------
; Envoi de l'heure sur l'afficheur LCD
;
; Entree: Rien
; Sortie: Rien
;
; Global: Counter, Counter2, TEMP1, TEMP2, TEMP3
;-----------------------------------------------------------------------------

		IF LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI
Time_Lcd
		movlw 0x80; ligne 1, colonne 1
		rcall SendINS
		movlw LOW MONTH_BCD
		movwf FSR
		IF _18F_
		movlw HIGH MONTH_BCD
		movwf FSR0H
		ELSE
		bsf STATUS,IRP; page 2
		ENDIF
		movlw 4
		movwf Counter2
		rcall Send_Indf_Hexa_Lcd
		movlw '/'
		bra Separator_Time
Loop_Time_Lcd
			rcall Send_Indf_Hexa_Lcd
			movf Counter2,W
			sublw 2
			movlw ' '
			btfss STATUS,Z
				bra Separator_Time
			IF !_18F_
			bsf STATUS,RP1; page 2
			ENDIF
			btfss SEC_BCD,0
				bra Separator_Time
			movlw ':'
Separator_Time
			IF !_18F_
			bcf STATUS,RP1; page 0
			ENDIF
			rcall SendCHAR; separateur
			incf FSR,F
			decfsz Counter2,F	
		bra Loop_Time_Lcd
Send_Indf_Hexa_Lcd
		movf INDF,W; valeur BCD
		bra Send_Hexa_Lcd
		ENDIF ; LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI

;-----------------------------------------------------------------------------
; Affichage du scan-code dans Value en hexa sur l'afficheur LCD
;
; Entree: Value
; Sortie: Rien
;
; Global: Counter, Counter2, TEMP1, TEMP2, TEMP3, TEMP4
;-----------------------------------------------------------------------------
		
		IF LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI && LCD_SCANCODE
Send_ScanCode_Lcd
		btfss Flags3,NEXT_CODE
			bra BreakCode_Lcd
		movf Value,W
		movwf TEMP4
		movlw 0xE0		
		movwf Value			
		movlw 0x8E; ligne 1, colonne 15
		rcall Send_Value_Lcd; $E0			
		movf TEMP4,W
		movwf Value
BreakCode_Lcd; code set 2/3			
		movlw 0xCE; ligne 2, colonne 15
		bra Send_Value_Lcd
		ENDIF ; LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI && LCD_SCANCODE

;------------------------------------------------------------------------
; Envoi valeur dans W en hexa sur tout l'afficheur LCD
;
; Entree: W = valeur
; Sortie: Rien
;
; Global: Counter2, TEMP2, TEMP3, TEMP4, TEMP5, TEMP6
;-----------------------------------------------------------------------------

		IF LCD && (LCD_DEBUG || LCD_DEBUG_ATARI)
Send_Debug_Hexa_Lcd
		movwf TEMP4; sauve valeur
		movf Counter,W
		movwf TEMP5
		movf TEMP1,W
		movwf TEMP6
		rcall Cursor_Debug_Lcd
		movf TEMP4,W
		rcall Send_Hexa_Lcd
		incf Counter_Debug_Lcd,F
		movlw 15
		andwf Counter_Debug_Lcd,F
		rcall Cursor_Debug_Lcd
		movlw ' '
		rcall SendCHAR
		movlw ' '
		rcall SendCHAR
		movf TEMP5,W
		movwf Counter 
		movf TEMP6,W
		movwf TEMP1
		return
		
Cursor_Debug_Lcd
		movf Counter_Debug_Lcd,W
		addwf Counter_Debug_Lcd,W
		btfsc Counter_Debug_Lcd,3
			bra Debug_Ligne2_Lcd; -> 2eme ligne
		addlw 0x80; ligne 1, colonne 1
		bra Debug_Ligne_Lcd
Debug_Ligne2_Lcd
		andlw 15
		addlw 0xC0; ligne 2, colonne 1
Debug_Ligne_Lcd
		bra SendINS
		ENDIF ; LCD && (LCD_DEBUG || LCD_DEBUG_ATARI)

;-----------------------------------------------------------------------------			
		
		IF _18F_
		
		IF LOAD_18F
		
		ORG 0x3B00
		
		ELSE
		
		ORG 0x1B00
		
		ENDIF

;-----------------------------------------------------------------------------
; AltGr table utilisateur
;-----------------------------------------------------------------------------	
		
Get_Scan_Codes_AltGr
		FILL 0x0000,MAX_VALUE_LOOKUP+1
		
		ELSE
				
		ORG 0xF00
		
;-----------------------------------------------------------------------------
; AltGr table utilisateur
;-----------------------------------------------------------------------------	
		
Get_Scan_Codes_AltGr
		addwf PCL,F
		FILL 0x3400,MAX_VALUE_LOOKUP+1; retlw 0x00

		ENDIF
	
;-----------------------------------------------------------------------------
; Envoi de la temperature sur l'afficheur LCD
;
; Entree: Rien
; Sortie: Rien
;
; Global: Counter, TEMP1, TEMP2, TEMP3, TEMP4
;-----------------------------------------------------------------------------

		IF LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI
Temperature_Lcd
		movlw 0xC0; ligne 2, colonne 1
		rcall SendINS
		movf Temperature,W
		movwf TEMP4
		movlw '0'
		movwf TEMP3
Lcd_Dec10
			movlw 10
			subwf TEMP4,W
			btfss STATUS,C
				bra Lcd_Dec1
			movwf TEMP4
			incf TEMP3,F
		bra Lcd_Dec10
Lcd_Dec1
		movf TEMP3,W
		rcall SendCHAR
		movlw '0'
		addwf TEMP4,W
		rcall SendCHAR
		movlw 0xDF
		rcall SendCHAR
		movlw 'C'
		rcall SendCHAR
		movlw ' '
		rcall SendCHAR
		movlw '-'
		btfsc PORTC,MOTORON
			movlw '+'
		bra SendCHAR
		ENDIF ; LCD && !LCD_DEBUG && !LCD_DEBUG_ATARI

;------------------------------------------------------------------------
;   Initialisation de l'afficheur LCD
;
;   Entree: Rien
;   Sortie: Rien
;
;   Global: Counter, TEMP1, TEMP2
;------------------------------------------------------------------------

		IF LCD
Init_Lcd
		Delay_Ms 200; attente 20 mS avant reset afficheur LCD
		bcf STATUS,C; efface Carry (Instruction Out)
		movlw 0x03; commande Reset
		rcall NybbleOut; Send Nybble
		Delay_Ms 50; attente 5 mS avant d'envoyer la suite
		EStrobe
		Delay 160; attente 160 uS
		EStrobe
		Delay 160; attente 160 uS
		bcf STATUS,C
		movlw 0x02; mode 4 bits
		rcall NybbleOut
		Delay 160
		movlw 0x28; 2 lignes d'affichages
		rcall SendINS
		movlw 0x08; coupe l'afficheur
		rcall SendINS
		movlw 0x01; efface l'affichage
		rcall SendINS
		Delay_Ms 50; 4.1 mS maxi
		movlw 0x06; autorisation deplacement curseur
		rcall SendINS
		movlw 0x0C; LCD Back On
		bra SendINS
		
;-----------------------------------------------------------------------------
; Envoi 2 espaces sur l'afficheur LCD
;
; Entree: W = position LCD + 0x80
; Sortie: Rien
;
; Global: Counter, TEMP1, TEMP2
;-----------------------------------------------------------------------------			

		IF !LCD_DEBUG && !LCD_DEBUG_ATARI
Spaces_Lcd
		rcall SendINS
		movlw ' '
		rcall SendCHAR
		movlw ' '
		ENDIF ; !LCD_DEBUG && !LCD_DEBUG_ATARI
		
;------------------------------------------------------------------------
;   Envoi d'un caractere vers le LCD
;
;   Entree: W = Caractere
;   Sortie: Rien
;
;   Global: Counter, TEMP1, TEMP2
;------------------------------------------------------------------------

SendCHAR
		movwf TEMP1; save la valeur
		swapf TEMP1,W; envoi les 4 bits de poids fort
		bsf STATUS,C; RS = 1
		rcall NybbleOut
		movf TEMP1,W; envoi les 4 bits de poids faible
		bsf STATUS,C
		bra NybbleOut

;------------------------------------------------------------------------
;   Envoi d'une instruction vers le LCD
;
;   Entree: W = Code
;   Sortie: Rien
;
;   Global: Counter, TEMP1, TEMP2
;------------------------------------------------------------------------

SendINS
		movwf TEMP1; sauve la valeur
		swapf TEMP1,W; envoi les 4 bits de poids fort
		bcf STATUS,C; RS = 0
		rcall NybbleOut
		movf TEMP1,W; envoi les 4 bits de poids faible
		bcf STATUS,C
		
;------------------------------------------------------------------------
;   Envoi de 4 bits vers le LCD
;   utilisation d'un registre a decalage externe 74LS174 ou
;   1Q = D4, 2Q = D5, 3Q = D6, 4Q = D7, 5Q = RS, 6Q = E
;
;   Entree: W = Valeur, C = RS
;   Sortie: Rien
;
;   Global: Counter, TEMP2
;------------------------------------------------------------------------

NybbleOut
		movwf TEMP2 ; sauve les 4 bits a envoyer
		swapf TEMP2 ; place les 4 bits a gauche
		movlw 6	; efface le registre a decalage (74LS714)
		movwf Counter
NOLoop1
			ClockStrobe
			decfsz Counter
		bra NOLoop1
		bsf PORTB,LCD_DATA; positionne Gate E Bit a 1
		ClockStrobe
		bcf PORTB,LCD_DATA; positionne RS Bit a 0
		btfsc STATUS,C
			bsf PORTB,LCD_DATA; RS a 1
		ClockStrobe
		movlw 4; envoi les bits Data
		movwf Counter
NOLoop2
			rlf TEMP2; decalage des 4 bits a envoyer
			bcf PORTB,LCD_DATA; efface le bit data
			btfsc STATUS,C
				bsf PORTB,LCD_DATA; bit data a 1
			ClockStrobe
			decfsz Counter
		bra NOLoop2
		EStrobe; Strobe LCD Data
		return
		
		IF _18F_
DelayStrobeLCD
		nop
		nop
		nop
		return
		ENDIF
		
;-----------------------------------------------------------------------------
; Ecrase message utilisateur de 8 caracteres avec le texte Bus-Off
; sur l'afficheur LCD
;
; Entree: Rien
; Sortie: Rien
;
; Global: Counter2
;-----------------------------------------------------------------------------	
		
		IF _18F_ && _CAN_ && !LCD_DEBUG && !LCD_DEBUG_ATARI
Message_Bus_Off_Lcd
		rcall Init_Message_User_Ptr
		clrf TBLPTRU
		movlw HIGH BusOffText
		movwf TBLPTRH
		movlw LOW BusOffText
		movwf TBLPTRL
Loop_Message_Bus_Off_Lcd
			tblrd*+
			movf TABLAT,W
			movwf INDF
			incf FSR,F
			decfsz Counter2,F
		bra Loop_Message_Bus_Off_Lcd
		return

BusOffText
		DB " BUSOFF "

		ENDIF ; _18F_ && _CAN_ && !LCD_DEBUG && !LCD_DEBUG_ATARI

		ENDIF ; LCD
		
;-----------------------------------------------------------------------------

		IF _18F_
		
		IF LOAD_18F
		
		ORG 0x3FC0
		
		ELSE
		
		ORG 0x1FC0
		
		ENDIF
		
Banks_2000_3FFF_OK
		DW 0xFFFF,0xFFFF,0xFFFF,0xFFFF
		DW 0xFFFF,0xFFFF,0xFFFF,0xFFFF
		DW 0xFFFF,0xFFFF,0xFFFF,0xFFFF
		DW 0xFFFF,0xFFFF,0xFFFF,0xFFFF
		DW 0xFFFF,0xFFFF,0xFFFF,0xFFFF
		DW 0xFFFF,0xFFFF,0xFFFF,0xFFFF
		DW 0xFFFF,0xFFFF,0xFFFF,0xFFFF
		DW 0xFFFF,0xFFFF,0xFFFF,0xFFFF; invalides
		
		IF LOAD_18F
		
		ORG 0x3D00
		
		ELSE		
		
		ORG 0x1D00
		
		ENDIF
		
		ELSE ; 16F876
		
		ORG 0xFFF
Banks_2_3_OK
		DW 0x3FFF; banks 2 & 3 invalides
		
		ORG 0x800
		
		ENDIF

;-----------------------------------------------------------------------------
; Programme de boot en page 0 ou 2 et de telechargement en Flash
;-----------------------------------------------------------------------------

Start_Flash
		bra Start_Flash_2
		
Ecriture_Flash	
		IF LCD
		movlw 0x01; efface l'affichage
		rcall SendINS
		ENDIF
		IF _18F_
		movlw LOW Banks_2000_3FFF_OK
		movwf Counter2; adresse FLASH poids faible
		movlw HIGH Banks_2000_3FFF_OK
		movwf Counter; adresse FLASH poids fort
		movlw 'E'; validation
		rcall Erase_Flash; effacement de 64 octets -> programme mauvais (0xFFFF) en 0x1FF8-0x1FFF
		ELSE
		movlw LOW Banks_2_3_OK
		movwf Counter2; adresse FLASH poids faible
		movlw HIGH Banks_2_3_OK
		movwf Counter; adresse FLASH poids fort
		movlw 0xFF
		movwf BUFFER_FLASH
		movlw 0x3F
		movwf BUFFER_FLASH+1
		movlw 'W'; validation
		call Write_Flash; ecriture 2 octets -> programme mauvais (0x3FFF) en 0x0FFF	
		ENDIF
		clrf Value; checkum
		clrf Counter2; adresse FLASH poids faible
		IF _18F_
		movlw 0x20; 0x2000-0x3FFF
		movwf Counter
		ELSE
		clrf Counter; adresse FLASH poids fort
		bsf Counter,4; pages 2-3 (0x1000 - 0x1FFF)
		ENDIF
Loop_Flash_1
				IF _18F_
				lfsr FSR0,BUFFER_FLASH
				movlw 4; 8 octets
				movwf Counter3
Loop_Flash_2
					IF _CAN_
					call SerialReceive
					ELSE
					btfss PIR1,RCIF
						bra Loop_Flash_2
					movf RCREG,W; poids fort
					ENDIF
					movwf TEMP4
					addwf Value,F
Loop_Flash_5
					IF _CAN_
					call SerialReceive
					ELSE
					btfss PIR1,RCIF
						bra Loop_Flash_5
					movf RCREG,W; poids faible
					ENDIF ; _CAN_
					movwf POSTINC0
					addwf Value,F
					movff TEMP4,POSTINC0
					decfsz Counter3
				bra Loop_Flash_2
				movf Counter2,W; adresse FLASH poids faible
				andlw 0x3F
				movlw 'E'; validation
				btfsc STATUS,Z
					rcall Erase_Flash; effacement de 64 octets
				ELSE
				btfss PIR1,RCIF
					bra Loop_Flash_1
				movf RCREG,W
				andlw 0x3F
				movwf BUFFER_FLASH+1; poids fort
				addwf Value,F
Loop_Flash_2
				btfss PIR1,RCIF
					bra Loop_Flash_2
				movf RCREG,W
				movwf BUFFER_FLASH; poids faible
				addwf Value,F
				ENDIF ; _18F_
				movlw 'W'; validation
				rcall Write_Flash; ecriture 2 octets (ou 8 pour le 18F)
				btfss Counter2,2
					bcf PORTB,LEDGREEN; allume les deux LEDs
				btfss Counter2,2
					bcf PORTB,LEDYELLOW
				btfsc Counter2,2
					bsf PORTB,LEDGREEN; eteint les deux LEDs
				btfsc Counter2,2
					bsf PORTB,LEDYELLOW
				IF LCD	
				movf Counter,W
				movwf TEMP4; sauve Counter
				movlw 0x80; ligne 1, colonne 1
				rcall SendINS
				movf TEMP4,W; adresse FLASH poids fort
				rcall Send_Hexa_Lcd
				movf Counter2,W; adresse FLASH poids faible
				rcall Send_Hexa_Lcd
				movf TEMP4,W
				movwf Counter
				ENDIF ; LCD
				IF _18F_
				movlw 8
				addwf Counter2,F
				ELSE
				incf Counter2,F
				ENDIF
				btfss STATUS,Z
			bra Loop_Flash_1
			incf Counter,F
			IF _18F_
			btfss Counter,6
			ELSE
			btfss Counter,5
			ENDIF
		bra Loop_Flash_1
Loop_Flash_3
		IF _18F_ && _CAN_
		call SerialReceive; lecture checksum
		ELSE
		btfss PIR1,RCIF
			bra Loop_Flash_3
		movf RCREG,W; lecture checksum
		ENDIF
		subwf Value,W; checksum octets en prevenance du port serie
		btfss STATUS,Z
			bra Fin_Prog_Flag; checksum mauvais				
		clrf PARITY; checkum
		clrf Counter2; adresse FLASH poids faible
		IF _18F_
		movlw 0x20; 0x2000-0x3FFF
		movwf Counter
		ELSE
		clrf Counter; adresse FLASH poids fort
		bsf Counter,4; pages 2-3 (0x1000 - 0x1FFF)
		ENDIF
Loop_Flash_4
				rcall Read_Flash; lecture 2 octets
				movf BUFFER_FLASH+1,W; poids fort
				addwf PARITY,F
				movf BUFFER_FLASH,W; poids faible
				addwf PARITY,F
				IF _18F_
				incf Counter2,F
				ENDIF
				incf Counter2,F
				btfss STATUS,Z
			bra Loop_Flash_4
			incf Counter,F
			IF _18F_
			btfss Counter,6
			ELSE
			btfss Counter,5
			ENDIF
		bra Loop_Flash_4
		movf PARITY,W; lecture checksum octets flash
		subwf Value,W
		btfss STATUS,Z
			bra Fin_Prog_Flag; checksum mauvais
		IF _18F_
		movlw LOW Banks_2000_3FFF_OK
		movwf Counter2; adresse FLASH poids faible
		movlw HIGH Banks_2000_3FFF_OK
		movwf Counter; adresse FLASH poids fort
		movlw 'E'; validation
		rcall Erase_Flash; effacement de 64 octets -> programme mauvais (0xFFFF) en 0x1FF8-0x1FFF
		clrf BUFFER_FLASH
		clrf BUFFER_FLASH+1
		clrf BUFFER_FLASH+2
		clrf BUFFER_FLASH+3
		clrf BUFFER_FLASH+4
		clrf BUFFER_FLASH+5
		clrf BUFFER_FLASH+6
		clrf BUFFER_FLASH+7		
Loop_Flash_6
			movlw 'W'; validation
			rcall Write_Flash; ecriture 8 octets -> programme OK (0) en 0x1FC0-0x1FFF
			movlw 8
			addwf Counter2,F
			btfss STATUS,Z
		bra Loop_Flash_6
		ELSE
		movlw LOW Banks_2_3_OK
		movwf Counter2; adresse FLASH poids faible
		movlw HIGH Banks_2_3_OK
		movwf Counter; adresse FLASH poids fort
		clrf BUFFER_FLASH
		clrf BUFFER_FLASH+1
		movlw 'W'; validation
		call Write_Flash; ecriture 2 octets -> programme OK (0) en 0x0FFF
		ENDIF
		IF LCD
		movlw ' '
		rcall SendCHAR
		movlw 'O'
		rcall SendCHAR
		movlw 'K'
		rcall SendCHAR
		ENDIF ; LCD
Fin_Prog_Flag
		IF !_18F_
		clrf PCLATH
		ENDIF
		clrf STATUS
		goto Reset_Prog

Read_Flash
		READ_FLASH Counter,Counter2,BUFFER_FLASH
		return
		
Write_Flash
		sublw 'W'
		btfss STATUS,Z
			return
		WRITE_FLASH Counter,Counter2,BUFFER_FLASH
		return
		
		IF _18F_
Erase_Flash
		sublw 'E'
		btfss STATUS,Z
			return
		ERASE_FLASH Counter,Counter2
		return
		ENDIF

Start_Flash_2
		clrf INTCON; interdit interruptions
		IF _18F_
		movlb 0
		lfsr FSR0,Status_Boot+1
Init_Pages
			clrf POSTINC0; initialisation RAM
			btfss FSR0H,1; 512 octets
		bra Init_Pages
		setf TRISC; 8 entrees
		ELSE
		bsf STATUS,IRP; pages 2-3
		movlw 0xA0; page 3
		movwf FSR
Init_Page_3
			clrf INDF; initialisation RAM
			incf FSR,F
			btfsc FSR,7
		bra Init_Page_3
		movlw 0x20; page 2
		movwf FSR
Init_Page_2
			clrf INDF
			incf FSR,F
			btfss FSR,7
		bra Init_Page_2
		bcf STATUS,IRP; pages 0-1
		movlw 0xA0; page 1
		movwf FSR
Init_Page_1
			clrf INDF
			incf FSR,F
			btfsc FSR,7
		bra Init_Page_1
		movlw Status_Boot+1; page 0
		movwf FSR
Init_Page_0
			clrf INDF
			incf FSR,F
			btfss FSR,7
		bra Init_Page_0
		bsf STATUS,RP0; page 1
		bcf STATUS,RP1
		movlw 0xFF
		movwf TRISC; 8 entrees
		bcf STATUS,RP0; page 0
		clrf PCLATH
		ENDIF
		clrf Info_Boot
		btfss PORTC,4; fire joystick 1
			goto Startup; force lancement programme en page page 0
		IF _18F_
		movlw LOW Banks_2000_3FFF_OK
		movwf Counter2; adresse FLASH poids faible
		movlw HIGH Banks_2000_3FFF_OK
		movwf Counter; adresse FLASH poids fort
		rcall Read_Flash; lecture 2 octets en 0x1FF8	
		ELSE
		movlw LOW Banks_2_3_OK
		movwf Counter2; adresse FLASH poids faible
		movlw HIGH Banks_2_3_OK
		movwf Counter; adresse FLASH poids fort
		bsf PCLATH,3; page 1 (0x800 - 0xFFF)
		rcall Read_Flash; lecture 2 octets en 0x0FFF	
		bcf PCLATH,3; page 0
		ENDIF
		movf BUFFER_FLASH,W
		iorwf BUFFER_FLASH+1,W
		btfss STATUS,Z
			goto Startup; lance programme en page page 0 si programme en page 2 invalide (0x1000 - 0x17FF)
		IF _18F_
		setf Info_Boot
		goto Startup+0x2000; lance programme telecharge valide (0x2000 - 0x3FFF)
		ELSE
		movlw 0xFF
		movwf Info_Boot
		bsf PCLATH,4; page 2 (0x1000 - 0x17FF)
		goto Startup; lance programme en page page 2 valide (0x1000 - 0x1FFF)
		ENDIF

;-----------------------------------------------------------------------------

		IF _18F_
		
		ORG 0xF00000
		
EEProm

;-----------------------------------------------------------------------------
;               Zone EEPROM de stockage des Scan-Codes Souris
;               Ces codes sont la valeurs par defaut a renvoyer
;-----------------------------------------------------------------------------
Tab_Scan_Codes
		DE 0x00, 0x00; offset + 0x00  jamais utilise, offset + 0x01  jamais utilise
		DE 0x00, 0x00; offset + 0x02  jamais utilise, offset + 0x03  jamais utilise
		DE 0x00, 0x00; offset + 0x04  jamais utilise, offset + 0x05  jamais utilise
		DE 0x00, 0x3B; offset + 0x06  jamais utilise, offset + 0x07 F1
		DE 0x01, 0x00; offset + 0x08 ESC, offset + 0x09  jamais utilise
		DE 0x00, 0x00; offset + 0x0A  jamais utilise, offset + 0x0B  jamais utilise
		DE 0x00, 0x0F; offset + 0x0C  jamais utilise, offset + 0x0D TABULATION
		DE DEF_RUSSE, 0x3C; offset + 0x0E <2> (`) ( a cote de 1 ), offset + 0x0F F2
		DE 0x00, 0x1D; offset + 0x10  jamais utilise, offset + 0x11 LEFT CTRL (Atari en n'a qu'un)
		DE 0x2A, 0x60; offset + 0x12 LEFT SHIFT, offset + 0x13 ><
		DE 0x3A, 0x10; offset + 0x14 CAPS, offset + 0x15 A (Q) 
		DE 0x02, 0x3D; offset + 0x16 1, offset + 0x17 F3
		DE 0x00, DEF_ALTGR; offset + 0x18  jamais utilise, offset + 0x19 LEFT ALT (Atari en n'a qu'un)
		DE 0x2C, 0x1F; offset + 0x1A W (Z), offset + 0x1B S
		DE 0x1E, 0x11; offset + 0x1C Q (A), offset + 0x1D Z (W)
		DE 0x03, 0x3E; offset + 0x1E 2, offset + 0x1F F4
		DE 0x00, 0x2E; offset + 0x20  jamais utilise, offset + 0x21 C
		DE 0x2D, 0x20; offset + 0x22 X, offset + 0x23 D
		DE 0x12, 0x05; offset + 0x24 E, offset + 0x25 4
		DE 0x04, 0x3F; offset + 0x26 3, offset + 0x27 F5
		DE 0x00, 0x39; offset + 0x28  jamais utilise, offset + 0x29 SPACE BAR
		DE 0x2F, 0x21; offset + 0x2A V, offset + 0x2B F
		DE 0x14, 0x13; offset + 0x2C T, offset + 0x2D R
		DE 0x06, 0x40; offset + 0x2E 5, offset + 0x2F F6
		DE 0x00, 0x31; offset + 0x30  jamais utilise, offset + 0x31 N
		DE 0x30, 0x23; offset + 0x32 B, offset + 0x33 H
		DE 0x22, 0x15; offset + 0x34 G, offset + 0x35 Y
		DE 0x07, 0x41; offset + 0x36 6, offset + 0x37 F7
		DE 0x00, DEF_ALTGR; offset + 0x38  jamais utilise, offset + 0x39 RIGHT ALT GR (Atari en n'a qu'un)
		DE 0x32, 0x24; offset + 0x3A <,> (M), offset + 0x3B J
		DE 0x16, 0x08; offset + 0x3C U, offset + 0x3D 7
		DE 0x09, 0x42; offset + 0x3E 8, offset + 0x3F F8
		DE 0x00, 0x33; offset + 0x40  jamais utilise, offset + 0x41 <;> (,)
		DE 0x25, 0x17; offset + 0x42 K, offset + 0x43 I
		DE 0x18, 0x0B; offset + 0x44 O (lettre O ), offset + 0x45 0 (chiffre ZERO)
		DE 0x0A, 0x43; offset + 0x46 9, offset + 0x47 F9
		DE 0x00, 0x34; offset + 0x48  jamais utilise, offset + 0x49 <:> (.)
		DE 0x35, 0x26; offset + 0x4A <!> (/), offset + 0x4B L
		DE 0x27, 0x19; offset + 0x4C M   (;), offset + 0x4D P
		DE 0x0C, 0x44; offset + 0x4E <)> (-), offset + 0x4F F10
		DE 0x00, 0x00; offset + 0x50  jamais utilise, offset + 0x51  jamais utilise
		DE 0x28, 0x2B; offset + 0x52 <—> ('), offset + 0x53 <*> (\) touche sur COMPAQ
		DE 0x1A, 0x0D; offset + 0x54 <^> ([), offset + 0x55 <=> (=)
		DE 0x62, DEF_PRINTSCREEN; offset + 0x56 F11 <= HELP ATARI (Fr), offset + 0x57 PRINT SCREEN
		DE 0x1D, 0x36; offset + 0x58 RIGHT CTRL (Atari en n'a qu'un), offset + 0x59 RIGHT SHIFT
		DE 0x1C, 0x1B; offset + 0x5A RETURN, offset + 0x5B <$> (])
		DE 0x2B, 0x00; offset + 0x5C <*> (\) touche sur SOFT KEY, offset + 0x5D  jamais utilise
		DE DEF_F12, DEF_SCROLL; offset + 0x5E F12 <= UNDO ATARI (Fr), offset + 0x5F SCROLL
		DE 0x50, 0x4B; offset + 0x60 DOWN ARROW, offset + 0x61 LEFT ARROW
		DE DEF_PAUSE, 0x48; offset + 0x62 PAUSE, offset + 0x63 UP ARROW
		DE 0x53, 0x55; offset + 0x64 DELETE, offset + 0x65 END
		DE 0x0E, 0x52; offset + 0x66 BACKSPACE, offset + 0x67 INSERT
		DE 0x00, 0x6D; offset + 0x68  jamais utilise, offset + 0x69 KP 1
		DE 0x4D, 0x6A; offset + 0x6A RIGHT ARROW, offset + 0x6B KP 4 )
		DE 0x67, DEF_PAGEDN; offset + 0x6C KP 7, offset + 0x6D PAGE DOWN    (unused on Atari before)
		DE 0x47, DEF_PAGEUP; offset + 0x6E CLEAR HOME, offset + 0x6F PAGE UP      (unused on Atari before)
		DE 0x70, 0x71; offset + 0x70 KP 0 (ZERO), offset + 0x71 KP . 
		DE 0x6E, 0x6B; offset + 0x72 KP 2, offset + 0x73 KP 5 
		DE 0x6C, 0x68; offset + 0x74 KP 6, offset + 0x75 KP 8 )
		DE DEF_VERRNUM, 0x65; offset + 0x76 VERR NUM (unused on Atari before), offset + 0x77 KP /
		DE 0x00, 0x72; offset + 0x78  jamais utilise, offset + 0x79 KP ENTER
		DE 0x6F, 0x00; offset + 0x7A KP 3, offset + 0x7B  jamais utilise
		DE 0x4E, 0x69; offset + 0x7C KP +, 0x69; offset + 0x7D KP 9
		DE 0x66, DEF_SLEEP; offset + 0x7E KP *, offset + 0x7F SLEEP  Eiffel 1.0.5
		DE DEF_POWER, DEF_WAKE; offset + 0x80  jamais utilise  Eiffel 1.0.8, offset + 0x81  jamais utilise  Eiffel 1.0.8
		DE 0x00, 0x00; offset + 0x82  jamais utilise, offset + 0x83  jamais utilise
		DE 0x4A, 0x00; offset + 0x84 KP -, offset + 0x85  jamais utilise
		DE 0x00, 0x00; offset + 0x86  jamais utilise, offset + 0x87  jamais utilise
		DE 0x00, 0x00; offset + 0x88  jamais utilise, offset + 0x89  jamais utilise
		DE 0x00, DEF_WINLEFT; offset + 0x8A  jamais utilise, offset + 0x8B LEFT WIN
		DE DEF_WINRIGHT, DEF_WINAPP; offset + 0x8C RIGHT WIN, offset + 0x8D POPUP WIN
		DE 0x00, 0x00; offset + 0x8E  jamais utilise, offset + 0x8F  jamais utilise
;-----------------------------------------------------------------------------
Tab_Mouse
		DE DEF_WHEELUP, DEF_WHEELDN; offset + 0x90 AT_WHEELUP  Eiffel 1.0.0, offset + 0x91 AT_WHEELDOWN  Eiffel 1.0.1 ( v1.0.0 retournait 0x60 )
		DE DEF_WHEELLT, DEF_WHEELRT; offset + 0x92 AT_WHEELLEFT  Eiffel 1.0.3 seulement, offset + 0x93 AT_WHEELRIGHT  Eiffel 1.0.3 seulement
		DE DEF_BUTTON3, DEF_BUTTON4; offset + 0x94 AT_BUTTON3  Eiffel 1.0.3 scan-code bouton 3 Central, offset + 0x95 AT_BUTTON4  Eiffel 1.0.3 scan-code bouton 4
		DE DEF_BUTTON5, DEF_WHREPEAT; offset + 0x96 AT_BUTTON5     Eiffel 1.0.3 scan-code bouton 5, offset + 0x97 ADR_WHEELREPEAT Eiffel 1.0.3 Nombre de repetition

		DE "Eiffel 3"
		DE " LCD    "
;-----------------------------------------------------------------------------
Tab_Temperature
		DE 40, 35; seuil maxi de temperature  Eiffel 1.0.4, seuil mini de temperature  Eiffel 1.0.4
Tab_CTN
		DE 27, 64; 2700 ohms, 63.6 deg C  Eiffel 1.0.6
		DE 33, 57; 3300 ohms, 57.5 deg C
		DE 39, 52; 3900 ohms, 52.3 deg C
		DE 47, 47; 4700 ohms, 46.7 deg C
		DE 56, 41; 5600 ohms, 41.5 deg C
		DE 68, 36; 6800 ohms, 35.7 deg C
		DE 82, 30; 8200 ohms, 30.5 deg C
		DE 100, 25; 10000 ohms, 25.1 deg C
		DE 120, 20; 12000 ohms, 20.1 deg C
		DE 150, 15; 15000 ohms, 14.7 deg C
		DE 180, 11; 18000 ohms, 10.6 deg C
		DE 220, 6; 22000 ohms, 5.6 deg C
;-----------------------------------------------------------------------------
Tab_Config
		DE 2; jeu 2 ou 3 clavier             Eiffel 1.0.5
;-----------------------------------------------------------------------------
		
		ELSE
		
		ORG 0x2100
		
EEProm

;-----------------------------------------------------------------------------
;               Zone EEPROM de stockage des Scan-Codes Souris
;               Ces codes sont la valeurs par defaut a renvoyer
;-----------------------------------------------------------------------------
Tab_Scan_Codes
		DE 0x00; offset + 0x00  jamais utilise: "Error or Buffer Overflow"
		DE 0x00; offset + 0x01  jamais utilise
		DE 0x00; offset + 0x02  jamais utilise
		DE 0x00; offset + 0x03  jamais utilise
		DE 0x00; offset + 0x04  jamais utilise
		DE 0x00; offset + 0x05  jamais utilise
		DE 0x00; offset + 0x06  jamais utilise
		DE 0x3B; offset + 0x07 F1
		DE 0x01; offset + 0x08 ESC
		DE 0x00; offset + 0x09  jamais utilise
		DE 0x00; offset + 0x0A  jamais utilise
		DE 0x00; offset + 0x0B  jamais utilise
		DE 0x00; offset + 0x0C  jamais utilise
		DE 0x0F; offset + 0x0D TABULATION
		DE DEF_RUSSE; offset + 0x0E <2> (`) ( a cote de 1 )
		DE 0x3C; offset + 0x0F F2
		DE 0x00; offset + 0x10  jamais utilise
		DE 0x1D; offset + 0x11 LEFT CTRL (Atari en n'a qu'un)
		DE 0x2A; offset + 0x12 LEFT SHIFT
		DE 0x60; offset + 0x13 ><
		DE 0x3A; offset + 0x14 CAPS
		DE 0x10; offset + 0x15 A (Q) 
		DE 0x02; offset + 0x16 1 
		DE 0x3D; offset + 0x17 F3
		DE 0x00; offset + 0x18  jamais utilise
		DE DEF_ALTGR; offset + 0x19 LEFT ALT (Atari en n'a qu'un)
		DE 0x2C; offset + 0x1A W (Z)
		DE 0x1F; offset + 0x1B S
		DE 0x1E; offset + 0x1C Q (A)
		DE 0x11; offset + 0x1D Z (W)
		DE 0x03; offset + 0x1E 2 
		DE 0x3E; offset + 0x1F F4
		DE 0x00; offset + 0x20  jamais utilise
		DE 0x2E; offset + 0x21 C
		DE 0x2D; offset + 0x22 X
		DE 0x20; offset + 0x23 D
		DE 0x12; offset + 0x24 E
		DE 0x05; offset + 0x25 4
		DE 0x04; offset + 0x26 3
		DE 0x3F; offset + 0x27 F5
		DE 0x00; offset + 0x28  jamais utilise
		DE 0x39; offset + 0x29 SPACE BAR
		DE 0x2F; offset + 0x2A V
		DE 0x21; offset + 0x2B F
		DE 0x14; offset + 0x2C T
		DE 0x13; offset + 0x2D R
		DE 0x06; offset + 0x2E 5 
		DE 0x40; offset + 0x2F F6
		DE 0x00; offset + 0x30  jamais utilise
		DE 0x31; offset + 0x31 N
		DE 0x30; offset + 0x32 B
		DE 0x23; offset + 0x33 H
		DE 0x22; offset + 0x34 G
		DE 0x15; offset + 0x35 Y
		DE 0x07; offset + 0x36 6 
		DE 0x41; offset + 0x37 F7
		DE 0x00; offset + 0x38  jamais utilise
		DE DEF_ALTGR; offset + 0x39 RIGHT ALT GR (Atari en n'a qu'un)
		DE 0x32; offset + 0x3A <,> (M)
		DE 0x24; offset + 0x3B J
		DE 0x16; offset + 0x3C U
		DE 0x08; offset + 0x3D 7
		DE 0x09; offset + 0x3E 8
		DE 0x42; offset + 0x3F F8
		DE 0x00; offset + 0x40  jamais utilise
		DE 0x33; offset + 0x41 <;> (,)
		DE 0x25; offset + 0x42 K
		DE 0x17; offset + 0x43 I
		DE 0x18; offset + 0x44 O (lettre O )
		DE 0x0B; offset + 0x45 0 (chiffre ZERO)
		DE 0x0A; offset + 0x46 9
		DE 0x43; offset + 0x47 F9
		DE 0x00; offset + 0x48  jamais utilise
		DE 0x34; offset + 0x49 <:> (.)
		DE 0x35; offset + 0x4A <!> (/)
		DE 0x26; offset + 0x4B L
		DE 0x27; offset + 0x4C M   (;)
		DE 0x19; offset + 0x4D P
		DE 0x0C; offset + 0x4E <)> (-)
		DE 0x44; offset + 0x4F F10
		DE 0x00; offset + 0x50  jamais utilise
		DE 0x00; offset + 0x51  jamais utilise
		DE 0x28; offset + 0x52 <—> (')
		DE 0x2B; offset + 0x53 <*> (\) touche sur COMPAQ
		DE 0x1A; offset + 0x54 <^> ([)
		DE 0x0D; offset + 0x55 <=> (=)
		DE 0x62; offset + 0x56 F11          <= HELP ATARI (Fr)
		DE DEF_PRINTSCREEN; offset + 0x57 PRINT SCREEN
		DE 0x1D; offset + 0x58 RIGHT CTRL   (Atari en n'a qu'un)
		DE 0x36; offset + 0x59 RIGHT SHIFT
		DE 0x1C; offset + 0x5A RETURN
		DE 0x1B; offset + 0x5B <$> (])
		DE 0x2B; offset + 0x5C <*> (\) touche sur SOFT KEY
		DE 0x00; offset + 0x5D  jamais utilise
		DE DEF_F12; offset + 0x5E F12          <= UNDO ATARI (Fr)
		DE DEF_SCROLL; offset + 0x5F SCROLL
		DE 0x50; offset + 0x60 DOWN ARROW
		DE 0x4B; offset + 0x61 LEFT ARROW
		DE DEF_PAUSE; offset + 0x62 PAUSE
		DE 0x48; offset + 0x63 UP ARROW
		DE 0x53; offset + 0x64 DELETE
		DE 0x55; offset + 0x65 END
		DE 0x0E; offset + 0x66 BACKSPACE
		DE 0x52; offset + 0x67 INSERT
		DE 0x00; offset + 0x68  jamais utilise
		DE 0x6D; offset + 0x69 KP 1
		DE 0x4D; offset + 0x6A RIGHT ARROW
		DE 0x6A; offset + 0x6B KP 4 )
		DE 0x67; offset + 0x6C KP 7 
		DE DEF_PAGEDN; offset + 0x6D PAGE DOWN    (unused on Atari before)
		DE 0x47; offset + 0x6E CLEAR HOME
		DE DEF_PAGEUP; offset + 0x6F PAGE UP      (unused on Atari before)
		DE 0x70; offset + 0x70 KP 0 (ZERO)
		DE 0x71; offset + 0x71 KP . 
		DE 0x6E; offset + 0x72 KP 2 
		DE 0x6B; offset + 0x73 KP 5 
		DE 0x6C; offset + 0x74 KP 6 
		DE 0x68; offset + 0x75 KP 8 )
		DE DEF_VERRNUM; offset + 0x76 VERR NUM     (unused on Atari before)
		DE 0x65; offset + 0x77 KP /
		DE 0x00; offset + 0x78  jamais utilise
		DE 0x72; offset + 0x79 KP ENTER
		DE 0x6F; offset + 0x7A KP 3 
		DE 0x00; offset + 0x7B  jamais utilise
		DE 0x4E; offset + 0x7C KP +
		DE 0x69; offset + 0x7D KP 9 
		DE 0x66; offset + 0x7E KP *
		DE DEF_SLEEP; offset + 0x7F SLEEP            Eiffel 1.0.5
		DE DEF_POWER; offset + 0x80  jamais utilise  Eiffel 1.0.8
		DE DEF_WAKE; offset + 0x81  jamais utilise   Eiffel 1.0.8
		DE 0x00; offset + 0x82  jamais utilise
		DE 0x00; offset + 0x83  jamais utilise
		DE 0x4A; offset + 0x84 KP -
		DE 0x00; offset + 0x85  jamais utilise
		DE 0x00; offset + 0x86  jamais utilise
		DE 0x00; offset + 0x87  jamais utilise
		DE 0x00; offset + 0x88  jamais utilise
		DE 0x00; offset + 0x89  jamais utilise
		DE 0x00; offset + 0x8A  jamais utilise
		DE DEF_WINLEFT;  offset + 0x8B LEFT WIN
		DE DEF_WINRIGHT; offset + 0x8C RIGHT WIN
		DE DEF_WINAPP;   offset + 0x8D POPUP WIN
		DE 0x00; offset + 0x8E  jamais utilise
		DE 0x00; offset + 0x8F  jamais utilise
;-----------------------------------------------------------------------------
Tab_Mouse
		DE DEF_WHEELUP; offset + 0x90 AT_WHEELUP     Eiffel 1.0.0
		DE DEF_WHEELDN; offset + 0x91 AT_WHEELDOWN   Eiffel 1.0.1 ( v1.0.0 retournait 0x60 )
		DE DEF_WHEELLT; offset + 0x92 AT_WHEELLEFT   Eiffel 1.0.3 seulement
		DE DEF_WHEELRT; offset + 0x93 AT_WHEELRIGHT  Eiffel 1.0.3 seulement
		DE DEF_BUTTON3; offset + 0x94 AT_BUTTON3     Eiffel 1.0.3 scan-code bouton 3 Central
		DE DEF_BUTTON4; offset + 0x95 AT_BUTTON4     Eiffel 1.0.3 scan-code bouton 4
		DE DEF_BUTTON5; offset + 0x96 AT_BUTTON5     Eiffel 1.0.3 scan-code bouton 5
		DE DEF_WHREPEAT; offset + 0x97 ADR_WHEELREPEAT Eiffel 1.0.3 Nombre de repetition

		DE "Eiffel 3"
		DE " LCD    "
;-----------------------------------------------------------------------------
Tab_Temperature
		DE 40; seuil maxi de temperature     Eiffel 1.0.4
		DE 35; seuil mini de temperature     Eiffel 1.0.4
Tab_CTN
		DE 27; 2700 ohms                     Eiffel 1.0.6
		DE 64; 63.6 deg C
		DE 33; 3300 ohms
		DE 57; 57.5 deg C
		DE 39; 3900 ohms
		DE 52; 52.3 deg C
		DE 47; 4700 ohms
		DE 47; 46.7 deg C
		DE 56; 5600 ohms
		DE 41; 41.5 deg C
		DE 68; 6800 ohms
		DE 36; 35.7 deg C
		DE 82; 8200 ohms
		DE 30; 30.5 deg C
		DE 100; 10000 ohms
		DE 25; 25.1 deg C
		DE 120; 12000 ohms
		DE 20; 20.1 deg C
		DE 150; 15000 ohms
		DE 15; 14.7 deg C
		DE 180; 18000 ohms
		DE 11; 10.6 deg C
		DE 220; 22000 ohms
		DE 6; 5.6 deg C
;-----------------------------------------------------------------------------
Tab_Config
		DE 2; jeu 2 ou 3 clavier             Eiffel 1.0.5
;-----------------------------------------------------------------------------

		ENDIF

		END
