CHOICE_S_2DD:
    db "1 - 720K, full format",13,10
    db "2 - 720K, quick format",13,10
    db 0

CHOICE_S_2HD:
    db "1 - 1.44M, full format",13,10
    db "2 - 1.44M, quick format",13,10
    db 0

CHOICE_S_ERR_NO_DEV:
    db "*** No USB FDD connected, press CTRL+C",13,10,0

CHOICE_S_ERR_NO_DISK:
    db "*** No disk in the drive, press CTRL+C",13,10,0

CHOICE_S_ERR_DISK_INFO:
    db "*** Error retrieving disk type, press CTRL+C",13,10,0

