import { writeFileSync } from "fs";
import { test, test_single } from "./test";

function test_factory(test_case: string, options: {[key: string]: string | number} = {}, which = test) {
    which(test_case, (base_path: string) => {
        const config = `
[Options]

${Object.keys(options).map(k => `${k} = ${options[k]}`).join("\n")}
    `;
        console.log(config)
        writeFileSync(`${base_path}/config/config.ini`, config);
        return {};
    });
}

test('test-started');
test_single('floats');
test_factory('floats', {workflow: 'tmux'});
test_factory('floats', {workflow: 'zellij'});
test_factory('floats', {workflow: 'emacs'});
test_factory('floats', {workflow: 'azul', use_cheatsheet: 'false'});
test_factory('floats', {workflow: 'tmux', use_cheatsheet: 'false'});
test_factory('floats', {workflow: 'zellij', use_cheatsheet: 'false'});
test('splits');
test_factory('splits', {workflow: 'tmux'});
test_factory('splits', {workflow: 'zellij'});
test_factory('splits', {workflow: 'emacs'});
test_factory('splits', {workflow: 'azul', use_cheatsheet: 'false'});
test_factory('splits', {workflow: 'tmux', use_cheatsheet: 'false'});
test_factory('splits', {workflow: 'zellij', use_cheatsheet: 'false'});
test('modes');
test_factory('modes', {workflow: 'tmux'});
test_factory('modes', {workflow: 'zellij'});
test_factory('modes', {workflow: 'azul', use_cheatsheet: 'false'});
test_factory('modes', {workflow: 'tmux', use_cheatsheet: 'false'});
test_factory('modes', {workflow: 'zellij', use_cheatsheet: 'false'});
test('tabs');
test_factory('tabs', {workflow: 'tmux'});
test_factory('tabs', {workflow: 'zellij'});
test_factory('tabs', {workflow: 'emacs'});
test_factory('tabs', {workflow: 'azul', use_cheatsheet: 'false'});
test_factory('tabs', {workflow: 'tmux', use_cheatsheet: 'false'});
test_factory('tabs', {workflow: 'zellij', use_cheatsheet: 'false'});
const tab_title = ':tab_n: :tab_name::is_current:';
test_factory('custom-tab-titles', {workflow: 'azul', tab_title: tab_title})
test_factory('custom-tab-titles', {workflow: 'tmux', tab_title: tab_title});
test_factory('custom-tab-titles', {workflow: 'zellij', tab_title: tab_title});
test_factory('custom-tab-titles', {workflow: 'emacs', tab_title: tab_title});
test_factory('custom-tab-titles', {workflow: 'azul', tab_title: tab_title, use_cheatsheet: 'false'});
test_factory('custom-tab-titles', {workflow: 'tmux', tab_title: tab_title, use_cheatsheet: 'false'});
test_factory('custom-tab-titles', {workflow: 'zellij', tab_title: tab_title, use_cheatsheet: 'false'});
test('custom-titles');
test('reload-config');
test_factory('reload-config', {workflow: 'tmux'});
test('remotes', (base_path: string) => {
    return {
        AZUL_REMOTE_CONNECTION: `azul://${base_path}/bin/azul`,
    }
});
test('layout');
test_factory('layout', {workflow: 'tmux'});
test_factory('layout', {workflow: 'zellij'});
test_factory('layout', {workflow: 'emacs'});
test_factory('layout', {workflow: 'azul', use_cheatsheet: 'false'});
test_factory('layout', {workflow: 'tmux', use_cheatsheet: 'false'});
test_factory('layout', {workflow: 'zellij', use_cheatsheet: 'false'});
test_factory('layout', {workflow: 'emacs', use_cheatsheet: 'false'});
