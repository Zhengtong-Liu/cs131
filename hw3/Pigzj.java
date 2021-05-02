import java.util.concurrent.ConcurrentHashMap;
import java.util.zip.*;


import java.io.*;
import java.nio.file.*;


class SingleThreadedGZipCompressor 
{
    public final static int BLOCK_SIZE = 131072; // 128 KB
    public final static int DICT_SIZE = 32768; // 32 KB
    private final static int GZIP_MAGIC = 0x8b1f;
    private final static int TRAILER_SIZE = 8;
    private int nThreads;

    public ByteArrayOutputStream outStream;

    private CRC32 crc = new CRC32();

    public SingleThreadedGZipCompressor(int nThreads) 
    {
        // this.fileName = fileName;
        this.nThreads = nThreads;
        this.outStream = new ByteArrayOutputStream();
    }

    private void writeHeader() throws IOException 
    {
        outStream.write(new byte[] 
        {
            (byte) GZIP_MAGIC,// Magic number (short)
            (byte)(GZIP_MAGIC >> 8),// Magic number (short)
            Deflater.DEFLATED,// Compression method (CM)
            0,// Flags (FLG)
            0,// Modification time MTIME (int)
            0,// Modification time MTIME (int)
            0,// Modification time MTIME (int)
            0,// Modification time MTIME (int)Sfil
            0,// Extra flags (XFLG)
            0 // Operating system (OS)
        });
    }


        /*
        * Writes GZIP member trailer to a byte array, starting at a given
        * offset.
        */
    private void writeTrailer(long totalBytes, byte[] buf, int offset) throws IOException 
    {
        writeInt((int)crc.getValue(), buf, offset); // CRC-32 of uncompr. data
        writeInt((int)totalBytes, buf, offset + 4); // Number of uncompr. bytes
    }

        /*
        * Writes integer in Intel byte order to a byte array, starting at a
        * given offset.
        */
    private void writeInt(int i, byte[] buf, int offset) throws IOException 
    {
        writeShort(i & 0xffff, buf, offset);
        writeShort((i >> 16) & 0xffff, buf, offset + 2);
    }

        /*
        * Writes short integer in Intel byte order to a byte array, starting
        * at a given offset
        */
    private void writeShort(int s, byte[] buf, int offset) throws IOException 
    {
        buf[offset] = (byte)(s & 0xff);
        buf[offset + 1] = (byte)((s >> 8) & 0xff);
    }

