# Forwarding EX/MEM -> EX: dependencia inmediata, sin stall.
# Resultado: x1=5, x2=10.
# Tras 3 pasos: productor en EX/MEM y consumidor en ID/EX.
# En el paso 4, el add calcula 10 usando el dato reenviado.
addi x1, x0, 5
add  x2, x1, x1
halt
