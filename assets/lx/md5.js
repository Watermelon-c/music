/**
 * 极简 MD5 实现，供 LX 自定义源脚本调用 lx.utils.crypto.md5 时使用。
 * 浏览器 / WebView / Node 都可用。只依赖 TextEncoder。
 * 用法：md5('abc') => '900150983cd24fb0d6963f7d28e17f72'
 */
var md5 = (function () {
  var S = [7, 12, 17, 22, 5, 9, 14, 20, 4, 11, 16, 23, 6, 10, 15, 21];

  var K = [];
  for (var i = 0; i < 64; i++) {
    K[i] = Math.floor(Math.abs(Math.sin(i + 1)) * 0x100000000) >>> 0;
  }

  function rotl(x, n) {
    return ((x << n) | (x >>> (32 - n))) >>> 0;
  }

  function toBytes(input) {
    if (typeof input === 'string') return new TextEncoder().encode(input);
    if (input instanceof Uint8Array) return input;
    if (input && input.bytes instanceof Uint8Array) return input.bytes;
    if (Array.isArray(input)) return new Uint8Array(input);
    throw new Error('md5: 不支持的类型');
  }

  return function md5(input) {
    var msg = toBytes(input);
    var bitLen = msg.length * 8;
    var total = ((((msg.length + 8) >> 6) + 1) << 6);
    var buf = new Uint8Array(total);
    buf.set(msg);
    buf[msg.length] = 0x80;

    var dv = new DataView(buf.buffer);
    dv.setUint32(total - 8, bitLen >>> 0, true);
    dv.setUint32(total - 4, Math.floor(bitLen / 0x100000000), true);

    var a0 = 0x67452301;
    var b0 = 0xefcdab89;
    var c0 = 0x98badcfe;
    var d0 = 0x10325476;

    for (var off = 0; off < total; off += 64) {
      var M = [];
      for (var j = 0; j < 16; j++) M[j] = dv.getUint32(off + j * 4, true);

      var A = a0;
      var B = b0;
      var C = c0;
      var D = d0;

      for (var k = 0; k < 64; k++) {
        var F;
        var g;
        if (k < 16) {
          F = (B & C) | (~B & D);
          g = k;
        } else if (k < 32) {
          F = (D & B) | (~D & C);
          g = (5 * k + 1) % 16;
        } else if (k < 48) {
          F = B ^ C ^ D;
          g = (3 * k + 5) % 16;
        } else {
          F = C ^ (B | ~D);
          g = (7 * k) % 16;
        }
        F = (F + A + K[k] + M[g]) >>> 0;
        A = D;
        D = C;
        C = B;
        B = (B + rotl(F, S[(k >> 4) * 4 + (k % 4)])) >>> 0;
      }

      a0 = (a0 + A) >>> 0;
      b0 = (b0 + B) >>> 0;
      c0 = (c0 + C) >>> 0;
      d0 = (d0 + D) >>> 0;
    }

    var words = [a0, b0, c0, d0];
    var out = '';
    for (var w = 0; w < 4; w++) {
      for (var b = 0; b < 4; b++) {
        var byte = (words[w] >>> (b * 8)) & 0xff;
        out += byte.toString(16).padStart(2, '0');
      }
    }
    return out;
  };
})();

if (typeof globalThis !== 'undefined') globalThis.__md5 = md5;
