; =============================================================================
; MODULE: EXIT (Init)
; =============================================================================

global exit_main_executor
exit_main_executor:
    mov qword [exfs_cur_dir_lba], 38
    ret
