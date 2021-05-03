import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.zip.*;


import java.io.*;
import java.nio.file.*;


class SharedVariables 
{
    public final static int BLOCK_SIZE = 131072; // 128 KB
    public final static int DICT_SIZE = 32768; // 32 KB
    public static ConcurrentHashMap<Integer, byte[]> outStreamMap = new ConcurrentHashMap<Integer, byte[]>();
    public static ConcurrentHashMap<Integer, Integer> bytesMap = new ConcurrentHashMap<Integer, Integer>();
    public static ConcurrentHashMap<Integer, byte[]> primingMap = new ConcurrentHashMap<Integer, byte[]>();

}

class SingleThreadedGZipCompressor 
{
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

    public void compress() throws FileNotFoundException, IOException, OutOfMemoryError 
    {

        this.writeHeader();
        this.crc.reset();

        /* Buffers for input blocks, compressed bocks, and dictionaries */
        byte[] blockBuf = new byte[SharedVariables.BLOCK_SIZE];
        // byte[] cmpBlockBuf = new byte[BLOCK_SIZE * 2];
        // byte[] dictBuf = new byte[DICT_SIZE];
        // Deflater compressor = new Deflater(Deflater.DEFAULT_COMPRESSION, true);

        ExecutorService executor = Executors.newFixedThreadPool(nThreads);;

        // File file = new File(this.fileName);
        // long fileBytes = file.length();
        long fileBytes = System.in.available();
        // System.out.println(fileBytes);
        // InputStream inStream = new FileInputStream(file);
        InputStream inStream = System.in;
        PushbackInputStream push = new PushbackInputStream(inStream);

        long totalBytesRead = 0;
        // boolean hasDict = false;
        int nBytes = push.read(blockBuf, 0, SharedVariables.BLOCK_SIZE);
        int curBlock = 0;
        if (nBytes > 0) totalBytesRead += nBytes;
        while (nBytes > 0) 
        {
            /* Update the CRC every time we read in a new block. */
            crc.update(blockBuf, 0, nBytes);
            boolean finishedFlag = (totalBytesRead == fileBytes);

            SingleBlockCompress worker = new SingleBlockCompress(blockBuf, nBytes, curBlock, finishedFlag);
            executor.execute(worker);

            nBytes = push.read(blockBuf, 0, SharedVariables.BLOCK_SIZE);
  
            if (nBytes > 0) totalBytesRead += nBytes;
            curBlock++;
        }


        executor.shutdown();
        while(!executor.isTerminated()) {}
        
        
        curBlock = 0;
        while (! SharedVariables.outStreamMap.isEmpty())
        {
            byte[] cmpBlockBuf = SharedVariables.outStreamMap.remove(curBlock);
            int deflatedBytes = SharedVariables.bytesMap.remove(curBlock);
            if (cmpBlockBuf != null && deflatedBytes > 0)
            {
                outStream.write(cmpBlockBuf, 0, deflatedBytes);
            }
            curBlock++;
        }

        /* Finally, write the trailer and then write to STDOUT */
        byte[] trailerBuf = new byte[TRAILER_SIZE];
        writeTrailer(fileBytes, trailerBuf, 0);
        outStream.write(trailerBuf);

        try {
            outStream.writeTo(System.out);
        } catch (IOException e) {
            System.err.println("write error: " + e.getMessage());
            System.exit(1);
        }
    }
}

class SingleBlockCompress implements Runnable 
{
    private byte[] blockBuf;
    private int blockId;
    private int nBytes;
    private boolean finishFlag;


    public SingleBlockCompress (byte[] blockBuf, int blockBytes, int id, boolean flag)
    {
        this.blockId = id;
        this.finishFlag = flag;
        this.nBytes = blockBytes;
        this.blockBuf = new byte[SharedVariables.BLOCK_SIZE];
        System.arraycopy(blockBuf, 0, this.blockBuf, 0, blockBytes);
    }

    // do compression on one block
    public void run()
    {
        Deflater compressor = new Deflater(Deflater.DEFAULT_COMPRESSION, true);

        byte[] cmpBlockBuf = new byte[SharedVariables.BLOCK_SIZE * 2];
        byte[] dictBuf = new byte[SharedVariables.DICT_SIZE];

        compressor.reset();

        if (SharedVariables.primingMap.containsKey(blockId-1))
        {
            compressor.setDictionary(SharedVariables.primingMap.get(blockId-1));
        }

        compressor.setInput(blockBuf, 0, nBytes);

        if (finishFlag)
        {
            if (!compressor.finished()) 
                {
                    compressor.finish();
                    while (!compressor.finished()) 
                    {
                        // need to be modified
                        int deflatedBytes = compressor.deflate(cmpBlockBuf, 0, cmpBlockBuf.length, Deflater.SYNC_FLUSH);
                        SharedVariables.outStreamMap.put(blockId, cmpBlockBuf);
                        SharedVariables.bytesMap.put(blockId, deflatedBytes);
                    }
                }
        }
        else
        {
            int deflatedBytes = compressor.deflate(cmpBlockBuf, 0, cmpBlockBuf.length, Deflater.SYNC_FLUSH);
            SharedVariables.outStreamMap.put(blockId, cmpBlockBuf);
            SharedVariables.bytesMap.put(blockId, deflatedBytes);
        }

        if (nBytes >= SharedVariables.DICT_SIZE)
        {
            System.arraycopy(blockBuf, nBytes - SharedVariables.DICT_SIZE, dictBuf, 0, SharedVariables.DICT_SIZE);
            SharedVariables.primingMap.put(blockId, dictBuf);
        }

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

        if (nThreads <= 0)
        {
            System.err.println("Thread number should be positive");
            System.exit(1);
        }

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
        try {
            cmp.compress(); 
        }
        catch (IOException e)
        {
            System.out.println(e.getCause());
            System.exit(1);
        }
        catch (OutOfMemoryError e)
        {
            System.out.println(e.getCause());
            System.exit(1);
        }
    }
}