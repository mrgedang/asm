; Percobaan pembuatan socket dengan bahasa assembly
; ~GG~
; 12-04-2017

section .data
	pesanuntukmu db './query http://<IPADDRESS>/', 0h
	http db 'http://', 0h
	errkonek db 'Tidak tau caranya terhubung.', 0h
	template db 'GET / HTTP/1.1', 0dh, 0ah, 'Host: ', 0h
	doublecrlf db 0dh, 0ah, 0dh, 0ah, 0h
	buflen equ 200

section .bss
	buf: resb buflen
	iptok: resb 16 
	hexip: resd 1
	sockfd: resb 4
	compiled: resb 2048

section .text
	global _start

; fungsi hitung panjang string
seberapabesar:
	push edi
	push ecx
	mov edi, eax
	mov al, 0h
	mov ecx, -1
	cld
	repne scasb
	mov eax, -1
	sub eax, ecx
	dec eax ; perlu dikurangi 1 setiap pake repe repe
	pop ecx
	pop edi
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; fungsi penampil pesan
tampil:
	push edx
	push ecx
	push ebx
	push eax
	call seberapabesar
	mov edx, eax
	pop eax
	mov ecx, eax
	mov ebx, 1
	mov eax, 4
	int 80h
	mov eax, 0ah
	push eax
	mov edx, 1
	mov ecx, esp
	mov ebx, 1
	mov eax, 4
	int 80h
	pop eax 
	pop ebx
	pop ecx
	pop edx
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; fungsi penanda offset string http://
kalkulasioffsethttp:
	push edx
	push ecx
	push ebx
	mov edx, http
	xor ecx, ecx

masihsama:
	mov bl, byte [edx]
	cmp byte [eax], bl
	jne markipul
	inc eax
	inc edx
	inc ecx
	jmp masihsama

markipul:
	mov eax, ecx
	pop ebx
	pop ecx
	pop edx
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; fungsi penanda offset char /
kalkulasioffsetslash:
	push edi
	push ecx
	mov edi, eax
	mov al, 2fh
	mov ecx, -1
	cld
	repne scasb
	mov eax, -1
	sub eax, ecx
	dec eax ; perlu dikurangi 1 setiap pake repe repe
	pop ecx
	pop edi
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; fungsi parse ip
ambilip:
	push edx
	push ecx
	push ebx
	push eax
	call kalkulasioffsethttp
	cmp eax, 0
	jz nohttp
	jmp adahttp

nohttp:
	call cara
	call keluar

adahttp:
	mov ebx, eax
	pop eax
	add eax, ebx
	push eax
	call kalkulasioffsetslash
	mov ecx, eax
	pop esi
	mov edi, iptok
	repnz movsb
	pop ebx
	pop ecx
	pop edx
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; cari dot, kayak balita
caridot:
	push ecx
	xor ecx, ecx

lanjut:
	cmp byte [eax], 2eh
	je nemudot
	cmp byte [eax], 0
	jz nemudot
	cmp ecx, 3
	je nemudot ; tiga digit terlewati, tidak ada ip 4 digit
	inc eax		; anggap sudah ketemu
	inc ecx
	jmp lanjut

nemudot:
	mov eax, ecx
	pop ecx
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; hitung per octet ip
getoctet: ; eax menyimpan hasil konversi, ebx last dot
	push edx
	push ecx
	push esi
	push eax
	call caridot ; cari dot 
	mov ebx, eax ; simpan letak dot di ebx
	pop eax
	push ebx
	mov esi, eax
	xor eax, eax
	xor ecx, ecx

terus:
	cmp ecx, ebx
	je ending
	xor edx, edx
	mov dl, byte [esi + ecx]
	cmp dl, 30h
	jl ending
	cmp dl, 39h
	jg ending
	cmp dl, 0
	jz ending
	sub dl, 30h
	add eax, edx
	mov edx, 0ah
	mul edx
	inc ecx
	jmp terus

ending:
	mov ebx, 0ah
	div ebx
	pop ebx
	inc ebx
	pop esi
	pop ecx
	pop edx
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; 256 pangkat berapa?
; fungsi khusus untuk konversi ip
pangkatkan:
	push edx
	push ecx
	push ebx
	mov ebx, eax
	xor ecx, ecx
	mov eax, 1 ; inisiasi

lagi:
	cmp ecx, ebx
	je sudah
	mov edx, 100h
	mul edx
	inc ecx
	jmp lagi

sudah:
	pop ebx
	pop ecx
	pop edx
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; fungsi kalkulasi ip address
kalkulasiip:
	push edx
	push ecx
	mov ecx, 4
	; we will count for 4 octet ip
looper:
	cmp ecx, 0
	jz done
	push eax
	call getoctet
	push ebx
	push eax
	mov eax, ecx
	dec eax ; kakehan dadi overflow
	call pangkatkan
	; kalikan octet dengan hasil pemangkatan
	pop ebx ; hexa dari eax getoctet
	mul ebx ; sampai di sini eax berisi konversi octet
	; dimana tempat penyimpanannya?
	add dword [hexip], eax
	pop ebx ; len ebx getoctet
	pop eax ; string ip
	add eax, ebx ; string dipotong sampai dot
	dec ecx
	jmp looper
