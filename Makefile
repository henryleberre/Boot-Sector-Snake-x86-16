build: snake.asm
	nasm -f bin ./snake.asm -o snake.img

run:
	qemu-system-x86_64 -device VGA -drive file=snake.img,format=raw,index=0,media=disk

flash_usb:
	dd bs=512 if=./snake.img of=/dev/sdc/

hex_dump:
	xxd ./snake.img
