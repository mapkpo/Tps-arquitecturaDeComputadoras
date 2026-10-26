# Forwarding MEM/WB -> EX: una instruccion independiente entre ambos.
# Resultado: x1=7, x2=14, x10=99. Sin stall.
# Tras 4 pasos: productor en MEM/WB y consumidor en ID/EX.
# En el paso 5, el add calcula 14 usando el dato reenviado.
addi x1, x0, 7
addi x10, x0, 99
add  x2, x1, x1
halt
