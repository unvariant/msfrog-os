#!/bin/sh

if ! type "qemu-system-x86_64" &> /dev/null; then
    echo "you do not have QEMU installed"
    echo "MSFROG OS requires QEMU to run"
    exit 1
fi

qemu-system-x86_64 --bios OVMF.fd -cdrom boot.iso