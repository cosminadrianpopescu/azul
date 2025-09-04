import { writeFileSync } from "fs";
import { test } from "./test";

function test_factory(test_case: string, options: {[key: string]: any} = {}, which = test) {
    which(test_case, (base_path: string) => {
        let config = `
[Options]

${Object.keys(options).filter(k => k != 'shortcuts').map(k => `${k} = ${options[k]}`).join("\n")}
    `;

        if (!!options.shortcuts) {
            const ss = options.shortcuts;
            config = `
${config}

[Shortcuts]

${Object.keys(ss).map(k => `${k} = ${ss[k]}`).join("\n")}
`
        }
        console.log(config)
        writeFileSync(`${base_path}/config/config.ini`, config);
        return {};
    });
}

test('test-started');
const do_floats = () => {
    test('floats');
    test_factory('floats', {workflow: 'tmux'});
    test_factory('floats', {workflow: 'zellij', shortcuts: {'terminal.enter_mode.m': '<C-x>'}});
    test_factory('floats', {workflow: 'emacs'});
    test_factory('floats', {workflow: 'azul', use_cheatsheet: 'false'});
    test_factory('floats', {workflow: 'tmux', use_cheatsheet: 'false'});
    test_factory('floats', {workflow: 'zellij', use_cheatsheet: 'false', shortcuts: {'terminal.enter_mode.m': '<C-x>'}});
}

const do_splits = () => {
    test('splits');
    test_factory('splits', {workflow: 'tmux'});
    test_factory('splits', {workflow: 'zellij'});
    test_factory('splits', {workflow: 'emacs'});
    test_factory('splits', {workflow: 'azul', use_cheatsheet: 'false'});
    test_factory('splits', {workflow: 'tmux', use_cheatsheet: 'false'});
    test_factory('splits', {workflow: 'zellij', use_cheatsheet: 'false'});
}

const do_modes = () => {
    test('modes');
    test_factory('modes', {workflow: 'tmux'});
    test_factory('modes', {workflow: 'zellij'});
    test_factory('modes', {workflow: 'azul', use_cheatsheet: 'false'});
    test_factory('modes', {workflow: 'tmux', use_cheatsheet: 'false'});
    test_factory('modes', {workflow: 'zellij', use_cheatsheet: 'false'});
}

const do_tabs = () => {
    test('tabs');
    test_factory('tabs', {workflow: 'tmux'});
    test_factory('tabs', {workflow: 'zellij'});
    test_factory('tabs', {workflow: 'emacs'});
    test_factory('tabs', {workflow: 'azul', use_cheatsheet: 'false'});
    test_factory('tabs', {workflow: 'tmux', use_cheatsheet: 'false'});
    test_factory('tabs', {workflow: 'zellij', use_cheatsheet: 'false'});
}

const do_tab_titles = () => {
    const tab_title = ':tab_n: :tab_name::is_current:';
    test_factory('custom-tab-titles', {workflow: 'azul', tab_title: tab_title})
    test_factory('custom-tab-titles', {workflow: 'tmux', tab_title: tab_title});
    test_factory('custom-tab-titles', {workflow: 'zellij', tab_title: tab_title});
    test_factory('custom-tab-titles', {workflow: 'emacs', tab_title: tab_title});
    test_factory('custom-tab-titles', {workflow: 'azul', tab_title: tab_title, use_cheatsheet: 'false'});
    test_factory('custom-tab-titles', {workflow: 'tmux', tab_title: tab_title, use_cheatsheet: 'false'});
    test_factory('custom-tab-titles', {workflow: 'zellij', tab_title: tab_title, use_cheatsheet: 'false'});
    test_factory('custom-tab-titles', {workflow: 'azul', tab_title: tab_title, use_dressing: 'false'})
    test_factory('custom-tab-titles', {workflow: 'tmux', tab_title: tab_title, use_dressing: 'false'})
    test_factory('custom-tab-titles', {workflow: 'zellij', tab_title: tab_title, use_dressing: 'false'})
    test_factory('custom-tab-titles', {workflow: 'emacs', tab_title: tab_title, use_dressing: 'false'})
    test_factory('custom-tab-titles', {workflow: 'azul', tab_title: tab_title, use_dressing: 'false', use_cheatsheet: 'false'})
    test_factory('custom-tab-titles', {workflow: 'tmux', tab_title: tab_title, use_dressing: 'false', use_cheatsheet: 'false'})
    test_factory('custom-tab-titles', {workflow: 'zellij', tab_title: tab_title, use_dressing: 'false', use_cheatsheet: 'false'})
}

const do_misc = () => {
    test('custom-titles');
    test('reload-config');
    test_factory('reload-config', {workflow: 'tmux'});
    test('remotes', (base_path: string) => {
        return {
            AZUL_REMOTE_CONNECTION: `azul://${base_path}/bin/azul`,
        }
    });
}

const do_layout = () => {
    test('layout');
    test_factory('layout', {workflow: 'tmux'});
    test_factory('layout', {workflow: 'zellij'});
    test_factory('layout', {workflow: 'emacs'});
    test_factory('layout', {workflow: 'azul', use_cheatsheet: 'false'});
    test_factory('layout', {workflow: 'tmux', use_cheatsheet: 'false'});
    test_factory('layout', {workflow: 'zellij', use_cheatsheet: 'false'});
}

do_floats();
do_splits();
do_modes();
do_tabs();
do_tab_titles();
do_misc();
do_layout();
