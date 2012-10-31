#include <stdio.h>
#include <trove/ptr.h>

template<typename P>
struct value_type{};

template<typename P>
struct value_type<P*> {
    typedef P type;
};

template<typename P>
struct value_type<trove::coalesced_ptr<P> > {
    typedef P type;
};

template<
    typename InputIterator,
    typename OutputIterator>
__global__ void
//__launch_bounds__(256, 8)
    copy(InputIterator input,
         OutputIterator output,
         int len) {
    int global_index = threadIdx.x + blockDim.x * blockIdx.x;
    int grid_size = gridDim.x * blockDim.x;
    
    for(int index = global_index; index < len; index += grid_size) {
        output[index] = input[index];
    }
}

#include <thrust/device_vector.h>

template<typename A>
thrust::device_vector<A> make_filled(int n) {
    typedef typename A::value_type T;
    thrust::device_vector<A> result(n);
    thrust::device_ptr<T> p = thrust::device_ptr<T>((T*)thrust::raw_pointer_cast(result.data()));
    thrust::counting_iterator<T> c(0);
    int s = n * A::size;
    thrust::copy(c, c+s, p);
    return result;
}

int main() {
    // typedef float T;
    // typedef trove::array<T, 6> n_array;
    typedef double T;
    typedef trove::array<T, 3> n_array;

    int n = 4 * 100 * 8 * 256 * 15;
    thrust::device_vector<n_array> c = make_filled<n_array>(n);
    trove::coalesced_ptr<n_array> c_c(thrust::raw_pointer_cast(c.data()));
    thrust::device_vector<n_array> r(n);
    n_array* p_r = thrust::raw_pointer_cast(r.data());
    trove::coalesced_ptr<n_array> c_r(p_r);
    n_array center = trove::counting_array<n_array >::impl();
    
   
    int nthreads = 256;
    int nblocks = min(15 * 8, n/nthreads);
    //int nblocks = n/nthreads;

    
    int iterations = 10;
    cudaEvent_t start, stop;
    float time = 0;
    std::cout << "Coalesced ";
    cudaEventCreate(&start);
    cudaEventCreate(&stop);
    cudaEventRecord(start, 0);
    for(int j = 0; j < iterations; j++) {
        copy<<<nblocks, nthreads>>>(c_c, c_r, n);
    }
    cudaEventRecord(stop, 0);
    cudaEventSynchronize(stop);
    cudaEventElapsedTime(&time, start, stop);
    float gbs = (float)(sizeof(n_array) * (iterations * (2 * n))) / (time * 1000000);
    std::cout << gbs << std::endl;

    
    n_array* p_c(thrust::raw_pointer_cast(c.data()));

    std::cout << "Direct ";
    cudaEventCreate(&start);
    cudaEventCreate(&stop);
    cudaEventRecord(start, 0);
    for(int j = 0; j < iterations; j++) {
        copy<<<nblocks, nthreads>>>(p_c, p_r, n);
    }
    cudaEventRecord(stop, 0);
    cudaEventSynchronize(stop);
    cudaEventElapsedTime(&time, start, stop);
    gbs = (float)(sizeof(n_array) * (iterations * (2 * n))) / (time * 1000000);
    std::cout << gbs << std::endl;

    
}

