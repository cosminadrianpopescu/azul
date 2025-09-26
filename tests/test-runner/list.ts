import { writeFileSync } from "fs";
import { test } from "./test";

const build_config = (base_path: string, options: {[key: string]: any}) => {
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
}

function test_factory(test_case: string, options: {[key: string]: any} = {}, which = test) {
    options.shell = 'bash';
    which(test_case, (base_path: string) => {
        build_config(base_path, options);
        return {};
    });
}

test('test-started');
const do_floats = () => {
    test_factory('floats', {workflow: 'azul'})
    test_factory('floats', {workflow: 'tmux'});
    test_factory('floats', {workflow: 'zellij', shortcuts: {'terminal.enter_mode.m': '<C-x>'}});
    test_factory('floats', {workflow: 'emacs'});
    test_factory('floats', {workflow: 'azul', use_cheatsheet: 'false'});
    test_factory('floats', {workflow: 'tmux', use_cheatsheet: 'false'});
    test_factory('floats', {workflow: 'zellij', use_cheatsheet: 'false', shortcuts: {'terminal.enter_mode.m': '<C-x>'}});
}

const expand_test = (which: string, with_emacs = true) => {
    test_factory(which, {workflow: 'azul'})
    test_factory(which, {workflow: 'tmux'});
    test_factory(which, {workflow: 'zellij'});
    if (with_emacs) {
        test_factory(which, {workflow: 'emacs'});
    }
    test_factory(which, {workflow: 'azul', use_cheatsheet: 'false'});
    test_factory(which, {workflow: 'tmux', use_cheatsheet: 'false'});
    test_factory(which, {workflow: 'zellij', use_cheatsheet: 'false'});
}

const do_splits = () => {
    expand_test('splits');
}

const do_modes = () => {
    expand_test('modes', false);
}

const do_tabs = () => {
    expand_test('tabs');
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
    test_factory('custom-titles');
    test_factory('reload-config');
    test_factory('reload-config', {workflow: 'tmux'});
    test('remotes', (base_path: string) => {
        build_config(base_path, {shell: 'bash'});
        return {
            AZUL_REMOTE_CONNECTION: `azul://${base_path}/bin/azul`,
            SHELL: 'bash'
        }
    });
}

const do_layout = () => {
    expand_test('layout');
}

const do_undo = () => {
    expand_test('undo');
}

do_floats();
do_splits();
do_modes();
do_tabs();
do_tab_titles();
do_misc();
do_undo();
do_layout();
