========================================================================
========================================================================
[Section 1] Implementation details:

Firstly, I read the starter code and test it on the small txt file to see
whether it outputs the same as gzip and pigz. This step would be repeated many
times in further implementation processes to ensure that every step I took was
safe and valid. Then I read the starter code and the documentation of the gzip
class in java to understand how the single threaded version is implemented. 
Baically, the compressor did the work of compression with the help of the bytes
array and inStream and Outstream. The crc and dictBuf helped to improve the 
performance and correctness through checksums and priming. After understanding 
the general idea, I started to modify the starter code.

The first step I made was to change the input from the file path to stdin. 
Initially, I set the System.in as the inputStream and inputStream.available()
as the bytes available. (this was later replaced by pushbackInputStream) Also,
I specified the arguments requirements from command line. Specifically, either
there is no arguments, meaning we use the default number of processors and
threads, or the user can specify a positive integer followed by '-p' as the
number of processes specified. After these two changes, I tested the code and
it still worked. 

Then I attempted to implemented the Runnable thread object. First I made a 
dummy class called ParallelThreads to test my understanding of threads in java.
Then I used the idea of implement the threads objecs needed in this hw. 
Initially, I only assigned the job of compressing to each threads, and only 
pass the compressor as the parameter of the thread bject. However, this 
proved to be wrong way of implementation, as the test failed when I made 
those changes. Aferwards, I observed that some objects can be maintained 
as shared objects. Specifically, the HashMaps to store the deflatedBytes, 
the compressed bytes arrays and the dict buffers. To make the HashMaps 
thread-safe, I used the concurrentHashMap object. Also, the constants 
like BLOCK_SIZE can also be stored in the shared varaible. Afterwards, I
noticed that the compressor object is reset for each block, so I just 
keep the compressor object private for each thread, which compressed one
block. Moreover, block buffer, the finished or not flag, the size of the
block and the block id (used as key in HashMaps) are passed as parameters
for one thread object. Note that the block buffer, which is a byte array,
needs to be "arraycopied" by the thread object to avoid passing by reference.
This was one of the obstacle I met in this hw, as I originally passed it
by reference and the output was out of order. Also, most of the work, 
aside from crc update and the block buffer read, is handled to the thread.
I tested after I made those changes, and it worked after some trials and
errors. 

The next thing I did was the implementation of the thread pool. I read the
documentation and tutorials for the ExecutorService and Executers in java
and finally created a newFixedThreadPool to satisfy the requirements in the
spec, i.e. use a certain number of threads to do the compression, although
the number of blocks might be more than the specifed thread number. I also
added the PushBackInputStream at this time to allow for more flexible input
from the stdin. I tested after I made those changes and it worked. Using the
sample test given in the spec, I noticed that the time of my implementation
is about 3 s, the gzip took about 7 s while pigz took about 2.5 s to do
the compression. Also, my output proved to be the same with the original file
after decompressed by pigz, meaning the performance is quite good up to now.

Then I make some some changes by trails and errors to satisfy the edge cases
specified in the spec. Firstly, to allow the input redirected from the 
terminal or more flexible input from the stdin in general, I replaced the
stopping condition for reading from the stdin from fileBytes == totalBytesRead,
which requires the available bytes from the inputStream ahead, with the stopping
condition that reading from the InputStream until the read method of the
FileInputStream object returns -1. This also means I need to read the next
block before deciding whether to stop reading. The second change I made was to
make sure that the program exits with nonzero exit status when receiving out of
range requests, i.e. the number of requested threads are more than the number
of available processors. This can be checked right after then argument is passed
in from the commnad line stdin. Also, the number of specified threads can not be
negative either. Also, I need to handle the cases when the stdin is not readable
or the stdout is not writable. To check whether the stdin is readble, I first
checked the available bytes from the InputStream. If the available bytes is less
or equal than zero, but the number of bytes read initially is not -1 (indicating
a successful read), it means that the input, or stdin, is redireced from 
/dev/zero, the special file containing no terminiating byte (but only null bytes
in it). To check whether the output is readable, I used the FileOutputStream. 
Before writing them directly to stdout, I changed the Outstream to a byte array,
and try to write to the stdout and catch IOException. If the exception happens,
it means that the stdout is writable. 

Another change to increase the performance was a change in the 
SingleBlockCompress class, which implements Runnable and served the role as
the thread worker. To make the dictBuf available for the other threads, I 
changed the order of the original codes so that the dictBuf is written first
if required. 

Several special test cases mentioned in spec:

[zhengton@lnxsrv11 ~/cs131/hw3]$ java Pigzj </dev/zero >/dev/full
read error: cannot read from stdin

[zhengton@lnxsrv11 ~/cs131/hw3]$ java Pigzj <test.txt >/dev/full
write error: No space left on device

[zhengton@lnxsrv11 ~/cs131/hw3]$ java Pigzj -p 100000 <test.txt
Resource unavailable: too many threads specified

[zhengton@lnxsrv11 ~/cs131/hw3]$ java Pigzj test.txt
Usage: Pigzj only supports -p processes option

[zhengton@lnxsrv11 ~/cs131/hw3]$ cat /etc/passwd | java Pigzj | cat >output1
[zhengton@lnxsrv11 ~/cs131/hw3]$ java Pigzj </etc/passwd >output2
[zhengton@lnxsrv11 ~/cs131/hw3]$ cmp output1 output2
[zhengton@lnxsrv11 ~/cs131/hw3]$ 


========================================================================
========================================================================
[Section 2] Tests of performance and different compression program using
different number of threads

