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

```c3
import miniz;

fn void compress_example() {
    MzStream stream;

    // Initialize deflate compressor (level 6 = default)
    if (miniz::mz_deflateInit(&stream, miniz::MZ_DEFAULT_LEVEL) != miniz::MZ_OK) {
        return; // handle error
    }
    defer miniz::mz_deflateEnd(&stream);

    // Set input/output buffers
    char[] input = "Hello, World!";
    char[128] output;

    stream.next_in = input.ptr;
    stream.avail_in = (uint)input.len;
    stream.next_out = &output[0];
    stream.avail_out = output.len;

    // Compress
    if (miniz::mz_deflate(&stream, miniz::MZ_FINISH) == miniz::MZ_STREAM_END) {
        // output[0..stream.total_out] contains compressed data
    }
}
```

## API

### Constants

- `MZ_DEFAULT_LEVEL` (6) - Default compression level
- `MZ_NO_FLUSH`, `MZ_SYNC_FLUSH`, `MZ_FINISH` - Flush modes
- `MZ_OK`, `MZ_STREAM_END`, `MZ_DATA_ERROR`, etc. - Return codes

### Deflate (Compression)

- `mz_deflateInit(stream, level)` - Initialize compressor
- `mz_deflateInit2(stream, level, method, window_bits, mem_level, strategy)` - Initialize with options
- `mz_deflate(stream, flush)` - Compress data
- `mz_deflateReset(stream)` - Reset for reuse
- `mz_deflateEnd(stream)` - Free resources
- `mz_deflateBound(stream, source_len)` - Get max compressed size

### Inflate (Decompression)

- `mz_inflateInit(stream)` - Initialize decompressor
- `mz_inflateInit2(stream, window_bits)` - Initialize with window size
- `mz_inflate(stream, flush)` - Decompress data
- `mz_inflateReset(stream)` - Reset for reuse
- `mz_inflateEnd(stream)` - Free resources

## License

MIT License - See [LICENSE](LICENSE)
