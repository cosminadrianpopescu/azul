export type TestCaseInitCallback = () => Promise<string> | string;
export type TestCaseDesc = {
    desc?: string;
    luaFile: string;
    init?: TestCaseInitCallback;
}
export const TESTS: Array<TestCaseDesc> = [];

export function test(luaFile: string, callback?: TestCaseInitCallback, desc?: string) {
    TESTS.push({luaFile: luaFile, init: callback as any, desc: desc});
}