===================================================================
Test 1 -- default thread number, three programs: gzip, pigz, Pigzj
==== Commands ====
input=/usr/local/cs/jdk-16.0.1/lib/modules
time gzip <$input >gzip.gz
time pigz <$input >pigz.gz
time java Pigzj <$input >Pigzj.gz
ls -l gzip.gz pigz.gz Pigzj.gz

pigz -d <Pigzj.gz | cmp - $input

==== Outputs ====

==== Trial #1 ==== 
[zhengton@lnxsrv11 ~/cs131/hw3]$ input=/usr/local/cs/jdk-16.0.1/lib/modules
[zhengton@lnxsrv11 ~/cs131/hw3]$ time gzip <$input >gzip.gz

real	0m8.236s
user	0m7.312s
sys	    0m0.085s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time pigz <$input >pigz.gz

real	0m2.724s
user	0m7.358s
sys	    0m0.040s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time java Pigzj <$input >Pigzj.gz

real	0m3.554s
user	0m8.787s
sys	    0m0.378s
[zhengton@lnxsrv11 ~/cs131/hw3]$ ls -l gzip.gz pigz.gz Pigzj.gz
-rw-r--r-- 1 zhengton csugrad 43261332 May  7 23:42 gzip.gz
-rw-r--r-- 1 zhengton csugrad 43134815 May  7 23:42 pigz.gz
-rw-r--r-- 1 zhengton csugrad 43136614 May  7 23:42 Pigzj.gz
[zhengton@lnxsrv11 ~/cs131/hw3]$ 
[zhengton@lnxsrv11 ~/cs131/hw3]$ pigz -d <Pigzj.gz | cmp - $input
[zhengton@lnxsrv11 ~/cs131/hw3]$ 

==== Trial #2 ====
[zhengton@lnxsrv11 ~/cs131/hw3]$ input=/usr/local/cs/jdk-16.0.1/lib/modules
[zhengton@lnxsrv11 ~/cs131/hw3]$ time gzip <$input >gzip.gz

real	0m7.667s
user	0m7.305s
sys	    0m0.062s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time pigz <$input >pigz.gz

real	0m3.328s
user	0m7.078s
sys	    0m0.056s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time java Pigzj <$input >Pigzj.gz

real	0m4.413s
user	0m9.426s
sys	    0m0.349s
[zhengton@lnxsrv11 ~/cs131/hw3]$ ls -l gzip.gz pigz.gz Pigzj.gz
-rw-r--r-- 1 zhengton csugrad 43261332 May  7 23:48 gzip.gz
-rw-r--r-- 1 zhengton csugrad 43134815 May  7 23:48 pigz.gz
-rw-r--r-- 1 zhengton csugrad 43138661 May  7 23:48 Pigzj.gz
[zhengton@lnxsrv11 ~/cs131/hw3]$ 
[zhengton@lnxsrv11 ~/cs131/hw3]$ pigz -d <Pigzj.gz | cmp - $input
[zhengton@lnxsrv11 ~/cs131/hw3]$ 

==== Trial #3 ====
[zhengton@lnxsrv11 ~/cs131/hw3]$ input=/usr/local/cs/jdk-16.0.1/lib/modules
[zhengton@lnxsrv11 ~/cs131/hw3]$ time gzip <$input >gzip.gz

real	0m7.704s
user	0m7.327s
sys	    0m0.077s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time pigz <$input >pigz.gz

real	0m2.652s
user	0m7.131s
sys	    0m0.041s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time java Pigzj <$input >Pigzj.gz

real	0m3.911s
user	0m9.602s
sys	    0m0.400s
[zhengton@lnxsrv11 ~/cs131/hw3]$ ls -l gzip.gz pigz.gz Pigzj.gz
-rw-r--r-- 1 zhengton csugrad 43261332 May  7 23:49 gzip.gz
-rw-r--r-- 1 zhengton csugrad 43134815 May  7 23:50 pigz.gz
-rw-r--r-- 1 zhengton csugrad 43136276 May  7 23:50 Pigzj.gz
[zhengton@lnxsrv11 ~/cs131/hw3]$ 
[zhengton@lnxsrv11 ~/cs131/hw3]$ pigz -d <Pigzj.gz | cmp - $input
[zhengton@lnxsrv11 ~/cs131/hw3]$ 

==== Comments ====
Note that when commpressing the same file, the order of
the performance of the three programs above is roughly 
gzip, Pigzj, pigz, from the slowest to the fastest. Notice that 
gzip takes rougly 7 ~ 8 seconds to do the compression, Pigzj takes
roughly 3.5 ~ 4.5 seconds to do the compression and pigz takes
2.5 ~ 3.5 seconds to do the compression (all measured in real time).
This means that Pigzj and pigz, which employ multiple threads to do
the compression, outperform the gzip in this test. Also, the speed 
of Pigzj is competitive with pigz. Moreover, the compression files
produced by all three compression programs are about the same, and
the file compressed by Pigzj is the same as the original file
from decompression. This means the Pigzj program we implemented in
Java is pretty robust from this test result. Other observations, 
including the time cost of syscalls, would be dicussed later. 


===================================================================
Test 2 -- thread number = 1, three programs: gzip, pigz, Pigzj

==== Commands ====
input=/usr/local/cs/jdk-16.0.1/lib/modules
time gzip <$input >gzip.gz
time pigz -p 1 <$input >pigz.gz
time java Pigzj -p 1 <$input >Pigzj.gz
ls -l gzip.gz pigz.gz Pigzj.gz

pigz -d <Pigzj.gz | cmp - $input

==== Outputs ====

