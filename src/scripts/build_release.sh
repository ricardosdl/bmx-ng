#!/bin/bash

# WINDOWS
#
# When using git bash on Windows, you can download wget from here : https://eternallybored.org/misc/wget/
# Copy wget.exe into C:\Program Files\Git\mingw64\bin
#
# Download 7za.exe from the 7-Zip extra archive at: https://www.7-zip.org/download.html
# Copy into C:\Program Files\Git\mingw64\bin
#

usage() {
	echo "Usage: "`basename "$0"`" -b <version> [OPTIONS]"
	echo "    -a <arch>    : Force architecture. e.g. x86, x64, arm, arm64, x86x64 (win32 only)"
	echo "    -r <arch>    : Source architecture. e.g. x86, x64, arm, arm64, x86x64 (win32 only)"
	echo "    -b <version> : Use build version. e.g. 0.105.3.35"
	echo "    -p <version> : Package for version. e.g. 0.105.3.35"
	echo "    -l <platform>: Platform. win32, macos, linux, rpi"
	echo "    -w <version> : Windows compiler version. e.g. mingw or llvm. Defaults to mingw"
	echo "    -c           : Don't clean dirs."
	echo "    -m           : Build all modules."
	echo "    -s           : Build samples."
	echo "    -z           : Clean 'zips' dir."
	exit 0
}

abort() {
	echo "Aborting"
	exit 0
}
	
if [[ $# -eq 0 ]] ; then
	usage
fi

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
trap abort SIGINT

test x$1 = x$'\x00' && shift || { set -o pipefail ; ( exec 2>&1 ; $0 $'\x00' "$@" ) | tee release_build_`date +%Y%m%d%H%M%S`.log ; exit $? ; }

echo ""
echo "Script arguments : $@"
echo ""

OPT_ARCH=""
SRC_ARCH=""
BUILD_VERSION=""
EXE=""
PLATFORM=""
RELEASE_URL="https://github.com/bmx-ng/bmx-ng/releases/download/"
CLEAN_DIRS="y"
CLEAN_ZIPS=""
BUILD_SAMPLES=""
PACKAGE_VERSION=""
MINGW_X86="i686-12.2.0-release-posix-dwarf-rt_v10-rev1.7z"
MINGW_X86_URL="https://github.com/niXman/mingw-builds-binaries/releases/download/12.2.0-rt_v10-rev1/i686-12.2.0-release-posix-dwarf-rt_v10-rev1.7z"
MINGW_X64="x86_64-12.2.0-release-posix-seh-rt_v10-rev1.7z"
MINGW_X64_URL="https://github.com/niXman/mingw-builds-binaries/releases/download/12.2.0-rt_v10-rev1/x86_64-12.2.0-release-posix-seh-rt_v10-rev1.7z"
LLVM_MINGW="llvm-mingw-20220323-ucrt-i686"
LLVM_MINGW_ZIP="llvm-mingw-20220323-ucrt-i686.zip"
LLVM_MINGW_URL="https://github.com/mstorsjo/llvm-mingw/releases/download/20220323/llvm-mingw-20220323-ucrt-i686.zip"
WIN_VER="mingw"

PLATFORMS=("win32" "linux" "rpi" "macos")
WIN_MINGW_ARCH=("x86" "x64" "x86x64")
WIN_LLVM_ARCH=("x86" "x64" "arm" "arm64")
MACOS_ARCH=("x64" "arm64")
LINUX_ARCH=("x86" "x64" "arm64")
RPI_ARCH=("arm" "arm64")
WIN_VERS=("mingw" "llvm")

MOD_LIST=("brl" "pub" "maxgui" "audio" "crypto" "image" "mky" "net" "random" "sdl" "steam" "text")
SAMPLE_LIST=("aaronkoolen/AStar/astar_demo.bmx" "birdie/games/tempest/tempest.bmx" "birdie/games/tiledrop/tiledrop.bmx" "birdie/games/zombieblast/game.bmx" "breakout/breakout.bmx" "digesteroids/digesteroids.bmx" "firepaint/firepaint.bmx" "flameduck/circlemania/cmania.bmx" "flameduck/oldskool2/oldskool2.bmx" "hitoro/fireworks.bmx" "hitoro/shadowimage.bmx" "simonh/fireworks/fireworks.bmx" "simonh/snow/snowfall.bmx" "spintext/spintext.bmx" "starfieldpong/starfieldpong.bmx" "tempest/tempest.bmx")

get_arch() {
	ARCH=`uname -m`
}

validate_arch() {
	VAL_ARCH=$1
	TYPE=$2

	case "$PLATFORM" in
		win32)
			if [[ ! " ${WIN_VERS[*]} " =~ " ${WIN_VER} " ]]; then
				echo "Invalid compiler version: $WIN_VER"
				exit 1
			fi

			case "$WIN_VER" in
				mingw)
					if [[ ! " ${WIN_MINGW_ARCH[*]} " =~ " ${VAL_ARCH} " ]]; then
						echo "Invalid $TYPE arch for mingw: $VAL_ARCH"
						exit 1
					fi
					;;
				llvm)
					if [[ ! " ${WIN_LLVM_ARCH[*]} " =~ " ${VAL_ARCH} " ]]; then
						echo "Invalid $TYPE arch for llvm: $VAL_ARCH"
						exit 1
					fi
					;;
			esac
			;;
		macos)
			if [[ ! " ${MACOS_ARCH[*]} " =~ " ${VAL_ARCH} " ]]; then
				echo "Invalid $TYPE arch for macos: $VAL_ARCH"
				exit 1
			fi
			;;
		linux)
			if [[ ! " ${LINUX_ARCH[*]} " =~ " ${VAL_ARCH} " ]]; then
				echo "Invalid $TYPE arch for linux: $VAL_ARCH"
				exit 1
			fi
			;;
		rpi)
			if [[ ! " ${RPI_ARCH[*]} " =~ " ${VAL_ARCH} " ]]; then
				echo "Invalid $TYPE arch for rpi: $VAL_ARCH"
				exit 1
			fi
			;;
	esac
}

