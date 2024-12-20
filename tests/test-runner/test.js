"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.TESTS = void 0;
exports.test = test;
exports.TESTS = [];
function test(luaFile, callback, desc) {
    exports.TESTS.push({ luaFile: luaFile, init: callback, desc: desc });
}
