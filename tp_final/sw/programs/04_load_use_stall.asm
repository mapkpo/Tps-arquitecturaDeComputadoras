# Load-use: un stall y luego forwarding MEM/WB -> EX.
# Resultado: x1=42, x2=42, x3=84, DMEM[0]=42.
# El sw prepara la memoria y recibe su dato por forwarding EX/MEM -> EX.
# Tras 4 pasos: lw en ID/EX y add en IF/ID.
# Paso 5: burbuja en ID/EX (valid=0); PC e IF/ID se mantienen.
# Paso 6: lw en MEM/WB y add en ID/EX.
# Paso 7: el add calcula 84 con el dato reenviado.
addi x1, x0, 42
sw   x1, 0(x0)
lw   x2, 0(x0)
add  x3, x2, x2
halt