raspi_test() {
	PI=$( cat /proc/device-tree/model )

	if [[ $PI == Rasp* ]]; then
		PLATFORM="rpi"
		ARCH=""
	fi
}

expand_platform() {
	case "$ARCH" in
		x86_64)
			ARCH="x64"
			;;
		arm*)
			case "$PLATFORM" in
				linux)
					raspi_test
					;;
			esac
			;;
	esac

	if [ ! -z "$OPT_ARCH" ]; then
		validate_arch $OPT_ARCH ""
		

		if [[ "$OPT_ARCH" == *"x86"* ]]; then
			ARCH=x86
		else
			ARCH=$OPT_ARCH
		fi
	fi

	if [ -z "$SRC_ARCH" ]; then
		SRC_ARCH=$OPT_ARCH
	else
		validate_arch $SRC_ARCH "source"
	fi
}

init() {
	get_arch

	if [ ! -z "$PLATFORM" ]; then
		if [[ ! " ${PLATFORMS[*]} " =~ " ${PLATFORM} " ]]; then
			echo "Unknown plaform: $PLATFORM"
			exit 1
		fi
	fi

	if [ -z "$PLATFORM" ]; then
		case "$OSTYPE" in
			darwin*)
				PLATFORM="macos"
				;; 
			linux*)
				PLATFORM="linux"
				raspi_test
				;;
			msys*)
				PLATFORM="win32"
				;;
			*)
				echo "Unknown platform: $OSTYPE"
				exit 1
				;;
		esac
	fi

	expand_platform

	echo "Platform    : " $PLATFORM
	echo "System Arch : " $ARCH
	echo "Source Arch : " $SRC_ARCH
}

