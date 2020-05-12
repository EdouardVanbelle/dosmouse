Title 'DosMouse','VANBELLE Edouard (c) 03/1997'

.Model Tiny
.code

Org 100h
Dos_mouse:
		jmp Debut

;*************************************
Hot_Key		 equ 2700h			;2700 4600h
args_flags 	 db 0000b

old_int28h	 dd ?				;adresses des anciennes
old_multiplexeur dd ?				;interruptions
old_mouse	 dd ?				
old_int_clavier	 dd ?				
old_int1Ch	 dd ?				 

can_run		 db 0				 
just_write	 db 0				
mouse_cnt	 db 253d			;255-253=2 => r.a.z de can_run
write_cnt	 db 253d			;toute les 2*1/18.2=0.03s
etat_mouse	 dw 0				;Si 0,la souris n' est pas aff
etat_mouse_sav	 dw 0
can_write	 db 0				

cursor		 dw ?				;sauv des attrib du curseur
col_40		 db 0Ah				;si bit0=1 => mode 40 colonnes
ecr_seg		 dw 0B800h			;adresse de l' ‚cran
ecr_ofs		 dw 0				;(nb: ecran couleur seulement)
start_pos	 dw 0				;adr. b‚but s‚lection sur ecr.
end_pos		 dw 0				;adr. fin selection sur ecr.
old_end_pos	 dw 0				;ard de sauvegarde
old_start_pos	 dw 0

ptr_sel		 dw offset Selection		;pour int_clavier
Selection	 db 'S‚lection vide.',241 dup (0)

BEEP	macro				;macro personnelle pour les tests
	push ax
	mov ax,0E07h
	int 10h
	pop ax
endm

INT33h	macro				;appel direct de la souris
	pushf
	call cs:old_mouse
endm

PUSHT	macro				;sauv ts les registres utiles
		push ax			;=PUSHT
		push bx
		push cx
		push dx
		push si
		push di
		push es
		push ds
endm	

POPT	macro				;rest ts les registres utiles
		pop ds
		pop es
		pop di
		pop si
		pop dx
		pop cx
		pop bx
		pop ax
endm

proc	DOES_MOUSE_MOVE
		push ax
		mov ax,0Bh
		INT33h
		or  cx,dx
		pop ax
		ret
endp

proc 	Multiplexeur_ED	Far		;nvelle int. (Multiplexeur)
		sti			;autre int. autoris‚es
		pushf
		cmp ah,0EDh		;test si on s' adresse … DOSMOUSE
		je mux_ok		;si oui ...
		popf
		jmp cs:Old_Multiplexeur	;sinon appel l' ancien Multiplexeur
mux_ok:
		popf
		or al,al		;al= nø de fonction
		jnz saut_mux_1		;si al <> fonction test
		mov al,0EDh		;indiquer que D.Mouse est install‚
fin_mux:
		iret			;Retour
saut_mux_1:
		cmp al,1		;fonction 1: modifier les flags. 
		jne saut_mux_2
		mov cs:args_flags,bl
		iret		
saut_mux_2:
		cmp al,2		;fonction 2: lire les flags
		jne fin_mux		;sinon: fonction inconnue, retour
		mov bl,cs:args_flags
		iret
endp	Multiplexeur_ED

proc	mouse_ed Far		;d‚termine si la souris est affich‚e ou non
		pushf
		or ax,ax
		jnz st_mouse0
		mov cs:etat_mouse,0	;fonction reset du driver
		jmp st_mouse_fin
st_mouse0:
		cmp ax,01h		;fonction affiche souris
		jne st_mouse1
		inc cs:etat_mouse	;(on incr‚ment le drapeau)
		jmp st_mouse_fin
st_mouse1:
		cmp ax,02h		;fonction cache souris
		jne st_mouse2
		dec cs:etat_mouse	;(d‚cr‚mente le drapeau)
		jmp st_mouse_fin
st_mouse2:
		cmp ax,021h		;fonction reset de la partie logicielle
		jne st_mouse3
		mov cs:etat_mouse,0	
		jmp st_mouse_fin
