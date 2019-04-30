# Compile FFmpeg and all its dependencies to JavaScript.
# You need emsdk environment installed and activated, see:
# <https://kripken.github.io/emscripten-site/docs/getting_started/downloads.html>.

PRE_JS = build/pre.js
LIBRARY_JS = build/library.js
POST_JS_SYNC = build/post-sync.js
POST_JS_WORKER = build/post-worker.js

COMMON_FILTERS = aresample scale crop overlay
# DEMUXER 解轨器
# COMMON_DEMUXERS = matroska ogg avi mov flv mpegps image2 mp3 concat
COMMON_DEMUXERS = avi mov image2 mp3 gif
# DECODER 解码器
# COMMON_DECODERS = \
# 	vp8 vp9 theora \
# 	mpeg2video mpeg4 h264 hevc \
# 	png mjpeg \
# 	vorbis opus \
# 	mp3 ac3 aac \
# 	ass ssa srt webvtt
COMMON_DECODERS = \
	h264 hevc \
	mjpeg \
	mp3 ac3 aac \
	gif

WEBM_MUXERS = webm ogg null image2
WEBM_ENCODERS = libvpx_vp8 libopus mjpeg
FFMPEG_WEBM_BC = build/ffmpeg-webm/ffmpeg.bc
LIBASS_PC_PATH = ../freetype/dist/lib/pkgconfig:../fribidi/dist/lib/pkgconfig
FFMPEG_WEBM_PC_PATH_ = \
	$(LIBASS_PC_PATH):\
	../libass/dist/lib/pkgconfig:\
	../opus/dist/lib/pkgconfig
FFMPEG_WEBM_PC_PATH = $(subst : ,:,$(FFMPEG_WEBM_PC_PATH_))
LIBASS_DEPS = \
	build/fribidi/dist/lib/libfribidi.so \
	build/freetype/dist/lib/libfreetype.so
WEBM_SHARED_DEPS = \
	$(LIBASS_DEPS) \
	build/libass/dist/lib/libass.so \
	build/opus/dist/lib/libopus.so \
	build/libvpx/dist/lib/libvpx.so

MP4_MUXERS = mp4 mp3 null image2
MP4_ENCODERS = libx264 libmp3lame aac mjpeg
FFMPEG_MP4_BC = build/ffmpeg-mp4/ffmpeg.bc
FFMPEG_MP4_PC_PATH = ../x264/dist/lib/pkgconfig
MP4_SHARED_DEPS = \
	build/lame/dist/lib/libmp3lame.so \
	build/x264/dist/lib/libx264.so

MPEG_MUXERS = mpegts null
MPEG_ENCODERS = mpeg1video
FFMPEG_MPEG_BC = build/ffmpeg-mpeg/ffmpeg.bc
FFMPEG_MPEG_PC_PATH =
MPEG_SHARED_DEPS =

GIF_MUXERS = gif
GIF_ENCODERS = gif

all: webm mp4 mpeg
webm: ffmpeg-webm.js ffmpeg-worker-webm.js
mp4: ffmpeg-mp4.js ffmpeg-worker-mp4.js
mpeg: ffmpeg-mpeg.js ffmpeg-mpeg.asm.js ffmpeg-worker-mpeg.js

clean: clean-js \
	clean-freetype clean-fribidi clean-libass \
	clean-opus clean-libvpx clean-ffmpeg-webm \
	clean-lame clean-x264 clean-ffmpeg-mp4
clean-js:
	rm -f -- ffmpeg*.js
clean-opus:
	-cd build/opus && rm -rf dist && make clean
clean-freetype:
	-cd build/freetype && rm -rf dist && make clean
clean-fribidi:
	-cd build/fribidi && rm -rf dist && make clean
clean-libass:
	-cd build/libass && rm -rf dist && make clean
clean-libvpx:
	-cd build/libvpx && rm -rf dist && make clean
clean-lame:
	-cd build/lame && rm -rf dist && make clean
clean-x264:
	-cd build/x264 && rm -rf dist && make clean
clean-ffmpeg-webm:
	-cd build/ffmpeg-webm && rm -f ffmpeg.bc && make clean
clean-ffmpeg-mp4:
	-cd build/ffmpeg-mp4 && rm -f ffmpeg.bc && make clean
clean-ffmpeg-mpeg:
	-cd build/ffmpeg-mpeg && rm -f ffmpeg.bc && make clean

build/opus/configure:
	cd build/opus && ./autogen.sh

