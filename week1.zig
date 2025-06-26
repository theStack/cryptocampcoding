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

// week 1, exercise 4: ElGamal cipher
fn el_gamal_encrypt(msg: u256, k: u256, pubkey: u256, g: u256, p: u256) struct { u256, u256 } {
    // c1 = g ^ k (mod p)
    // c2 = m * pubkey ^ k (mod p)
    const c1: u256 = fast_exp(g, k, p);
    const c2: u256 = @intCast((@as(u512, msg) * fast_exp(pubkey, k, p)) % p);
    return .{ c1, c2 };
}

fn el_gamal_decrypt(msg_c1: u256, msg_c2: u256, privkey: u256, p: u256) u256 {
    // x = c1 ^ privkey (mod p)
    // msg = c2 * x ^ (-1)
    const x_inv = mod_inv(fast_exp(msg_c1, privkey, p), p);
    return @intCast((@as(u512, msg_c2) * x_inv) % p);
}

fn test_el_gamal(p: u256, g: u256, seckey: u256, k: u256, msg: u256, c1: u256, c2: u256) void {
    const pubkey = fast_exp(g, seckey, p);
    const msg_encrypted = el_gamal_encrypt(msg, k, pubkey, g, p);
    std.debug.assert(msg_encrypted[0] == c1);
    std.debug.assert(msg_encrypted[1] == c2);
    const msg_decrypted = el_gamal_decrypt(c1, c2, seckey, p);
    std.debug.assert(msg_decrypted == msg);
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

    // Example 2.8
    const p: u256 = 467;
    const g: u256 = 2;
    const alice_seckey: u256 = 153;
    const k: u256 = 197;
    const msg: u256 = 331;
    const c1: u256 = 87;
    const c2: u256 = 57;

    test_el_gamal(p, g, alice_seckey, k, msg, c1, c2);
    // test vectors from https://gist.github.com/devinrsmith/58926b3d62ccfe9818057f94d2c7189c
    // (p, g, seckey, k, msg, c1, c2)
    test_el_gamal(11, 3, 2, 2, 0, 9, 0); // row 2
    test_el_gamal(23, 6, 7, 6, 9, 12, 6); // row 3
    test_el_gamal(47, 24, 6, 16, 0, 34, 0);  // row 4
    test_el_gamal(83, 28, 29, 11, 34, 10, 76); // row 5
    test_el_gamal(77279, 17442, 12299, 150, 43204, 8248, 48125); // row 15
    test_el_gamal(4202847119, 3029704687, 533580054, 1120584101, 3691455310, 644014762, 1557586851); // row 30
    test_el_gamal(4092145366777755203682186734042650564345352699,
                  1051450173797439405545224608740546619408739744,
                  1016395083713815200070860873582396187864408930,
                  1280499476430694975631054790651024450990630074,
                  3297836689168609338192747050112241734399173199,
                  3999903961515651082948005923680185129818107807,
                  1043151897407240125820554727106010732793200135); // row 150
    test_el_gamal(107150133059714849383040775224872422804145525051906279618646960978244990841799,
                  54537822060005830722806302333590773628061614535577595292078946368772242503789,
                  27726310702412252309631727311090429263488026274250077276562789230179329732763,
                  3480802698257998058673621842900608071783695803330013332888296460950933151580,
                  69343534778041115477539680851912468734642746571193365559409876127500388260953,
                  91488203231249369234964274811744238026243571571492448064527293451061320891790,
                  11209282901022306118288918194811454319005307400363409064300833371165136057604); // row 254

    // more test vectors published by the same user, gathered from various resources
    // https://gist.github.com/devinrsmith/19256389288b7e9ff5685a658f9b22d1
    test_el_gamal(71, 33, 62, 31, 15, 62, 18);
    test_el_gamal(23, 11, 6, 3, 10, 20, 22);
    test_el_gamal(809, 3, 68, 89, 100, 345, 517);
    test_el_gamal(17, 6, 5, 10, 13, 15, 9);
    test_el_gamal(84265675725482892459719348378630146162719620409152809167814480007059199482163,
                  5,
                  2799014790424892046701478888900891009403869701173893426,
                  23517683968368899022119256606644551548285683288848885921,
                  87521618088882658227876453,
                  22954586883013884818653063688294540134886732496160582262267014428782771199687,
                  56046128113101346099694619669629128017849277484825379502821514323706183544424);
    // MEH, the last one doesn't fit into u256 :/
}
