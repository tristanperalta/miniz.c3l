/**
 * Tests for miniz C3 bindings
 */
module miniz_test @test;

import miniz;
import std::core::mem;

fn void test_deflate_inflate_roundtrip()
{
    // Test data - repeated text compresses well
    char[] input = "This is a test.This is a test.This is a test.1234567This is a test.This is a test.123456";
    usz input_len = input.len;

    // Buffers
    char[1024] compressed;
    char[1024] decompressed;

    // Initialize and run deflate
    miniz::MzStream deflate_stream;
    mem::clear(&deflate_stream, MzStream.sizeof);

    int ret = miniz::mz_deflateInit(&deflate_stream, miniz::MZ_DEFAULT_LEVEL);
    assert(ret == miniz::MZ_OK, "mz_deflateInit failed");

    deflate_stream.next_in = input.ptr;
    deflate_stream.avail_in = (uint)input_len;
    deflate_stream.next_out = &compressed[0];
    deflate_stream.avail_out = (uint)compressed.len;

    ret = miniz::mz_deflate(&deflate_stream, miniz::MZ_FINISH);
    assert(ret == miniz::MZ_STREAM_END, "mz_deflate failed");

    usz compressed_len = deflate_stream.total_out;
    miniz::mz_deflateEnd(&deflate_stream);

    // Verify compression actually reduced size
    assert(compressed_len < input_len, "compression should reduce size");

    // Initialize and run inflate
    miniz::MzStream inflate_stream;
    mem::clear(&inflate_stream, MzStream.sizeof);

    ret = miniz::mz_inflateInit(&inflate_stream);
    assert(ret == miniz::MZ_OK, "mz_inflateInit failed");

    inflate_stream.next_in = &compressed[0];
    inflate_stream.avail_in = (uint)compressed_len;
    inflate_stream.next_out = &decompressed[0];
    inflate_stream.avail_out = (uint)decompressed.len;

    ret = miniz::mz_inflate(&inflate_stream, miniz::MZ_FINISH);
    assert(ret == miniz::MZ_STREAM_END, "mz_inflate failed");

    usz decompressed_len = inflate_stream.total_out;
    miniz::mz_inflateEnd(&inflate_stream);

    // Verify round-trip
    assert(decompressed_len == input_len, "decompressed length should match input");

    for (usz i = 0; i < input_len; i++) {
        assert(decompressed[i] == input[i], "data mismatch after round-trip");
    }
}

fn void test_version()
{
    char* version = miniz::mz_version();
    assert(version != null, "mz_version should return non-null");
}

fn void test_deflate_bound()
{
    miniz::MzStream stream;
    mem::clear(&stream, MzStream.sizeof);

    miniz::mz_deflateInit(&stream, miniz::MZ_DEFAULT_LEVEL);
    miniz::MzUlong bound = miniz::mz_deflateBound(&stream, 1000);
    miniz::mz_deflateEnd(&stream);

    assert(bound > 1000, "deflate bound should be larger than input for safety margin");
}

// ============================================================================
// Simple one-shot APIs
// ============================================================================

fn void test_compress_uncompress()
{
    char[] input = "This is a test.This is a test.This is a test.1234567This is a test.This is a test.123456";
    usz input_len = input.len;

    // Get upper bound for compressed size
    miniz::MzUlong bound = miniz::mz_compressBound((miniz::MzUlong)input_len);
    assert(bound > 0, "mz_compressBound should return positive value");

    // Compress
    char[1024] compressed;
    miniz::MzUlong compressed_len = compressed.len;
    int ret = miniz::mz_compress(&compressed[0], &compressed_len, input.ptr, (miniz::MzUlong)input_len);
    assert(ret == miniz::MZ_OK, "mz_compress failed");
    assert(compressed_len < input_len, "compression should reduce size");
    assert(compressed_len <= bound, "compressed size should be within bound");

    // Decompress
    char[1024] decompressed;
    miniz::MzUlong decompressed_len = decompressed.len;
    ret = miniz::mz_uncompress(&decompressed[0], &decompressed_len, &compressed[0], compressed_len);
    assert(ret == miniz::MZ_OK, "mz_uncompress failed");
    assert(decompressed_len == input_len, "decompressed length should match input");

    // Verify data
    for (usz i = 0; i < input_len; i++) {
        assert(decompressed[i] == input[i], "data mismatch after round-trip");
    }
}

fn void test_compress2_levels()
{
    char[] input = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    usz input_len = input.len;

    char[256] compressed_fast;
    char[256] compressed_best;
    miniz::MzUlong len_fast = compressed_fast.len;
    miniz::MzUlong len_best = compressed_best.len;

    // Compress with fastest
    int ret = miniz::mz_compress2(&compressed_fast[0], &len_fast, input.ptr, (miniz::MzUlong)input_len, miniz::MZ_BEST_SPEED);
    assert(ret == miniz::MZ_OK, "mz_compress2 MZ_BEST_SPEED failed");

    // Compress with best
    ret = miniz::mz_compress2(&compressed_best[0], &len_best, input.ptr, (miniz::MzUlong)input_len, miniz::MZ_BEST_COMPRESSION);
    assert(ret == miniz::MZ_OK, "mz_compress2 MZ_BEST_COMPRESSION failed");

    // Best compression should be <= fast compression (or equal for small data)
    assert(len_best <= len_fast, "best compression should produce smaller or equal output");
}

