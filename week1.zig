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

// week 1, exercise 3: compute modular inverse
fn mod_inv(number: u256, prime_modulus: u256) u256 {
    return fast_exp(number, prime_modulus - 2, prime_modulus);
}

fn diffie_hellman_example() void {
    // diffie-hellman example from
    // "Hoffstein, Pipher, Silverman - An Introduction to Mathematical Cryptography", p. 66, Example 2.7
    const dh_prime: u256 = 941;
    const primitive_root: u256 = 627;
    const secret_a = 347;
    const public_A = fast_exp(primitive_root, secret_a, dh_prime);
    const secret_b = 781;
    const public_B = fast_exp(primitive_root, secret_b, dh_prime);
    std.debug.print("\npublic A: {d}\npublic B: {d}\n", .{public_A, public_B});
    const shared_secret_a = fast_exp(public_B, secret_a, dh_prime);
    const shared_secret_b = fast_exp(public_A, secret_b, dh_prime);
    std.debug.print("shared secret A*b: {d}\n", .{shared_secret_a});
    std.debug.print("shared secret B*a: {d}\n", .{shared_secret_b});
    std.debug.assert(shared_secret_a == shared_secret_b);
}

pub fn main() !void {
    std.debug.print("Hello cryptocamp!\n", .{});
    var result = fast_exp(123, 42, 31337);
    // expected according to Python:
    //
    // $ python3 -c "print((123**42)%31337)"
    // 12516
    std.debug.print("Result1: {d}\n", .{result});
    std.debug.assert(result == 12516);

    result = fast_exp(12345678901234567890, 111222333444555, (1<<256)-189);
    // expected according to Python:
    //
    // $ python3 -c "print(pow(12345678901234567890, 111222333444555, 2**256-189))"
    // 112673583709934996208095005760186049717637847226582546385812839628819812331205
    std.debug.print("Result2: {d}\n", .{result});
    std.debug.assert(result == 112673583709934996208095005760186049717637847226582546385812839628819812331205);

    result = mod_inv(23, (1<<256)-189);
    // $ python3 -c "print(pow(23, -1, 2**256-189))"
    // 75516579937380127450154990223057331208654337825417759156167989570378128025922
    std.debug.print("Result3: {d}\n", .{result});
    std.debug.assert(result == 75516579937380127450154990223057331208654337825417759156167989570378128025922);

    result = mod_inv(1<<255, (1<<256)-189);
    // $ python3 -c "print(pow(1<<255, -1, 2**256-189))"
    // 72293473703721222539584001222355413368708244394421092892359761444093911626932
    std.debug.print("Result4: {d}\n", .{result});
    std.debug.assert(result == 72293473703721222539584001222355413368708244394421092892359761444093911626932);

    result = mod_inv(0xdeadbeefdeadbeef, (1<<256)-189);
    // $ python3 -c "print(pow(0xdeadbeefdeadbeef, -1, 2**256-189))"
    // 112217903953090270193476458320138877800162620050754748174923495265476845425532
    std.debug.print("Result5: {d}\n", .{result});
    std.debug.assert(result == 112217903953090270193476458320138877800162620050754748174923495265476845425532);

    diffie_hellman_example();
}
