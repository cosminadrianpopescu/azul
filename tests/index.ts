import { spawn } from "child_process";
import { attach } from "neovim";

(async function() {
    process.on('exit', () => {

    });

    const proc = spawn(`${process.env['HOME']}/.local/bin/azul`, ['--embed'], {});
    const nvim = await attach({proc: proc});
    await nvim.feedKeys("ils -al<cr>", 't', false);
    const buf = await nvim.buffer;
    console.log('result is', await buf.getLines());
})();
