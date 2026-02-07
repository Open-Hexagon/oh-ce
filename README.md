# Open Hexagon CE

A potential rewrite for Open Hexagon by Vittorio Romeo using Love2D.

*(omg it's finally happening)*

You can get the game [here](https://openhexagon.fun). The website gets the latest action artifacts via webhook.

## External dependencies
Apart from the pure lua dependencies that are present in the repository, the game relies on:
- Love2D 12.0 
- SQLite
- libsodium (for server)
- ffmpeg (for video export)

If love is compiled with puc lua 5.1 instead of luajit, the cffi-lua library is also required.

These dependencies may have dependencies of their own.

## Building the video export module
There is a `CMakeLists.txt` for building the c code for the video export. It requires the following dependencies to work:
- cmake
- make
- gcc
- pkg config
- ffmpeg

(Keep in mind that the packages should not be too up to date for the code to compile.)

On debian-based distributions they can be installed with this command:
```
apt install \
    cmake \
    make \
    g++ \
    git \
    pkg-config \
    libavformat-dev \
    libavcodec-dev \
    libswresample-dev \
    libswscale-dev \
    libavutil-dev
```

On arch based distributions they can be installed with this line:
```
pacman -S cmake make gcc libsodium pkgconf ffmpeg
```

On RHEL based distributions (Fedora, OpenSUSE) they can be installed with this line:
```
dnf install cmake make gcc libsodium pkgconf ffmpeg-devel
```

Then you can proceed with building
```
mkdir build && cd build
cmake ..
make
make install
```
The last command will put the libraries inside the repository folder where the game will find them (it will not attempt to put files in standard system directories).

## Server
If you want to run a server with the web api you also need to install other dependencies.
To install openssl headers on a debian-based distribution execute: `apt install libssl-dev`.
On an arch based distribution you can use `pacman -S openssl`.
Then install the lua modules using luarocks: `luarocks --lua-version 5.1 install luasec`

To run the web api server with tls you need to set the environment variables `TLS_KEY` and `TLS_CERT` to point to their respective .pem files.
