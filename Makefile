dist/libtil.so: dist/libeditline.so
	ldc2 --shared source/til/*.d source/til/commands/*.d source/til/nodes/*.d \
		-I=source -I=3rd-parties/editline/source \
		-link-defaultlib-shared \
		-L-L${PWD}/dist -L-leditline -L-ledit \
		--O2 -of=dist/libtil.so

lib-debug:
	ldc2 --d-debug --shared source/til/*.d source/til/commands/*.d source/til/nodes/*.d \
		-I=source -I=3rd-parties/editline/source \
		-link-defaultlib-shared \
		-L-L${PWD}/dist -L-leditline -L-ledit \
		-of=dist/libtil.so

til.release: dist/libtil.so
	ldc2 interpreter/source/app.d \
		-L-L${PWD}/dist -L-ltil -L-ledit \
		-I=source -I=3rd-parties/editline/source \
		-link-defaultlib-shared \
		--O2 -of=til.release

til.debug: dist/libtil.so
	ldc2 --d-debug interpreter/source/app.d \
		-L-L${PWD}/dist -L-ltil -L-ledit \
		-I=source -I=3rd-parties/editline/source \
		-link-defaultlib-shared \
		-of=til.debug

libtil_hellomodule.so: modules/hello/hellomodule.d
	ldc2 --shared modules/hello/hellomodule.d \
		-I=source -I=3rd-parties/editline/source \
		-link-defaultlib-shared \
		-L-L${PWD}/dist -L-ltil -L-ledit \
		--O2 -of=libtil_hellomodule.so

test: libtil_hellomodule.so til.release
	./run-examples.sh

clean:
	rm -f til.release
	rm -f til.debug
	rm -f dist/libtil.so

3rd-parties/editline:
	git clone --single-branch --branch v0.0.1 https://github.com/theoremoon/editline-d.git 3rd-parties/editline

dist/libeditline.so:
	ldc2 --shared 3rd-parties/editline/source/editline/package.d \
		-I=3rd-parties/editline/source \
		-L-ledit \
		-of=dist/libeditline.so