==== Trial #1 ====
[zhengton@lnxsrv11 ~/cs131/hw3]$ input=/usr/local/cs/jdk-16.0.1/lib/modules
[zhengton@lnxsrv11 ~/cs131/hw3]$ time gzip <$input >gzip.gz

real	0m7.663s
user	0m7.304s
sys	    0m0.059s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time pigz -p 1 <$input >pigz.gz

real	0m7.943s
user	0m6.969s
sys	    0m0.086s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time java Pigzj -p 1 <$input >Pigzj.gz

real	0m8.447s
user	0m14.527s
sys	    0m0.345s
[zhengton@lnxsrv11 ~/cs131/hw3]$ ls -l gzip.gz pigz.gz Pigzj.gz
-rw-r--r-- 1 zhengton csugrad 43261332 May  8 00:04 gzip.gz
-rw-r--r-- 1 zhengton csugrad 43134815 May  8 00:04 pigz.gz
-rw-r--r-- 1 zhengton csugrad 43136276 May  8 00:05 Pigzj.gz
[zhengton@lnxsrv11 ~/cs131/hw3]$ 
[zhengton@lnxsrv11 ~/cs131/hw3]$ pigz -d <Pigzj.gz | cmp - $input
[zhengton@lnxsrv11 ~/cs131/hw3]$ 

==== Trial #2 ====
[zhengton@lnxsrv11 ~/cs131/hw3]$ input=/usr/local/cs/jdk-16.0.1/lib/modules
[zhengton@lnxsrv11 ~/cs131/hw3]$ time gzip <$input >gzip.gz

real	0m7.624s
user	0m7.295s
sys	    0m0.074s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time pigz -p 1 <$input >pigz.gz

real	0m7.721s
user	0m6.968s
sys	    0m0.064s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time java Pigzj -p 1 <$input >Pigzj.gz

real	0m8.038s
user	0m14.247s
sys	    0m0.335s
[zhengton@lnxsrv11 ~/cs131/hw3]$ ls -l gzip.gz pigz.gz Pigzj.gz
-rw-r--r-- 1 zhengton csugrad 43261332 May  8 00:07 gzip.gz
-rw-r--r-- 1 zhengton csugrad 43134815 May  8 00:07 pigz.gz
-rw-r--r-- 1 zhengton csugrad 43136276 May  8 00:07 Pigzj.gz
[zhengton@lnxsrv11 ~/cs131/hw3]$ 
[zhengton@lnxsrv11 ~/cs131/hw3]$ pigz -d <Pigzj.gz | cmp - $input
[zhengton@lnxsrv11 ~/cs131/hw3]$ 

==== Trail #3 ====
[zhengton@lnxsrv11 ~/cs131/hw3]$ input=/usr/local/cs/jdk-16.0.1/lib/modules
[zhengton@lnxsrv11 ~/cs131/hw3]$ time gzip <$input >gzip.gz

real	0m8.042s
user	0m7.305s
sys	    0m0.079s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time pigz -p 1 <$input >pigz.gz

real	0m8.529s
user	0m7.010s
sys	    0m0.088s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time java Pigzj -p 1 <$input >Pigzj.gz

real	0m8.540s
user	0m14.621s
sys	    0m0.347s
[zhengton@lnxsrv11 ~/cs131/hw3]$ ls -l gzip.gz pigz.gz Pigzj.gz
-rw-r--r-- 1 zhengton csugrad 43261332 May  8 00:08 gzip.gz
-rw-r--r-- 1 zhengton csugrad 43134815 May  8 00:08 pigz.gz
-rw-r--r-- 1 zhengton csugrad 43136276 May  8 00:08 Pigzj.gz
[zhengton@lnxsrv11 ~/cs131/hw3]$ 
[zhengton@lnxsrv11 ~/cs131/hw3]$ pigz -d <Pigzj.gz | cmp - $input
[zhengton@lnxsrv11 ~/cs131/hw3]$ 

==== Comments ====
Notice when the number of processor specified is 1, the performance of
three programs are about the same, about 7 ~ 8 seconds, and this is 
considerablly slowly than the parallel versions. The similar speed 
(measure in real time) when the number of processor is the same means
that the parallelization really speeds up the compression greatly. 
Moreover, notice that the user time for our program, Pigzj, is much
larger than the user time for the other two programs. This means that
despite the number of threads specified is 1, Java still takes advantages
of the parallel programming and do parallel execution on multiple CPUs
available. This optimization makes the Java program appears to be as 
fast as two other programs in real time. The sys call time would be
analyzed later. Also notice that the file size of compression results
is about the same across the 3 trials, meaning the compression is 
pretty deterministic.


===================================================================
Test 3 -- thread number = 2, two programs: pigz, Pigzj

==== Commands ====
input=/usr/local/cs/jdk-16.0.1/lib/modules
time pigz -p 2 <$input >pigz.gz
time java Pigzj -p 2 <$input >Pigzj.gz
ls -l pigz.gz Pigzj.gz

pigz -d <Pigzj.gz | cmp - $input

==== Outputs ====

==== Trial #1 ====
[zhengton@lnxsrv11 ~/cs131/hw3]$ input=/usr/local/cs/jdk-16.0.1/lib/modules
[zhengton@lnxsrv11 ~/cs131/hw3]$ time pigz -p 2 <$input >pigz.gz

real	0m4.323s
user	0m7.043s
sys	    0m0.101s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time java Pigzj -p 2 <$input >Pigzj.gz

