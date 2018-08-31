incbin "smpboot"

times ((($ - $$ + 511) / 512) * 512 + $$ - $) db 0
