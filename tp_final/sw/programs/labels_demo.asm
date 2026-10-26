# Suma 4+3+2+1. Resultado: x1=0, x2=10, DMEM[0]=10.
addi x1, x0, 4
addi x2, x0, 0
loop:
    add x2, x2, x1
    addi x1, x1, -1
    bne x1, x0, loop
    jal x0, finish
    addi x2, x0, -1  # Se descarta por el salto.
finish:
    sw x2, 0(x0)
    halt
