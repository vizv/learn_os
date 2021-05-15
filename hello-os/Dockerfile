# stage 1: builder
FROM alpine:latest as builder

RUN apk --no-cache add nasm gcc make

COPY . /usr/src
WORKDIR /usr/src

RUN make hello-os.img

# stage 2: emulator
FROM alpine:latest

RUN apk --no-cache add qemu-system-x86_64 qemu-ui-curses

COPY --from=builder /usr/src/hello-os.img /hello-os.img

CMD ["qemu-system-x86_64", "-curses", "-drive", "file=/hello-os.img,format=raw,index=0,media=disk"]