build/opus/dist/lib/libopus.so: build/opus/configure
	cd build/opus && \
	emconfigure ./configure \
		CFLAGS=-O3 \
		--prefix="$$(pwd)/dist" \
		--disable-static \
		--disable-doc \
		--disable-extra-programs \
		--disable-asm \
		--disable-rtcd \
		--disable-intrinsics \
		&& \
	emmake make -j8 && \
	emmake make install

build/freetype/builds/unix/configure:
	cd build/freetype && ./autogen.sh

# XXX(Kagami): host/build flags are used to enable cross-compiling
# (values must differ) but there should be some better way to achieve
# that: it probably isn't possible to build on x86 now.
build/freetype/dist/lib/libfreetype.so: build/freetype/builds/unix/configure
	cd build/freetype && \
	git reset --hard && \
	patch -p1 < ../freetype-asmjs.patch && \
	emconfigure ./configure \
		CFLAGS="-O3" \
		--prefix="$$(pwd)/dist" \
		--host=x86-none-linux \
		--build=x86_64 \
		--disable-static \
		\
		--without-zlib \
		--without-bzip2 \
		--without-png \
		--without-harfbuzz \
		&& \
	emmake make -j8 && \
	emmake make install

build/fribidi/configure:
	cd build/fribidi && ./bootstrap

build/fribidi/dist/lib/libfribidi.so: build/fribidi/configure
	cd build/fribidi && \
	git reset --hard && \
	patch -p1 < ../fribidi-make.patch && \
	emconfigure ./configure \
		CFLAGS=-O3 \
		NM=llvm-nm \
		--prefix="$$(pwd)/dist" \
		--disable-dependency-tracking \
		--disable-debug \
		--without-glib \
		&& \
	emmake make -j8 && \
	emmake make install

build/libass/configure:
	cd build/libass && ./autogen.sh

build/libass/dist/lib/libass.so: build/libass/configure $(LIBASS_DEPS)
	cd build/libass && \
	EM_PKG_CONFIG_PATH=$(LIBASS_PC_PATH) emconfigure ./configure \
		CFLAGS="-O3" \
		--prefix="$$(pwd)/dist" \
		--disable-static \
		--disable-enca \
		--disable-fontconfig \
		--disable-require-system-font-provider \
		--disable-harfbuzz \
		--disable-asm \
		&& \
	emmake make -j8 && \
	emmake make install

build/libvpx/dist/lib/libvpx.so:
	cd build/libvpx && \
	emconfigure ./configure \
		--prefix="$$(pwd)/dist" \
		--target=generic-gnu \
		--disable-dependency-tracking \
		--disable-multithread \
		--disable-runtime-cpu-detect \
		--enable-shared \
		--disable-static \
		\
		--disable-examples \
		--disable-docs \
		--disable-unit-tests \
		--disable-webm-io \
		--disable-libyuv \
		--disable-vp8-decoder \
		--disable-vp9 \
		&& \
	emmake make -j8 && \
	emmake make install

build/lame/dist/lib/libmp3lame.so:
	cd build/lame && \
	git reset --hard && \
	patch -p1 < ../lame-configure.patch && \
	emconfigure ./configure \
		--prefix="$$(pwd)/dist" \
		--host=x86-none-linux \
		--disable-static \
		\
		--disable-gtktest \
		--disable-analyzer-hooks \
		--disable-decoder \
		--disable-frontend \
		&& \
	emmake make -j8 && \
	emmake make install

build/x264/dist/lib/libx264.so:
	cd build/x264 && \
	git reset --hard && \
	patch -p1 < ../x264-configure.patch && \
	emconfigure ./configure \
		--prefix="$$(pwd)/dist" \
		--extra-cflags="-Wno-unknown-warning-option" \
		--host=x86-none-linux \
		--disable-cli \
		--enable-shared \
		--disable-opencl \
		--disable-thread \
		--disable-asm \
		\
		--disable-avs \
		--disable-swscale \
		--disable-lavf \
		--disable-ffms \
		--disable-gpac \
		--disable-lsmash \
		&& \
	emmake make -j8 && \
	emmake make install

