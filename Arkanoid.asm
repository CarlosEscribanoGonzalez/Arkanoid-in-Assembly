##################################################
#
# Proyecto de Arquitecturas Gráficas - URJC
#
# AUTORES:
# - Escribano González, Carlos
# - Valero Abella, Cristina
#
# Bitmap Display:
# - Unit width in pixels: 8
# - Unit height in pixels: 8
# - Display width in pixels: 256
# - Display height in pixels: 128
# - Base Adress for Display: 0x10010000 (static data)
#
# Máximo objetivo alcanzado en el proyecto:
# - 3 ampliaciones
#
# Ampliaciones implementadas:
# - Puntos 5, 7 y 8
#
# Instrucciones del juego:
# - La barra se desplaza horizontalmente con las teclas "a" y "d" minúsculas. Pulsando el espacio el juego terminará.
# - Si la bola toca el margen inferior el jugador perderá una vida y automáticamente comenzará de nuevo el juego. Si no quedan vidas el juego acaba.
#
#######################################################

.data
	display: .word	0x10010000

.text
	lw	$s0, display # Se guarda en s0 la dirección del display
	li	$s1, 13 # En s1 se guarda el número correspondiente a la casilla (en la coordenada x) original de la barra
	li	$s2, 5 # En $s2 se guarda el número de vidas del jugador
	li 	$s3, 0x8CD9D3 # Se guarda el color elegido para el fondo en s3
	li	$s4, 0xD52222 # Se guarda el color elegido para la barra en s4
	li 	$s5, 0x40783E # Se guarda el color elegido para la bola en s5
	li	$s6, 0 # Se almacena en $s6 el número de rebotes de la bola en la barra para aumentar la velocidad cada x rebotes
	li	$s7, 50000 # $s7 corresponde al número de iteraciones del bucle de espera
	la	$t9, 0xffff0004 # En $t9 se guarda la entrada por teclado
	li	$t7, 12	# En $t7 se guarda la altura de la casilla original de la pelota (coordenada y)
	li	$t6, 15 # En $t6 se guarda la casilla original de la pelota respecto a las x
	li	$t5, 1	# En t5 se va a guardar la velocidad horizontal de la pelota (1 hacia la derecha, -1 hacia la izquierda)
	li	$t4, -1 # En t4 se va a guardar la velocidad vertical de la pelota (-1 hacia arriba, 1 hacia abajo)
	
pintarFondo:
	add	$t8, $zero, $s7 # Se reestablece el número de iteraciones para que la espera siempre sea la misma en cada bucle del juego
	la	$t0, 0($s0) # El fondo se pinta conforme a $t0 para no tener que alterar el valor almacenado en $s0
buclePintarFondo: # Se hace un loop para pintar el fondo
	sw 	$s3, 0($t0) # Se pinta la dirección almacenada en t0 con el color almacenado en s3
	addi	$t0,$t0,4 # Se le suma 4 a la dirección para obtener la siguiente casilla
	bne	$t0,0x10010800,buclePintarFondo # Si la dirección de la casilla siguiente no corresponde con la de la última casilla + 4 significa 
					   # que el fondo no está del todo pintado, por lo que se deberá seguir pintando. La dirección se ha obtenido 
					   # multiplicando el total de casillas por 4 y sumándoselo a la dirección (en hexadecimal)
		
pintarVidas: # El número de vidas aparece representado arriba a la izquierda en forma de barra de color rojo
	la	$t0, 0($s0)
	add	$t1, $zero, $s2 # El número de vidas se almacena en $t1	
buclePintarVidas:
	sw	$s4, 0($t0)
	addi	$t0, $t0, 4
	sub	$t1, $t1, 1
	bnez	$t1, buclePintarVidas
		
pintarBarra: 	
	add	$t0, $zero, 448 # Se hacen cálculos para, a partir de la posición en x de la barra, obtener su dirección en memoria
	add	$t0, $t0, $s1
	mul	$t0, $t0, 4
	add	$t0, $t0, $s0 # La dirección de memoria se almacena en el registro $t0
	addi	$t1,$t0,20 # Se utiliza $t1 para delimitar el tamaño de la barra
buclePintarBarra: # Se hace un loop para pintar la barra
	sw	$s4, 0($t0) # Se pinta la dirección t0 con el color elegido para la barra
	addi	$t0, $t0, 4 # Se le suma 4 para obtener la siguiente casilla
	bne	$t0, $t1, buclePintarBarra # Se impone la misma condición que en bucle de pintar el fondo
	
pintarBola:
	mul	$t0, $t7, 32 # Se realizan cálculos para obtener la dirección de memoria de la pelota a partir de sus casillas en x e y
	add	$t0, $t0, $t6
	mul	$t0, $t0, 4
	add	$t0, $t0, $s0
	sw	$s5, 0($t0) #Se pinta la posición de la bola con el color elegido para la misma
	beq	$t5, 1, bolaDerecha # Si la velocidad en x es positiva, la pelota se desplazará hacia la derecha. De lo contrario, hacia la izquierda
	
bolaIzquierda:
	subi	$t6, $t6, 1 # Se le resta una casilla en el eje x
	beq	$t6, 0, alterarHorizontal # Si la pelota se encuentra ahora en el margen izquierdo su velocidad se altera para que vaya hacia la derecha
	b	bolaArriba 