real	0m4.671s
user	0m10.797s
sys	    0m0.369s
[zhengton@lnxsrv11 ~/cs131/hw3]$ ls -l pigz.gz Pigzj.gz
-rw-r--r-- 1 zhengton csugrad 43134815 May  8 00:19 pigz.gz
-rw-r--r-- 1 zhengton csugrad 43136276 May  8 00:19 Pigzj.gz
[zhengton@lnxsrv11 ~/cs131/hw3]$ 
[zhengton@lnxsrv11 ~/cs131/hw3]$ pigz -d <Pigzj.gz | cmp - $input
[zhengton@lnxsrv11 ~/cs131/hw3]$ 

==== Trial #2 ====
[zhengton@lnxsrv11 ~/cs131/hw3]$ input=/usr/local/cs/jdk-16.0.1/lib/modules
[zhengton@lnxsrv11 ~/cs131/hw3]$ time pigz -p 2 <$input >pigz.gz

real	0m4.504s
user	0m7.041s
sys	    0m0.105s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time java Pigzj -p 2 <$input >Pigzj.gz

real	0m4.698s
user	0m10.724s
sys	    0m0.404s
[zhengton@lnxsrv11 ~/cs131/hw3]$ ls -l pigz.gz Pigzj.gz
-rw-r--r-- 1 zhengton csugrad 43134815 May  8 00:50 pigz.gz
-rw-r--r-- 1 zhengton csugrad 43136276 May  8 00:50 Pigzj.gz
[zhengton@lnxsrv11 ~/cs131/hw3]$ 
[zhengton@lnxsrv11 ~/cs131/hw3]$ pigz -d <Pigzj.gz | cmp - $input
[zhengton@lnxsrv11 ~/cs131/hw3]$ 

==== Trial #3 ====
[zhengton@lnxsrv11 ~/cs131/hw3]$ input=/usr/local/cs/jdk-16.0.1/lib/modules
[zhengton@lnxsrv11 ~/cs131/hw3]$ time pigz -p 2 <$input >pigz.gz

real	0m4.488s
user	0m7.032s
sys	    0m0.108s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time java Pigzj -p 2 <$input >Pigzj.gz

real	0m4.635s
user	0m10.729s
sys	    0m0.367s
[zhengton@lnxsrv11 ~/cs131/hw3]$ ls -l pigz.gz Pigzj.gz
-rw-r--r-- 1 zhengton csugrad 43134815 May  8 00:51 pigz.gz
-rw-r--r-- 1 zhengton csugrad 43136276 May  8 00:51 Pigzj.gz
[zhengton@lnxsrv11 ~/cs131/hw3]$ 
[zhengton@lnxsrv11 ~/cs131/hw3]$ pigz -d <Pigzj.gz | cmp - $input
[zhengton@lnxsrv11 ~/cs131/hw3]$ 


===================================================================
Test 3 -- thread number = 3, two programs: pigz, Pigzj

==== Commands ====
input=/usr/local/cs/jdk-16.0.1/lib/modules
time pigz -p 3 <$input >pigz.gz
time java Pigzj -p 3 <$input >Pigzj.gz
ls -l pigz.gz Pigzj.gz

pigz -d <Pigzj.gz | cmp - $input

==== Outputs ====

==== Trial #1 ====
[zhengton@lnxsrv11 ~/cs131/hw3]$ input=/usr/local/cs/jdk-16.0.1/lib/modules
[zhengton@lnxsrv11 ~/cs131/hw3]$ time pigz -p 3 <$input >pigz.gz

real	0m3.288s
user	0m7.088s
sys	    0m0.093s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time java Pigzj -p 3 <$input >Pigzj.gz

real	0m3.464s
user	0m9.587s
sys	    0m0.409s
[zhengton@lnxsrv11 ~/cs131/hw3]$ ls -l pigz.gz Pigzj.gz
-rw-r--r-- 1 zhengton csugrad 43134815 May  8 00:30 pigz.gz
-rw-r--r-- 1 zhengton csugrad 43136276 May  8 00:30 Pigzj.gz
[zhengton@lnxsrv11 ~/cs131/hw3]$ 
[zhengton@lnxsrv11 ~/cs131/hw3]$ pigz -d <Pigzj.gz | cmp - $input
[zhengton@lnxsrv11 ~/cs131/hw3]$ 

==== Trial #2 ====
[zhengton@lnxsrv11 ~/cs131/hw3]$ input=/usr/local/cs/jdk-16.0.1/lib/modules
[zhengton@lnxsrv11 ~/cs131/hw3]$ time pigz -p 3 <$input >pigz.gz

real	0m3.242s
user	0m7.028s
sys	    0m0.107s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time java Pigzj -p 3 <$input >Pigzj.gz

real	0m3.696s
user	0m9.530s
sys	    0m0.410s
[zhengton@lnxsrv11 ~/cs131/hw3]$ ls -l pigz.gz Pigzj.gz
-rw-r--r-- 1 zhengton csugrad 43134815 May  8 00:52 pigz.gz
-rw-r--r-- 1 zhengton csugrad 43136276 May  8 00:52 Pigzj.gz
[zhengton@lnxsrv11 ~/cs131/hw3]$ 
[zhengton@lnxsrv11 ~/cs131/hw3]$ pigz -d <Pigzj.gz | cmp - $input
[zhengton@lnxsrv11 ~/cs131/hw3]$ 

==== Trial #3 ====
[zhengton@lnxsrv11 ~/cs131/hw3]$ input=/usr/local/cs/jdk-16.0.1/lib/modules
[zhengton@lnxsrv11 ~/cs131/hw3]$ time pigz -p 3 <$input >pigz.gz

