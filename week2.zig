const std = @import("std");
const week1 = @import("week1.zig");

// week 2, secp256k1 exercise 1:
// Implement affine point addition for secp256k1
const FE = u256;
const secp256k1_P: FE = (1<<256) - (1<<32) - 977;
fn fe_add(f1: FE, f2: FE) FE { return @intCast((@as(u257, f1) + f2) % secp256k1_P); }
fn fe_neg(f: FE) FE          { return secp256k1_P - f; }
fn fe_sub(f1: FE, f2: FE) FE { return fe_add(f1, fe_neg(f2)); }
fn fe_mul(f1: FE, f2: FE) FE { return @intCast((@as(u512, f1) * f2) % secp256k1_P); }
fn fe_inv(f: FE) FE          { return week1.mod_inv(f, secp256k1_P); }
fn fe_div(f1: FE, f2: FE) FE { return fe_mul(f1, fe_inv(f2)); }
fn fe_pow(f1: FE, f2: FE) FE { return week1.fast_exp(f1, f2, secp256k1_P); }

const GE = struct { x: FE, y: FE, inf: bool };
const point_at_infinity = GE { .x = 0, .y = 0, .inf = true };

fn ge_equal(p1: *const GE, p2: *const GE) bool {
    return p1.x == p2.x and p1.y == p2.y and p1.inf == p2.inf;
}

fn ge_add(p1: *const GE, p2: *const GE) GE {
    // trivial cases
    if (p1.inf) return p2.*;
    if (p2.inf) return p1.*;
    if (p1.x == p2.x and fe_add(p1.y, p2.y) == 0) return point_at_infinity;

    // compute the slope
    const lambda = if (ge_equal(p1, p2))
        fe_div(fe_mul(3, fe_mul(p1.x, p2.x)), fe_mul(2, p1.y)) // point doubling
    else
        fe_div(fe_sub(p2.y, p1.y), fe_sub(p2.x, p1.x)); // point addition

    // compute resulting affine coordinates
    const x_result = fe_sub(fe_mul(lambda, lambda), fe_add(p1.x, p2.x));
    const y_result = fe_sub(fe_mul(lambda, fe_sub(p1.x, x_result)), p1.y);
    return GE { .x = x_result, .y = y_result, .inf = false };
}

// week 2, secp256k1 exercise 2:
// Implement jacobian point addition for secp256k1
const GEJ = struct { x: FE, y: FE, z: FE, inf: bool };
const point_at_infinity_gej = GEJ { .x = 0, .y = 0, .z = 0, .inf = true };

// use "add-1986-cc" addition and "dbl-1998-cmo" doubling formulas from EFD
// [https://www.hyperelliptic.org/EFD/g1p/auto-shortw-jacobian.html#addition-add-1986-cc]
// [https://www.hyperelliptic.org/EFD/g1p/auto-shortw-jacobian.html#doubling-dbl-1998-cmo]
fn gej_add(p1: *const GEJ, p2: *const GEJ) GEJ {
    // trivial cases
    if (p1.inf) return p2.*;
    if (p2.inf) return p1.*;

    const z1_squared = fe_mul(p1.z, p1.z);
    const z1_cubed = fe_mul(z1_squared, p1.z);
    const z2_squared = fe_mul(p2.z, p2.z);
    const z2_cubed = fe_mul(z2_squared, p2.z);
    const uu1 = fe_mul(p1.x, z2_squared);
    const uu2 = fe_mul(p2.x, z1_squared);
    const s1 = fe_mul(p1.y, z2_cubed);
    const s2 = fe_mul(p2.y, z1_cubed);
    if (uu1 == uu2) { // x-coordinates are equal
        if (s1 != s2) { // y-coordinates are not equal -> case P + (-P)
            return point_at_infinity_gej;
        } else { // y-coordinates are equal -> case P + P (point doubling)
            const x_squared = fe_mul(p1.x, p1.x);
            const y_squared = fe_mul(p1.y, p1.y);
            const y_quartic = fe_mul(y_squared, y_squared);

            const s = fe_mul(fe_mul(4, p1.x), y_squared);
            const m = fe_mul(3, x_squared); // a=0, so right term of addition is zero
            const t = fe_sub(fe_mul(m, m), fe_mul(2, s));
            return GEJ {
                .x = t,
                .y = fe_sub(fe_mul(m, fe_sub(s, t)), fe_mul(8, y_quartic)),
                .z = fe_mul(fe_mul(2, p1.y), p1.z),
                .inf = false,
            };
        }
    }

    const p = fe_sub(uu2, uu1);
    const r = fe_sub(s2, s1);
    const r_squared = fe_mul(r, r);
    const p_squared = fe_mul(p, p);
    const p_cubed = fe_mul(p_squared, p);

    const x_result = fe_sub(r_squared, fe_mul(fe_add(uu1, uu2), p_squared));
    const y_result = fe_sub(fe_mul(r, fe_sub(fe_mul(uu1, p_squared), x_result)), fe_mul(s1, p_cubed));
    const z_result = fe_mul(fe_mul(p1.z, p2.z), p);
    return GEJ { .x = x_result, .y = y_result, .z = z_result, .inf = false };
}

