"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
const child_process_1 = require("child_process");
const crypto_1 = require("crypto");
const fs_1 = require("fs");
require("./list");
const test_1 = require("./test");
const UUID = process.env['AZUL_UUID'] || (0, crypto_1.randomUUID)();
const base_path = `/tmp/azul-${UUID}`;
process.env['AZUL_PREFIX'] = base_path;
process.env['AZUL_CONFIG'] = `${base_path}/config`;
process.on('exit', () => {
    if (process.env['AZUL_SKIP_CLEANUP']) {
        return;
    }
    console.log('Performing clean up', base_path);
    (0, fs_1.rmSync)(base_path, { recursive: true });
});
const last_result = () => `${base_path}/last-result`;
function run(cmd) {
    return (0, child_process_1.spawn)(cmd);
}
function wait_proc(cmd_1) {
    return __awaiter(this, arguments, void 0, function* (cmd, args = [], options = {}) {
        const proc = (0, child_process_1.spawn)(cmd, args, options);
        if (proc == null) {
            throw 'COULD_NOT_START_INSTALL';
        }
        let [result, err] = ['', ''];
        return new Promise(resolve => {
            proc.stdout.on('data', data => result += data.toString());
            proc.stderr.on('data', data => err += data.toString());
            proc.on('exit', code => resolve([code, result, err]));
        });
    });
}
function run_azul() {
    return __awaiter(this, void 0, void 0, function* () {
        const [code, result, err] = yield wait_proc(`${base_path}/bin/azul`, ['-a', UUID, '-c', `${base_path}/config`]);
    });
}
function new_install() {
    return __awaiter(this, void 0, void 0, function* () {
        const [code, result, err] = yield wait_proc(`../../install.sh`);
        (0, fs_1.copyFileSync)('../test-env.lua', `${base_path}/config/lua/test-env.lua`);
        (0, fs_1.copyFileSync)('../init.lua', `${base_path}/config/init.lua`);
        (0, fs_1.writeFileSync)(`${base_path}/config/lua/uuid.lua`, `
return {
    uuid = '${UUID}'
}
`);
    });
}
function run_test(t) {
    console.log(`Running ${t.desc || t.luaFile}`);
    return new Promise((resolve) => __awaiter(this, void 0, void 0, function* () {
        t.init && (yield t.init());
        if ((0, fs_1.existsSync)(last_result())) {
            (0, fs_1.rmSync)(last_result());
        }
        const file = `${t.luaFile}.lua`;
        (0, fs_1.copyFileSync)(`../specs/${file}`, `${base_path}/config/lua/spec.lua`);
        run_azul().then(() => resolve());
    }));
}
function assert_test_passed() {
    if (!(0, fs_1.existsSync)(last_result())) {
        console.error("Did not finished properly. It's considered failed");
        throw 'NOT_FINISHED';
    }
    const data = (0, fs_1.readFileSync)(last_result()).toString();
    if (data != 'passed') {
        console.error(data);
        throw 'failed';
    }
    console.log('passed');
}
function loop_tests(idx) {
    return __awaiter(this, void 0, void 0, function* () {
        if (idx >= test_1.TESTS.length) {
            return;
        }
        yield run_test(test_1.TESTS[idx]);
        assert_test_passed();
        return loop_tests(idx + 1);
    });
}
(function () {
    return __awaiter(this, void 0, void 0, function* () {
        console.log('Preparing the test environment');
        yield new_install();
        console.log('The test environment has been set up to ', base_path);
        if (test_1.TESTS.length == 0) {
            console.log("There are no defined tests. Exiting");
        }
        yield loop_tests(0);
    });
})();
