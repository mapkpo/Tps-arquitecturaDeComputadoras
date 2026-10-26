# Resultado: x1=42, x2=42, x3=84, DMEM[0]=42.
addi x1, x0, 42
sw x1, 0(x0)
lw x2, 0(x0)
add x3, x2, x2
halt