fn gej_to_ge(p: *const GEJ) GE {
    if (p.inf) return point_at_infinity;
    const z2 = fe_mul(p.z, p.z);
    const z3 = fe_mul(z2, p.z);
    return GE { .x = fe_div(p.x, z2), .y = fe_div(p.y, z3), .inf = false };
}

// week 2, secp256k1 exercise 3:
// Implement scalar multiplication for secp256k1
const Scalar = u256;

fn scalar_mul_gej(s: Scalar, p: *const GEJ) GEJ {
    var result = point_at_infinity_gej;
    var p_i = p.*; // doubled point for next loop iteration (p_i = p * (2^i))
    for (0..256) |_i| {
        const i: u8 = @intCast(_i);
        if ((s & (@as(u256, 1) << i)) != 0) {
            result = gej_add(&result, &p_i);
        }
        p_i = gej_add(&p_i, &p_i);
    }
    return result;
}

// week 2, secp256k1 exercise 4:
// Let P = (-6^((p+2)/9), 1) be a point on the secp256k1 curve. Let Q be the point
// on the curve for which 3 * Q = 5 * G - lambda * P. What are the affine coordinates
// of Q?
const secp256k1_N: Scalar = 0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141;
const G = GEJ {
    .x = 0x79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798,
    .y = 0x483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8,
    .z = 1, .inf = false
};

fn exercise4_calculate_Q() void {
    // solve for Q by multiplying both sides with the modular inverse of 3 (mod group order N):
    // 3 * Q =  5 * G - lambda * P            | * 3^(-1)
    // =>  Q = (5 * G - lambda * P) * 3^(-1)
    const lambda: Scalar = 0x5363ad4cc05c30e0a5261c028812645a122e22ea20816678df02967c1b23bd72;
    const P = GEJ { .x = fe_neg(fe_pow(6, fe_div(fe_add(secp256k1_P, 2), 9))), .y = 1, .z = 1, .inf = false };
    std.debug.print("Exercise 4, affine coordinates of P:\nx = {d},\ny = {d}\n", .{P.x, P.y});
    const l_times_P = scalar_mul_gej(lambda, &P);
    const neg_l_times_P = GEJ { .x = l_times_P.x, .y = fe_neg(l_times_P.y), .z = l_times_P.z, .inf = false };
    const five_G = scalar_mul_gej(5, &G);
    const tmp_point = gej_add(&five_G, &neg_l_times_P);
    const Q = scalar_mul_gej(week1.mod_inv(3, secp256k1_N), &tmp_point);
    const Q_affine = gej_to_ge(&Q);
    std.debug.print("Exercise 4, affine coordinates of Q:\nx = {d},\ny = {d}\n", .{Q_affine.x, Q_affine.y});
    std.debug.assert(Q_affine.x % 1000 == 452);
}

