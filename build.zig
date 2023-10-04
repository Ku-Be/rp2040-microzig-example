const std = @import("std");
const rp2040 = @import("rp2040");

pub fn build(b: *std.Build) void {
    const microzig = @import("microzig").init(b, "microzig");
    const optimize = b.standardOptimizeOption(.{});

    const dest = .{ .name = "pico", .target = rp2040.boards.raspberry_pi.pico };
	// const dest = .{ .name = "pico", .target = rp2040.boards.raspberry_pi.pico_ram_only };
    const firmware = microzig.addFirmware(b, .{
        .name = b.fmt("morse-{s}", .{dest.name}),
        .target = dest.target,
        .optimize = optimize,
        .source_file = .{ .path = "src/morse.zig" },
    });
    firmware.addObjectFile(std.Build.LazyPath.relative("src/minimal.o"));
    microzig.installFirmware(b, firmware, .{});
    microzig.installFirmware(b, firmware, .{ .format = .elf });
    microzig.installFirmware(b, firmware, .{ .format = .bin });
}