real	0m3.182s
user	0m7.090s
sys	    0m0.088s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time java Pigzj -p 3 <$input >Pigzj.gz

real	0m3.775s
user	0m9.566s
sys	    0m0.416s
[zhengton@lnxsrv11 ~/cs131/hw3]$ ls -l pigz.gz Pigzj.gz
-rw-r--r-- 1 zhengton csugrad 43134815 May  8 00:53 pigz.gz
-rw-r--r-- 1 zhengton csugrad 43136276 May  8 00:53 Pigzj.gz
[zhengton@lnxsrv11 ~/cs131/hw3]$ 
[zhengton@lnxsrv11 ~/cs131/hw3]$ pigz -d <Pigzj.gz | cmp - $input
[zhengton@lnxsrv11 ~/cs131/hw3]$ 

===================================================================
Test 4 -- thread number = 4, two programs: pigz, Pigzj

==== Commands ====
input=/usr/local/cs/jdk-16.0.1/lib/modules
time pigz -p 4 <$input >pigz.gz
time java Pigzj -p 4 <$input >Pigzj.gz
ls -l pigz.gz Pigzj.gz

pigz -d <Pigzj.gz | cmp - $input

==== Outputs ====

==== Trial #1 ====
[zhengton@lnxsrv11 ~/cs131/hw3]$ input=/usr/local/cs/jdk-16.0.1/lib/modules
[zhengton@lnxsrv11 ~/cs131/hw3]$ time pigz -p 4 <$input >pigz.gz

real	0m2.544s
user	0m7.092s
sys	    0m0.037s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time java Pigzj -p 4 <$input >Pigzj.gz

real	0m3.784s
user	0m9.149s
sys	    0m0.386s
[zhengton@lnxsrv11 ~/cs131/hw3]$ ls -l pigz.gz Pigzj.gz
-rw-r--r-- 1 zhengton csugrad 43134815 May  8 00:21 pigz.gz
-rw-r--r-- 1 zhengton csugrad 43136276 May  8 00:21 Pigzj.gz
[zhengton@lnxsrv11 ~/cs131/hw3]$ 
[zhengton@lnxsrv11 ~/cs131/hw3]$ pigz -d <Pigzj.gz | cmp - $input
[zhengton@lnxsrv11 ~/cs131/hw3]$ 

==== Trial #2 ====
[zhengton@lnxsrv11 ~/cs131/hw3]$ input=/usr/local/cs/jdk-16.0.1/lib/modules
[zhengton@lnxsrv11 ~/cs131/hw3]$ time pigz -p 4 <$input >pigz.gz

real	0m2.608s
user	0m7.133s
sys	    0m0.037s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time java Pigzj -p 4 <$input >Pigzj.gz

real	0m3.400s
user	0m9.037s
sys	    0m0.419s
[zhengton@lnxsrv11 ~/cs131/hw3]$ ls -l pigz.gz Pigzj.gz
-rw-r--r-- 1 zhengton csugrad 43134815 May  8 00:54 pigz.gz
-rw-r--r-- 1 zhengton csugrad 43136947 May  8 00:54 Pigzj.gz
[zhengton@lnxsrv11 ~/cs131/hw3]$ 
[zhengton@lnxsrv11 ~/cs131/hw3]$ pigz -d <Pigzj.gz | cmp - $input
[zhengton@lnxsrv11 ~/cs131/hw3]$ 


==== Trial #3 ====
[zhengton@lnxsrv11 ~/cs131/hw3]$ input=/usr/local/cs/jdk-16.0.1/lib/modules
[zhengton@lnxsrv11 ~/cs131/hw3]$ time pigz -p 4 <$input >pigz.gz

real	0m2.613s
user	0m7.104s
sys	0m0.040s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time java Pigzj -p 4 <$input >Pigzj.gz

real	0m3.821s
user	0m9.624s
sys	0m0.391s
[zhengton@lnxsrv11 ~/cs131/hw3]$ ls -l pigz.gz Pigzj.gz
-rw-r--r-- 1 zhengton csugrad 43134815 May  8 00:55 pigz.gz
-rw-r--r-- 1 zhengton csugrad 43136276 May  8 00:55 Pigzj.gz
[zhengton@lnxsrv11 ~/cs131/hw3]$ 
[zhengton@lnxsrv11 ~/cs131/hw3]$ pigz -d <Pigzj.gz | cmp - $input
[zhengton@lnxsrv11 ~/cs131/hw3]$ 


==== Comments =====
First note that the maximum number of processors available on lnxsrv is 4, so
we only tests the thread number 1,2,3,4. For the Pigzj program, note that the 
speed increases slower and slower as the thread number increases from 1 to 4,
and the spped increase is minimal when the thread number gets 4 from 3. This 
trend is also visible in the tests for the pigz program. However, notice that
the pigz program is faster than the java program Pigzj in each test. The 
compression outputs, however, are consistent among different tests. Notice that
when comparing to the original input, the output of Pigzj is the same as the
the original file after decompression. This means the parallelization, or the
use of threads, only increase the speed, but does not increase the correctness
of compression. 

======== Observations ========
From this section, we see that the compression really speeds up as the threads
number increases, but the increase gets smaller and smaller when the number of
threads is close to the maximum number of processors available. The potential
reason for this is that the operating system would do more and more
synchronization work like mutual exclusions or other kinds of locks to ensure 
that the shared data structure is thread safe, i.e. the race conditions would 
not happen. Also, the context switches would be more likely given more mutex
calls and some threads might need to yield the CPU to wait for the shared 
resources. Therefore, the additional work added would decrease the efficicency
and speed of the program, and makes the effects of parallelization less 
significant as the number of threads scale up. However, this program might be
partially solved if the number of available processors is larger, or the 
program is better optimized. 

