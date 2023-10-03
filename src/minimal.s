// minimal example for a function that can be called externally

.syntax unified
.cpu cortex-m0plus
.thumb
.global myfunction
.type myfunction,%function
.thumb_func
myfunction:
	add r0,r0,r1
	bx lr