st_mouse3:
		cmp ax,016h		;fonction sauvegarde
		jne st_mouse4
		push ax
		mov ax,cs:etat_mouse
		mov cs:etat_mouse_sav,ax
		pop ax
		jmp st_mouse_fin
st_mouse4:
		cmp ax,017h		;fonction restauration
		jne st_mouse_fin
		push ax
		mov ax,cs:etat_mouse_sav
		mov cs:etat_mouse,ax
		pop ax
st_mouse_fin:
		popf 
		jmp cs:old_mouse	;appel l' ancien driver
EndP	mouse_ed

proc	int_clavier far		;simule l' appuie de touches sur le clavier
		sti				; pour envoyer la s‚lection
		cmp cs:can_write,00		; v‚rifie si on peut ‚crire
		jne write_selection
		cli
		jmp cs:old_int_clavier		;sinon appel ancien drv clavier
write_selection:
		push bx
		mov bx,cs:ptr_sel	;regarde ou en est le transfert de car.
		cmp byte ptr cs:[bx],0	
		jne do_tfr_car		;si <>0, il y a encore des car. a tfr.
		lea bx,selection	;sinon remet le pointer … l'origine
		mov cs:ptr_sel,bx
		pop bx
		mov cs:can_write,00	;plus besoin d'ecrire (tfr termin‚)
		mov cs:just_write,0FFh	;on vient juste d'ecrire, on a donc 
		cli			; plus besoin de la souris
		jmp cs:old_int_clavier  ;ancien gestinnaire clavier
do_tfr_car:
		mov cs:can_run,0	;d‚sactive le controleur DosMouse
		cmp ah,00h		;ici,fonction 0= fonction 10
		je  fct0		; (lecture car. avec inc ptr)
		cmp ah,10h		
		je  fct0
		cmp ah,01h		;ici,fonction 1= fonction 11
		je  fct1		; (lecture car, sans modifier source)
		cmp ah,11h
		je  fct1
		pop bx
		cli
		jmp cs:old_int_clavier		;sinon appel ancien drv clavier
	fct0:
		mov al,cs:[bx]		;tranfert le car point‚ par bx
		xor ah,ah		;pas de scancode (souvent inutile)
		inc cs:ptr_sel		;passe au car suivant (appel suivant)
		pop bx
		iret			;retour
	fct1:
		mov al,cs:[bx]		;transfert le car point‚ par bx
		xor ah,ah		;pas de scancode
		pop bx
		cmp ah,1		;ZF=0 => car pr‚sent
		ret 2			;retour en conservant les flags
endp

proc	tache_de_fond far	;procedure appel‚e quand le DOS ne fait rien
		sti				;int autoris‚es
		pushf
		PUSHT
		
		cmp cs:etat_mouse,0		;la souris est-elle ‚teinte?
		jz I_can			;oui
Ho_no:
		jmp no_I_can_not		;non, on sort
I_can:
		cmp cs:just_write,0
		jne Ho_no			;vient-on juste d' ‚crire?

		call does_mouse_move
		or  cx,cx
		jz  ho_no

		mov ah,0Fh			;lit mode vid‚o actuelle
		int 10h
		cmp al,03			;seul le mode texte est suport‚
		jna I_can1
		jmp no_I_can_not 		;si mode graphique (>3) on sort
I_can1:
		mov al,ah			;al=ah=nbr de colonnes
		mov cl,3			;ici seul bit0 est significatif
		shr al,cl			
		mov cs:col_40,al		;sauvegarde pour les calculs
		xor al,al			;al inutile
		xchg al,ah			;bh=page_vid‚o
		mul bh				;calcul offset de l'‚cran car:
		mov dh,50d			;off=(col*25*2)*page_page_vid‚o
		mul dh
		mov cs:ecr_ofs,ax		;sauv l'offset

		mov ah,03h			;lit forme du curseur
		int 10h
		mov cs:cursor,cx		;on la sauvegarde(pour restit.)
		mov ah,01h
		mov cx,2020h			;‚teint le curseur texte
		int 10h
		test cs:args_flags,1000b	;la souris part d'o— ?
		jz no_relocation		;si ZF,part de ancien situation
		mov ah,03h			
		int 10h				;lit pos du curseur
		xor ah,ah			;ah inutile
		mov al,dl			;al=dl=colonne(=pos en X)
		mov cl,3			;80 col,largeur curseur= 8 pxls
		mov bl,cs:col_40		;40 col,largeur curseur=16 pxls
		shr bl,1
		adc cl,0			;lit la bit0 via ZC
		shl ax,cl			;=mul 8 ou 16
		push ax				;sauv r‚sultat sur la pile
		xor ah,ah
		mov al,dh			;al=dh=ligne(=pos en Y)
		mov cl,3			
		shl ax,cl			;=mul 8
		mov dx,ax			;dx=ligne_souris
		pop cx				;cx=sauvgarde_pile=col_souris
		mov ax,04h			;modifie la pos de la souris
		INT33h
