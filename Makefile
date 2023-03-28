disk: zig-out/bin/BOOTX64.EFI
	-mkdir uefi/iso
	dd if=/dev/zero of=uefi/iso/boot.img bs=1M count=512 status=progress
	mformat -i uefi/iso/boot.img ::
	mmd -i uefi/iso/boot.img ::/EFI
	mmd -i uefi/iso/boot.img ::/EFI/BOOT
	mcopy -i uefi/iso/boot.img zig-out/bin/BOOTX64.EFI ::/EFI/BOOT
	xorriso -as mkisofs -R -f -e boot.img -no-emul-boot -o uefi/boot.iso uefi/iso

frames:
	-mkdir src/frames
	ffmpeg -i rick-roll-video -s 160x100 -to 00:00:33 src/frames/frame-%05d.tga
	cat src/frames/* > src/video.raw

run:
	qemu-system-x86_64 --bios uefi/OVMF.fd -cdrom uefi/boot.iso

zip: dist
	cp uefi/OVMF.fd dist
	cp uefi/boot.iso dist
	cd dist; zip dist.zip OVMF.fd boot.iso run.sh