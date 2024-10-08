use aiken/builtin

//root f925d3dd914c853b62c83e99f7b0e487342bb9e82e736f44dddda9b2f1862935 this contains a KYC and a blacklist address

fn equal_one(a) {
  a == 1
}

test one() {
  equal_one(1)
}

//element 011c471b31ea0b04c652bd8f76b239aea5f57139bdc5a2b28ab1e69175fd3a6bfce30d7744ac55e9cf9146d8a2a04ec7fb2ce2ee6986260653 non è blacklistato
//proof that is there that we are going to show is not 
//9fd8799f005f5840bdbf62b9b11b04cc975768ee5318c9cad3ef40fe0ef1050638d1ff6cb38d5bdf85c09af929492a871e4fae32d9d5c36e352471cd659bcdb61de08f1722acc3b158400eb923b0cbd24df54401d998531feead35a47a99f4deed205de4af81120f97610000000000000000000000000000000000000000000000000000000000000000ffffff

//devo dimostrare che non c'è

const publicKey_a =
  #"7428ceb80ceb7c2fa90517d84c48cec80df6a4539bce6c95f1d4f425bc57b809"

const publicKey_b =
  #"e0d6c8203dfa8dddf03c8c7960a10fb36bc0772866b9894f9671a2de2c936855"

const publicKey_c =
  #"e0d6c8203dfa8dddf03c8c7960a10fb36bc0772866b9894f9671a2de2c936855"

const signature_a =
  #"513eb995132ad2b8f39e4d825e2b8b492b10e8f592929eac5d2d08590bdd84ceb77062ecbdcef36d7f832da7546a4367b78501b595569c3c151fcdb92e490f05"

const signature_b =
  #"9b0ee7365c9a6e8e8cccc55648fbe9cebbf2c7c79658f2d215f7765b78480f8e06807fb138fd8e9aa44698cbe1287f9a9ba71878ce898b05db12dd995b1ca00a"

const signature_c =
  #"9fa092380ab1b7f3b61b17f55ed391df2f802de69ed5d2507a89e264f1638531a2ecb4427b8bdf43fdee8381dac6a65b6e23b10ed7880ee9eb63d2f65b17e603"

test test_oracle() {
  builtin.verify_ed25519_signature(publicKey_a, #"d87c9f00ff", signature_a)
}

test test_oracle_2() {
  builtin.verify_ed25519_signature(publicKey_b, #"d87c9f00ff", signature_b)
}

test test_oracle_3() {
  builtin.verify_ed25519_signature(
    publicKey_c,
    #"d8799f5823d8799f581cf6099832f9563e4cf59602b3351c3c5a8a7dda2d44575ef69b82cf8d40ff46d8799f4040ff01011b0000019268766aa0ff",
    signature_c,
  )
}
//DIMOSTRA CHE NON SI PUO BARARE