# TODO(Kagami): Emscripten documentation recommends to always use shared
# libraries but it's not possible in case of ffmpeg because it has
# multiple declarations of `ff_log2_tab` symbol. GCC builds FFmpeg fine
# though because it uses version scripts and so `ff_log2_tag` symbols
# are not exported to the shared libraries. Seems like `emcc` ignores
# them. We need to file bugreport to upstream. See also:
# - <https://kripken.github.io/emscripten-site/docs/compiling/Building-Projects.html>
# - <https://github.com/kripken/emscripten/issues/831>
# - <https://ffmpeg.org/pipermail/libav-user/2013-February/003698.html>
FFMPEG_COMMON_ARGS = \
	--cc=emcc \
	--enable-cross-compile \
	--target-os=none \
	--arch=x86 \
	--disable-runtime-cpudetect \
	--disable-asm \
	--disable-fast-unaligned \
	--disable-pthreads \
	--disable-w32threads \
	--disable-os2threads \
	--disable-debug \
	--disable-stripping \
	\
	--disable-all \
	--enable-ffmpeg \
	--enable-avcodec \
	--enable-avformat \
	--enable-avutil \
	--enable-swresample \
	--enable-swscale \
	--enable-avfilter \
	--disable-network \
	--disable-d3d11va \
	--disable-dxva2 \
	--disable-vaapi \
	--disable-vdpau \
	$(addprefix --enable-decoder=,$(COMMON_DECODERS)) \
	$(addprefix --enable-demuxer=,$(COMMON_DEMUXERS)) \
	--enable-protocol=file \
	$(addprefix --enable-filter=,$(COMMON_FILTERS)) \
	--disable-bzlib \
	--disable-iconv \
	--disable-libxcb \
	--disable-lzma \
	--disable-securetransport \
	--disable-xlib \
	--disable-zlib

build/ffmpeg-webm/ffmpeg.bc: $(WEBM_SHARED_DEPS)
	cd build/ffmpeg-webm && \
	git reset --hard && \
	patch -p1 < ../ffmpeg-disable-arc4random.patch && \
	patch -p1 < ../ffmpeg-default-font.patch && \
	EM_PKG_CONFIG_PATH=$(FFMPEG_WEBM_PC_PATH) emconfigure ./configure \
		$(FFMPEG_COMMON_ARGS) \
		--disable-sdl \
		$(addprefix --enable-encoder=,$(WEBM_ENCODERS)) \
		$(addprefix --enable-muxer=,$(WEBM_MUXERS)) \
		--enable-filter=subtitles \
		--enable-libass \
		--enable-libopus \
		--enable-libvpx \
		--extra-cflags="-I../libvpx/dist/include" \
		--extra-ldflags="-L../libvpx/dist/lib" \
		&& \
	emmake make -j8 && \
	cp ffmpeg ffmpeg.bc

build/ffmpeg-mp4/ffmpeg.bc: $(MP4_SHARED_DEPS)
	cd build/ffmpeg-mp4 && \
	git reset --hard && \
	patch -p1 < ../ffmpeg-disable-arc4random.patch && \
	EM_PKG_CONFIG_PATH=$(FFMPEG_MP4_PC_PATH) emconfigure ./configure \
		$(FFMPEG_COMMON_ARGS) \
		--disable-sdl2 \
		$(addprefix --enable-encoder=,$(MP4_ENCODERS)) \
		$(addprefix --enable-muxer=,$(MP4_MUXERS)) \
		--enable-gpl \
		--enable-libmp3lame \
		--enable-libx264 \
		--extra-cflags="-I../lame/dist/include" \
		--extra-ldflags="-L../lame/dist/lib" \
		&& \
	emmake make -j8 && \
	cp ffmpeg ffmpeg.bc

build/ffmpeg-mpeg/ffmpeg.bc: $(MPEG_SHARED_DEPS)
	cd build/ffmpeg-mpeg && \
	git reset --hard && \
	patch -p1 < ../ffmpeg-disable-arc4random.patch && \
	patch -p1 < ../ffmpeg-async-stdin-stdout.patch && \
	patch -p1 < ../ffmpeg-always-use-newlines.patch && \
	EM_PKG_CONFIG_PATH=$(FFMPEG_MPEG_PC_PATH) emconfigure ./configure \
		$(FFMPEG_COMMON_ARGS) \
		$(addprefix --disable-decoder=,$(COMMON_DECODERS)) \
		$(addprefix --disable-demuxer=,$(COMMON_DEMUXERS)) \
		$(addprefix --disable-filter=,$(COMMON_FILTERS)) \
		$(addprefix --enable-encoder=,$(MPEG_ENCODERS)) \
		$(addprefix --enable-muxer=,$(MPEG_MUXERS)) \
		--enable-filter=scale \
		--enable-decoder=rawvideo \
		--enable-demuxer=rawvideo \
		--enable-demuxer=image2pipe \
		--enable-parser=mjpeg \
		--enable-decoder=mjpeg \
		--enable-demuxer=mjpeg \
		--enable-protocol=pipe \
		&& \
	emmake make -j8 && \
	cp ffmpeg ffmpeg.bc