no_relocation:
		mov ax,0Ah
		xor bx,bx
		mov cl,0
		mov dl,04
		mov ch,01110111b
		mov dh,01110111b
		test cs:args_flags,0100b
		jz  cur_mouse_carreau
		mov dl,18
	cur_mouse_carreau:
		INT33h

		mov ax,01h
		int33h
tache_loop:
		mov ax,03h
		INT33h
		cmp bx,10b
		je tache_no_loop
		cmp bx,01b
		jne no_sel_mouse
		mov ax,cs:end_pos
		mov cs:old_end_pos,ax
		mov ax,cs:old_start_pos
		mov cs:start_pos,ax
		mov cs:end_pos,ax
		call redraw

		call sel_mouse
no_sel_mouse:
		mov ah,01h
		pushf
		call cs:old_int_clavier
		jz tache_loop
		mov cs:can_write,00h
		jmp fin_tache
tache_no_loop:
		mov ax,0003h
		INT33h
		or bx,bx
		jnz tache_no_loop
		mov cs:can_write,0FFh
		test cs:args_flags,0001b
		jz  fin_tache
		call add_point
fin_tache:
		mov ax,cs:end_pos
		mov cs:old_end_pos,ax
		mov ax,cs:old_start_pos
		mov cs:start_pos,ax
		mov cs:end_pos,ax
		call redraw

		mov ax,0002h
		INT33h
		mov ah,01h
		mov cx,cs:cursor
		int 10h
		mov byte ptr cs:can_run,0h
		POPT
		popf
		Iret
no_i_can_not:
		POPT
		popf
		cli
		jmp cs:old_int28h
endp	tache_de_fond

;proc	event_mouse far
;		cmp cs:just_write,0
;		jne not_allowed
;		mov cs:can_run,0FFh
;not_allowed:
;		retf
;endp	event_mouse

proc	sel_mouse
		pushf
		push ds
		push es
		push cx
		push ax
		push bx
		push si
		push di
		cld
		call DOES_MOUSE_MOVE
		call calc_pos_dx
		mov cs:start_pos,dx
		mov cs:end_pos,dx
		mov cs:old_start_pos,dx
ret_sel_mouse:
		call DOES_MOUSE_MOVE
		jz no_move
		test cs:args_flags,0100b
		jz no_mode_ligne
		mov al,cs:col_40
		xor ah,ah
		mov cl,4
		shl ax,cl
		mov bx,ax
		call calc_pos_dx
		sub dx,cs:start_pos
		mov ax,dx
		mov cl,8
		idiv cl
		or  al,al
		jz  no_mode_ligne
		cmp al,0
		jg  inc_start_pos
		mov ax,cs:start_pos
		mov cs:old_start_pos,ax
		sub ax,bx
		mov cs:start_pos,ax
		jmp no_mode_ligne
	inc_start_pos:
		mov ax,cs:start_pos
		mov cs:old_start_pos,ax
		add ax,bx
		mov cs:start_pos,ax
	no_mode_ligne:
		call calc_pos_dx
		mov ax,dx
		sub ax,cs:start_pos
		cmp ax,00FBh
		jl move_it
		mov bx,cs:start_pos
		mov dx,0FBh
		add dx,bx
	move_it:
		mov ax,cs:end_pos
		mov cs:old_end_pos,ax
		mov cs:end_pos,dx
		call redraw
		mov ax,cs:start_pos
		mov cs:old_start_pos,ax
	no_move:
		mov ax,03
		INT33h
		test bx,01b
		jz no_ret_sel_mouse
		jmp ret_sel_mouse
	no_ret_sel_mouse:
		
		mov ax,cs
		mov es,ax
		mov ax,cs:ecr_seg
		mov ds,ax
		mov si,cs:start_pos
		mov dx,cs:end_pos
		cmp si,dx
		je  no_selection
		lea di,cs:selection
	sel_mouse_rep:
		cmp si,dx
		jae no_car_to_sav
		lodsw
		cmp al,' '
		jae sel_car_ok
		mov al,' '
	sel_car_ok:
		stosb
		jmp sel_mouse_rep
	no_car_to_sav:
		test cs:args_flags,0010b
		jz  no_addi_enter
		mov al,0Dh
		stosb
	no_addi_enter:
		mov al,0
		stosb

	no_selection:
		pop di
		pop si
		pop bx
		pop ax
		pop cx
		pop es
		pop ds
		popf
		ret