clean_dirs() {
	echo "--------------------"
	echo "-   CLEAN DIRS     -"
	echo "--------------------"

	echo "Removing release dir"
	rm -rf release

	echo "Removing temp dir"
	rm -rf temp

	if [ ! -z "$CLEAN_ZIPS" ]; then
		echo "Removing zips dir"
		rm -rf zips
	fi
}

make_dirs() {
	echo "--------------------"
	echo "-    MAKE DIRS     -"
	echo "--------------------"

	if [ ! -d "zips" ]; then
		echo "Creating zips dir"
		mkdir -p zips
	fi

	if [ ! -d "release" ]; then
		echo "Creating release dir"
		mkdir -p release
	fi

	if [ ! -d "temp" ]; then
		echo "Creating temp dir"
		mkdir -p temp
	fi

	case "$PLATFORM" in
		win32)
			if [ ! -d "mingw" ]; then
				echo "Creating mingw dir"
				mkdir -p mingw
			fi

			if [ ! -d "llvm" ]; then
				echo "Creating llvm dir"
				mkdir -p llvm
			fi
			;;
	esac
}

check_base() {
	echo "--------------------"
	echo "-  CHECK BLITZMAX  -"
	echo "--------------------"

	if [ ! -d "BlitzMax" ]; then
		if [ -z "$BUILD_VERSION" ]; then
			echo "BlitzMax missing and no build defined"
			exit 1
		fi

		DOWNLOAD_URL_ARCH=".${SRC_ARCH}"
		ARCHIVE_ARCH="${SRC_ARCH}_"
		case "$PLATFORM" in
			win32)
				if [[ "$OPT_ARCH" == "x86x64" ]]; then
					DOWNLOAD_URL_ARCH=""
					ARCHIVE_ARCH=""
				fi
				;;
		esac

		SUFFIX=".tar.xz"
		URL="${RELEASE_URL}v${BUILD_VERSION}.${PLATFORM}${DOWNLOAD_URL_ARCH}/"
		ARCHIVE="BlitzMax_${PLATFORM}_"

		case "$PLATFORM" in
			win32)
				ARCHIVE="${ARCHIVE}${ARCHIVE_ARCH}"
				SUFFIX=".7z"
				;;
			linux)
				ARCHIVE="${ARCHIVE}${ARCHIVE_ARCH}"
				;;
			rpi) ;;
			macos)
				ARCHIVE="${ARCHIVE}${ARCHIVE_ARCH}"
				SUFFIX=".zip"
				;;
		esac

		ARCHIVE="${ARCHIVE}${BUILD_VERSION}${SUFFIX}"

		if [ ! -f "${ARCHIVE}" ]; then

			URL="${URL}${ARCHIVE}"

			echo "Archive (${ARCHIVE}) not found. Downloading..."

			wget -nv $URL
		fi

		echo "Extracting ${ARCHIVE}"

		case "$PLATFORM" in
			win32)
				7za x ${ARCHIVE}
				;;
			macos)
				unzip -q ${ARCHIVE}
				;;
			*)
				tar -xJf ${ARCHIVE}
				;;
		esac
		
		case "$PLATFORM" in
			macos)
				CUR=`pwd`
				echo "Running init scripts"
				source BlitzMax/run_me_first.command
				cd "$CUR"
				;;
		esac
	else
		echo "Using local BlitzMax"
	fi
}


