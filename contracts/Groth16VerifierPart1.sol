// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.10;

contract Groth16VerifierPart1 {
    struct ECPoint {
        uint256 x;
        uint256 y;
    }

    struct ECPoint2 {
        uint256[2] x;
        uint256[2] y;
    }

    uint256 constant FIELD_MOD = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    function _neg(ECPoint memory pt) private view returns (ECPoint memory) {
        if (pt.x == 0 && pt.y == 0)
            return pt;
        else
            return ECPoint(pt.x, (FIELD_MOD - pt.y) % FIELD_MOD);
    }

    function verify(ECPoint memory A1, ECPoint2 memory B2, ECPoint memory C1) public view returns (bool) {
        ECPoint2 memory G2 = ECPoint2([10857046999023057135944570762232829481370756359578518086990519993285655852781, 11559732032986387107991004021392285783925812861821192530917403151452391805634],[8495653923123431417604973247489272438418190587263600148770280649306958101930, 4082367875863433681332203403145435568316851327593401208105741076214120093531]);
        ECPoint memory alpha1 = ECPoint(1368015179489954701390400359078579693043519447331113978918064868415326638035, 9918110051302171585080402603319702774565515993150576347155970296011118125764);
        ECPoint2 memory beta2 = ECPoint2([2725019753478801796453339367788033689375851816420509565303521482350756874229, 7273165102799931111715871471550377909735733521218303035754523677688038059653],[2512659008974376214222774206987427162027254181373325676825515531566330959255, 957874124722006818841961785324909313781880061366718538693995380805373202866]);

        ECPoint memory negA1 = _neg(A1);

        uint256[18] memory inputs = [
            negA1.x,
            negA1.y,
            B2.x[1],
            B2.x[0],
            B2.y[1],
            B2.y[0],
            alpha1.x,
            alpha1.y,
            beta2.x[1],
            beta2.x[0],
            beta2.y[1],
            beta2.y[0],
            C1.x,
            C1.y,
            G2.x[1],
            G2.x[0],
            G2.y[1],
            G2.y[0]
        ];

        uint256[1] memory out;
        bool success;

        assembly {
            success := staticcall(gas(), 0x08, inputs, mul(18, 0x20), out, 0x20)
        }

        require(success, "pairing failed");

        return success;
    }
}