# Compile bitcode to JavaScript.
# NOTE(Kagami): Bump heap size to 64M, default 16M is not enough even
# for simple tests and 32M tends to run slower than 64M.
EMCC_COMMON_ARGS = \
	--closure 0 \
	-s TOTAL_MEMORY=67108864 \
	-s ALLOW_MEMORY_GROWTH=1 \
	-O2 --memory-init-file 0 \
	--pre-js $(PRE_JS) \
	-o $@

EMCC_ASMJS_ARGS = \
  -s WASM=0

EMCC_MPEG_ARGS = \
	-s EMTERPRETIFY=1 -s EMTERPRETIFY_ASYNC=1 \
	-s EMTERPRETIFY_WHITELIST='["_main","_ffmpeg_parse_options","_open_files","_open_input_file","_avformat_open_input","_ff_id3v2_read","_id3v2_read_internal","_avio_read","_fill_buffer","_io_read_packet","_ffurl_read","_file_read","_avformat_find_stream_info","_read_frame_internal","_ff_read_packet","_ff_img_read_packet","_rawvideo_read_packet","_av_get_packet","_append_packet_chunked","_transcode","_av_read_frame"]' \
	--js-library $(LIBRARY_JS)

ffmpeg-webm.js: $(FFMPEG_WEBM_BC) $(PRE_JS) $(POST_JS_SYNC)
	emcc $(FFMPEG_WEBM_BC) $(WEBM_SHARED_DEPS) \
		--post-js $(POST_JS_SYNC) \
		$(EMCC_COMMON_ARGS)

ffmpeg-worker-webm.js: $(FFMPEG_WEBM_BC) $(PRE_JS) $(POST_JS_WORKER)
	emcc $(FFMPEG_WEBM_BC) $(WEBM_SHARED_DEPS) \
		--post-js $(POST_JS_WORKER) \
		$(EMCC_COMMON_ARGS) \
		$(EMCC_ASMJS_ARGS) 

ffmpeg-mp4.js: $(FFMPEG_MP4_BC) $(PRE_JS) $(POST_JS_SYNC)
	emcc $(FFMPEG_MP4_BC) $(MP4_SHARED_DEPS) \
		--post-js $(POST_JS_SYNC) \
		$(EMCC_COMMON_ARGS)

ffmpeg-worker-mp4.js: $(FFMPEG_MP4_BC) $(PRE_JS) $(POST_JS_WORKER)
	emcc $(FFMPEG_MP4_BC) $(MP4_SHARED_DEPS) \
		--post-js $(POST_JS_WORKER) \
		$(EMCC_COMMON_ARGS)

ffmpeg-worker-mp4-asm.js: $(FFMPEG_MP4_BC) $(PRE_JS) $(POST_JS_WORKER)
	emcc $(FFMPEG_MP4_BC) $(MP4_SHARED_DEPS) \
		--post-js $(POST_JS_WORKER) \
		$(EMCC_COMMON_ARGS) \
		$(EMCC_ASMJS_ARGS) 

ffmpeg-mpeg.js: $(FFMPEG_MPEG_BC) $(PRE_JS) $(POST_JS_SYNC)
	emcc $(FFMPEG_MPEG_BC) $(MPEG_SHARED_DEPS) \
		--post-js $(POST_JS_SYNC) \
		$(EMCC_COMMON_ARGS) \
		$(EMCC_MPEG_ARGS)

ffmpeg-mpeg.asm.js: $(FFMPEG_MPEG_BC) $(PRE_JS) $(POST_JS_SYNC)
	emcc $(FFMPEG_MPEG_BC) $(MPEG_SHARED_DEPS) \
		--post-js $(POST_JS_SYNC) \
		$(EMCC_COMMON_ARGS) \
		$(EMCC_ASMJS_ARGS) \
		$(EMCC_MPEG_ARGS)

ffmpeg-worker-mpeg.js: $(FFMPEG_MPEG_BC) $(PRE_JS) $(POST_JS_WORKER)
	emcc $(FFMPEG_MPEG_BC) $(MPEG_SHARED_DEPS) \
		--post-js $(POST_JS_WORKER) \
		$(EMCC_COMMON_ARGS) \
		$(EMCC_MPEG_ARGS)
