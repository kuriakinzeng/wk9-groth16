// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.10;

contract Groth16VerifierPart2 {
    struct ECPoint {
        uint256 x;
        uint256 y;
    }

    struct ECPoint2 {
        uint256[2] x;
        uint256[2] y;
    }

    uint256 constant FIELD_MOD = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    function _neg(ECPoint memory pt) private pure returns (ECPoint memory) {
        if (pt.x == 0 && pt.y == 0)
            return pt;
        else
            return ECPoint(pt.x, (FIELD_MOD - pt.y) % FIELD_MOD);
    }

    function ecAdd(ECPoint memory p1, ECPoint memory p2) internal view returns (ECPoint memory add_result) {
        uint256[4] memory input = [p1.x, p1.y, p2.x, p2.y];
        bool success;
        assembly {
            success := staticcall(gas(), 6, input, 0xc0, add_result, 0x60)
        }
        require(success, "add failed");
    }

    function ecScalarMul(ECPoint memory p, uint256 s) internal view returns (ECPoint memory mul_result) {
        uint256[3] memory input = [p.x, p.y, s];
        bool success;
        assembly {
            success := staticcall(gas(), 7, input, 0x80, mul_result, 0x60)
        }
        require(success, "mul failed");
    }

    function verify(ECPoint memory A1, ECPoint2 memory B2, ECPoint memory C1, uint256[2] memory public_inputs) public view returns (bool) {
        // ECPoint2 memory G2 = ECPoint2([10857046999023057135944570762232829481370756359578518086990519993285655852781, 11559732032986387107991004021392285783925812861821192530917403151452391805634],[8495653923123431417604973247489272438418190587263600148770280649306958101930, 4082367875863433681332203403145435568316851327593401208105741076214120093531]);
        ECPoint memory alpha1 = ECPoint(1368015179489954701390400359078579693043519447331113978918064868415326638035, 9918110051302171585080402603319702774565515993150576347155970296011118125764);
        ECPoint2 memory beta2 = ECPoint2([2725019753478801796453339367788033689375851816420509565303521482350756874229, 7273165102799931111715871471550377909735733521218303035754523677688038059653],[2512659008974376214222774206987427162027254181373325676825515531566330959255, 957874124722006818841961785324909313781880061366718538693995380805373202866]);
        ECPoint2 memory delta2 = ECPoint2([20954117799226682825035885491234530437475518021362091509513177301640194298072, 4540444681147253467785307942530223364530218361853237193970751657229138047649], [21508930868448350162258892668132814424284302804699005394342512102884055673846, 11631839690097995216017572651900167465857396346217730511548857041925508482915]);
        ECPoint2 memory gamma2 = ECPoint2([10191129150170504690859455063377241352678147020731325090942140630855943625622, 12345624066896925082600651626583520268054356403303305150512393106955803260718],[16727484375212017249697795760885267597317766655549468217180521378213906474374, 13790151551682513054696583104432356791070435696840691503641536676885931241944]);

        // The powers of tau for public inputs
        ECPoint[2] memory IC = [
            ECPoint(1734927732345068694301515209562532239318600504317180308729057773769848558699, 19722566664570487528650939874173356232826447202146540143123675137388417037501),
            ECPoint(6438840577582292625162118885091812192178203930942724297089946023082472068656, 5493842616449798024334563058642067236932794156239635055798105809241989463253)
        ];
        ECPoint memory negA1 = _neg(A1);

        ECPoint memory X1 = ecAdd(ecScalarMul(IC[0], public_inputs[0]), ecScalarMul(IC[1], public_inputs[1]));

        uint256[24] memory inputs = [
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
            X1.x,
            X1.y,
            gamma2.x[1],
            gamma2.x[0],
            gamma2.y[1],
            gamma2.y[0],
            C1.x,
            C1.y,
            delta2.x[1],
            delta2.x[0],
            delta2.y[1],
            delta2.y[0]
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