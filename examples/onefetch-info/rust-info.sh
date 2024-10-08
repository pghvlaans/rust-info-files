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
PRGNAM=${PRGNAM:-onefetch}
VERSION=${VERSION:-2.21.0}
HOMEPAGE=${HOMEPAGE:-https://github.com/o2sh/onefetch}
REQUIRES=${REQUIRES:-rust-opt}
MAINTAINER=${MAINTAINER:-K. Eugene Carlson}
EMAIL=${EMAIL:-kvngncrlsn@gmail.com}

# Change the following, if necessary
ARCHIVE=${ARCHIVE:-$PRGNAM-$VERSION.tar.gz}
# Command to extract the tarball
TARCMD=${TARCMD:-"tar xf $ARCHIVE"}
PRGDIR=${PRGDIR:-$PRGNAM-$VERSION}
# Package tarball download
URL=${URL:-$HOMEPAGE/archive/$VERSION/$ARCHIVE}

# Rust crates come from here
WEBADDR="https://static.crates.io/crates/"

rm -rf DEBUG CRATES
# Need to be sure the completions are generated by the current version
rm -rf $PRGNAM-*

wget $URL || exit
$TARCMD || exit

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

sed -e "s/%%VERSION%%/$VERSION/g" $PRGNAM.SlackBuild.base > $PRGNAM.SlackBuild

# EXTRA: Need to generate completions with the new version of the program or whatever.
cd $PRGDIR
export PATH=$HOME/.cargo/bin:/opt/rust/bin:$PATH
export LD_LIBRARY_PATH=/opt/rust/lib64
cargo build --release
cd ..

rm -rf EXPORT misc
mkdir -p EXPORT misc
cd misc
NEWBIN=$(find .. -type f -name $PRGNAM)
$NEWBIN --generate bash > onefetch.bash
$NEWBIN --generate zsh > _onefetch
$NEWBIN --generate fish > onefetch.fish
$NEWBIN --generate powershell > _onefetch.ps1
$NEWBIN --generate elvish > onefetch.elv
tar cavf onefetch-misc-$VERSION.tar *
mv onefetch-misc-$VERSION.tar ../EXPORT
cd ..

# Cleaning up; see the DEBUG directory for intermediate documents.
mkdir DEBUG
mv DOWNLOADS MD5SUMS deps depsgood checksums greparg DEBUG/

mv $PRGNAM.SlackBuild $PRGNAM.info EXPORT/
