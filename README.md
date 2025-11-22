# miniz.c3l

C3 bindings for [miniz](https://github.com/richgel999/miniz), a lossless, high performance data compression library that implements zlib (RFC 1950) and Deflate (RFC 1951).

## Installation

Add this library to your project's `project.json`:

```json
{
  "dependencies": ["miniz"]
}
```

clone directly into your `lib` directory:

```bash
git clone --recursive https://github.com/user/miniz.c3l lib/miniz.c3l
```

## Usage

### Simple One-Shot API (Recommended)

```c3
import miniz;

fn void simple_compress_example() {
    char[] input = "Hello, World! This text will be compressed.";

    // Get max compressed size
    MzUlong bound = miniz::mz_compressBound((MzUlong)input.len);

    // Compress
    char[256] compressed;
    MzUlong compressed_len = compressed.len;
    if (miniz::mz_compress(&compressed[0], &compressed_len, input.ptr, (MzUlong)input.len) == miniz::MZ_OK) {
        // compressed[0..compressed_len] contains compressed data
    }

    // Decompress
    char[256] decompressed;
    MzUlong decompressed_len = decompressed.len;
    if (miniz::mz_uncompress(&decompressed[0], &decompressed_len, &compressed[0], compressed_len) == miniz::MZ_OK) {
        // decompressed[0..decompressed_len] contains original data
    }
}
```

### Streaming API

```c3
import miniz;
import std::core::mem;

fn void stream_compress_example() {
    MzStream stream;
    mem::clear(&stream, MzStream.sizeof);

    // Initialize deflate compressor (level 6 = default)
    if (miniz::mz_deflateInit(&stream, miniz::MZ_DEFAULT_LEVEL) != miniz::MZ_OK) {
        return;
    }
    defer miniz::mz_deflateEnd(&stream);

    char[] input = "Hello, World!";
    char[128] output;

    stream.next_in = input.ptr;
    stream.avail_in = (uint)input.len;
    stream.next_out = &output[0];
    stream.avail_out = output.len;

    if (miniz::mz_deflate(&stream, miniz::MZ_FINISH) == miniz::MZ_STREAM_END) {
        // output[0..stream.total_out] contains compressed data
    }
}
```

### Low-Level API

```c3
import miniz;

fn void low_level_example() {
    char[] input = "Data to compress";

    // Compress to heap (caller must free with mz_free)
    usz compressed_len;
    int flags = miniz::TDEFL_WRITE_ZLIB_HEADER | miniz::TDEFL_DEFAULT_MAX_PROBES;
    void* compressed = miniz::tdefl_compress_mem_to_heap(input.ptr, input.len, &compressed_len, flags);
    defer miniz::mz_free(compressed);

    // Decompress from heap
    usz decompressed_len;
    void* decompressed = miniz::tinfl_decompress_mem_to_heap(compressed, compressed_len, &decompressed_len, miniz::TINFL_FLAG_PARSE_ZLIB_HEADER);
    defer miniz::mz_free(decompressed);
}
```

## API Reference

### Constants

**Compression Levels:**
- `MZ_NO_COMPRESSION` (0) - No compression
- `MZ_BEST_SPEED` (1) - Fastest compression
- `MZ_DEFAULT_LEVEL` (6) - Default compression level
- `MZ_BEST_COMPRESSION` (9) - Best compression ratio
- `MZ_UBER_COMPRESSION` (10) - Maximum compression (slower)

**Return Codes:**
- `MZ_OK`, `MZ_STREAM_END`, `MZ_DATA_ERROR`, `MZ_MEM_ERROR`, `MZ_BUF_ERROR`, etc.

**Checksum Init Values:**
- `MZ_CRC32_INIT` (0) - Initial value for CRC-32
- `MZ_ADLER32_INIT` (1) - Initial value for Adler-32

### Simple One-Shot Functions

- `mz_compress(dest, dest_len, source, source_len)` - Compress in one call
- `mz_compress2(dest, dest_len, source, source_len, level)` - Compress with level
- `mz_uncompress(dest, dest_len, source, source_len)` - Decompress in one call
- `mz_compressBound(source_len)` - Get max compressed size

### Streaming Deflate (Compression)

- `mz_deflateInit(stream, level)` - Initialize compressor
- `mz_deflateInit2(stream, level, method, window_bits, mem_level, strategy)` - Initialize with options
- `mz_deflate(stream, flush)` - Compress data
- `mz_deflateReset(stream)` - Reset for reuse
- `mz_deflateEnd(stream)` - Free resources
- `mz_deflateBound(stream, source_len)` - Get max compressed size

### Streaming Inflate (Decompression)

- `mz_inflateInit(stream)` - Initialize decompressor
- `mz_inflateInit2(stream, window_bits)` - Initialize with window size
- `mz_inflate(stream, flush)` - Decompress data
- `mz_inflateReset(stream)` - Reset for reuse
- `mz_inflateEnd(stream)` - Free resources

### Checksums

- `mz_crc32(crc, ptr, len)` - Calculate CRC-32
- `mz_adler32(adler, ptr, len)` - Calculate Adler-32

### Low-Level tdefl (Compression)

- `tdefl_compress_mem_to_heap(src, src_len, out_len, flags)` - Compress to malloc'd buffer
- `tdefl_compress_mem_to_mem(out, out_len, src, src_len, flags)` - Compress to fixed buffer
- `tdefl_compressor_alloc()` / `tdefl_compressor_free(comp)` - Allocate/free compressor

**Flags:** `TDEFL_WRITE_ZLIB_HEADER`, `TDEFL_COMPUTE_ADLER32`, `TDEFL_DEFAULT_MAX_PROBES`, etc.

### Low-Level tinfl (Decompression)

- `tinfl_decompress_mem_to_heap(src, src_len, out_len, flags)` - Decompress to malloc'd buffer
- `tinfl_decompress_mem_to_mem(out, out_len, src, src_len, flags)` - Decompress to fixed buffer
- `tinfl_decompressor_alloc()` / `tinfl_decompressor_free(decomp)` - Allocate/free decompressor

**Flags:** `TINFL_FLAG_PARSE_ZLIB_HEADER`, `TINFL_FLAG_COMPUTE_ADLER32`, etc.

### ZIP Archive Reading

**Types:**
- `MzZipArchive` - Main archive struct
- `MzZipArchiveFileStat` - File metadata (filename, sizes, CRC, etc.)

**Reader Init/End:**
- `mz_zip_zero_struct(zip)` - Clear struct before use (required!)
- `mz_zip_reader_init_mem(zip, mem, size, flags)` - From memory buffer
- `mz_zip_reader_init_file(zip, filename, flags)` - From file
- `mz_zip_reader_end(zip)` - Free resources

**Query:**
- `mz_zip_reader_get_num_files(zip)` - File count
- `mz_zip_reader_get_filename(zip, index, buf, buf_size)` - Get filename
- `mz_zip_reader_locate_file(zip, name, comment, flags)` - Find file by name
- `mz_zip_reader_file_stat(zip, index, stat)` - Get file metadata
- `mz_zip_reader_is_file_a_directory(zip, index)`

**Extract:**
- `mz_zip_reader_extract_to_mem(zip, index, buf, buf_size, flags)`
- `mz_zip_reader_extract_file_to_mem(zip, filename, buf, buf_size, flags)`
- `mz_zip_reader_extract_to_heap(zip, index, size, flags)` - Returns malloc'd buffer
- `mz_zip_reader_extract_file_to_heap(zip, filename, size, flags)`
- `mz_zip_reader_extract_to_file(zip, index, dst_filename, flags)`

### ZIP Archive Writing

**Writer Init/End:**
- `mz_zip_writer_init_heap(zip, reserve, initial_size)` - To memory
- `mz_zip_writer_init_file(zip, filename, reserve)` - To file
- `mz_zip_writer_finalize_archive(zip)` - Must call before end
- `mz_zip_writer_finalize_heap_archive(zip, buf, size)` - Get heap buffer
- `mz_zip_writer_end(zip)` - Free resources

**Add Files:**
- `mz_zip_writer_add_mem(zip, name, buf, size, level_and_flags)`
- `mz_zip_writer_add_file(zip, name, src_filename, comment, comment_size, level_and_flags)`

**Flags:** `MZ_ZIP_FLAG_CASE_SENSITIVE`, `MZ_ZIP_FLAG_IGNORE_PATH`, `MZ_ZIP_FLAG_WRITE_ZIP64`, etc.

**High-Level Helpers:**
- `mz_zip_add_mem_to_archive_file_in_place(filename, name, buf, size, ...)` - Append to file
- `mz_zip_extract_archive_file_to_heap(filename, name, size, flags)` - Extract single file

### Utility

- `mz_version()` - Get miniz version string
- `mz_free(ptr)` - Free miniz-allocated memory
- `mz_zip_get_last_error(zip)` - Get last ZIP error
- `mz_zip_get_error_string(err)` - Error code to string
- `mz_zip_end(zip)` - Universal end (reader or writer)

## License

MIT License - See [LICENSE](LICENSE)