endp	sel_mouse

proc	redraw
		push ds
		push es
		push di
		push si
		push ax
		push bx
		push cx
		push dx

		mov ax,02
		pushf
		call cs:old_mouse
				
		mov ax,cs:ecr_seg
		mov ds,ax
		mov es,ax
		mov si,cs:old_start_pos
		mov di,si
		xor cx,cx
		mov dx,cs:old_end_pos
	invert_car:
		cmp si,dx
		jae no_invert_car
		lodsw
		mov bx,ax
		mov bl,bh
		and bh,10001000b
		not bl
		and bl,01110111b
		or  bl,bh
		mov ah,bl
		stosw
		jmp invert_car
	no_invert_car:
		or cx,cx
		jnz fin_redraw
		not cx
		mov si,cs:start_pos
		mov di,si
		mov di,si
		mov dx,cs:end_pos
		jmp invert_car
	fin_redraw:
	
		mov ax,01
		pushf
		call cs:old_mouse

		pop dx
		pop cx
		pop bx
		pop ax
		pop si
		pop di
		pop es
		pop ds
endp

proc calc_pos_dx
		push ax
		push bx
		push cx
		mov ax,03
		INT33h
		mov ax,cx			;ax=cx=colonne souris
		mov cl,2			;80 col,largeur curseur= 8 pxls
		mov bl,cs:col_40		;40 col,largeur curseur=16 pxls
		shr bl,1
		adc cl,0			;lit la bit0 via ZC
		shr ax,cl			;=div 4 ou 8
		push ax				;ax=(colonne_ecr*2)
		mov ax,dx			;ax=dx=ligne souris
		mov cl,2			;80 col,largeur curseur= 8 pxls
		shr ax,cl			;=div 4 (on div 8 puis mul 2)
		mov bl,cs:col_40
		xor bh,bh
		mov cl,3
		shl bx,cl
		mul bx				;ax=ax*bx
		mov dx,cs:ecr_ofs
		add dx,ax			
		pop ax
		add dx,ax
		pop cx
		pop bx
		pop ax
		ret
endp

proc	int1Ch_ed
		cli
		pushf
		inc cs:mouse_cnt
		jnz no_reset1
		mov cs:mouse_cnt,253d
		mov cs:can_run,00h
no_reset1:
		inc cs:write_cnt
		jnz no_reset2
		mov cs:write_cnt,253d
		mov cs:just_write,00
no_reset2:
		popf
		jmp cs:old_int1Ch
endp

proc 	add_point
		ret
		;
		pushf
		push di
		push ax
		push cx
		lodsb
		xor ah,ah
		add di,ax
		std
		mov cx,04
		mov al,' '
		repne scasb
		jne no_point
		mov byte ptr ds:[di],'.'
no_point:
		pop cx
		pop ax
		pop di
		popf
		ret
endp	add_point

installe:
		call does_mouse_move
		lea dx,Debut
		mov cl,4
		shr dx,cl
		inc dx
		mov ax,3100h
		int 21h

