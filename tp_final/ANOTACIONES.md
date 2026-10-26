Progam counter avanza en 4 bits, 0x00 >>> 0x04. Procesador de 32 bits

Arquitectura Hardvard: memoria se divide en; ambas de 4KB, se puede acceder simultaneamente a ambas. 
IMEM: memoria de instrucciones y DMEM: memoria de datos. Ambas estan mapeadas con BLOCK RAM, son volatiles.
    4096 bytes, con direcciones de `0` a `4095` (`0xFFF`).

Stall: frena la ejecucion de instrucciones, no avanza el PC.
Burbuja: pone el bit valid en 0, la etapa avanza sin una instrucción válida, es como un NOP.
Flush: se elimina una instruccion poniendo burbujas en todas sus etapas.

Para resolver dependencias se implementaron forwarding, bypass de WB a ID y stalls para el caso load-use. Los saltos se resuelven en EX y limpian las instrucciones incorrectas del pipeline.
Politica de saltos: PREDECIMOS NO TOMADO

Etapas del pipeline
1. IF (instruction fetch) se buscan las instrucciones de memoria y se actualiza el program counter.
2. ID (instruction decode) se decodifican las instrucciones, genera el inmediato y lee registros.
3. EX (exceute) ejecuta la ALU, compara branches y calcula direcciones de memoria o saltos.
4. MEM (memory) realiza lecturas y escrituras en la memoria de datos.
5. WB (write back): escribe el resultado final en el banco de registros.

"GENERAR EL INMEDIATO": extraer de la instrucción un valor numérico que viene codificado dentro de ella y convertirlo a 32 bits para poder utilizarlo.
ejemplo:    addi x5, x2, 10  >>>>  x5 = x2 + 10

Hazzards estructurales:
    cuando dos etapas necesitan el mismo recurso al mismo tiempo. Por ejemplo, IF quiere buscar una instrucción mientras MEM quiere acceder a datos.
    Cómo los mitigamos: usamos arquitectura Harvard, con memorias separadas:
        IF accede a la memoria de instrucciones (IMEM).
        MEM accede a la memoria de datos (DMEM).
        Así ambas operaciones pueden realizarse simultáneamente.    Osea no tenemos hazzard estructural por diseño.

Hazzards de datos:
    cuando una instruccion necesita el resultado de la anterior que todavia no escribió en memoria. En nuestro caso el problema son las RAW (read after write), porque todos escriben solo en WB y todas van en orden.
      Los mitigamos mediante: forwarding (un cable que lleva el dato a otra etapa directamente sin esperar que se escriba y vuelva a leer el banco de registros)
        Tenemos de:
            EX/MEM ---> EX
            MEM/WB ---> EX
            Forwarding para store: cuando el dato que se quiere guardar acaba de ser calculado y 
                todavía no fue escrito en el banco de registros
            Bypass WD: envia un valor de WB directo a ID (evita leer un valor viejo cuando un
               registro se escribe y se lee en el mismo ciclo.)
            Load-use: cuando una instrucción usa inmediatamente el dato que está cargando un load,
                el dato no está disponible hasta después de MEM, por lo que no alcanza con        
                    forwarding. Se hace un stall, luego se usa el forwarding de MEM a EX.

Hazards de control: 
    cuando tenemos branches y saltos que todavia no sabemos cual sera la siguiente instruccion.
        Lo mitigamos mediante deteccion en EX, redirección del PC y flush del pipeline.
            Hacemos un "flush" ponemos en 0 el bit "valid" de las etapas del camino mal predecido y esto hace que se generen burbujas, asi no se ejecutan las instrucciones de esa etapa.


Señales de control del pipeline:

    ifid_valid, idex_valid, exmem_valid, memwb_valid:	Indican si cada registro entre etapas contiene una instrucción válida. Con valid=0, su contenido no debe producir efectos.
    load_use_hazard:	Detecta que una instrucción necesita el resultado de una carga inmediatamente anterior. Conserva PC e IF/ID e introduce una burbuja en ID/EX.
    ex_branch_taken:	Indica que se cumplió la condición de beq o bne.
    ex_redirect:	Ordena cambiar el PC por un branch tomado o un salto. También anula las instrucciones jóvenes.
    fetch_stopped:	Impide incorporar nuevas instrucciones mientras las anteriores terminan.
    dmem_access_fault:	Detecta un acceso de datos desalineado o fuera de rango y activa el tratamiento del error.
    rf_write_enable:	Es la habilitación efectiva de escritura del banco de registros. Combina ejecución habilitada, instrucción válida y reg_write.

Señales de control de la debug unit:

    i_start:	    Inicia una ejecución desde PC cero, limpia contadores, registros y validez de pipeline.
    i_enable:	    Permite que el procesador avance. En pausa vale 0; un Step lo activa durante un ciclo.
    i_rst:	        Reinicia el estado del core.
    o_running:	    Indica que hay una ejecución iniciada que todavía no terminó. Puede seguir en 1 durante una pausa.
    o_halted:	    Indica que el core terminó y el pipeline quedó vacío.
    o_stop_cause:	Informa el motivo de parada: halt, instrucción ilegal, error de dirección, etc.


tiempos:    100mhz no cerraba WNS -0.184 ns

    WNS 0.376 ns    setup tiempo donde llega el dato y esta estable (Registro de origen → lógica y conexiones → registro de destino)
    WHS 0.039 ns    hold  margen de tiempo donde se esta leyendo un dato.


camino que mas tiempo tarda:
    es desde la memoria de datos hasta el registro de memoria del core.
    5.064 ns
    desde la lecura en flanco negativo hasta su recepcion en flanco positivo tenemos 5.064 de los 5.556 ns disponibles del clock

    se prodria mejorar si, agregando un registo intermedio es la forma mas facil, 
                        mejorar el enrutado o el lugar del registro.




            
    