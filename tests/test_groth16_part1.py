'''
Continuing work from hw7
'''

import numpy as np
from py_ecc.bn128 import G1, G2, add, multiply, pairing, neg, final_exponentiate, curve_order, eq, Z1, Z2, FQ, FQ2, FQ12
from ape import accounts, project
import galois
import random

# curve_order = 79
GF = galois.GF(curve_order)

def get_qap(x, y):
    def remove_negatives(row):
        return [curve_order+el if el < 0 else el for el in row] 

    # Define the matrices
    A = GF(np.apply_along_axis(remove_negatives, 1, np.array([[0,0,3,0,0,0],
                                                        [0,0,0,0,1,0],
                                                        [0,0,1,0,0,0]])))

    B = GF(np.apply_along_axis(remove_negatives, 1, np.array([[0,0,1,0,0,0],
                                                        [0,0,0,1,0,0],
                                                        [0,0,0,5,0,0]])))
    
    # np.apply_along_axis on C resulted in OverflowError: Python int too large to convert to C long
    C_raw = np.array([[0,0,0,0,1,0],
                  [0,0,0,0,0,1],
                  [-3,1,1,2,0,-1]])
    C = GF([remove_negatives(row) for row in C_raw])

    # Compute the witness
    x = GF(x)
    y = GF(y)
    v1 = GF(3)*x*x
    v2 = v1 * y
    out = GF(3)*x*x*y + GF(5)*x*y + GF(curve_order-1)*x + GF(curve_order-2)*y + GF(3) # out = 3x^2y + 5xy - x - 2y + 3
    w = GF(np.array([1, out, x, y, v1, v2]))

    # Sanity check
    assert np.all(np.equal(A.dot(w) * B.dot(w), C.dot(w))), "Aw * Bw != Cw"

    # Convert each matrix into polynomial matrices U V W using Lagrange on xs = [1,2,3] and each column of the matrices
    def interpolate_col(col):
        xs = GF(np.array([1,2,3]))
        return galois.lagrange_poly(xs, col)

    U = np.apply_along_axis(interpolate_col, 0, A)
    V = np.apply_along_axis(interpolate_col, 0, B)
    W = np.apply_along_axis(interpolate_col, 0, C)

    # Rename w as a to follow the notation on the book
    a = w

    # Compute Uw, Vw and Ww 
    Ua = U.dot(a)
    Va = V.dot(a)
    Wa = W.dot(a)

    t = galois.Poly([1, curve_order-1], field=GF) * galois.Poly([1, curve_order-2], field=GF) * galois.Poly([1, curve_order-3], field=GF)
    h = (Ua * Va - Wa) // t

    # The equation is then Uw Vw = Ww + h t
    assert Ua * Va == Wa + h * t, "Ua * Va != Wa + h(x)t(x)"

    return Ua, Va, Wa, h, t, U, V, W, a

# The trusted setup here is just a mock, with the values hidden from everyone
def trusted_setup(U, V, W, t, degrees):
    tau = GF(4)
    alpha = GF(2)
    beta = GF(3)
    gamma = GF(5)
    delta = GF(6)

    powers_of_tau_A = [multiply(G1,int(tau**i)) for i in range(degrees + 1)]
    alpha1 = multiply(G1, int(alpha))
    powers_of_tau_B = [multiply(G2,int(tau**i)) for i in range(degrees + 1)]
    beta2 = multiply(G2, int(beta))
    print(alpha1, beta2)

    # We evaluate the polynomial t at tau and multiply it with various powers of tau
    # to get a vector of (encrypted) various powers of tau that the prover can conveniently 
    # replace the powers of x with (i.e. multiply the coefficients of h with the powers of tau)
    powers_of_tau_HT = [multiply(G1, int(tau**i * t(tau))) for i in range(t.degree)]

    # Finally, we want to pre-compute W(tau) + beta*U(tau) + alpha*V(tau)).
    # This computation is different as we are given row matrixes of galois.Poly
    # e.g. U = [0, 0, 2x^2 + 70x + 10, 0, 78x^2 + 4x + 76, 0] so
    # so we need to evaluate each polynomial in the matrix at tau and scale the
    # them by alpha or beta resulting e.g. beta * U(tau) = [0, 0, 3*82, 0, 3*158, 0]
    # Then we encrypt it with G1
    W_tau = np.array([poly(tau) for poly in W])
    U_tau = np.array([beta * poly(tau) for poly in U])
    V_tau = np.array([alpha * poly(tau) for poly in V])

    # TODO: The verifier accepts this while it's clearly wrong
    # W_tau = [poly(tau) for poly in W]
    # U_tau = [beta * poly(tau) for poly in U]
    # V_tau = [alpha * poly(tau) for poly in V]
    C_tau = [w + u + v for w, u, v in zip(W_tau, U_tau, V_tau)]
    powers_of_tau_C = [multiply(G1,int(c)) for c in C_tau]

    return powers_of_tau_A, alpha1, powers_of_tau_B, beta2, powers_of_tau_C, powers_of_tau_HT

def inner_product(powers_of_tau, coeffs, z):
    sum = z
    for i in range(len(coeffs)):
        pdt = multiply(powers_of_tau[i], int(coeffs[i]))
        sum = add(sum, pdt)
    return sum

# part 1
def test_verify(accounts):
    x = random.randint(1, curve_order)
    y = random.randint(1, curve_order)
    # TODO: Since I need all these, I might as well compute Ua, Va, Wa in here
    Ua, Va, Wa, h, t, U, V, W, a = get_qap(x,y) 

    # Remember only a is secret and cannot be passed around
    powers_of_tau_A, alpha1, powers_of_tau_B, beta2, powers_of_tau_C, powers_of_tau_HT = trusted_setup(U, V, W, t, Ua.degree)

    A1 = add(inner_product(powers_of_tau_A, Ua.coeffs[::-1], Z1), alpha1)
    B2 = add(inner_product(powers_of_tau_B, Va.coeffs[::-1], Z2), beta2)
    C_prime_1 = inner_product(powers_of_tau_C, a, Z1) 
    HT1 = inner_product(powers_of_tau_HT, h.coeffs[::-1], Z1)
    C1 = add(C_prime_1, HT1)

    # Sanity checks. This is only works properly if the right curve_order is used 
    pair1 = pairing(B2, neg(A1))
    pair2 = pairing(beta2, alpha1)
    pair3 = pairing(G2, C1)
    print(final_exponentiate(pair1 * pair2 * pair3) == FQ12.one())

    A1_str = [repr(el) for el in A1]
    B2_str = [[repr(el.coeffs[0]), repr(el.coeffs[1])] for el in B2]
    C1_str = [repr(el) for el in C1]

    account = accounts[0]
    contract = account.deploy(project.Groth16VerifierPart1)
    result = contract.verify(A1_str, B2_str, C1_str)
    assert result