;********************************** la partie qui suit ne reste pas en m‚moire
Debut:
		mov ah,30h
		int 21h
		cmp al,3
		jae Debut1
		lea bx,Er_Ver_Dos
		jmp erreur
Debut1:
		mov ax,0ED00h
		int 2Fh
		mov is_installed,al
		or  al,al
		jz  no_old_set
		mov ax,0ED02h
		int 2Fh
		mov args_flags,bl
no_old_set:
		lea dx,args_to_find
		call litargs
		
		pushf
		xor cx,cx
		mov bh,F_point
		cmp bh,80h
		je  no_F_point
		or  bh,bh
		jz  reset1
		or  ch,0001b
		jmp no_f_point
	reset1:
		or  cl,0001b
	no_f_point:
		mov bh,F_entre
		cmp bh,80h
		je  no_F_entre
		or  bh,bh
		jz  reset2
		or  ch,0010b
		jmp no_f_entre
	reset2:
		or  cl,0010b
	no_f_entre:
		mov bh,F_ligne
		cmp bh,80h
		je  no_F_ligne
		or  bh,bh
		jz  reset3
		or  ch,0100b
		jmp no_f_ligne
	reset3:
		or  cl,0100b
	no_f_ligne:
		mov bh,F_org
		cmp bh,80h
		je  no_F_org
		or  bh,bh
		jz  reset4
		or  ch,1000b
		jmp no_f_org
	reset4:
		or  cl,1000b
	no_f_org:
		mov bl,args_flags
		not cl
		and bl,cl
		or  bl,ch
		mov args_flags,bl
		popf

		jnc param_ok
		or  al,al
		jz  no_param
		lea bx,usage
		jmp erreur	
no_param:
		cmp is_installed,0
		jz  doit_installer
		lea dx,dj_inst
		mov ah,09h
		int 21h
		mov ax,4C01h
		int 21h
param_ok:
		cmp is_installed,0
		jz  Doit_installer

		cmp ah,01h
		jne change_args_flags
		cmp f_visu,0FFh
		jne change_args_flags

		mov ax,0ED02h
		int 2Fh
		call aff_visu
		jmp fin_visu

change_args_flags:
		mov bl,cs:args_flags
		mov ax,0ED01h
		int 2Fh
		mov ah,09h
		lea dx,bascule
		int 21h
		cmp f_visu,0
		je fin_visu
		call aff_visu
fin_visu:
		mov ax,4C00h
		int 21h
Doit_installer:
		xor ax,ax
		int 33h
		or ax,ax
		jnz drv_souris_ok
		lea bx,no_mouse
		jmp erreur
drv_souris_ok:
		;************** Ici les ‚changes d'interruptions
		mov ax,0352Fh
		int 21h
		mov word ptr cs:old_multiplexeur,Bx
		mov word ptr cs:old_multiplexeur+2,Es
		mov al,28h
		int 21h
		mov word ptr cs:old_int28h,Bx
		mov word ptr cs:old_int28h+2,Es
		mov al,33h
		int 21h
		mov word ptr cs:old_mouse,Bx
		mov word ptr cs:old_mouse+2,Es
		mov al,1Ch
		int 21h
		mov word ptr cs:old_int1Ch,Bx
		mov word ptr cs:old_int1Ch+2,Es
		mov al,16h
		int 21h
		mov word ptr cs:old_int_clavier,Bx
		mov word ptr cs:old_int_clavier+2,Es

		push cs
		pop ds
		mov ax,0252Fh
		lea dx,multiplexeur_ed
		int 21h
		mov al,28h
		lea dx,tache_de_fond
		int 21h
		mov al,33h
		lea dx,mouse_ed
		int 21h
		mov al,1Ch
		lea dx,int1Ch_ed
		int 21h
		mov al,16h
		lea dx,Int_clavier
		int 21h

		push cs
		pop ds

		lea dx,dm_inst
		mov ah,09h
		int 21h
		cmp cs:f_visu,0
		je  di_saut
		mov bl,args_flags
		call aff_visu
di_saut:
		jmp installe

Erreur:
		mov ah,09h
		lea dx,Auteur
		int 21h
		mov dx,bx
		int 21h
		mov ax,4CFFh
		int 21h

