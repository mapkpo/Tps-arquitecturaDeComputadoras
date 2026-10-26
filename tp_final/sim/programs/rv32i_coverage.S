# Programa de cobertura del subconjunto RV32I obligatorio.
# No contiene NOPs y finaliza con ebreak (halt del proyecto).

    addi x1,  x0, 5
    addi x2,  x0, -8
    add  x3,  x1, x2
    sub  x4,  x1, x2
    sll  x5,  x1, x1
    srl  x6,  x2, x1
    sra  x7,  x2, x1
    and  x8,  x1, x2
    or   x9,  x1, x2
    xor  x10, x1, x2
    slt  x11, x2, x1
    sltu x12, x2, x1

    andi  x13, x9, 15
    ori   x14, x8, 0x55
    xori  x15, x14, 0xff
    slti  x16, x2, 0
    sltiu x17, x1, 6
    slli  x18, x1, 3
    srli  x19, x2, 2
    srai  x20, x2, 2
    lui   x21, 0xabcde

    addi x22, x0, -128
    sw   x21, 0(x0)
    sb   x22, 1(x0)
    sh   x15, 2(x0)
    lb   x23, 1(x0)
    lbu  x24, 1(x0)
    lh   x25, 2(x0)
    lhu  x26, 2(x0)
    lw   x27, 0(x0)

    beq  x23, x22, beq_taken
    addi x28, x0, 99
    addi x28, x0, 88
beq_taken:
    addi x28, x0, 1

    bne  x1, x2, bne_taken
    addi x28, x0, 77
    addi x28, x0, 66
bne_taken:
    addi x28, x28, 1

    beq  x1, x2, beq_not_taken
    addi x28, x28, 1
beq_not_taken:
    bne  x1, x1, bne_not_taken
    addi x28, x28, 1
bne_not_taken:

    jal  x29, jal_target
    addi x28, x0, 55
    addi x28, x0, 56
jal_target:
    addi x28, x28, 1

    addi x30, x0, 200
    jalr x31, 0(x30)
    addi x28, x0, 44
    addi x28, x0, 45
jalr_target:
    addi x28, x28, 1
    ebreak
