**rust-info-files**

For Slackware script build script maintainers. Generate `*.info` files for `rust` software automatically using the scripts in this repository.

When putting together a SlackBuild for `rust` software, writing the `info` file is by far the most daunting task. Most projects require hundreds of crates, all of which must be found in `Cargo.lock`, downloaded, verified for `sha256` sums and finally written to the file, complete with `md5` sums, all in the proper order. Without automation, a simple script update could easily turn into an all-day project.

The scripts in this repository are meant to turn those potential tedious hours into minutes or seconds.

* `rust-info.sh`: Generate a `*.info` file for a SlackBuild supporting all architectures.
* `rust64-info.sh`: Generate a `*.info` file for a SlackBuild supporting x86_64 only.

Internet access is required, but everything can be done as a non-root user. The procedure is straightforward:

* Copy the required script to a dedicated directory.
* Insert (or supply as variables) the following information:
  * `PRGNAM`: The name of the program.
  * `VERSION`
  * `HOMEPAGE`
  * `REQUIRES`
  * `MAINTAINER`
  * `EMAIL`
  * `ARCHIVE`: The file name of the source archive.
  * `TARCMD`: The command needed to extract the source archive.
  * `PRGDIR`: The directory name of the extracted source archive.
  * `URL`: The download URL of the source tarball.
* Run the script.

The source archive will be downloaded and extracted, and all crate names and versions will be found in `Cargo.lock`. The crates will then be downloaded and checked for `sha256` sums. If all is well, the end result is an `info` file, complete with all sources and `md5` sums.

Although I have never encountered errors with this iteration of the script, please feel free to make an issue or contact me directly if problems do occur.

