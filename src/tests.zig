//! Test aggregator root.
//!
//! In Zig 0.16, `zig test` on an executable root whose `main` uses
//! `std.process.Init` only collects test blocks from that root file, so the
//! `test` build step targets this file instead. It references every module,
//! which pulls in all of their test blocks (verified: 13 tests).

const cli = @import("cli.zig");
const commands = @import("commands.zig");
const config = @import("config.zig");
const utils = @import("utils.zig");

test "modules link into test build" {
    _ = cli.Args;
    _ = commands.ChangeStats;
    _ = config.version;
    _ = utils.Ctx;
}
