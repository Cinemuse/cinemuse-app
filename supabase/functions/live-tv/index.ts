import { defaultDeps, handle } from "./handler.ts";

const deps = defaultDeps();

Deno.serve((req) => handle(req, deps));