In general, from the data we got, pigz would be the fastest as the number of
threads scale up, Pigzj would be competitive to pigz as the nubmer of the 
threads scale up, but still a bit slower than it. Gzip would be the slowest
among the three. Also, as the number of threads specified is closer to the
maximum number of processors available, pigz would achieve a better result 
comparing to Pigzj. Specifically, while pigz and Pigzj both take about 
7 ~ 8 seconds to do the compression of the same file above with a single thread, 
pigz takes about 2 ~ 3 seconds while Pigzj takes about 3 ~ 4 seconds with 4
threads, and the relative difference in time cost is much higher than the
results with a single thread. This means that pigz achieves a better optimization
and utilization of parallelization than our Java Pigz program. Overall, as
long as the number of threads is within the nubmer of available processors, 
and the thread number is greater than 1, pigz and Pigzj perform better than
gzip on compression of the same file. 



========================================================================
========================================================================
[Section 3] Use strace to generate traces of system calls executed by the
three programs, and compare and contrast the resulting traces

==== Commands ==== 
input=/usr/local/cs/jdk-16.0.1/lib/modules
strace -c gzip <$input >gzip.gz
strace -c pigz <$input >pigz.gz
strace -c java Pigzj <$input >Pigzj.gz

pigz -d <Pigzj.gz | cmp - $input

==== Outputs ====
[zhengton@lnxsrv11 ~/cs131/hw3]$ input=/usr/local/cs/jdk-16.0.1/lib/modules
[zhengton@lnxsrv11 ~/cs131/hw3]$ strace -c gzip <$input >gzip.gz
% time     seconds  usecs/call     calls    errors syscall
------ ----------- ----------- --------- --------- ----------------
 77.02    0.005929        1482         4           close
 12.16    0.000936           0      2641           write
 10.82    0.000833           0      3846           read
  0.00    0.000000           0         3           fstat
  0.00    0.000000           0         1           lseek
  0.00    0.000000           0         5           mmap
  0.00    0.000000           0         4           mprotect
  0.00    0.000000           0         1           munmap
  0.00    0.000000           0         1           brk
  0.00    0.000000           0        12           rt_sigaction
  0.00    0.000000           0         1         1 ioctl
  0.00    0.000000           0         1         1 access
  0.00    0.000000           0         1           execve
  0.00    0.000000           0         2         1 arch_prctl
  0.00    0.000000           0         2           openat
------ ----------- ----------- --------- --------- ----------------
100.00    0.007698                  6525         3 total
[zhengton@lnxsrv11 ~/cs131/hw3]$ strace -c pigz <$input >pigz.gz
% time     seconds  usecs/call     calls    errors syscall
------ ----------- ----------- --------- --------- ----------------
 49.14    0.008495           8       971           read
 42.02    0.007264          16       450         1 futex
  3.84    0.000663          82         8           brk
  2.41    0.000417          14        28           mmap
  0.80    0.000139          27         5           clone
  0.67    0.000116           7        15           mprotect
  0.29    0.000050           8         6           openat
  0.20    0.000034           5         6           fstat
  0.15    0.000026           4         6           close
  0.12    0.000021           1        21           munmap
  0.08    0.000013           4         3           lseek
  0.08    0.000013           4         3           rt_sigaction
  0.05    0.000009           4         2         2 ioctl
  0.04    0.000007           7         1         1 access
  0.03    0.000005           5         1           prlimit64
  0.02    0.000004           4         1           rt_sigprocmask
  0.02    0.000004           2         2         1 arch_prctl
  0.02    0.000004           4         1           set_tid_address
  0.02    0.000004           4         1           set_robust_list
  0.00    0.000000           0         1           execve
------ ----------- ----------- --------- --------- ----------------
100.00    0.017288                  1532         5 total
[zhengton@lnxsrv11 ~/cs131/hw3]$ strace -c java Pigzj <$input >Pigzj.gz
% time     seconds  usecs/call     calls    errors syscall
------ ----------- ----------- --------- --------- ----------------
 99.63    0.368727      184363         2           futex
  0.12    0.000426           8        49        39 openat
  0.06    0.000219           6        33        30 stat
  0.05    0.000177           7        23           mmap
  0.04    0.000145           9        15           mprotect
  0.02    0.000087          29         3           munmap
  0.02    0.000063           5        12           read
  0.02    0.000057           5        11           close
  0.01    0.000052           5        10           fstat
  0.01    0.000032          16         2           readlink
  0.01    0.000026          26         1           clone
  0.00    0.000017           4         4           brk
  0.00    0.000017           8         2         1 access
  0.00    0.000014           4         3           lseek
  0.00    0.000008           4         2           rt_sigaction
  0.00    0.000008           4         2         1 arch_prctl
  0.00    0.000006           6         1           execve
  0.00    0.000005           5         1           rt_sigprocmask
  0.00    0.000004           4         1           getpid
  0.00    0.000004           4         1           set_tid_address
  0.00    0.000004           4         1           set_robust_list
  0.00    0.000004           4         1           prlimit64
------ ----------- ----------- --------- --------- ----------------
100.00    0.370102                   180        71 total
[zhengton@lnxsrv11 ~/cs131/hw3]$ 
[zhengton@lnxsrv11 ~/cs131/hw3]$ pigz -d <Pigzj.gz | cmp - $input
[zhengton@lnxsrv11 ~/cs131/hw3]$ 