download() {
	echo "--------------------"
	echo "-    DOWNLOAD      -"
	echo "--------------------"

	# mingw
	case "$PLATFORM" in
		win32)
			case "$WIN_VER" in
				mingw)
					if [[ "$OPT_ARCH" == *"x86"* ]]; then
						if [ ! -f "mingw/$MINGW_X86" ]; then
							echo "Downloading $MINGW_X86"
							wget -nv -P mingw $MINGW_X86_URL
						fi
					fi

					if [[ "$OPT_ARCH" == *"x64"* ]]; then
						if [ ! -f "mingw/$MINGW_X64" ]; then
							echo "Downloading $MINGW_X64"
							wget -nv -P mingw $MINGW_X64_URL
						fi
					fi
					;;
				llvm)
					if [ ! -f "mingw/$MINGW_X86" ]; then
						echo "Downloading $MINGW_X86"
						wget -nv -P mingw $MINGW_X86_URL
					fi

					if [ ! -f "llvm/$LLVM_MINGW_ZIP" ]; then
						echo "Downloading $LLVM_MINGW_ZIP"
						wget -nv -P llvm $LLVM_MINGW_URL
					fi
					;;
			esac
			;;
	esac

	# base
	if [ ! -f zips/bmx-ng.zip ]; then
		echo "Downloading bmx-ng.zip"
		wget -nv -P zips https://github.com/bmx-ng/bmx-ng/archive/master.zip && \
			mv zips/master.zip zips/bmx-ng.zip
	else
		echo "Using local bmx-ng.zip"
	fi

	# apps
	if [ ! -f zips/bcc.zip ]; then
		echo "Downloading bcc.zip"
		wget -nv -P zips https://github.com/bmx-ng/bcc/archive/master.zip && \
			mv zips/master.zip zips/bcc.zip
	else
		echo "Using local bcc.zip"
	fi

	if [ ! -f zips/bmk.zip ]; then
		echo "Downloading bmk.zip"
		wget -nv -P zips https://github.com/bmx-ng/bmk/archive/master.zip && \
			mv zips/master.zip zips/bmk.zip
	else
		echo "Using local bmk.zip"
	fi

	if [ ! -f zips/maxide.zip ]; then
		echo "Downloading maxide.zip"
		wget -nv -P zips https://github.com/bmx-ng/maxide/archive/master.zip && \
			mv zips/master.zip zips/maxide.zip
	else
		echo "Using local maxide.zip"
	fi

	# modules
	for mod in "${MOD_LIST[@]}"
	do
		if [ ! -f zips/${mod}.mod.zip ]; then
			echo "Downloading ${mod}.mod.zip"
			wget -nv -P zips https://github.com/bmx-ng/${mod}.mod/archive/master.zip && \
				mv zips/master.zip zips/${mod}.mod.zip
		else
			echo "Using local ${mod}.mod.zip"
		fi
	done
}

