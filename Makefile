dist/libtil.so: dist/libeditline.so
	ldc2 --shared \
		source/til/*.d source/til/commands/*.d source/til/nodes/*.d \
		-I=source -I=3rd-parties/editline/source \
		-link-defaultlib-shared \
		-L-L${PWD}/dist -L-leditline \
		--O2 -of=dist/libtil.so

lib-debug:
	ldc2 --d-debug --shared \
		source/til/*.d source/til/commands/*.d source/til/nodes/*.d \
		-link-defaultlib-shared \
		-L-L${PWD}/dist \
		--O1 -of=dist/libtil.so

til.release: dist/libtil.so
	ldc2 \
		cli/source/*.d \
		-L-L${PWD}/dist -L-ltil -L-ledit \
		-I=source -I=3rd-parties/editline/source \
		-link-defaultlib-shared \
		--O2 -of=til.release

til.debug:
	ldc2 --d-debug \
		cli/source/*.d \
		-L-L${PWD}/dist -L-ltil -L-ledit \
		-I=source -I=3rd-parties/editline/source \
		-link-defaultlib-shared \
		--O1 -of=til.debug

debug: lib-debug til.debug

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
	-rm -f til.release
	-rm -f til.debug
	-rm -f dist/libtil.*

3rd-parties/editline:
	git clone --single-branch --branch v0.0.1 https://github.com/theoremoon/editline-d.git 3rd-parties/editline

dist/libeditline.so: 3rd-parties/editline
	ldc2 --shared 3rd-parties/editline/source/editline/package.d \
		-I=3rd-parties/editline/source \
		-L-ledit \
		-of=dist/libeditline.so
