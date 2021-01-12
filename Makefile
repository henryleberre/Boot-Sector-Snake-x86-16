build: snake.asm
	nasm -f bin ./snake.asm -o snake.img

run:
	qemu-system-x86_64 -device VGA -drive file=snake.img,format=raw,index=0,media=disk

hex_dump:
	xxd ./snake.img