prepare() {
	echo "--------------------"
	echo "-     PREPARE      -"
	echo "--------------------"

	echo "Extracting bmx-ng"
	unzip -q zips/bmx-ng.zip -d release && \
		mv release/bmx-ng-master release/BlitzMax

	rm -rf release/BlitzMax/.github
	rm -rf release/BlitzMax/.gitignore

	mkdir -p release/BlitzMax/mod release/BlitzMax/bin release/BlitzMax/lib

	# copy all to temp
	echo "Copying sources for build (into temp)"
	cp -R release/BlitzMax temp

	# bcc
	echo "Extracting bcc" 
	unzip -q zips/bcc.zip -d release/BlitzMax/src && \
		mv release/BlitzMax/src/bcc-master release/BlitzMax/src/bcc

	unzip -q zips/bcc.zip -d temp/BlitzMax/src && \
		mv temp/BlitzMax/src/bcc-master temp/BlitzMax/src/bcc

	# bmk
	echo "Extracting bmk" 
	unzip -q zips/bmk.zip -d release/BlitzMax/src && \
		mv release/BlitzMax/src/bmk-master release/BlitzMax/src/bmk

	unzip -q zips/bmk.zip -d temp/BlitzMax/src && \
		mv temp/BlitzMax/src/bmk-master temp/BlitzMax/src/bmk

	# maxide
	echo "Extracting maxide" 
	unzip -q zips/maxide.zip -d release/BlitzMax/src && \
		mv release/BlitzMax/src/maxide-master release/BlitzMax/src/maxide

	unzip -q zips/maxide.zip -d temp/BlitzMax/src && \
		mv temp/BlitzMax/src/maxide-master temp/BlitzMax/src/maxide

	# modules
	for mod in "${MOD_LIST[@]}"
	do
		echo "Extracting ${mod}.mod"
		case "$PLATFORM" in
			macos)
				ditto -x -k --sequesterRsrc --rsrc zips/${mod}.mod.zip release/BlitzMax/mod && \
					mv release/BlitzMax/mod/${mod}.mod-master release/BlitzMax/mod/${mod}.mod

				ditto -x -k --sequesterRsrc --rsrc zips/${mod}.mod.zip temp/BlitzMax/mod && \
					mv temp/BlitzMax/mod/${mod}.mod-master temp/BlitzMax/mod/${mod}.mod
				;;
			*)
				unzip -q zips/${mod}.mod.zip -d release/BlitzMax/mod && \
					mv release/BlitzMax/mod/${mod}.mod-master release/BlitzMax/mod/${mod}.mod

				unzip -q zips/${mod}.mod.zip -d temp/BlitzMax/mod && \
					mv temp/BlitzMax/mod/${mod}.mod-master temp/BlitzMax/mod/${mod}.mod
				;;
		esac
	done

	case "$PLATFORM" in
		win32)
			case "$WIN_VER" in
				mingw)
					if [[ "$OPT_ARCH" == *"x86"* ]]; then
						echo "Extracting x86 MinGW"
						7za x mingw/${MINGW_X86}
						mv mingw32 release/BlitzMax/MinGW32x86

						echo "Extracting x86 MinGW (into temp)"
						7za x mingw/${MINGW_X86}
						mv mingw32 temp/BlitzMax/MinGW32x86
					fi

					if [[ "$OPT_ARCH" == *"x64"* ]]; then
						echo "Extracting x64 MinGW"
						7za x mingw/${MINGW_X64}
						mv mingw64 release/BlitzMax/MinGW32x64

						echo "Extracting x64 MinGW (into temp)"
						7za x mingw/${MINGW_X64}
						mv mingw64 temp/BlitzMax/MinGW32x64
					fi
					;;
				llvm)
					echo "Extracting llvm-mingw"
					7za x llvm/${LLVM_MINGW_ZIP}
					mv ${LLVM_MINGW} release/BlitzMax/llvm-mingw

					echo "Extracting llvm-mingw (into temp)"
					7za x llvm/${LLVM_MINGW_ZIP}
					mv ${LLVM_MINGW} temp/BlitzMax/llvm-mingw

					echo "Extracting x86 MinGW (into temp)"
					7za x mingw/${MINGW_X86}
					mv mingw32 temp/BlitzMax/MinGW32x86
					;;
			esac
			;;
	esac

	case "$PLATFORM" in
		macos)
			echo "Copying bootstrap config"
			cp release/BlitzMax/src/bootstrap/bootstrap.cfg release/BlitzMax/bin
			cp temp/BlitzMax/src/bootstrap/bootstrap.cfg temp/BlitzMax/bin
			
			echo "Configuring bootstrap for $PLATFORM/$ARCH"
			echo -e "t\tmacos\t"$ARCH"\n$(cat temp/BlitzMax/bin/bootstrap.cfg)" > temp/BlitzMax/bin/bootstrap.cfg
			
			echo "Copying scripts"
			cp release/BlitzMax/src/macos/build_dist.sh release/BlitzMax
			cp release/BlitzMax/src/macos/run_me_first.command release/BlitzMax
			;;
		esac
	
}