// ============================================================================
// Checksum APIs
// ============================================================================

fn void test_crc32()
{
    char[] data = "Hello, World!";

    // Calculate CRC-32
    miniz::MzUlong crc = miniz::mz_crc32(miniz::MZ_CRC32_INIT, data.ptr, data.len);
    assert(crc != 0, "CRC-32 should be non-zero for non-empty data");

    // CRC-32 of same data should be consistent
    miniz::MzUlong crc2 = miniz::mz_crc32(miniz::MZ_CRC32_INIT, data.ptr, data.len);
    assert(crc == crc2, "CRC-32 should be deterministic");

    // Incremental CRC should match single-shot
    miniz::MzUlong crc_inc = miniz::mz_crc32(miniz::MZ_CRC32_INIT, data.ptr, 7);  // "Hello, "
    crc_inc = miniz::mz_crc32(crc_inc, &data[7], data.len - 7);  // "World!"
    assert(crc == crc_inc, "incremental CRC should match single-shot");
}

fn void test_adler32()
{
    char[] data = "Hello, World!";

    // Calculate Adler-32
    miniz::MzUlong adler = miniz::mz_adler32(miniz::MZ_ADLER32_INIT, data.ptr, data.len);
    assert(adler != miniz::MZ_ADLER32_INIT, "Adler-32 should change for non-empty data");

    // Adler-32 of same data should be consistent
    miniz::MzUlong adler2 = miniz::mz_adler32(miniz::MZ_ADLER32_INIT, data.ptr, data.len);
    assert(adler == adler2, "Adler-32 should be deterministic");

    // Incremental Adler should match single-shot
    miniz::MzUlong adler_inc = miniz::mz_adler32(miniz::MZ_ADLER32_INIT, data.ptr, 7);
    adler_inc = miniz::mz_adler32(adler_inc, &data[7], data.len - 7);
    assert(adler == adler_inc, "incremental Adler should match single-shot");
}

// ============================================================================
// Low-level tdefl/tinfl APIs
// ============================================================================

fn void test_tdefl_tinfl_mem_to_heap()
{
    char[] input = "This is a test.This is a test.This is a test.1234567This is a test.This is a test.123456";
    usz input_len = input.len;

    // Compress to heap
    usz compressed_len;
    int flags = miniz::TDEFL_WRITE_ZLIB_HEADER | miniz::TDEFL_DEFAULT_MAX_PROBES;
    void* compressed = miniz::tdefl_compress_mem_to_heap(input.ptr, input_len, &compressed_len, flags);
    assert(compressed != null, "tdefl_compress_mem_to_heap failed");
    assert(compressed_len > 0, "compressed length should be positive");

    // Decompress from heap
    usz decompressed_len;
    void* decompressed = miniz::tinfl_decompress_mem_to_heap(compressed, compressed_len, &decompressed_len, miniz::TINFL_FLAG_PARSE_ZLIB_HEADER);
    assert(decompressed != null, "tinfl_decompress_mem_to_heap failed");
    assert(decompressed_len == input_len, "decompressed length should match input");

    // Verify data
    char* decomp_chars = (char*)decompressed;
    for (usz i = 0; i < input_len; i++) {
        assert(decomp_chars[i] == input[i], "data mismatch after tdefl/tinfl round-trip");
    }

    // Free heap allocations
    miniz::mz_free(compressed);
    miniz::mz_free(decompressed);
}

fn void test_tdefl_tinfl_mem_to_mem()
{
    char[] input = "This is a test.This is a test.This is a test.1234567This is a test.This is a test.123456";
    usz input_len = input.len;

    char[1024] compressed;
    char[1024] decompressed;

    // Compress to fixed buffer
    int flags = miniz::TDEFL_WRITE_ZLIB_HEADER | miniz::TDEFL_DEFAULT_MAX_PROBES;
    usz compressed_len = miniz::tdefl_compress_mem_to_mem(&compressed[0], compressed.len, input.ptr, input_len, flags);
    assert(compressed_len > 0, "tdefl_compress_mem_to_mem failed");

    // Decompress to fixed buffer
    usz decompressed_len = miniz::tinfl_decompress_mem_to_mem(&decompressed[0], decompressed.len, &compressed[0], compressed_len, miniz::TINFL_FLAG_PARSE_ZLIB_HEADER);
    assert(decompressed_len == input_len, "tinfl_decompress_mem_to_mem failed");

    // Verify data
    for (usz i = 0; i < input_len; i++) {
        assert(decompressed[i] == input[i], "data mismatch");
    }
}
