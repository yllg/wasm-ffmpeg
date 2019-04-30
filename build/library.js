mergeInto(LibraryManager.library, {
  emscripten_binary_read__deps: ['$EmterpreterAsync'],
  emscripten_binary_read: function(buf, size) {
    return EmterpreterAsync.handle(function(resume) {
      Module['stdinAsync'](size, function(data) {
        var finalSize = Math.min(size, data.length);
        Module['HEAPU8'].set(data.subarray(0, finalSize), buf);
        resume(function() { return finalSize; });
      });
    });
  },

  emscripten_binary_write: function(buf, size) {
    Module['stdoutBinary'](Module['HEAPU8'].subarray(buf, buf + size));
    return size;
  }
});