build_apps() {
	echo "--------------------"
	echo "-   BUILD - apps   -"
	echo "--------------------"

	G_OPTION=""
	if [ ! -z "$ARCH" ]; then
		G_OPTION="-g $ARCH"
	fi

	# initial bcc, built with current release
	echo "Building Initial bcc"
	BlitzMax/bin/bmk makeapp -r temp/BlitzMax/src/bcc/bcc.bmx && \
		cp temp/BlitzMax/src/bcc/bcc temp/BlitzMax/bin


	echo "Building Initial bmk"
	if BlitzMax/bin/bmk makeapp -r temp/BlitzMax/src/bmk/bmk.bmx; then
		cp temp/BlitzMax/src/bmk/bmk temp/BlitzMax/bin
	else
		# initial bmk, built with new bcc and current bmk
		echo ""
		echo "Copying current bmk"
		cp BlitzMax/bin/bmk temp/BlitzMax/bin && \
			cp BlitzMax/bin/core.bmk temp/BlitzMax/bin && \
			cp BlitzMax/bin/custom.bmk temp/BlitzMax/bin && \
			cp BlitzMax/bin/make.bmk temp/BlitzMax/bin

		echo "Building Initial bmk"
		if temp/BlitzMax/bin/bmk makeapp -r $G_OPTION -single temp/BlitzMax/src/bmk/bmk.bmx; then
			retries=0
			while [ $retries -lt 30 ]
			do
				cp temp/BlitzMax/src/bmk/bmk temp/BlitzMax/bin 2>/dev/null
				if [ $? -eq 0 ]; then
					break
				else
					echo "bmk is busy... Attempt $((retries + 1))"
					sleep 1
					retries=$((retries + 1))
				fi
			done
			if [ $retries -eq 30 ]; then
				echo "bmk still busy after 30 seconds. Exiting..."
				exit -1
			fi
		else
			echo ""
			echo "Failed to build bmk"
			exit -1
		fi
	fi

	# copy bmk resources
	echo "Copying bmk resources"
	cp temp/BlitzMax/src/bmk/core.bmk temp/BlitzMax/bin && \
		cp temp/BlitzMax/src/bmk/custom.bmk temp/BlitzMax/bin && \
		cp temp/BlitzMax/src/bmk/make.bmk temp/BlitzMax/bin

	case "$PLATFORM" in
		macos)
			echo "Creating bootstrap"
			temp/BlitzMax/bin/bmk makebootstrap -a -r
			
			echo "Copying bootstrap to release"
			mv temp/BlitzMax/dist release/BlitzMax

			echo "Copying bmk resources"
			cp temp/BlitzMax/bin/core.bmk release/BlitzMax/bin && \
			cp temp/BlitzMax/bin/custom.bmk release/BlitzMax/bin && \
			cp temp/BlitzMax/bin/make.bmk release/BlitzMax/bin
			;;
		*)
			# re-build latest bcc with latest release
			echo "Building latest bcc"
			temp/BlitzMax/bin/bmk makeapp -a -r $G_OPTION temp/BlitzMax/src/bcc/bcc.bmx && \
				cp temp/BlitzMax/src/bcc/bcc release/BlitzMax/bin

			# build latest bmk
			echo "Building latest bmk"
			temp/BlitzMax/bin/bmk makeapp -a -r $G_OPTION temp/BlitzMax/src/bmk/bmk.bmx && \
				cp temp/BlitzMax/src/bmk/bmk release/BlitzMax/bin && \
				cp temp/BlitzMax/bin/core.bmk release/BlitzMax/bin && \
				cp temp/BlitzMax/bin/custom.bmk release/BlitzMax/bin && \
				cp temp/BlitzMax/bin/make.bmk release/BlitzMax/bin

			# build latest docmods
			echo "Building docmods"
			temp/BlitzMax/bin/bmk makeapp -r $G_OPTION temp/BlitzMax/src/docmods/docmods.bmx && \
				cp temp/BlitzMax/src/docmods/docmods release/BlitzMax/bin

			# build latest makedocs
			echo "Building makedocs"
			temp/BlitzMax/bin/bmk makeapp -r $G_OPTION temp/BlitzMax/src/makedocs/makedocs.bmx && \
				cp temp/BlitzMax/src/makedocs/makedocs release/BlitzMax/bin

			# build maxide
			echo "Building maxide"
			temp/BlitzMax/bin/bmk makeapp -r $G_OPTION -t gui temp/BlitzMax/src/maxide/maxide.bmx && \
				cp temp/BlitzMax/src/maxide/maxide release/BlitzMax/MaxIDE
			;;
	esac
}

