; This needs to be present in both bank 0 (for the kernel) and bank 1 (for the driver)

	db   0
	;; default dpb
	db   0F9h		; Media F9
	dw   512		; 80 Tracks	
	db   0Fh		; 9 sectors
	db   04h		; 2 sides
	db   01h		; 3.5" 720 Kb
	db   02h
	dw   1
	db   2
	db   112
	dw   14
	dw   714
	db   3
	dw   7