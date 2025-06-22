const std = @import("std");

// week 1, exercise 1: use square-and-multiply algorithm
fn fast_exp(base: u256, exponent: u256, modulus: u256) u256 {
    var squarings_table: [256]u256 = undefined;
    var a_i: u256 = undefined;
    for (0..256) |i| {
        if (i == 0) {
            a_i = base;
        } else {
            a_i = @intCast((@as(u512, a_i) * a_i) % modulus);
        }
        squarings_table[i] = a_i;
    }

    var result: u256 = 1;
    for (0..256) |_i| {
        const i: u8 = @intCast(_i);
        if ((exponent & (@as(u256, 1) << i)) != 0) {
            result = @intCast((@as(u512, result) * squarings_table[i]) % modulus);
        }
    }

    return result;
}

pub fn main() !void {
    std.debug.print("Hello cryptocamp!\n", .{});
    var result = fast_exp(123, 42, 31337);
    // expected according to Python:
    //
    // $ python3 -c "print((123**42)%31337)"
    // 12516
    std.debug.print("Result1: {d}\n", .{result});

    result = fast_exp(12345678901234567890, 111222333444555, 115792089237316195423570985008687907853269984665640564039457584007913129639747);
    // expected according to Python:
    //
    // $ python3 -c "print(pow(12345678901234567890, 111222333444555, 2**256-189))"
    // 112673583709934996208095005760186049717637847226582546385812839628819812331205
    std.debug.print("Result2: {d}\n", .{result});
}
