"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
const child_process_1 = require("child_process");
const neovim_1 = require("neovim");
(function () {
    return __awaiter(this, void 0, void 0, function* () {
        process.on('exit', () => {
        });
        const proc = (0, child_process_1.spawn)(`${process.env['HOME']}/.local/bin/azul`, ['--embed'], {});
        const nvim = yield (0, neovim_1.attach)({ proc: proc });
        yield nvim.feedKeys("ils -al<cr>", 't', false);
        const buf = yield nvim.buffer;
        console.log('result is', yield buf.getLines());
    });
})();
