import { spawn } from "child_process";
import { randomUUID } from "crypto";
import { copyFileSync, existsSync, readFileSync, rmSync, writeFileSync } from "fs";
import './list';
import { TestCaseDesc, TESTS } from "./test";

let TO_RUN: Array<TestCaseDesc> = [];

const UUID = process.env['VESPER_UUID'] || randomUUID();
const base_path = `/tmp/vesper-${UUID}`;
process.env['VESPER_PREFIX'] = base_path;
process.env['VESPER_CONFIG'] = `${base_path}/config`;

process.on('exit', () => {
    if (process.env['VESPER_SKIP_CLEANUP']) {
        return ;
    }
    console.log('Performing clean up', base_path);
    rmSync(base_path, {recursive: true});
});

const last_result = `${base_path}/last-result`;

const running_last_result = (t: TestCaseDesc) => `${last_result}-${t.luaFile}`;

async function wait_proc(cmd: string, args: Array<string> = [], options: Object = {}): Promise<[number, string, string]> {
    const proc = spawn(cmd, args, options);
    if (proc == null) {
        throw 'COULD_NOT_START_INSTALL';
    }

    if (!!process.env['VESPER_WATCH_TESTS']) {
        spawn(cmd, ['-a', process.env['VESPER_WATCH_TESTS'], '-c', `${base_path}/config`, '-s', ` ${cmd} ${args.join(' ')}<cr>`], {detached: true})
    }

    let [result, err] = ['', ''];
    return new Promise(resolve => {
        proc.stdout.on('data', data => result += data.toString());
        proc.stderr.on('data', data => err += data.toString());
        proc.on('exit', code => resolve([code as number, result, err]));
    })
}

async function run_vesper(vesper_env = {}) {
    const final_env = Object.assign({}, process.env, vesper_env);
    const sess_file = `${base_path}/config/sessions/${UUID}.vesper`;
    if (existsSync(sess_file)) {
        rmSync(sess_file);
    }
    const [code, result, err] = await wait_proc(`${base_path}/bin/vesper`, ['-a', UUID, '-c', `${base_path}/config`], {env: final_env});
    // console.log(`VESPER RAN ${code}, ${result}, ${err}`)
}

function init_test_env() {
    console.log('Initializing the test environment');
    copyFileSync('../test-env.lua', `${base_path}/config/lua/test-env.lua`)
    copyFileSync('../init.lua', `${base_path}/config/init.lua`)
    copyFileSync('../../examples/vesper.ini', `${base_path}/config/config.ini`)
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
    let vesper_env = {};
    if (!!t.init) {
        const init_result = t.init(base_path);
        vesper_env = init_result;
        if ((init_result as Promise<Object>)?.then) {
            vesper_env = await init_result;
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
    await run_vesper(vesper_env);
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
