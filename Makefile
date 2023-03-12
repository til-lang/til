dist/libnow.a:
	ldc2 --lib \
		-oq -od=build/ \
		source/now/*.d source/now/commands/*.d source/now/nodes/*.d \
		--O2 -of=dist/libnow.a

dist/libnow.debug.a:
	ldc2 --d-debug --lib \
		-oq -od=build/ \
		source/now/*.d source/now/commands/*.d source/now/nodes/*.d \
		--O1 -of=dist/libnow.debug.a

now: dist/libnow.a
	ldc2 \
		cli/source/*.d \
		-L-L${PWD}/dist -L-lnow -L-ledit \
		-I=source -I=3rd-parties/editline/source \
		--O2 -of=now

now.debug: dist/libnow.debug.a
	ldc2 --d-debug \
		cli/source/*.d \
		-L-L${PWD}/dist -L-lnow.debug -L-ledit \
		-I=source -I=3rd-parties/editline/source \
		--O1 -of=now.debug

dist/libnow_hello.so: packages/hello/hello.d
	ldc2 --shared \
		packages/hello/hello.d \
		-I=source \
		-L-L${PWD}/dist -L-lnow \
		--O2 -of=dist/libnow_hello.so

test: dist/libnow_hello.so
	bin/run-examples.sh

clean:
	-rm -f now
	-rm -f now.debug
	-rm -f dist/libnow.*

3rd-parties/editline:
	git clone --single-branch --branch v0.0.1 https://github.com/theoremoon/editline-d.git 3rd-parties/editline

dist/libeditline.so: 3rd-parties/editline
	ldc2 --shared 3rd-parties/editline/source/editline/package.d \
		-I=3rd-parties/editline/source \
		-L-ledit \
		-of=dist/libeditline.so
