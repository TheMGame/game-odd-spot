#!/usr/bin/env node
"use strict";

const fs = require("fs");
const zlib = require("zlib");

const MAX_MEMORY_PAGES = 4096; // 256 MiB; avoids iOS WebAssembly 2 GiB startup failures.

function readUleb(buffer, offset) {
    let value = 0;
    let shift = 0;
    let cursor = offset;
    while (cursor < buffer.length) {
        const byte = buffer[cursor++];
        value += (byte & 0x7f) * 2 ** shift;
        if ((byte & 0x80) === 0) {
            return { value, next: cursor };
        }
        shift += 7;
    }
    throw new Error("truncated unsigned LEB128");
}

function writeUleb(value) {
    const bytes = [];
    let remaining = value;
    do {
        let byte = remaining % 128;
        remaining = Math.floor(remaining / 128);
        if (remaining !== 0) byte |= 0x80;
        bytes.push(byte);
    } while (remaining !== 0);
    return Buffer.from(bytes);
}

function patchMemorySection(payload) {
    let cursor = 0;
    const countResult = readUleb(payload, cursor);
    cursor = countResult.next;
    const chunks = [writeUleb(countResult.value)];
    let changed = false;

    for (let index = 0; index < countResult.value; index += 1) {
        const flagsResult = readUleb(payload, cursor);
        cursor = flagsResult.next;
        const initialResult = readUleb(payload, cursor);
        cursor = initialResult.next;
        const hasMaximum = (flagsResult.value & 1) !== 0;
        const maximumResult = hasMaximum ? readUleb(payload, cursor) : null;
        if (maximumResult) cursor = maximumResult.next;

        let flags = flagsResult.value;
        let maximum = maximumResult ? maximumResult.value : MAX_MEMORY_PAGES;
        if (!hasMaximum) flags |= 1;
        if (maximum > MAX_MEMORY_PAGES) {
            maximum = MAX_MEMORY_PAGES;
            changed = true;
        }
        if (initialResult.value > maximum) {
            throw new Error(
                `initial WebAssembly memory ${initialResult.value} pages exceeds ${maximum}`
            );
        }

        chunks.push(writeUleb(flags), writeUleb(initialResult.value), writeUleb(maximum));
        // Preserve an optional page-size field used by newer memory flags.
        if ((flagsResult.value & 8) !== 0) {
            const pageSizeResult = readUleb(payload, cursor);
            cursor = pageSizeResult.next;
            chunks.push(writeUleb(pageSizeResult.value));
        }
    }
    if (cursor !== payload.length) {
        throw new Error("unexpected trailing bytes in WebAssembly memory section");
    }
    return { payload: Buffer.concat(chunks), changed };
}

function patchWasm(wasm) {
    if (
        wasm.length < 8 ||
        wasm.readUInt32LE(0) !== 0x6d736100 ||
        wasm.readUInt32LE(4) !== 1
    ) {
        throw new Error("not a WebAssembly v1 module");
    }

    const output = [wasm.subarray(0, 8)];
    let cursor = 8;
    let memoryFound = false;
    let changed = false;
    while (cursor < wasm.length) {
        const sectionId = wasm[cursor++];
        const sizeResult = readUleb(wasm, cursor);
        cursor = sizeResult.next;
        const end = cursor + sizeResult.value;
        if (end > wasm.length) throw new Error("truncated WebAssembly section");
        let payload = wasm.subarray(cursor, end);
        if (sectionId === 5) {
            const patched = patchMemorySection(payload);
            payload = patched.payload;
            memoryFound = true;
            changed = changed || patched.changed;
        }
        output.push(Buffer.from([sectionId]), writeUleb(payload.length), payload);
        cursor = end;
    }
    if (!memoryFound) throw new Error("WebAssembly module has no memory section");
    return { wasm: Buffer.concat(output), changed };
}

function main() {
    const target = process.argv[2];
    if (!target) {
        throw new Error("Usage: patch_wasm_memory.js <godot.wasm.br>");
    }
    const compressed = fs.readFileSync(target);
    const original = zlib.brotliDecompressSync(compressed);
    const result = patchWasm(original);
    const patched = zlib.brotliCompressSync(result.wasm, {
        params: {
            [zlib.constants.BROTLI_PARAM_MODE]: zlib.constants.BROTLI_MODE_GENERIC,
            [zlib.constants.BROTLI_PARAM_QUALITY]: 9,
        },
    });
    fs.writeFileSync(target, patched);
    console.log(
        `WASM_MEMORY_LIMIT_OK max=${MAX_MEMORY_PAGES * 65536 / 1048576}MiB ` +
        `changed=${result.changed} compressed=${patched.length}`
    );
}

try {
    main();
} catch (error) {
    console.error(`WASM_MEMORY_LIMIT_FAILED: ${error && error.message || error}`);
    process.exit(1);
}
