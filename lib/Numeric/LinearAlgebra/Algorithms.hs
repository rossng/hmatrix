{-# OPTIONS_GHC -fglasgow-exts #-}
-----------------------------------------------------------------------------
{- |
Module      :  Numeric.LinearAlgebra.Algorithms
Copyright   :  (c) Alberto Ruiz 2006-7
License     :  GPL-style

Maintainer  :  Alberto Ruiz (aruiz at um dot es)
Stability   :  provisional
Portability :  uses ffi

A generic interface for some common functions. Using it we can write higher level algorithms
and testing properties both for real and complex matrices.

In any case, the specific functions for particular base types can also be explicitly
imported from "Numeric.LinearAlgebra.LAPACK".

-}
-----------------------------------------------------------------------------

module Numeric.LinearAlgebra.Algorithms (
-- * Linear Systems
    linearSolve,
    inv, pinv,
    pinvTol, det, rank, rcond,
-- * Matrix factorizations
-- ** Singular value decomposition
    svd,
    full, economy,
-- ** Eigensystems
    eig, eigSH,
-- ** QR
    qr,
-- ** Cholesky
    chol,
-- ** Hessenberg
    hess,
-- ** Schur
    schur,
-- * Matrix functions
    expm,
    matFunc,
-- * Nullspace
    nullspacePrec,
    nullVector,
-- * Norms
    Normed(..), NormType(..),
-- * Misc
    ctrans,
    eps, i,
-- * Util
    haussholder,
    unpackQR, unpackHess,
    GenMat(linearSolveSVD,lu,eigSH',cholSH)
) where


import Data.Packed.Internal hiding (fromComplex, toComplex, comp, conj)
import Data.Packed
import qualified Numeric.GSL.Matrix as GSL
import Numeric.GSL.Vector
import Numeric.LinearAlgebra.LAPACK as LAPACK
import Complex
import Numeric.LinearAlgebra.Linear
import Data.List(foldl1')

-- | Auxiliary typeclass used to define generic computations for both real and complex matrices.
class (Normed (Matrix t), Linear Matrix t) => GenMat t where
    -- | Singular value decomposition using lapack's dgesvd or zgesvd.
    svd         :: Matrix t -> (Matrix t, Vector Double, Matrix t)
    lu          :: Matrix t -> (Matrix t, Matrix t, [Int], t)
    -- | Solution of a general linear system (for several right-hand sides) using lapacks' dgesv and zgesv.
    --  See also other versions of linearSolve in "Numeric.LinearAlgebra.LAPACK".
    linearSolve :: Matrix t -> Matrix t -> Matrix t
    linearSolveSVD :: Matrix t -> Matrix t -> Matrix t
    -- | Eigenvalues and eigenvectors of a general square matrix using lapack's dgeev or zgeev.
    --
    -- If @(s,v) = eig m@ then @m \<> v == v \<> diag s@
    eig         :: Matrix t -> (Vector (Complex Double), Matrix (Complex Double))
    -- | Similar to eigSH without checking that the input matrix is hermitian or symmetric.
    eigSH'      :: Matrix t -> (Vector Double, Matrix t)
    -- | Similar to chol without checking that the input matrix is hermitian or symmetric.
    cholSH      :: Matrix t -> Matrix t
    -- | QR factorization using lapack's dgeqr2 or zgeqr2.
    --
    -- If @(q,r) = qr m@ then @m == q \<> r@, where q is unitary and r is upper triangular.
    qr          :: Matrix t -> (Matrix t, Matrix t)
    -- | Hessenberg factorization using lapack's dgehrd or zgehrd.
    --
    -- If @(p,h) = hess m@ then @m == p \<> h \<> ctrans p@, where p is unitary
    -- and h is in upper Hessenberg form.
    hess        :: Matrix t -> (Matrix t, Matrix t)
    -- | Schur factorization using lapack's dgees or zgees.
    --
    -- If @(u,s) = schur m@ then @m == u \<> s \<> ctrans u@, where u is unitary
    -- and s is a Shur matrix. A complex Schur matrix is upper triangular. A real Schur matrix is
    -- upper triangular in 2x2 blocks.
    --
    -- \"Anything that the Jordan decomposition can do, the Schur decomposition
    -- can do better!\" (Van Loan)
    schur       :: Matrix t -> (Matrix t, Matrix t)
    -- | Conjugate transpose.
    ctrans :: Matrix t -> Matrix t
    -- | Matrix exponential (currently implemented only for diagonalizable matrices).
    expm :: Matrix t -> Matrix t


instance GenMat Double where
    svd = svdR
    lu  = GSL.luR
    linearSolve = linearSolveR
    linearSolveSVD = linearSolveSVDR Nothing
    ctrans = trans
    eig = eigR
    eigSH' = eigS
    cholSH = cholS
    qr = GSL.unpackQR . qrR
    hess = unpackHess hessR
    schur = schurR
    expm = fst . fromComplex . expm' . comp

instance GenMat (Complex Double) where
    svd = svdC
    lu  = GSL.luC
    linearSolve = linearSolveC
    linearSolveSVD = linearSolveSVDC Nothing
    ctrans = conj . trans
    eig = eigC
    eigSH' = eigH
    cholSH = cholH
    qr = unpackQR . qrC
    hess = unpackHess hessC
    schur = schurC
    expm = expm'

-- | Eigenvalues and Eigenvectors of a complex hermitian or real symmetric matrix using lapack's dsyev or zheev.
--
-- If @(s,v) = eigSH m@ then @m == v \<> diag s \<> ctrans v@
eigSH :: GenMat t => Matrix t -> (Vector Double, Matrix t)
eigSH m | m `equal` ctrans m = eigSH' m
        | otherwise = error "eigSH requires complex hermitian or real symmetric matrix"

-- | Cholesky factorization of a positive definite hermitian or symmetric matrix using lapack's dpotrf or zportrf.
--
-- If @c = chol m@ then @m == c \<> ctrans c@.
chol :: GenMat t => Matrix t ->  Matrix t
chol m | m `equal` ctrans m = cholSH m
       | otherwise = error "chol requires positive definite complex hermitian or real symmetric matrix"

square m = rows m == cols m

det :: GenMat t => Matrix t -> t
det m | square m = s * (product $ toList $ takeDiag $ u)
      | otherwise = error "det of nonsquare matrix"
    where (_,u,_,s) = lu m

-- | Inverse of a square matrix using lapacks' dgesv and zgesv.
inv :: GenMat t => Matrix t -> Matrix t
inv m | square m = m `linearSolve` ident (rows m)
      | otherwise = error "inv of nonsquare matrix"

-- | Pseudoinverse of a general matrix using lapack's dgelss or zgelss.
pinv :: GenMat t => Matrix t -> Matrix t
pinv m = linearSolveSVD m (ident (rows m))

-- | A version of 'svd' which returns an appropriate diagonal matrix with the singular values.
--
-- If @(u,d,v) = full svd m@ then @m == u \<> d \<> trans v@.
full :: Field t 
     => (Matrix t -> (Matrix t, Vector Double, Matrix t)) -> Matrix t -> (Matrix t, Matrix Double, Matrix t)
full svd m = (u, d ,v) where
    (u,s,v) = svd m
    d = diagRect s r c
    r = rows m
    c = cols m

-- | A version of 'svd' which returns only the nonzero singular values and the corresponding rows and columns of the rotations.
--
-- If @(u,s,v) = economy svd m@ then @m == u \<> diag s \<> trans v@.
economy :: Field t 
        => (Matrix t -> (Matrix t, Vector Double, Matrix t)) -> Matrix t -> (Matrix t, Vector Double, Matrix t)
economy svd m = (u', subVector 0 d s, v') where
    (u,s,v) = svd m
    sl@(g:_) = toList s
    s' = fromList . filter (>tol) $ sl
    t = 1
    tol = (fromIntegral (max (rows m) (cols m)) * g * t * eps)
    r = rows m
    c = cols m
    d = dim s'
    u' = takeColumns d u
    v' = takeColumns d v


-- | The machine precision of a Double: @eps = 2.22044604925031e-16@ (the value used by GNU-Octave).
eps :: Double
eps =  2.22044604925031e-16

-- | The imaginary unit: @i = 0.0 :+ 1.0@
i :: Complex Double
i = 0:+1


-- matrix product
mXm :: (Num t, GenMat t) => Matrix t -> Matrix t -> Matrix t
mXm = multiply

-- matrix - vector product
mXv :: (Num t, GenMat t) => Matrix t -> Vector t -> Vector t
mXv m v = flatten $ m `mXm` (asColumn v)

-- vector - matrix product
vXm :: (Num t, GenMat t) => Vector t -> Matrix t -> Vector t
vXm v m = flatten $ (asRow v) `mXm` m


---------------------------------------------------------------------------

norm2 :: Vector Double -> Double
norm2 = toScalarR Norm2

norm1 :: Vector Double -> Double
norm1 = toScalarR AbsSum

data NormType = Infinity | PNorm1 | PNorm2 -- PNorm Int

pnormRV PNorm2 = norm2
pnormRV PNorm1 = norm1
pnormRV Infinity = vectorMax . vectorMapR Abs
--pnormRV _ = error "pnormRV not yet defined"

pnormCV PNorm2 = norm2 . asReal
pnormCV PNorm1 = norm1 . liftVector magnitude
pnormCV Infinity = vectorMax . liftVector magnitude
--pnormCV _ = error "pnormCV not yet defined"

pnormRM PNorm2 m = head (toList s) where (_,s,_) = svdR m
pnormRM PNorm1 m = vectorMax $ constant 1 (rows m) `vXm` liftMatrix (vectorMapR Abs) m
pnormRM Infinity m = vectorMax $ liftMatrix (vectorMapR Abs) m `mXv` constant 1 (cols m)
--pnormRM _ _ = error "p norm not yet defined"

pnormCM PNorm2 m = head (toList s) where (_,s,_) = svdC m
pnormCM PNorm1 m = vectorMax $ constant 1 (rows m) `vXm` liftMatrix (liftVector magnitude) m
pnormCM Infinity m = vectorMax $ liftMatrix (liftVector magnitude) m `mXv` constant 1 (cols m)
--pnormCM _ _ = error "p norm not yet defined"

-- | Objects which have a p-norm.
-- Using it you can define convenient shortcuts: @norm2 = pnorm PNorm2@, @frobenius = norm2 . flatten@, etc.
class Normed t where
    pnorm :: NormType -> t -> Double

instance Normed (Vector Double) where
    pnorm = pnormRV

instance Normed (Vector (Complex Double)) where
    pnorm = pnormCV

instance Normed (Matrix Double) where
    pnorm = pnormRM

instance Normed (Matrix (Complex Double)) where
    pnorm = pnormCM

-----------------------------------------------------------------------

-- | The nullspace of a matrix from its SVD decomposition.
nullspacePrec :: GenMat t
              => Double     -- ^ relative tolerance in 'eps' units
              -> Matrix t   -- ^ input matrix
              -> [Vector t] -- ^ list of unitary vectors spanning the nullspace
nullspacePrec t m = ns where
    (_,s,v) = svd m
    sl@(g:_) = toList s
    tol = (fromIntegral (max (rows m) (cols m)) * g * t * eps)
    rank = length (filter (> g*tol) sl)
    ns = drop rank $ toRows $ ctrans v

-- | The nullspace of a matrix, assumed to be one-dimensional, with default tolerance (shortcut for @last . nullspacePrec 1@).
nullVector :: GenMat t => Matrix t -> Vector t
nullVector = last . nullspacePrec 1

------------------------------------------------------------------------

{-  Pseudoinverse of a real matrix with the desired tolerance, expressed as a
multiplicative factor of the default tolerance used by GNU-Octave (see 'pinv').

@\> let m = 'fromLists' [[1,0,    0]
                    ,[0,1,    0]
                    ,[0,0,1e-10]]
\ 
\> 'pinv' m 
1. 0.           0.
0. 1.           0.
0. 0. 10000000000.
\ 
\> pinvTol 1E8 m
1. 0. 0.
0. 1. 0.
0. 0. 1.@

-}
--pinvTol :: Double -> Matrix Double -> Matrix Double
pinvTol t m = v' `mXm` diag s' `mXm` trans u' where
    (u,s,v) = svdR m
    sl@(g:_) = toList s
    s' = fromList . map rec $ sl
    rec x = if x < g*tol then 1 else 1/x
    tol = (fromIntegral (max (rows m) (cols m)) * g * t * eps)
    r = rows m
    c = cols m
    d = dim s
    u' = takeColumns d u
    v' = takeColumns d v

---------------------------------------------------------------------

-- many thanks, quickcheck!

haussholder :: (GenMat a) => a -> Vector a -> Matrix a
haussholder tau v = ident (dim v) `sub` (tau `scale` (w `mXm` ctrans w))
    where w = asColumn v


zh k v = fromList $ replicate (k-1) 0 ++ (1:drop k xs)
              where xs = toList v

zt 0 v = v
zt k v = join [subVector 0 (dim v - k) v, constant 0 k]


unpackQR :: (GenMat t) => (Matrix t, Vector t) -> (Matrix t, Matrix t)
unpackQR (pq, tau) = (q,r)
    where cs = toColumns pq
          m = rows pq
          n = cols pq
          mn = min m n
          r = fromColumns $ zipWith zt ([m-1, m-2 .. 1] ++ repeat 0) cs
          vs = zipWith zh [1..mn] cs
          hs = zipWith haussholder (toList tau) vs
          q = foldl1' mXm hs

unpackHess :: (GenMat t) => (Matrix t -> (Matrix t,Vector t)) -> Matrix t -> (Matrix t, Matrix t)
unpackHess hf m
    | rows m == 1 = ((1><1)[1],m)
    | otherwise = (uH . hf) m

uH (pq, tau) = (p,h)
    where cs = toColumns pq
          m = rows pq
          n = cols pq
          mn = min m n
          h = fromColumns $ zipWith zt ([m-2, m-3 .. 1] ++ repeat 0) cs
          vs = zipWith zh [2..mn] cs
          hs = zipWith haussholder (toList tau) vs
          p = foldl1' mXm hs

--------------------------------------------------------------------------

-- | Reciprocal of the 2-norm condition number of a matrix, computed from the SVD.
rcond :: GenMat t => Matrix t -> Double
rcond m = last s / head s
    where (_,s',_) = svd m
          s = toList s'

-- | Number of linearly independent rows or columns.
rank :: GenMat t => Matrix t -> Int
rank m | pnorm PNorm1 m < eps = 0
       | otherwise = dim s where (_,s,_) = economy svd m

expm' m = case diagonalize (complex m) of
    Just (l,v) -> v `mXm` diag (exp l) `mXm` inv v
    Nothing -> error "Sorry, expm not yet implemented for non-diagonalizable matrices"
  where exp = vectorMapC Exp

diagonalize m = if rank v == n
                    then Just (l,v)
                    else Nothing
    where n = rows m
          (l,v) = if m `equal` ctrans m
                    then let (l',v') = eigSH m in (real l', v')
                    else eig m

-- | Generic matrix functions for diagonalizable matrices.
matFunc :: GenMat t => (Complex Double -> Complex Double) -> Matrix t -> Matrix (Complex Double)
matFunc f m = case diagonalize (complex m) of
    Just (l,v) -> v `mXm` diag (liftVector f l) `mXm` inv v
    Nothing -> error "Sorry, matFunc requieres a diagonalizable matrix" 