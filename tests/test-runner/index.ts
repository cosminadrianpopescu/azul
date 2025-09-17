import { ChildProcessWithoutNullStreams, spawn } from "child_process";
import { randomUUID } from "crypto";
import { copyFileSync, existsSync, readFileSync, rmSync, writeFileSync } from "fs";
import './list';
import { TestCaseDesc, TESTS } from "./test";

let TO_RUN: Array<TestCaseDesc> = [];

const UUID = process.env['AZUL_UUID'] || randomUUID();
const base_path = `/tmp/azul-${UUID}`;
process.env['AZUL_PREFIX'] = base_path;
process.env['AZUL_CONFIG'] = `${base_path}/config`;

process.on('exit', () => {
    if (process.env['AZUL_SKIP_CLEANUP']) {
        return ;
    }
    console.log('Performing clean up', base_path);
    rmSync(base_path, {recursive: true});
});

const last_result = `${base_path}/last-result`;

const running_last_result = (t: TestCaseDesc) => `${last_result}-${t.luaFile}`;

function run(cmd: string): ChildProcessWithoutNullStreams {
    return spawn(cmd);
}

async function wait_proc(cmd: string, args: Array<string> = [], options: Object = {}): Promise<[number, string, string]> {
    const proc = spawn(cmd, args, options);
    if (proc == null) {
        throw 'COULD_NOT_START_INSTALL';
    }

    if (!!process.env['AZUL_WATCH_TESTS']) {
        spawn(cmd, ['-a', process.env['AZUL_WATCH_TESTS'], '-c', `${base_path}/config`, '-s', ` ${cmd} ${args.join(' ')}<cr>`], {detached: true})
    }

    let [result, err] = ['', ''];
    return new Promise(resolve => {
        proc.stdout.on('data', data => result += data.toString());
        proc.stderr.on('data', data => err += data.toString());
        proc.on('exit', code => resolve([code as number, result, err]));
    })
}

async function run_azul(azul_env = {}) {
    const final_env = Object.assign({}, process.env, azul_env);
    const sess_file = `${base_path}/config/sessions/${UUID}.azul`;
    if (existsSync(sess_file)) {
        rmSync(sess_file);
    }
    const [code, result, err] = await wait_proc(`${base_path}/bin/azul`, ['-a', UUID, '-c', `${base_path}/config`], {env: final_env});
    // console.log(`AZUL RAN ${code}, ${result}, ${err}`)
}

function init_test_env() {
    console.log('Initializing the test environment');
    copyFileSync('../test-env.lua', `${base_path}/config/lua/test-env.lua`)
    copyFileSync('../init.lua', `${base_path}/config/init.lua`)
    copyFileSync('../../examples/azul.ini', `${base_path}/config/config.ini`)
    writeFileSync(`${base_path}/config/lua/uuid.lua`, `
return {
    uuid = '${UUID}'
}
`);
}

async function new_install() {
    console.log('Preparing the test environment');
    const [code, result, err] = await wait_proc(`../../install.sh`);
    console.log('The test environment has been set up to ', base_path);
}

async function run_test(t: TestCaseDesc) {
    console.log(`${t.desc || t.luaFile} test case`);
    init_test_env();
    console.log('Running...')
    let azul_env = {};
    if (!!t.init) {
        const init_result = t.init(base_path);
        azul_env = init_result;
        if ((init_result as Promise<Object>)?.then) {
            azul_env = await init_result;
        }
    }
    if (existsSync(running_last_result(t))) {
        rmSync(running_last_result(t));
    }
    const file = `${t.luaFile}.lua`;
    let content = readFileSync(`../specs/${file}`).toString();
    content = `-- Auto generated code, don't modify it
require('test-env').set_test_running('${t.luaFile}')
-- End auto generated code

${content}
`;
    writeFileSync(`${base_path}/config/lua/spec.lua`, content);
    await run_azul(azul_env);
}

function assert_test_passed(t: TestCaseDesc) {
    if (!existsSync(running_last_result(t))) {
        console.error("Did not finished properly. It's considered failed")
        throw 'NOT_FINISHED';
    }
    const data = readFileSync(running_last_result(t)).toString();
    if (data != 'passed') {
        console.error(data);
        throw 'failed';
    }
    console.log('passed');
}

async function loop_tests(idx: number) {
    if (idx >= TO_RUN.length) {
        return ;
    }

    await run_test(TO_RUN[idx]);
    assert_test_passed(TO_RUN[idx]);
    await new Promise(resolve => setTimeout(resolve, 500));
    console.log("");
    return loop_tests(idx + 1);
}

(async function() {
    await new_install();
    if (TESTS.length == 0) {
        console.log("There are no defined tests. Exiting");
        process.exit(0)
    }
    const arr = TESTS.filter(t => t.single);
    TO_RUN = arr.length > 0 ? arr : TESTS;
    await loop_tests(0);
    console.log('All tests passed successfully');
})();
