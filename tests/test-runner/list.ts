import { writeFileSync } from "fs";
import { test } from "./test";

function test_workflow_factory(test_case: string, wf: string, other_options?: string, which = test) {
    which(test_case, (base_path: string) => {
        console.log(`test ${wf} workflow`)
        const config = `
[Options]

workflow = ${wf}
${other_options || ''}
    `;
        writeFileSync(`${base_path}/config/config.ini`, config);
    });
}

test('test-started');
test('floats');
test_workflow_factory('floats', 'tmux');
test_workflow_factory('floats', 'zellij');
test_workflow_factory('floats', 'emacs');
test('splits');
test_workflow_factory('splits', 'tmux');
test_workflow_factory('splits', 'zellij');
test_workflow_factory('splits', 'emacs');
test('modes');
test_workflow_factory('modes', 'tmux');
test_workflow_factory('modes', 'zellij');
test('tabs');
test_workflow_factory('tabs', 'tmux');
test_workflow_factory('tabs', 'zellij');
test_workflow_factory('tabs', 'emacs');
const tab_title_option = "tab_title = :tab_n: :tab_name::is_current:\n";
test('custom-tab-titles', (base_path: string) => {
    const config = `
[Options]

${tab_title_option}
`;
    writeFileSync(`${base_path}/config/config.ini`, config);
});
test_workflow_factory('custom-tab-titles', 'tmux', tab_title_option);
test_workflow_factory('custom-tab-titles', 'zellij', tab_title_option);
test_workflow_factory('custom-tab-titles', 'emacs', tab_title_option);
test('layout');
test_workflow_factory('layout', 'tmux');
test_workflow_factory('layout', 'zellij');
test_workflow_factory('layout', 'emacs');
test('custom-titles');
test('reload-config');
test_workflow_factory('reload-config', 'tmux');
