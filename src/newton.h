#ifndef __NEWTON_H__
#define __NEWTON_H__

#include "polynomial.h"

// fill arrays for points before and after performing the newton iteration on them
__global__ void fillArrays(dfloat ReSpacing, dfloat ImSpacing, Complex *zValsInitial,
                              Complex *zVals, int NRe, int NIm);

// perform Nit iterations of newton's method on a polynomial p
__global__ void newtonIterate(Complex *zVals, Polynomial P, Polynomial Pprime,
                                 int NRe, int NIm, int Nit);

// find all of the unique values in zVals
__host__ __device__ int findSolns(Polynomial P, Complex *solns, Complex *zVals,
                                     int nSolns, int nVals);

// for each val in zVals, find the solution in solns it's closest to
__global__ void findClosestSoln(int *closest, Complex *zVals, int NRe, int NIm,
                                   Complex *solns, int nSolns, int norm);

// L2 distance between two points
__host__ __device__ dfloat L2Distance(Complex z1, Complex z2);

// L1 distance between two points
__host__ __device__ dfloat L1Distance(Complex z1, Complex z2);

#endif