package() {
	echo "--------------------"
	echo "-     PACKAGE      -"
	echo "--------------------"

	echo "Cleanup"
	rm -f release/BlitzMax/mod/image.mod/raw.mod/examples/gh2.rw2

	case "$PLATFORM" in
		win32)
			PACK_ARCH="_$OPT_ARCH"
			if [[ "$OPT_ARCH" == "x86x64" ]]; then
				PACK_ARCH=""
			fi
			ZIP="BlitzMax_win32${PACK_ARCH}_${WIN_VER}_${PACKAGE_VERSION}.7z"
			echo "Creating release zip : ${ZIP}"

			cd release
			7za a -mx9 -mmt4 ../${ZIP} BlitzMax/
			cd ..
			;;
		linux)
			ZIP="BlitzMax_linux_${OPT_ARCH}_${PACKAGE_VERSION}"
			echo "Creating release zip : ${ZIP}"
			
			cd release
			tar -cf ${ZIP}.tar BlitzMax
			xz -z ${ZIP}.tar
			mv ${ZIP}.tar.xz ..
			cd ..
			;;
		rpi)
			ZIP="BlitzMax_rpi_${OPT_ARCH}_${PACKAGE_VERSION}"
			echo "Creating release zip : ${ZIP}"
			
			cd release
			tar -cf ${ZIP}.tar BlitzMax
			xz -z ${ZIP}.tar
			mv ${ZIP}.tar.xz ..
			cd ..
			;;
		macos)
			ZIP="BlitzMax_macos_${OPT_ARCH}_${PACKAGE_VERSION}"
			echo "Creating release zip : ${ZIP}"
			
			cd release
			zip -9 -r -q ${ZIP}.zip BlitzMax
			mv ${ZIP}.zip ..
			cd ..
			;;
	esac
}

build_modules() {
	echo "--------------------"
	echo "- BUILD - modules  -"
	echo "--------------------"

	G_OPTION=""
	if [ ! -z "$ARCH" ]; then
		G_OPTION="-g $ARCH"
	fi

	temp/BlitzMax/bin/bmk makemods -a $G_OPTION
}

build_samples() {
	echo "--------------------"
	echo "- BUILD - samples  -"
	echo "--------------------"

	G_OPTION=""
	if [ ! -z "$ARCH" ]; then
		G_OPTION="-g $ARCH"
	fi

	for sample in "${SAMPLE_LIST[@]}"
	do
		temp/BlitzMax/bin/bmk makeapp -r $G_OPTION temp/BlitzMax/samples/${sample}
	done
}


while getopts ":a:b:p:w:r:l:cfmsz" options; do
	case "${options}" in
		a)
			OPT_ARCH=${OPTARG}
			;;
		r)
			SRC_ARCH=${OPTARG}
			;;
		b)
			BUILD_VERSION=${OPTARG}
			;;
		c)
			CLEAN_DIRS=""
			;;
		z)
			CLEAN_ZIPS="y"
			;;
		m)
			BUILD_MODULES="y"
			;;
		s)
			BUILD_SAMPLEs="y"
			;;
		p)
			PACKAGE_VERSION=${OPTARG}
			;;
		w)
			WIN_VER=${OPTARG}
			;;
		l)
			PLATFORM=${OPTARG}
			;;
		:)
			echo "Error: -${OPTARG} requires an argument."
			exit 1
			;;
	esac
done

init
if [ ! -z "$CLEAN_DIRS" ]; then
	clean_dirs
fi
make_dirs
check_base
download
prepare
build_apps
if [ ! -z "$BUILD_MODULES" ]; then
	build_modules
fi
if [ ! -z "$PACKAGE_VERSION" ]; then
	package
fi
if [ ! -z "$BUILD_SAMPLES" ]; then
	build_samples
fi

echo "--------------------"
echo "-     FINISHED     -"
echo "--------------------"
