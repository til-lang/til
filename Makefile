dist/til.release: dist/libtil.so
	ldc2 \
		cli/source/*.d \
		-L-L${PWD}/dist -L-ltil -L-ledit \
		-I=source -I=3rd-parties/editline/source \
		--O2 -of=dist/til.release

dist/til.debug: lib-debug
	ldc2 --d-debug \
		cli/source/*.d \
		-L-L${PWD}/dist -L-ltil -L-ledit \
		-I=source -I=3rd-parties/editline/source \
		--O1 -of=dist/til.debug

debug: lib-debug dist/til.debug

lib-debug:
	ldc2 --d-debug --shared \
		source/til/*.d source/til/commands/*.d source/til/nodes/*.d \
		-L-L${PWD}/dist \
		--O1 -of=dist/libtil.so

dist/libtil.so: dist/libeditline.so dist/libdruntime.so dist/libphobos2.so
	ldc2 --shared \
		source/til/*.d source/til/commands/*.d source/til/nodes/*.d \
		-I=source -I=3rd-parties/editline/source \
		-L-L${PWD}/dist -L-leditline -L-lphobos2 \
		--O2 -of=dist/libtil.so

dist/libphobos2.so:
	gcc -shared -fPIC \
		-lphobos2 \
		-L${PWD}/dist \
		-o dist/libphobos2.so

dist/libdruntime.so:
	gcc -shared -fPIC \
		-ldruntime \
		-o dist/libdruntime.so

dist/libtil_hello.so: packages/hello/hello.d
	ldc2 --shared \
		packages/hello/hello.d \
		-I=source \
		-link-defaultlib-shared \
		-L-L${PWD}/dist -L-ltil \
		--O2 -of=dist/libtil_hello.so

test: dist/libtil_hello.so
	bin/run-examples.sh

clean:
	-rm -f dist/lib*
	-rm -f dist/*.o
	-rm -f dist/til.*

3rd-parties/editline:
	git clone --single-branch --branch v0.0.1 https://github.com/theoremoon/editline-d.git 3rd-parties/editline

dist/libeditline.so: 3rd-parties/editline
	ldc2 --shared 3rd-parties/editline/source/editline/package.d \
		-I=3rd-parties/editline/source \
		-L-ledit \
		-of=dist/libeditline.so
