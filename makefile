newton:
	make setup
	nvcc src/run.cu src/newton.cu src/complex.cu src/polynomial.cu -dc
	nvcc *.o -o bin/newton
	rm *.o

test:
	make setup
	nvcc src/test.cu src/newton.cu src/complex.cu src/polynomial.cu -dc
	nvcc *.o -o bin/test
	rm *.o
	./bin/test

setup:
	if [ ! -d "./bin" ]; then \
	mkdir bin; \
	fi

	if [ ! -d "./data" ]; then \
	mkdir data; \
	fi

	if [ ! -d "./plots" ]; then \
	mkdir plots; \
	fi

debug:
	nvcc -g -G src/test.cu src/newton.cu src/complex.cu src/polynomial.cu -dc
	nvcc -g -G *.o -o bin/test
	rm *.o

runSmallTest:
	./bin/newton 100 100 smallTest