==== Observations ====
The outputs above are the statistics of syscalls of three different
compression methods. Note that gzip spends much time doing the 
i/o operations, i.e. close(), write() and open(). This potentially
explains the relatively low performance, or relatively low speed, of
the gzip program comparing to two others as the number of threads scale
up. To be specfic, our Java program would read every block and send the
block to one thread to do the compression. Also, we only write to stdout
one time, which is at the end of the program when all the outputs are 
ready to be written to stdout. In contrast, gzip would call read() and 
write() for thousands of times (close() operation also costs a lot of time). 
This might due to its unparallelized nature, but desipte the reasons, 
the syscalls cost much time (note that the I/O operations nearly take
 100% of the total time) in the gzip program. 
In contrast, one syscall is more common in the other two programs, i.e.
futex(). From searching, a futex (short for "fast userspace mutex")
is a kernel system call that programmers can use to implement basic locking, 
or as a building block for higher-level locking abstractions such as 
semaphores and POSIX mutexes or condition variables. From this definition, 
we know that futex, like mutex, relates to parallel programming and is used
to prevent race conditions among different threads via semaphores or locks.
This means that the two other programs, pigz and Pigzj, heavily use the 
futex() call to ensure that the data shared are thread-safe, so that
the compression can be done in parallel for different blocks of input to
speed up the program. The futex() calls are more pervasive in our Java
Pigzj program than pigz. Here is the data of the futex calls in Pigzj:
% time     seconds  usecs/call     calls    errors syscall
------ ----------- ----------- --------- --------- ----------------
99.63    0.368727      184363         2           futex
Note that the futex calls take much of the sys time of the Pigzj program,
and it nearly cost 0.37 seconds in total. This might relates the way I 
implemented the Pigzj program. To ensure that the shared data, or the 
data compressed from each block, is thread-safe, I maintain two concurrentHashMaps
as the shared varaibles. The interal implementation of concurrentHashMap class
in Java may use futex if there is potential race conditions. Also, notice that
I need to fork the threads using ExecutorService and join them at last, and 
this may also need calls to futex(). Notice that although we only call 
futex for two times, each time cost about 0.2 seconds, meaning some threads
may wait for the shared resources for a long time. This might indicates that
the parallelization is not good enough, and our Java program can be even more
optimized. Other syscalls issued in Pigzj also relates the protection and
mangement of the memory. For example, mprotect helps to protect
the memory space and mmap maps files or devices into memory. 
In comparison, here are top two time-consuming syscalls in pigz:
% time     seconds  usecs/call     calls    errors syscall
------ ----------- ----------- --------- --------- ----------------
 49.14    0.008495           8       971           read
 42.02    0.007264          16       450         1 futex

Notice that although the number of futex() calls is much larger than that in
Pigzj, each futex() call costs a low amount of time. This means the shared 
data is better orgranized in the pigz program, or little data is shared 
among threads in pigz program. Also, the calls to read() is less than that in
gzip, and this also saves a lot of time. 
Finally, notice that although gzip do many i/o sycalls, it costs the least
time in terms of the system calls, while Pigzj costs the most time in terms
of the sycalls. As gzip does not do parallel programming, it saves a lot of
time in terms of syscalls as it does not need to make syscalls like futex()
to do locking, context switches and other system calls that issued by
the operating system in the scheduling problems of different threads. However,
the real time of the two other programs outperform the first one (gzip), and
they take advantages of the parallelization to do compression concurrently
to save (real) time. 


========================================================================
========================================================================
[Section 4] Discussion on file size using the three compression programs

==== Test 1 ====

==== Commands ====
input=test.txt
time gzip <$input >gzip.gz
time pigz <$input >pigz.gz
time java Pigzj <$input >Pigzj.gz
ls -l gzip.gz pigz.gz Pigzj.gz

pigz -d <Pigzj.gz | cmp - $input

==== Outputs ====

[zhengton@lnxsrv11 ~/cs131/hw3]$ input=test.txt
[zhengton@lnxsrv11 ~/cs131/hw3]$ time gzip <$input >gzip.gz

real	0m0.004s
user	0m0.000s
sys	    0m0.002s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time pigz <$input >pigz.gz

real	0m0.004s
user	0m0.002s
sys	    0m0.000s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time java Pigzj <$input >Pigzj.gz

real	0m0.060s
user	0m0.038s
sys	    0m0.023s
[zhengton@lnxsrv11 ~/cs131/hw3]$ ls -l gzip.gz pigz.gz Pigzj.gz
-rw-r--r-- 1 zhengton csugrad 26 May  8 02:26 gzip.gz
-rw-r--r-- 1 zhengton csugrad 26 May  8 02:26 pigz.gz
-rw-r--r-- 1 zhengton csugrad 26 May  8 02:26 Pigzj.gz
[zhengton@lnxsrv11 ~/cs131/hw3]$ 
[zhengton@lnxsrv11 ~/cs131/hw3]$ pigz -d <Pigzj.gz | cmp - $input
[zhengton@lnxsrv11 ~/cs131/hw3]$ 

==== Test 2 ====

==== Commands ====
input=README.txt
time gzip <$input >gzip.gz
time pigz <$input >pigz.gz
time java Pigzj <$input >Pigzj.gz
ls -l gzip.gz pigz.gz Pigzj.gz

pigz -d <Pigzj.gz | cmp - $input

==== Outputs ====
[zhengton@lnxsrv11 ~/cs131/hw3]$ input=README.txt
[zhengton@lnxsrv11 ~/cs131/hw3]$ time gzip <$input >gzip.gz

real	0m0.005s
user	0m0.002s
sys	    0m0.001s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time pigz <$input >pigz.gz

