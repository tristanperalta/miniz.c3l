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
