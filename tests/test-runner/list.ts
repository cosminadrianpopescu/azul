import { writeFileSync } from "fs";
import { test } from "./test";

test('test-started');
test('floats');
test('splits');
test('modes');
test('tabs');
test('custom-tab-titles', (base_path: string) => {
    const config = `
[Options]

tab_title = :tab_n: :tab_name::is_current:
`;
    writeFileSync(`${base_path}/config/config.ini`, config);
});
test('layout');
test('custom-titles');
test('reload-config');
