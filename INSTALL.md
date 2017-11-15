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
