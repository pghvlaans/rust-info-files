#!/bin/bash

# Automatic $PRGNAM.info generator for Rust software. Use this script for
# software that supports both x86-64 and x86 architecture.

# Copyright 2022-2023 K. Eugene Carlson  Tsukuba, Japan 
# All rights reserved.
#
# Redistribution and use of this script, with or without modification, is
# permitted provided that the following conditions are met:
#
# 1. Redistributions of this script must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
#  THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED
#  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO
#  EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
#  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
#  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
#  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
#  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Running this script in a dedicated directory for your Rust package would be
# convenient (a DEBUG directory with files from intermediate steps is
# generated).

# Information about the program goes here
PRGNAM=${PRGNAM:-ncspot}
VERSION=${VERSION:-1.0.0}
HOMEPAGE=${HOMEPAGE:-https://github.com/hrkfdn/ncspot}
REQUIRES=${REQUIRES:-rust16}
MAINTAINER=${MAINTAINER:-"K. Eugene Carlson"}
EMAIL=${EMAIL:-kvngncrlsn@gmail.com}

# Change the following, if necessary
ARCHIVE=${ARCHIVE:-$PRGNAM-$VERSION.tar.gz}
# Command to extract the tarball
TARCMD=${TARCMD:-"tar xf $ARCHIVE"}
PRGDIR=${PRGDIR:-$PRGNAM-$VERSION}
# Package tarball download
URL=${URL:-https://github.com/hrkfdn/ncspot/archive/v$VERSION/$PRGNAM-$VERSION.tar.gz}

# Rust crates come from here
WEBADDR="https://static.crates.io/crates/"

rm -rf DEBUG CRATES $ARCHIVE $PRGDIR

wget $URL || exit
$TARCMD || exit

sleep 10

# Get name and version for Crate dependencies
grep -e ^name -e ^version $PRGDIR/Cargo.lock | grep \" | cut -d \" -f2- | tr -d \" > deps
# Get checksum as well
grep ^checksum $PRGDIR/Cargo.lock | grep \" | cut -d \" -f2- | tr -d \" > checksums

echo DOWNLOAD='"'$URL \\ > DOWNLOADS

# Generating depsgood; name of crate with suffix and version info
while read -r line; do
  # Even-numbered lines in the deps document are version numbers
  linemod=$((linecount % 2))
  if [ "$linemod" = 0 ]; then
    echo '          '"$WEBADDR$line/$line" | tr \\n \- >> DOWNLOADS
  else
    echo "$line".crate \\ >> DOWNLOADS
  fi

  if [ "$linemod" = 0 ]; then
    echo $line | tr \\n \- >> depsgood
  else
    echo $line.crate >> depsgood
  fi
  linecount=$((linecount + 1))
done < deps

# Don't actually use crates without checksums (not for download)
grep -v -e ^$ -e ^# $PRGDIR/Cargo.lock > ignore1
cat ignore1 | tr -d \\n > ignore2
sed -i 's|package]]|package]]\n|g' ignore2 
grep -v "checksum =" ignore2 > ignore3
grep ^name ignore3 > ignore4
while read -r line; do
  echo $line | cut -d\" -f2- | cut -d\" -f-3 >> ignore
done < ignore4
sed -i 's|"version = "|-|g' ignore
sed -i 's|$|.crate|g' ignore
sed -i 's|^| -e |g' ignore
cat ignore | tr -d \\n > greparg

# Use constructed grep argument to ignore
if [ $(cat greparg | wc -c) -gt 0 ]; then
  grep -v $(cat greparg) depsgood > depsgood2
  grep -v $(cat greparg) DOWNLOADS > DOWNLOADS2
  mv depsgood2 depsgood
  mv DOWNLOADS2 DOWNLOADS
fi
sed -i '$ s| \\|"|' DOWNLOADS

# Quick cleanup
rm -f ignore*

source ./DOWNLOADS
mkdir -p CRATES
cd CRATES
wget $DOWNLOAD || exit
cd ..

# Using depsgood, check sha256sum
COUNT=0
while read -r crate; do
  sha256=$(sha256sum CRATES/$crate | cut -d' ' -f-1)
  COUNT=$((COUNT + 1))
  cksum=$(head -n $COUNT checksums | tac | head -n 1)
  [ $sha256 != $cksum ] && echo $crate has a bad sha256sum! && exit
done < depsgood

echo MD5SUM='"'$(md5sum $ARCHIVE | cut -d' ' -f-1) \\ > MD5SUMS

# Getting md5sums based on depsgood list (ensures the sums don't get mixed up)
while read -r crate; do
  md5=$(md5sum CRATES/$crate | cut -d' ' -f-1)
  echo '        '$md5 \\ >> MD5SUMS
done < depsgood
sed -i '$ s| \\|"|' MD5SUMS

# Putting $PRGNAM.info together
cat << EOF > $PRGNAM.info
PRGNAM="$PRGNAM"
VERSION="$VERSION"
HOMEPAGE="$HOMEPAGE"
$(cat DOWNLOADS MD5SUMS)
DOWNLOAD_x86_64=""
MD5SUM_x86_64=""
REQUIRES="$REQUIRES"
MAINTAINER="$MAINTAINER"
EMAIL="$EMAIL"
EOF

# Cleaning up; see the DEBUG directory for intermediate documents.
mkdir DEBUG
mv DOWNLOADS MD5SUMS deps depsgood checksums greparg DEBUG/

# EXTRA: handle the SlackBuild as well.
cp ncspot.SlackBuild.base ncspot.SlackBuild
sed -i "s/%VER%/$VERSION/g" ncspot.SlackBuild

rm -rf EXPORT
mkdir EXPORT
mv ncspot.SlackBuild ncspot.info EXPORT

# Generate the manpage and shell completions
export PATH=$HOME/.cargo/bin:/opt/rust16/bin:$PATH
export LD_LIBRARY_PATH=/opt/rust16/lib64

[ ! -x $HOME/.cargo/bin/cargo-xtask ] && cargo install cargo-xtask
cd $PRGDIR
cargo run --package xtask -- generate-manpage
cargo run --package xtask -- generate-shell-completion --shells=bash,zsh,fish,powershell,elvish
cd misc
tar cavf ncspot-misc-$VERSION.tar _ncspot _ncspot.ps1 ncspot.1 ncspot.bash ncspot.fish ncspot.elv
mv ncspot-misc-$VERSION.tar $HOME/Builds/RUST-INFO-DIRS/ncspot-info/EXPORT
