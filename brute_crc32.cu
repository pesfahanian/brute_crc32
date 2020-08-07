#include <time.h>
#include "stdio.h"
#include "cuda_runtime.h"

#define BlockNum 256
#define ThreadNum 1024 
#define Len 4

__host__ __device__ unsigned int crc32(unsigned char *message)
{
   int i, j;
   unsigned int byte, crc, mask;
   i = 0;
   crc = 0xFFFFFFFF;
   while (message[i] != 0)
   {
      byte = message[i];       // Get next byte.
      crc = crc ^ byte;
      for (j = 7; j >= 0; j--) // Do eight times.
      {    
         mask = -(crc & 1);
         crc = (crc >> 1) ^ (0xEDB88320 & mask);
      }
      i = i + 1;
   }
   return ~crc;
}

__host__ void crc32Host(int len, unsigned int target)
{
	unsigned char buf[Len];
	for(int i=0;i<len;i++)
	{
		buf[i]=0;
	}
	unsigned int crc=0;
	while(target!=crc)
	{
		buf[0]++;
       	for(int i=0;i<len;i++)
       	{
       		if (buf[i]>=255)
       		{
       			buf[(i+1)%len]++;
       			buf[i]=0;
       		}
   		}
        crc=crc32(buf);
    	if(crc == target)
    	{
    		printf("Input Found in CPU=");
    		for (int i = 0; i < Len; ++i)
    		{
    			printf("%c",buf[i]);
    		}
    		printf("\n");
    		break;
		}
	}
}

__global__ void crc32Device(int len, unsigned int target)
{ 
	unsigned int idx = blockIdx.x*blockDim.x + threadIdx.x;
	unsigned int size = BlockNum*ThreadNum;
	unsigned long long spacesearch=1;
	for(int i=0;i<len;i++)
	{
		spacesearch *=256;
	}
	if(idx==0) printf("spacesearc=%ld,Size=%d\n",spacesearch,size );
	{
		__syncthreads();
	}
	unsigned char buf[Len];
	for(int i=0;i<len;i++)
	{
		buf[i]=0;
	}
	unsigned int crc=0;
	unsigned int index=idx*((spacesearch/size)+1);
	for(int i=0;i<Len;i++)
	{
		buf[i]=(unsigned char)((index)&0xff);
	   	index=(index) >>8;
	}
	for(int i=0;i<((spacesearch/size)+1);i++)
	{
		for(int j=0;j<len;j++)
		{
			if (buf[j]>=255)
			{
				buf[(j+1)%len]++;
	       		buf[j]=0;
	       	}	
	   	}
        crc=crc32(buf);
        buf[0]++;
   		if(crc == target)
   		{
   			printf("Input Found in GPU=");
    		for (int i = 0; i < Len; ++i)
    		{
    			printf("%c",buf[i]);
 			}
    		printf("\n");
		}
    }
	__syncthreads(); 
}

int main()
{
	unsigned char boi[Len]={0};
	for(int i=0;i<Len;i++)
		boi[i]='b';
	unsigned int test =crc32(boi);
	printf("%x\n",test );

    // Set the Device Number
    cudaSetDevice(0);

    // Allocating memory in device
    int len; unsigned int target;
    cudaMalloc((void**)&len, sizeof(int) * 1);
    cudaMalloc((void**)&target, sizeof(unsigned int) * 1);

    // Setting CUDA timer finction
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    // Host function in CPU
    cudaEventRecord(start,0);

	// crc32Host( Len,test);
    cudaEventRecord(stop,0);
    cudaEventSynchronize(stop);
    float miliseconds_cpu = 0;
    cudaEventElapsedTime(&miliseconds_cpu,start,stop);

  	// printf("Elapsed Time for the CPU computation is :%f\n",miliseconds_cpu/1000);
    // Device function in GPU
    cudaEventCreate(&start);
    cudaEventCreate(&stop);
    float miliseconds_gpu = 0;
   	cudaEventRecord(start,0);
    crc32Device<<<BlockNum,ThreadNum>>>(Len, test);
    cudaEventRecord(stop,0);
    cudaEventSynchronize(stop);
    cudaEventElapsedTime(&miliseconds_gpu,start,stop);
    printf("Elapsed Time for the GPU computation is :%f\n",miliseconds_gpu/1000);
	
	//printf("GPU speedup over CPU is :%f\nx",miliseconds_cpu/miliseconds_gpu);
    cudaDeviceReset();
    return 0;
}