    public void compress() throws FileNotFoundException, IOException 
    {

        this.writeHeader();
        this.crc.reset();

        /* Buffers for input blocks, compressed bocks, and dictionaries */
        byte[] blockBuf = new byte[BLOCK_SIZE];
        byte[] cmpBlockBuf = new byte[BLOCK_SIZE * 2];
        byte[] dictBuf = new byte[DICT_SIZE];
        Deflater compressor = new Deflater(Deflater.DEFAULT_COMPRESSION, true);

        ConcurrentHashMap<Integer, Tuple<Integer, byte[]>> outStreamMap = 
        new ConcurrentHashMap<Integer, Tuple<Integer, byte[]>>();

        Thread[] threads = new Thread [nThreads];
        int counter = 0;

        // File file = new File(this.fileName);
        // long fileBytes = file.length();
        long fileBytes = System.in.available();
        // System.out.println(fileBytes);
        // InputStream inStream = new FileInputStream(file);
        InputStream inStream = System.in;

        long totalBytesRead = 0;
        boolean hasDict = false;
        int nBytes = inStream.read(blockBuf);
        totalBytesRead += nBytes;
        while (nBytes > 0) 
        {
            /* Update the CRC every time we read in a new block. */
            crc.update(blockBuf, 0, nBytes);

            compressor.reset();

            /* If we saved a dictionary from the last block, prime the deflater with it */
            if (hasDict) 
            {
                compressor.setDictionary(dictBuf);
            }
            compressor.setInput(blockBuf, 0, nBytes);

            if (totalBytesRead == fileBytes) 
            {
                /* If we've read all the bytes in the file, this is the last block.
                     We have to clean out the deflater properly */
                if (!compressor.finished()) 
                {
                    compressor.finish();
                    while (!compressor.finished()) 
                    {
                        if (counter < nThreads)
                        {
                            SingleBlockCompress curBlock = new SingleBlockCompress(compressor);
                            threads[counter] = new Thread(curBlock);
                            threads[counter].start();
                            outStreamMap.put(counter, curBlock.getValue());
                        }
                        else
                        {
                            int deflatedBytes = compressor.deflate(cmpBlockBuf, 0, cmpBlockBuf.length, Deflater.NO_FLUSH);
                            outStreamMap.put(counter, 
                                            new Tuple<Integer, byte[]>(deflatedBytes, cmpBlockBuf));
                            // if (deflatedBytes > 0) 
                            // {
                            //     outStream.write(cmpBlockBuf, 0, deflatedBytes);
                            // }
                        }
                        counter++;
                    }
                }
            } 
            else 
            {
                /* Otherwise, just deflate and then write the compressed block out. Not using SYNC_FLUSH here leads to
                some issues, but using it probably results in less efficient compression. There's probably a better
                way to deal with this. */
                if (counter < nThreads)
                {
                    SingleBlockCompress curBlock = new SingleBlockCompress(compressor);
                    threads[counter] = new Thread(curBlock);
                    threads[counter].start();
                    outStreamMap.put(counter, curBlock.getValue());
                }
                else
                {
                    int deflatedBytes = compressor.deflate(cmpBlockBuf, 0, cmpBlockBuf.length, Deflater.NO_FLUSH);
                    outStreamMap.put(counter, 
                                    new Tuple<Integer, byte[]>(deflatedBytes, cmpBlockBuf));
                }
                counter++;
            }

                /* If we read in enough bytes in this block, store the last part as the dictionary for the
                next iteration */
            if (nBytes >= DICT_SIZE) 
            {
                System.arraycopy(blockBuf, nBytes - DICT_SIZE, dictBuf, 0, DICT_SIZE);
                hasDict = true;
            } 
            else 
            {
                hasDict = false;
            }
            nBytes = inStream.read(blockBuf);
            totalBytesRead += nBytes;
        }

        int actualThreads = nThreads < counter ? nThreads : counter;
        for (int i = 0; i < actualThreads; i++)
        {
            try {
                threads[i].join();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }
        
        counter = 0;
        while (! outStreamMap.isEmpty())
        {
            Tuple<Integer, byte[]> compressedBlock = 
            outStreamMap.remove(counter);
            if (compressedBlock != null && compressedBlock.x > 0)
            {
                outStream.write(compressedBlock.y, 0, compressedBlock.x);
            }
            counter++;
        }

        /* Finally, write the trailer and then write to STDOUT */
        byte[] trailerBuf = new byte[TRAILER_SIZE];
        writeTrailer(fileBytes, trailerBuf, 0);
        outStream.write(trailerBuf);

        outStream.writeTo(System.out);
    }
}

class SingleBlockCompress implements Runnable 
{
    private Tuple <Integer, byte[]> compressedBlock;
    private byte[] cmpBlockBuf;
    private Deflater compressor;
    public final static int BLOCK_SIZE = 131072; // 128 KB


    public SingleBlockCompress (Deflater compressor)
    {
        this.compressor = compressor;
        this.cmpBlockBuf = new byte[BLOCK_SIZE * 2];
        this.compressedBlock = new Tuple<Integer, byte[]>(0, cmpBlockBuf);
    }

    // do compression on one block

    public void run()
    {
        synchronized(compressor)
        {
            int deflatedBytes = compressor.deflate(cmpBlockBuf, 0, cmpBlockBuf.length, Deflater.SYNC_FLUSH);
            compressedBlock.x = deflatedBytes;
            compressedBlock.y = cmpBlockBuf;
        }

    }

    public Tuple<Integer, byte[]> getValue()
    {
        return compressedBlock;
    }

}


class Tuple <X, Y> {
    public X x;
    public Y y;
    public Tuple(X x, Y y)
    {
        this.x = x;
        this.y = y;
    }
}

public class Pigzj
{
    public static void main (String[] args) throws NumberFormatException, IOException 
    {
        // for (int k = 0; k < 5; k++)
        // {
        //     byte[] current_buf = new byte[1];
        //     System.in.read(current_buf);
        //     System.out.println(current_buf);
        // }

        int nThreads = 0;
        if (args.length == 0) 
        {
            nThreads = Runtime.getRuntime().availableProcessors();
        }
        else if ((! args[0].equals("-p")) || (args.length != 2))
        {
            System.err.println("Usage: Pigzj only supports -p processes option");
            System.exit(1);
        }
        else nThreads = (int) Integer.parseInt(args[1]);

        // System.out.println(nThreads);

        // var counter = new AtomicInteger(0);
        // Thread threads [] = new Thread [nThreads];
        // for (int i = 0; i < nThreads; i++)
        // {
        //     threads[i] = new Thread(new ParallelThreads(counter));
        //     threads[i].start();
        // }
        // for (int i = 0; i < nThreads; i++)
        // {
        //     try {
        //         threads[i].join();
        //     } catch (InterruptedException e) {
        //         e.printStackTrace();
        //     }
        // }

        SingleThreadedGZipCompressor cmp = new SingleThreadedGZipCompressor(nThreads);
        cmp.compress();
    }
}