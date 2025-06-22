const std = @import("std");

// week 1, exercise 1
fn fast_exp(base: u256, exponent: u256, modulus: u256) u256 {
    std.debug.print("Calculating {d}, {d}, {d}...\n", .{base, exponent, modulus});
    // TODO: implement
    return 42;
}

pub fn main() !void {
    std.debug.print("Hello cryptocamp!\n", .{});
    const result = fast_exp(23, 42, 1337);
    std.debug.print("Answer: {d}\n", .{result});
}