done: 
	pop ecx
	pop edx
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; socketcall(socket(), args)
buatkansocket:
	push ecx
	push ebx
	push eax
	push 0
	push 1
	push 2
	mov ecx, esp ; stack array pointer
	mov ebx, 1 ; socket
	mov eax, 102 ; socketcall
	int 80h
	mov dword [sockfd], eax
	;;;;; embuh iki, sing penting hemat stack :D
	pop ebx
	pop ebx
	pop ebx
	;;;;;
	pop eax
	pop ebx
	pop ecx
	ret

; socketcall(connect(), args)
cobakonekkesana:
	push ecx
	push ebx
	;;;;;;;;
	; struct sockaddr_in
	push eax ; sin_addr.s_addr (ip)
	push word 0x05000 ; sin_addr.port (80)
	push word 2 ; sin_family (AF_INET)
	mov ecx, esp ; buat pointer ke address struct
	mov ebx, dword [sockfd] ; ambil sockfd
	;;;; argument connect
	push 16 ; size addr
	push ecx ; pointer sockaddr_in
	push ebx ; sockfd
	mov ebx, 3 ; connect
	mov ecx, esp
	mov eax, 102
	int 80h
	pop ebx ; eax digunakan untuk return
	pop ebx
	;;;;;;;
	pop ebx
	pop ebx
	pop ebx
	;;;;;;;
	pop ebx
	pop ecx
	ret

;; susun query
susunquery:
	push eax ; simpan ips
	;;; isi template dulu
	mov eax, template
	call seberapabesar
	mov ecx, eax
	mov esi, template
	mov edi, compiled
	mov al, 0h ; cek null
	repne movsb

	;;; tambahkan ips
	mov eax, compiled
	call seberapabesar
	mov edi, compiled
	add edi, eax
	pop esi
	mov eax, esi
	call seberapabesar
	mov ecx, eax
	mov al, 0h
	repne movsb

	;;; tambahkan double crlf
	mov eax, compiled
	call seberapabesar
	mov edi, compiled
	add edi, eax
	mov esi, doublecrlf
	mov eax, esi
	call seberapabesar
	mov ecx, eax
	mov al, 0h
	repne movsb
	ret

; fungsi pembentuk network byte order
swaporder:
	push edx
	push ecx
	push ebx
	mov ebx, eax
	and eax, 0ff000000h
	shr eax, 24
	push eax
	mov eax, ebx
	and eax, 00ff0000h
	shr eax, 8
	pop ecx
	or eax, ecx
	push eax
	mov eax, ebx
	and eax, 0000ff00h
	shl eax, 8
	pop ecx
	or eax, ecx
	push eax
	mov eax, ebx
	and eax, 000000ffh
	shl eax, 24
	pop ecx
	or eax, ecx
	pop ebx
	pop ecx
	pop edx
	ret

;; tulis request
tulissock:
	push edx
	push ecx
	push ebx
	push eax
	call seberapabesar
	mov edx, eax
	pop eax
	mov ecx, eax
	mov ebx, dword [sockfd]
	mov eax, 4
	int 80h
	pop ebx
	pop ecx
	pop edx
	ret

; tetep harus pakai sys_recv() - 10
; karena read berdasarkan buflen
; sedangkan sys_recv() menunggu data
; mari kita praktek kan
; ssize_t recv(int sockfd, void *buf, size_t len, int flags);
; flag = 256
; len = 81370
; buf 
; sockfd
recvsock:
	push eax
	;;;;;;;;
	push dword 256
	push dword buflen
	push dword buf
	push dword [sockfd]
	mov ecx, esp
	mov ebx, 10
	mov eax, 102
	int 80h
	;;;;;;;
	pop eax
	pop eax
	pop eax
	pop eax
	pop eax
	;;;;;;;
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; ini fungsi nganu
request:
	call ambilip ; ip berada di iptok
	mov eax, iptok
	call kalkulasiip ; hasil kalkulasi di hexip
	call buatkansocket ; return sockfd
	; ip sudah dalam bentuk hexa
	mov eax, dword [hexip]
	call swaporder; swap membentuk network byte order
	call cobakonekkesana
	cmp eax, 0 ; cek apakah error?
	jz bisakonek
	call koneksierror
	call keluar
bisakonek:
	; build query 
	; template + ip sebagai host header
	mov eax, iptok
	call susunquery
	; kirim request
	mov eax, compiled
	call tulissock
	; baca response
	call recvsock ; data ada di buf
	; tampilkan respon
	mov eax, buf
	call tampil

	call keluar
	;;;;;;;
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

koneksierror:
	mov eax, errkonek
	call tampil
	ret

cara:
	mov eax, pesanuntukmu
	call tampil
	ret

keluar:
	mov ebx, 0
	mov eax, 1
	int 80h
	ret

_start:
	pop ecx
	cmp ecx, 1 ; cek apakah argumen hanya nama program tok?
	je pesandariku
	cmp ecx, 2
	je lanjutkan
	jne pesandariku
pesandariku:
	call cara
	call keluar
lanjutkan:
	pop eax ; buang nama program
	pop eax ; ambil argumen pertama
	;call tampil
	call request
	call keluar
