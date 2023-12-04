# Implement Groth16 from scratch

Take what you did with the encrypted QAP, then modify it to accept

- [α] and [β]
- [δ] and [γ]
- r and s

******************************************************************************************Do this step by step, not all at once or you will have a hard time debugging it!**

The α and β are δ and γ are set during the trusted setup, not by the prover. The prover selects a random (r, s) per per proof.

Use this as a reference: https://www.rareskills.io/post/groth16