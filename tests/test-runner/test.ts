export type TestCaseInitCallback = () => Promise<void | string> | string;
export type TestCaseDesc = {
    desc?: string;
    luaFile: string;
    init?: TestCaseInitCallback;
    single?: boolean;
}
export const TESTS: Array<TestCaseDesc> = [];

export function test(luaFile: string, callback?: TestCaseInitCallback, desc?: string) {
    TESTS.push({luaFile: luaFile, init: callback as any, desc: desc});
}

export function test_single(luaFile: string, callback?: TestCaseInitCallback, desc?: string) {
    TESTS.push({luaFile: luaFile, init: callback as any, desc: desc, single: true});
}