// more convenient point types for test vectors (null = point at infinity)
const SimplePoint2 = ?struct{FE, FE};
const SimplePoint3 = ?struct{FE, FE, FE};

fn simple_point2_to_ge(tp: SimplePoint2) GE {
    return if (tp != null) GE { .x = tp.?[0], .y = tp.?[1], .inf = false } else point_at_infinity;
}

fn simple_point2_to_gej(tp: SimplePoint2) GEJ {
    return if (tp != null) GEJ { .x = tp.?[0], .y = tp.?[1], .z = 1, .inf = false } else point_at_infinity_gej;
}

fn simple_point3_to_gej(tp: SimplePoint3) GEJ {
    return if (tp != null) GEJ {
        .x = tp.?[0], .y = tp.?[1], .z = tp.?[2], .inf = false } else point_at_infinity_gej;
}

fn test_point_add_affine(tp1: SimplePoint2, tp2: SimplePoint2, res: SimplePoint2) void {
    const p1 = simple_point2_to_ge(tp1);
    const p2 = simple_point2_to_ge(tp2);
    const result_expected = simple_point2_to_ge(res);
    const result_actual = ge_add(&p1, &p2);
    std.debug.assert(ge_equal(&result_actual, &result_expected));
}

fn test_point_add_jacobian(tp1: SimplePoint3, tp2: SimplePoint3, res: SimplePoint2) void {
    const p1 = simple_point3_to_gej(tp1);
    const p2 = simple_point3_to_gej(tp2);
    const result_expected = simple_point2_to_ge(res);
    const result_actual_gej = gej_add(&p1, &p2);
    const result_actual = gej_to_ge(&result_actual_gej);
    std.debug.assert(ge_equal(&result_actual, &result_expected));
}

fn test_point_mul(s: Scalar, tp: SimplePoint2, res: SimplePoint2) void {
    const p = simple_point2_to_gej(tp);
    const result_expected = simple_point2_to_ge(res);
    const result_actual_gej = scalar_mul_gej(s, &p);
    const result_actual = gej_to_ge(&result_actual_gej);
    std.debug.assert(ge_equal(&result_actual, &result_expected));
}

