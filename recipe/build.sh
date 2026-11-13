#! /bin/bash
# Prior to conda-forge, Copyright 2014-2019 Peter Williams and collaborators.
# This file is licensed under a 3-clause BSD license; see LICENSE.txt.

set -e

if [[ "$CONDA_BUILD_CROSS_COMPILATION" == "1" ]]; then
  # g-ir-scanner cannot introspect target binaries, so build the GIR/typelib
  # files in a native build against the build prefix and ship those
  unset _CONDA_PYTHON_SYSCONFIGDATA_NAME
  (
    export CC=$CC_FOR_BUILD
    export AR="$($CC_FOR_BUILD -print-prog-name=ar)"
    export NM="$($CC_FOR_BUILD -print-prog-name=nm)"
    export LDFLAGS=${LDFLAGS//$PREFIX/$BUILD_PREFIX}
    export PKG_CONFIG_PATH=$BUILD_PREFIX/lib/pkgconfig
    unset CFLAGS CPPFLAGS CXXFLAGS
    export host_alias=$build_alias

    meson setup native-build \
        -D docs=false \
        -D introspection=enabled \
        --prefix=$BUILD_PREFIX \
        --libdir=$BUILD_PREFIX/lib \
        --wrap-mode=nofallback
    ninja -v -C native-build -j ${CPU_COUNT}
    ninja -C native-build install -j ${CPU_COUNT}

    mkdir -p introspection/gir introspection/typelib
    cp -vap $BUILD_PREFIX/lib/girepository-1.0/{Atk,Atspi}-*.typelib introspection/typelib/
    cp -vap $BUILD_PREFIX/share/gir-1.0/{Atk,Atspi}-*.gir introspection/gir/
  )

  export PKG_CONFIG=$BUILD_PREFIX/bin/pkg-config
  meson setup builddir \
      ${MESON_ARGS} \
      -D docs=false \
      -D introspection=disabled \
      --wrap-mode=nofallback
else
  meson setup builddir \
      -D docs=false \
      --prefix=$PREFIX \
      --libdir=$PREFIX/lib  \
      --wrap-mode=nofallback
fi
ninja -v -C builddir -j ${CPU_COUNT}
ninja -C builddir install -j ${CPU_COUNT}

if [[ "$CONDA_BUILD_CROSS_COMPILATION" == "1" ]]; then
  mkdir -p $PREFIX/lib/girepository-1.0 $PREFIX/share/gir-1.0
  cp -vap introspection/typelib/* $PREFIX/lib/girepository-1.0/
  cp -vap introspection/gir/* $PREFIX/share/gir-1.0/
fi

cd $PREFIX
find . '(' -name '*.la' -o -name '*.a' ')' -delete
rm -rf etc/xdg lib/systemd share/gtk-doc share/locale
