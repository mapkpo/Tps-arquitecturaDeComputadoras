# Bypass WB -> ID: dos instrucciones independientes entre ambos.
# Resultado: x1=9, x2=18, x10=11, x11=22. Sin stall.
# En el paso 5 coinciden WB del productor e ID del consumidor:
# A y B quedan en 9 en ID/EX. En el paso 6, el add calcula 18.
addi x1, x0, 9
addi x10, x0, 11
addi x11, x0, 22
add  x2, x1, x1
halt
