#include "newton.h"

extern "C"
{
#include "png_util.h"
}

#include <stdlib.h>
#include <string>

// perform the iteration and output to png
int main(int argc, char **argv)
{
    if (argc < 2) {
        printf("Example Usage: ./bin/newton <testName> [NRe=300] NIm=300]\n"
               "               [ReSpacing=3] [ImSpacing=3] [L1=false] [step=false] \n");

        printf("testName  - name of the test, if bigTest or bigTest2, the other "
                "options will be ignored\n");
        printf("NRe       - Number of real points to run iteration on\n");
        printf("NIm       - number of imaginary points to run iteration on\n");
        printf("ReSpacing - if 4, then the real values will be spaced from -4 to 4\n");
        printf("ImSpacing - same as ReSpacing but for the imaginary values\n");
        printf("L1        - true if you want to use L1 norm to measure distance\n");
        printf("step      - true if you want to output a png for each step\n");
        exit(-1);
    }

    // device array pointers
    int     *closest;
    Complex *solns;
    Complex *zValsInitial;
    Complex *zVals;

    // will be initialized below based on which test we use
    dfloat ReSpacing = 3;
    dfloat ImSpacing = 3;
    int norm         = 2;
    bool step        = false;
    int NRe = 500;
    int NIm = 500;

    // characteristics of the polynomial
    int order;
    dfloat *h_coeffs;

    char *testName = argv[1];

    // iterate through command line args and set values
    for (int i = 2; i < argc; ++i) {
        // the value to set - i.e. NRe, L1, step
        char *token = strtok(argv[i], "=");

        // what to set it to
        char *val = strtok(NULL, "=");

        if (token != NULL && val != NULL) {
            if (strcmp(token, "L1") == 0)
                norm = strcmp(val, "true") == 0 ? 1 : 2;

            else if (strcmp(token, "step") == 0)
                step = strcmp(val, "true") == 0 ? true : false;

            else if (strcmp(token, "NRe") == 0)
                // if nothing is specified, set to 3, else to the specified value
                NRe = atoi(val);

            else if (strcmp(token, "NIm") == 0)
                NIm = atoi(val);

            else if (strcmp(token, "ReSpacing") == 0)
                ReSpacing = atoi(val);

            else if (strcmp(token, "ImSpacing") == 0)
                ImSpacing = atoi(val);
        }
    }


    // based on testName - either set the default values for these polynomials, or
    // prompt for a custom polynomial

    // test on -4x^3 + 6x^2 + 2x = 0, which has roots
    // 0, ~1.78, ~-.28 (for debugging)
    if (strcmp(testName, "smallTest") == 0) {

        // create an order 3 polynomial
        order = 3;
        h_coeffs = new dfloat[4] {-4, 6, 2, 0};

        // the spacing on our grid, i.e. 1000 => run iteration on Nx and Ny evenly
        // spaced points from -1000 to 1000 on x and y
        ReSpacing = 4;
        ImSpacing = 4;
    }

    // random polynomial of order 7
    else if (strcmp(testName, "order7") == 0) {
        int max = 10;
        int seed = 123456;
        order = 7;

        // create a random order 7 polynomial
        h_coeffs = randomCoeffs(order, max, seed);

        if (!step) {
            NRe = 1000;
            NIm = 1000;
        }
    }

    // order 12
    else if (strcmp(testName, "order12") == 0) {
        // create a random order 11 polynomial
        int max = 50;
        int seed = 654321;

        order = 12;

        ReSpacing = 2;
        ImSpacing = 2;
        h_coeffs = randomCoeffs(order, max, seed);

        if (!step) {
            NRe = 1000;
            NIm = 1000;
        }
    }

    // prompt for custom polynomial
    else {
        char str[100];

        do {
            printf("Enter up to 99 characters of the roots of your polynomial separated by spaces:\n"
                    "ex. 5 4 3 2 1 to correspond to 5x^4 + 4x^3 + 3x^2 + 2x + 1\n");

            printf("Or, enter 'random' to get a random polynomial\n");
        } while (scanf(" %99[^\n]", str) != 1);

        char *val = strtok(str, " ");

        // if random was entered, prompt for an order, max, and seed
        if (strcmp(val, "random") == 0) {
            do {
                printf("Enter [order] [max] [seed]\n");
                printf("Order - the order of the polynomial\n");
                printf("Max   - the max value of the coefficients (if 10, then all "
                        "coefficients will be from -10 to 10\n");
                printf("Seed  - seed the random polynomial (seeds drand48)\n");

            } while (scanf(" %99[^\n]", str) != 1);

            order = 5;
            int max  = 10;
            int seed = 123456;

            char *val = strtok(str, " ");
            if (val != NULL)
                order = atoi(val);

            val = strtok(NULL, " ");
            if (val != NULL)
                order = atoi(val);

            val = strtok(NULL, " ");
            if (val != NULL)
                seed = atoi(val);

            h_coeffs = randomCoeffs(order, max, seed);
        }

        // parse each entry separated by spaces into coeffs
        else {
            h_coeffs = new dfloat[12];

            int i;
            for (i = 0; i < 12 && val != NULL; ++i) {
                h_coeffs[i] = atof(val);
                val = strtok(NULL, " ");
            }

            order = i - 1;
        }
    }

    // create our polynomial and its first derivative
    Polynomial P(order, h_coeffs);

    Polynomial Pprime = P.derivative();
    int N = NRe * NIm;

    dim3 B(16, 16, 1);
    dim3 G((NRe + 16 - 1) / 16, (NRe + 16 - 1) / 16);

    // arrays for initial points and points following iteration
    cudaMalloc(&zValsInitial, N * sizeof(Complex));
    cudaMalloc(&zVals       , N * sizeof(Complex));

    Complex *h_zVals = (Complex *)malloc(N*sizeof(Complex));

    // initialize arrays - evenly spaced over complex plane
    fillArrays<<<G, B>>>(ReSpacing, ImSpacing, zValsInitial, zVals, NRe, NIm);

    // perform 500 steps of the iteration and copy result back to host
    newtonIterate<<<G, B>>>(zVals, P, Pprime, NRe, NIm, 500);

    // copy result to host
    cudaMemcpy(h_zVals, zVals, N * sizeof(Complex), cudaMemcpyDeviceToHost);

    // find the solutions - unique values in zVals
    Complex *h_solns = (Complex *)malloc(order*sizeof(Complex));
    int nSolns = findSolns(P, h_solns, h_zVals, order, N);

    free(h_zVals);

    // find closest solutions to each point in zVals
    cudaMalloc(&closest, N * sizeof(int));

    // copy h_solns to device for use in findClosestSoln
    cudaMalloc(&solns, nSolns * sizeof(Complex));
    cudaMemcpy(solns, h_solns, nSolns * sizeof(Complex), cudaMemcpyHostToDevice);

    free(h_solns);

    // array for closest solutions
    int *h_closest;
    h_closest = new int[N];

    // loop over 50 steps and output an image for each
    if (step) {
        // reset zVals
        fillArrays<<<G, B>>>(ReSpacing, ImSpacing, zValsInitial, zVals, NRe, NIm);

        for (int i = 0; i < 50; ++i) {
            // find the closest solution to each value in zVals and store it in closest
            findClosestSoln<<<G, B>>>(closest, zVals, NRe, NIm, solns, nSolns, norm);

            // copy results back to host
            cudaMemcpy(h_closest, closest, N * sizeof(int), cudaMemcpyDeviceToHost);

            // output image
            writeImage(("fractals/"+std::string(testName)+"Step-"+std::to_string(i)+".png").c_str(),
                       NRe, NIm, h_closest);

            // perform 1 iteration
            newtonIterate<<<G, B>>>(zVals, P, Pprime, NRe, NIm, 1);
        }
    }

    // just output the one image
    else {
        // find the closest solution to each value in zVals and store it in closest
        findClosestSoln<<<G, B>>>(closest, zVals, NRe, NIm, solns, nSolns, norm);

        // copy results back to host
        cudaMemcpy(h_closest, closest, N * sizeof(int), cudaMemcpyDeviceToHost);

        // output image
        writeImage(("fractals/"+std::string(testName)+".png").c_str(), NRe, NIm, h_closest);
    }

    // free heap memory
    delete[] h_closest;

    cudaFree(closest);
    cudaFree(solns);
    cudaFree(zVals);
    cudaFree(zValsInitial);

    return 0;
}