proc aff_visu
		pushf
		push dx
		push ds
		push es
		push di
		push si
		push ax

		mov ax,cs
		mov es,ax
		mov ds,ax

		mov ah,09h
		lea dx,auteur
		int 21h

		test bl,0001b
		jz  av_saut1
		lea si,Oui
		lea di,etat_pnt
		movsw
		movsb
av_saut1:
		test bl,0010b
		jz  av_saut2
		lea si,oui
		lea di,etat_ent
		movsw
		movsb
av_saut2:
		test bl,0100b
		jz  av_saut3
		lea si,oui
		lea di,etat_sel
		movsw
		movsb
av_saut3:
		test bl,1000b
		jz  av_saut4
		lea si,oui
		lea di,etat_org
		movsw
		movsb
av_saut4:
		lea dx,dm_etat
		int 21h

		pop ax
		pop si
		pop di
		pop es
		pop ds
		pop dx
		popf
		ret
endp

;*************************************

Auteur		db 'DosMouse.com    Version 1.0 Copyright (c) 1997'
		db ' VANBELLE Edouard',10,13,'$'
dm_inst		db 'DosMouse install‚',10,13,'$'
no_mouse	db 'Installation stopp‚e: le driver souris n'' est pas en'
		db ' m‚moire',10,13,'$'
bascule		db 'DosMouse reconfigur‚',10,13,'$'
dj_inst		db 'DosMouse d‚j… install‚',10,13,'$'
Usage		db 10,13,'Syntaxe: DOSMOUSE [/options+|-] [/v] [/r]',10,13
		db 10,13,' V = affiche le mode DosMouse (visualisation des'
		db ' r‚glages)'
		db 10,13,'option peut ˆtre l''une des quatre lettres: P,E,L,C'
		db 10,13,' P = ajout automatique du Point d''extension sur'
		db ' les fichiers'
		db 10,13,' E = simulation de l''appuie de la touche Entr‚e'
		db ' aprŠs une s‚l‚ction'
		db 10,13,' L = d‚placement de la s‚lection avec la souris en'
		db ' mode Ligne horizontale'
		db 10,13,' C = repositionnement de la souris … l''emplacement'
		db ' actuel du Curseur'
		db 10,13,' (chaque option doit ˆtre suivie de + ou - sauf pour'
		db ' ''v'' et ''r'')'
		db 10,13,' + = activation de l''option,    - = d‚sactivation.'
		db 10,13
		db 10,13,' exemple: DOSMOUSE /p+ /e- /v /c+'
		db 10,13,'       (par d‚faut, DosMouse d‚sactive chaque'
		db ' option)',10,13,'$'
Er_Ver_dos	db 10,13,' Version Ms-Dos trop ancienne',10,13,'$'
Oui		db 'Oui'
dm_Etat		db 10,13,'Etat de dosmouse:'
		db 10,13,' ajout automatique du Point d''extension sur'
		db ' les fichiers              : '
etat_pnt	db 'Non'
		db 10,13,' simulation de l''appuie de la touche Entr‚e aprŠs'
		db ' une s‚lection       : '
etat_Ent	db 'Non'
		db 10,13,' d‚placement de la s‚lection avec la souris en mode'
		db ' Ligne horizontale : '
etat_sel	db 'Non'
		db 10,13,' repositionnement de la souris … l''emplacement'
		db ' actuel du Curseur      : '
etat_org	db 'Non'
		db 10,13,'$'

F_point		db 80h
F_entre		db 80h
F_ligne		db 80h
F_Org		db 80h
F_Visu		db 0
Is_Installed	db 0
;ReInstalle	db 0

args_on		equ '+'
args_off	equ '-'

Include litargs.inc

args_to_find label word
		dw offset f_point
		db 'P',1,0
		dw offset f_entre
		db 'E',1,0
		dw offset f_ligne
		db 'L',1,0
		dw offset f_org
		db 'C',1,0
		dw offset f_visu
		db 'V',0
		dw 0FFFFh

End	Dos_Mouse

; **************** VANBELLE Edouard *********************** Fin de programme **