pub fn main() !void {
    // TODO: consider restructuring using zig's testing capabilities
    test_point_add_affine(
        .{67021774492365321256634043516869791044054964063002935266026048760627130221114,
          22817883221438079958217963063610327523693969913024717835557258242342029550595},
        .{61124938217888369397608518626468079588341162087856379517664485009963441753645,
          5723382937169086635766392599511664586625983027860520036338464885987365575658},
        .{78518484088348927894279633941273782106215956054783044881924083038087974375069,
          18400956471605157290158330638123206056219981947313880254846397293938760781200}
    );
    test_point_add_affine(
        .{44797955726860071483167773525787460171685721903803276437396496681708013097206,
          112878323467240798018200025047246733779416351939079609883282945822975931592141},
        .{44797955726860071483167773525787460171685721903803276437396496681708013097206,
          2913765770075397405370959961441174073853632726560954156174638184932903079522},
        null
    );
    test_point_add_affine(
        .{95200151225387174391707134980196577229773167465894787919263504089948495725202,
          94213123740092242124032541289267941722641721980066680728855126898974205181980},
        .{95200151225387174391707134980196577229773167465894787919263504089948495725202,
          94213123740092242124032541289267941722641721980066680728855126898974205181980},
        .{5909177817561749019375996132097716007690336893057112295739767175467136927121,
          32162989297956602751967132742255814558956860587998309119003795115938320862381}
    );
    test_point_add_affine(
        .{24050370140998638157368766089090079788245793492514664296883668741529047882113,
          14478882322437672032054487172211630444001167135141445302555096737662467817571},
        .{15045863282447234231848775263852322721143017336655001075698483887751182719636,
          14478882322437672032054487172211630444001167135141445302555096737662467817571},
        .{76695855813870323034353443655745505343881173836470898666875431378628604069914,
          101313206914878523391516497836476277409268817530499118736902487270246366854092}
    );
    test_point_add_affine(
        .{14256779447437936128616290794341059890063336098474125854681710102809814868320,
          90566103014364716248988921534849031279541603477816641946022463390335657035131},
        .{2303067510121489830312323422056091166740725427601969990117485452141659178613,
          25225986222951479174582063473838876573728381187823922093435120617573177636532},
        .{95430772898311369787541983276504378677140303663720683940530878996024106515165,
          48068184564993462938397020947826677061288691733511084479824032705110581338856}
    );

    test_point_add_jacobian(
        .{61168739479711927142764658335960185139044138470269152817362835609619277248733,
          21365265259791813296359020025112135293342760115353080382870338561918313862807,
          37064183328797598544560694959943799168750358913858865780091974718018553562419},
        .{75776791705958340557958402430698975706422201066979121642449913138944604425660,
          66383280047496136929271400526347103822935621943780462161181840552194350141564,
          75975606300704613123930174557625573844043347281105167940536468038500802717509},
        .{72863032945283280953636129059545959529634042357753453132026174732744194676931,
          111529132148508388427246132585785101600429639308058372390604751264868469767543}
    );
    test_point_add_jacobian(
        .{89959325059742944430358451400705002920926825355225869621717936807494095714290,
          96093053924735119484524007701924861311484651710593769022900107977673928960245,
          66142611799578950251083409575885695298839488135797694779041885661190727675299},
        .{61152793683249667605361745755257610395039301799655537107480658643593848781730,
          108824838086741573141078213715633247883899533027170274847878148878014138167046,
          20026567909062914103680712539641599080083135680565932483453732406779235372092},
        null
    );
    test_point_add_jacobian(
        .{1547568827951595983041825486208171785819741431893371520256763714464258127790,
          87153109579099129796596751254693228766379983077346253255841414029284516911078,
          105104885998309941273615701006706417602105584887217436384728254947105995740715},
        .{102754269592907928248165438489539780821724369832426272173645274109108284691770,
          38298190034438650883752719589335983487411860447931052099125319988280170002045,
          56745928453254477537417735654158445415425453625586007664329168279192608303666},
        .{21324256287414615615026299379536579336529998865990184416926039607504524853626,
          96719670966356830360698314514227297774284915420887284954650836535688914930874}
    );

    test_point_mul(
        23529072936145521956642440150769408702836782170707519110832596096096916532363,
        .{94777218176490725267733209794395406270863807953747235979017564313980479098344,
          53121120406880321033414824968851949358991212541220678285657788880408683486672},
        .{81492582484984365721511233996054540050314813088236204730182464710703690737195,
          84165397430175583340352582740254662715932722835371860159802475562062898918484}
    );
    test_point_mul(
        77770687059601253501098075906318324640585620643934538062621691587089455400301,
        .{5187380010089560191829928600869675928625207216422014112981972591844926771008,
          75026050083095897004323393777174635055491620440662638678606562665317466685019},
        .{76999255841974189685876230118581110410155956505185745130247574937430232984638,
          87571171775685157828750403037960903210473289232782306139148947195874900187006}
    );
    test_point_mul(
        3747619523960563074315083315669137577217731866086110333821423552891044218266,
        .{66371586610273545144505648512343824229224003523952192165787799288317344396675,
          6489011411151914877089190610663845093649879070897583530615192453262848111419},
        .{109441138145498884726545575659592733193661671281368885246963601136369148387669,
          83708880322787879701338478937074052809697986569225329829504559758598509123336}
    );

    exercise4_calculate_Q();
}
