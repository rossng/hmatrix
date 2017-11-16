# hmatrix installation

This package requires [GHC 7.8](http://www.haskell.org/ghc), [cabal-install](http://www.haskell.org/haskellwiki/Cabal-Install) (available in the [Haskell Platform](http://hackage.haskell.org/platform)), and the development packages for BLAS/[LAPACK](http://www.netlib.org/lapack) and [GSL](http://www.gnu.org/software/gsl).

## Linux ##################################################

### Ubuntu/Debian:

```
$ sudo apt-get install libgsl0-dev liblapack-dev libatlas-base-dev
$ cabal update
$ cabal install hmatrix-tests
```

Other distributions may require additional libraries. They can be given in a `--configure-option`.

Adrian Victor Crisciu has developed an [installation method](http://comments.gmane.org/gmane.comp.lang.haskell.glasgow.user/24976) for systems which don't provide shared LAPACK libraries.

## Mac OS/X ###############################################

GSL must be installed via Homebrew or MacPorts.

### Via Homebrew:

```
$ brew install gsl
$ cabal install hmatrix
```

###  Via MacPorts:

```
$ sudo port install gsl +universal
$ cabal install hmatrix
```

(Contributed by Heinrich Apfelmus, Torsten Kemps-Benedix and Ted Fujimoto).

## Windows ###############################################

### Stack-based build (preferred)

The build process is similar to other OSes, like Linux and OSX. These instructions have been tested with Stack 1.4.0 and 1.5.1.

1) 
```
> stack setup
```

2) Download [OpenBLAS](http://www.openblas.net/) and unzip it to a permanent location.

3) In MSYS2 console of Stack, (`C:\Users\{User}\AppData\Local\Programs\stack\x86_64-windows\msys2-{version}\msys2_shell.bat`)

```
$ cd /.../OpenBLAS
$ pacman -Sy
$ pacman -S make perl gcc-fortran
$ make clean
$ make
$ make install
```

3) In a normal Windows console, build the `hmatrix` base lib. Replace `{User}` and versions as necessary, and check if paths are different on your machine.

```
> stack install --flag hmatrix:openblas --extra-include-dirs=C:\Users\{User}\AppData\Local\Programs\stack\x86_64-windows\msys2-20150512\opt\OpenBLAS\include --extra-lib-dirs=C:\Users\{User}\AppData\Local\Programs\stack\x86_64-windows\msys2-20150512\opt\OpenBLAS\bin --extra-lib-dirs=C:\Users\{User}\AppData\Local\Programs\stack\x86_64-windows\msys2-20150512\usr\lib\gcc\x86_64-pc-msys\6.3.0\
```

#### Troubleshooting

If you install `gcc-fortran` now, you will get `libgfortran` version 7 or later. In `libgfortran` 7, the DLL changed from `libgfortran-3.dll` to `libgfortran-4.dll`. The reference to `libgfortran` was [updated](https://github.com/albertoruiz/hmatrix/commit/f2eadcbadb07aaf93c8e727488c1198ff22e17f2#diff-e5faeafc4e191407dbfa8f9132344ab1R124) in `hmatrix 0.18.1.0`, but this doesn't seem to work on Windows. Here are some steps that might resolve errors about missing libraries:

Try installing the `mingw64` version of `libgfortran`:

```
$ pacman -S mingw-w64-x86_64-toolchain mingw-w64-x86_64-glpk mingw-w64-x86_64-gsl
```

You may need to add `--extra-lib-dirs=C:\Users\{User}\AppData\Local\Programs\stack\x86_64-windows\msys2-20150512\mingw64\bin` when running `stack` commands.

You may also need to make the following changes to the following `hmatrix` Cabal files:

* `packages/base/hmatrix.cabal`
  * From `extra-libraries: libopenblas libgcc_s_seh-1 libgfortran libquadmath-0`
  * To `extra-libraries: openblas, gcc, gfortran-4, quadmath`

* `packages/gsl/hmatrix-gsl.cabal`
  * From `extra-libraries: gsl-0`
  * To `extra-libraries: gsl`

You can run the test suite with:

```
stack test --flag hmatrix:openblas --extra-include-dirs=C:\Users\{User}\AppData\Local\Programs\stack\x86_64-windows\msys2-20150512\opt\OpenBLAS\include --extra-lib-dirs=C:\Users\{User}\AppData\Local\Programs\stack\x86_64-windows\msys2-20150512\opt\OpenBLAS\bin
```

If you get a runtime error about missing `libopenblas.dll`, ensure that the OpenBLAS folder containing this DLL is added to your `PATH` environment variable.

#### Permanently adding paths to `stack.yaml`

If you add the following lines to `stack.yaml`, you should be able to run `stack` commands with just `stack {command} --flag hmatrix:openblas`:

```
extra-include-dirs:
- C:\Users\{User}\AppData\Local\Programs\stack\x86_64-windows\msys2-20150512\opt\OpenBLAS\include
extra-lib-dirs:
- C:\Users\{User}\AppData\Local\Programs\stack\x86_64-windows\msys2-20150512\opt\OpenBLAS\bin
- C:\Users\{User}\AppData\Local\Programs\stack\x86_64-windows\msys2-20150512\usr\lib\gcc\x86_64-pc-msys\6.3.0\
```

### Cabal-based build (not tested)

It should be possible to install the new package `hmatrix >= 0.16` using
the DLLs contributed by Gilberto Camara available in [gsl-lapack-windows.zip](https://github.com/downloads/AlbertoRuiz/hmatrix/gsl-lapack-windows.zip).

1) 
```
> cabal update
```

2) Download and unzip [gsl-lapack-windows.zip](https://github.com/downloads/AlbertoRuiz/hmatrix/gsl-lapack-windows.zip) into a stable folder `%GSL%`

3)
    1) In an MSys shell:
       ```
       $ cabal install hmatrix-0.13.1.0 --extra-lib-dir=${GSL} --extra-include-dirs=${GSL}
       ```

    2) In a normal Windows command prompt:
       ```
       > cabal install --extra-lib-dir=%GSL% --extra-include-dirs=%GSL%
       ```

It may be necessary to put the DLLs in the search path.

It is expected that a future version of the new `hmatrix-gsl` package can also be installed
using this method.

[Download winpack](https://github.com/downloads/AlbertoRuiz/hmatrix/gsl-lapack-windows.zip)

### Alternative Windows build

1) 

```
> cabal update
```

2) Download [OpenBLAS](http://www.openblas.net/) and unzip it to a permanent location.

3) In a normal Windows command prompt:

```
> cabal install --flags=openblas --extra-lib-dirs=C:\...\OpenBLAS\lib --extra-include-dirs=C:\...\OpenBLAS\include
```

## Tests ###############################################

After installation we can verify that the library works as expected:

```
$ cabal install hmatrix-tests
$ ghci
> Numeric.LinearAlgebra.Tests.runTests 20
+++ OK, passed 100 tests.
+++ OK, passed 100 tests.
... etc...
+++ OK, passed 100 tests.
------ some unit tests
Cases: 71  Tried: 71  Errors: 0  Failures: 0
```
