const std = @import("std");

// week 1, exercise 1: use square-and-multiply algorithm
fn fast_exp(base: u256, exponent: u256, modulus: u256) u256 {
    var squarings_table: [256]u256 = undefined;
    var a_i: u256 = undefined;
    for (0..256) |i| {
        if (i == 0) {
            a_i = base;
        } else {
            a_i = (a_i * a_i) % modulus;
        }
        squarings_table[i] = a_i;
    }

    var result: u256 = 1;
    for (0..256) |_i| {
        const i: u8 = @intCast(_i);
        if ((exponent & (@as(u256, 1) << i)) != 0) {
            result = (result * squarings_table[i]) % modulus;
        }
    }

    return result;
}

pub fn main() !void {
    std.debug.print("Hello cryptocamp!\n", .{});
    const result = fast_exp(123, 42, 31337);
    // expected according to Python:
    //
    // $ python3 -c "print((123**42)%31337)"
    // 12516
    std.debug.print("Answer: {d}\n", .{result});
}