bolaDerecha:
	addi	$t6, $t6, 1 # Se le suma una casilla en el eje x
	beq	$t6, 31, alterarHorizontal # Si se encuentra en el margen derecho se altera su velocidad para que vaya hacia la izquierda

bolaArriba:
	beq	$t4, 1, bolaAbajo # Se comprueba la velocidad de la bola, si va hacia abajo se va a la etiqueta pertinente
	subi	$t7, $t7, 1 # Se le resta una casilla en y
	beq	$t7, 0, alterarVertical # Si choca contra el margen superior se invierte su velocidad en el eje y
	b	inputs
	
bolaAbajo:
	addi	$t7, $t7, 1 # Se le suma una casilla en el eje y 
	beq	$t7, 16, reducirVidas # Si choca contra el margen inferior el jugador pierde una vida
	b	colisionBarra
	
reducirVidas: # El número de vidas del jugador disminuye y todos los elementos del juego se reestablecen a su estado inicial
	subi	$s2, $s2, 1
	li	$t7, 12
	li	$t6, 15
	li	$t4, -1
	li	$s1, 13
	sw	$s3, 0($s0)
	li	$s7, 50000
	beq	$s2, 0, end # Si el jugador se ha quedado sin vidas el juego se acaba
	 
colisionBarra:	
	add	$t0, $zero, $s1 # Se guarda en $t0 la posición de la barra para detectar las colisiones de la pelota con la misma
	addi	$t1, $t0, 5 # En $t1 se guarda $t0 + 5 para poder ver las colisiones en toda la longitud de la barra
	bne	$t7, 13, inputs # Para que la pelota colisione debe de estar en la fila número 13, que es la inmediatamente superior a la de la barra
	
bucleColision:
	beq	$t0, $t6, alterarVertical # Si la pelota está en la fila 13 y coincide con uno de las casillas en x de la barra hay colisión
	addi	$t0, $t0, 1 # Si no ha habido colisión en una casilla de la barra puede haberla en la siguiente, por lo que se le suma 1 a $t0
	beq	$t0, $t1, inputs # Si la barra se acaba y no ha habido ninguna colisión se sale del bucle
	b	bucleColision
	
alterarHorizontal: # La velocidad horizontal de la pelota se invierte
	# Se reproduce un efecto de sonido con el syscall 31:
	li	$a0, 90 # En $a0 se almacena el pitch
	li	$a1, 750 # En $a1 se almacena la duración (en ms)
	li	$a2, 13 # En $a2 se almacena el instrumento
	li	$a3, 127 # En $a3 se almacena el volumen
	li	$v0, 31
	syscall
	mul	$t5, $t5, -1
	b 	bolaArriba

alterarVertical: # La velocidad vertical de la pelota se invierte
	# Se reproduce un efecto de sonido con el syscall 31:
	li	$a0, 90 # En $a0 se almacena el pitch
	li	$a1, 750 # En $a1 se almacena la duración (en ms)
	li	$a2, 13 # En $a2 se almacena el instrumento
	li	$a3, 127 # En $a3 se almacena el volumen
	li	$v0, 31
	syscall
	mul	$t4, $t4, -1
	addi	$s6, $s6, 1 # Cada vez que se altera la velocidad en el eje y se suma 1 a $s6
	beq	$s6, 6, aumentarVelocidad # Cada 3 rebotes en la barra (contando con que rebota otras 3 en el techo) se aumenta la velocidad
	b	inputs
	
aumentarVelocidad:
	li	$s6, 0 # Se reinicia $s6 a 0
	sub	$s7, $s7, 5000 # Se reduce el número de iteraciones del bucle de espera y, por lo tanto, la velocidad de la pelota aumenta
	
	
inputs:
	lw	$t0, 0($t9) # En $t0 se carga la información existente en el registro que almacena el input del usuario
	beq	$t0, 100, moverDerecha # Si se presiona "d" se mueve hacia la derecha
	beq	$t0, 97, moverIzquierda # Si se presiona "a" se mueve hacia la izquierda
	beq	$t0, 32, end # Si se presiona espacio el programa termina de ejecutarse
	b 	cooldown # Si se ha presionado cualquier otra tecla o no se ha presionado ninguna no pasa nada
	
moverIzquierda:
	beq 	$s1, 0, cooldown # Si la posición de la barra está en su margen izquierdo no se podrá ir a la izquierda
	addi	$s1, $s1, -1 # La barra se mueve una posicián a la izquierda
	sw	$zero, 0($t9) # Se guarda en la dirección del input del jugador el valor 0 para que no se ejecute la misma indicación en los bucles sucesivos
	b 	cooldown
	
moverDerecha:
	beq	$s1, 27, cooldown # Si la posición de la barra está en su margen derecho no se podrá ir a la derecha
	addi 	$s1, $s1, 1 # La barra se mueve una posición a la derecha
	sw	$zero, 0($t9)
	b 	cooldown
	
cooldown: # Se espera un poco antes de volver a ejecutar todo el código anterior (es decir, ir a la etiqueta pintarFondo que corresponde con el inicio del loop del juego)
	nop
	sub	$t8,$t8,1
	bnez	$t8, cooldown	
	b	pintarFondo
	
end:	
	li	$v0, 17
	la	$a0, 0
	syscall