real	0m0.005s
user	0m0.001s
sys	    0m0.003s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time java Pigzj <$input >Pigzj.gz

real	0m0.060s
user	0m0.035s
sys	    0m0.028s
[zhengton@lnxsrv11 ~/cs131/hw3]$ ls -l gzip.gz pigz.gz Pigzj.gz
-rw-r--r-- 1 zhengton csugrad 7570 May  8 02:26 gzip.gz
-rw-r--r-- 1 zhengton csugrad 7560 May  8 02:26 pigz.gz
-rw-r--r-- 1 zhengton csugrad 7560 May  8 02:26 Pigzj.gz
[zhengton@lnxsrv11 ~/cs131/hw3]$ 
[zhengton@lnxsrv11 ~/cs131/hw3]$ pigz -d <Pigzj.gz | cmp - $input
[zhengton@lnxsrv11 ~/cs131/hw3]$ 

==== Test 3 ====

==== Commands ====
input=mylong.txt
time gzip <$input >gzip.gz
time pigz <$input >pigz.gz
time java Pigzj <$input >Pigzj.gz
ls -l gzip.gz pigz.gz Pigzj.gz

pigz -d <Pigzj.gz | cmp - $input

==== Outputs ====
[zhengton@lnxsrv11 ~/cs131/hw3]$ input=mylong.txt
[zhengton@lnxsrv11 ~/cs131/hw3]$ time gzip <$input >gzip.gz

real	0m0.043s
user	0m0.030s
sys	    0m0.003s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time pigz <$input >pigz.gz

real	0m0.018s
user	0m0.032s
sys	    0m0.005s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time java Pigzj <$input >Pigzj.gz

real	0m0.085s
user	0m0.077s
sys	    0m0.037s
[zhengton@lnxsrv11 ~/cs131/hw3]$ ls -l gzip.gz pigz.gz Pigzj.gz
-rw-r--r-- 1 zhengton csugrad 27285 May  8 02:27 gzip.gz
-rw-r--r-- 1 zhengton csugrad 27517 May  8 02:27 pigz.gz
-rw-r--r-- 1 zhengton csugrad 27560 May  8 02:27 Pigzj.gz
[zhengton@lnxsrv11 ~/cs131/hw3]$ 
[zhengton@lnxsrv11 ~/cs131/hw3]$ pigz -d <Pigzj.gz | cmp - $input
[zhengton@lnxsrv11 ~/cs131/hw3]$ 


==== Test4 ====

==== Commands ====
input=/usr/local/cs/jdk-16.0.1/lib/modules
time gzip <$input >gzip.gz
time pigz <$input >pigz.gz
time java Pigzj <$input >Pigzj.gz
ls -l gzip.gz pigz.gz Pigzj.gz

# This checks Pigzj's output.
pigz -d <Pigzj.gz | cmp - $input

==== Outputs ====
[zhengton@lnxsrv11 ~/cs131/hw3]$ input=/usr/local/cs/jdk-16.0.1/lib/modules
[zhengton@lnxsrv11 ~/cs131/hw3]$ time gzip <$input >gzip.gz

real	0m8.115s
user	0m7.324s
sys	    0m0.064s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time pigz <$input >pigz.gz

real	0m3.293s
user	0m7.087s
sys	    0m0.057s
[zhengton@lnxsrv11 ~/cs131/hw3]$ time java Pigzj <$input >Pigzj.gz

real	0m3.832s
user	0m8.717s
sys	    0m0.364s
[zhengton@lnxsrv11 ~/cs131/hw3]$ ls -l gzip.gz pigz.gz Pigzj.gz
-rw-r--r-- 1 zhengton csugrad 43261332 May  8 02:30 gzip.gz
-rw-r--r-- 1 zhengton csugrad 43134815 May  8 02:30 pigz.gz
-rw-r--r-- 1 zhengton csugrad 43142004 May  8 02:30 Pigzj.gz
[zhengton@lnxsrv11 ~/cs131/hw3]$ 
[zhengton@lnxsrv11 ~/cs131/hw3]$ # This checks Pigzj's output.
[zhengton@lnxsrv11 ~/cs131/hw3]$ pigz -d <Pigzj.gz | cmp - $input
[zhengton@lnxsrv11 ~/cs131/hw3]$ 

==== Observations ====
Notice that as the file size is relatively small, gzip and pigz performs better 
than Pigzj. For instance, when the file size is only 6 bytes, gzip and pigz takes
only 0.005 seconds to finish the compression while Pigzj costs 0.06 seconds, while
is considerably longer than the previous two. However, as the file size gets larger,
the difference gets smaller. For the compression of mylong.txt, which is 3864890 bytes
long, gzip takes 0.043 seconds, pigz takes 0.018 seconds, and Pigzj takes 0.085 seconds.
From this data, the speed difference is not that significant than that when compressing
the small files, and pigz has shown the potential to be faster than gzip. When doing
compression on the large file, i.e. the source code of some modules in Java with 
125942959 bytes, gzip takes much longer time than the other two. Note that gzip takes
more than 8 seconds to do the compression, while pigz compressed in about 3 seconds, and
Pigzj finished compression in 4 seconds. This shows that Pigzj is competitive in speed 
to pigz as the file size scales up, and Pigzj, pigz achieves much higher speed than gzip
as the file size scales up. Due to the parallelization and concurrent compression of 
the input blocks, pigz and Pigzj are likely to perform better for large file compression,
and pigz probably would be a bit faster than Pigzj.

(Note: the discussion on the thread numbers used in different programs is in section 2)