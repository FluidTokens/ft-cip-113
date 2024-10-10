use aiken/collection/dict
use aiken/collection/list
use aiken/collection/pairs.{has_key}
use aiken/merkle_patricia_forestry.{
  MerklePatriciaForestry, Proof, from_root, has, insert,
}
use cardano/address.{Address, Credential, Inline, Script, VerificationKey}
use cardano/assets.{PolicyId, quantity_of}
use cardano/transaction.{
  Datum, InlineDatum, Input, Output, OutputReference, Transaction,
}

//Each transfer manager will look for the Account manager reference 
//the utxo containing the patricia trees roots are identified with the utxo with the token policy.root
//Users CAN have accounts according to the implementation that has some Data stored related to the user
pub type AccountDatum {
  Permissions { root_wl: Option<ByteArray>, root_bl: Option<ByteArray> }
  UserStatus { status: Option<Data> }
}

//the redeemer for withdraw should be a pair Hash/Proof, in CASE it CAN BE REDUCED TO A SINGLE REDEEMER TransferComplete, where we put option every field
// pub type Redeemer {
//   Tranfer
//   TransferWL { proofsWL: Pairs<ByteArray, Proof> }
//   TransferBL { proofsBL: Pairs<ByteArray, Proof> }
//   TransferWBL {
//     proofsWL: Pairs<ByteArray, Proof>,
//     proofsBL: Pairs<ByteArray, Proof>,
//   }
//   TransferStatus { statusList: List<Data> }
//   TransferComplete {
//     proofsWL: Pairs<ByteArray, Proof>,
//     proofsBL: Pairs<ByteArray, Proof>,
//     statusList: List<Data>,
//   }
// }

pub type Redeemer {
  Transfer {
    proofsWL: Option<Pairs<ByteArray, Proof>>,
    proofsBL: Option<Pairs<ByteArray, Proof>>,
    statusList: Option<List<Data>>,
    token_index: Int,
  }
}

validator transfer(
  owner: ByteArray,
  assetName: ByteArray,
  flagwl: Bool,
  flagbl: Bool,
  flagstatus: Bool,
) {
  spend(
    _datum: Option<Datum>,
    _redeemer: Redeemer,
    own_ref: OutputReference,
    self: Transaction,
  ) {
    //cerca il withdar
    expect Some(input) =
      self.inputs
        |> transaction.find_input(own_ref)

    expect Script(hash) = input.output.address.payment_credential

    let account = Script(hash)
    has_key(self.withdrawals, account)
  }

  //ideally I want to be able to mint the merkleTree NFTs only once, the project will identify the real merkle tree like this
  //so far there are 2 possible merkleTree applications BlackList and WhiteList
  //The first one is the rule when everyone can trade unless in blacklist
  //The second one is nobody can trade unless Whitelisted
  //They can add rules to mint until a certain date

  withdraw(redeemer: Redeemer, account: Credential, self: Transaction) {
    //even if there are different addresses involved, the patricia trie is the same, so one reference input

    let Transfer(maybeProofsWL, maybeProofsBL, _, token_index) = redeemer
    expect Some(referenceInputAccountManager) =
      list.at(self.reference_inputs, token_index)
    expect InlineDatum(datum) = referenceInputAccountManager.output.datum
    expect datum_account: AccountDatum = datum
    expect Script(hash) = account
    expect Permissions(maybe_wl, maybe_bl): AccountDatum = datum_account
    and {
      token_with_credentials_in_contract(account, self),
      wl_checks(flagwl, self, account, maybeProofsWL, maybe_wl),
      bl_checks(flagbl, self, account, maybeProofsBL, maybe_bl),
      status_check(),
      quantity_of(referenceInputAccountManager.output.value, hash, "root") == 1,
    }
  }

  mint(_redeemer: Redeemer, _policy: PolicyId, self: Transaction) {
    is_owner_signing(owner, self)
  }

  else(_) {
    fail
  }
}

pub fn wl_checks(
  flag: Bool,
  self: Transaction,
  account: Credential,
  maybeProofsWL: Option<Pairs<ByteArray, Proof>>,
  maybe_wl: Option<ByteArray>,
) {
  if !flag {
    True
  } else {
    expect Some(root_wl) = maybe_wl
    expect Some(proofsWL) = maybeProofsWL
    credentials_wl(account, self, proofsWL, from_root(root_wl))
  }
}

pub fn bl_checks(
  flag: Bool,
  self: Transaction,
  account: Credential,
  maybeProofsBL: Option<Pairs<ByteArray, Proof>>,
  maybe_bl: Option<ByteArray>,
) {
  if !flag {
    True
  } else {
    expect Some(root_bl) = maybe_bl
    expect Some(proofsBL) = maybeProofsBL
    credentials_not_bl(account, self, proofsBL, from_root(root_bl))
  }
}

pub fn status_check() {
  True
}

pub fn token_with_credentials_in_contract(
  account: Credential,
  self: Transaction,
) {
  expect Script(hash) = account
  let inputs_contract = get_input_contract(self.inputs, hash)
  and {
    //first thing is that for each input the credentials are correct
    list.all(
      inputs_contract,
      fn(input) {
        expect Some(stake_cred) = input.output.address.stake_credential
        expect Inline(a) = stake_cred
        expect VerificationKey(hash) = a
        is_owner_signing(hash, self)
      },
    ),
    get_input_token_contract(self.inputs, hash) + quantity_of(
      self.mint,
      hash,
      assetName,
    ) == get_output_token_contract(self.outputs, hash),
  }
}

//this is not optimized, grows with the number of the utxos to validate
//ideally we should get the list of hashes involved and then calculate the proofs
pub fn credentials_not_bl(
  account: Credential,
  self: Transaction,
  proofsBL: Pairs<ByteArray, Proof>,
  trie: MerklePatriciaForestry,
) {
  expect Script(hash) = account
  let inputs_contract = get_input_contract(self.inputs, hash)
  list.all(
    inputs_contract,
    fn(input) {
      expect Some(stake_cred) = input.output.address.stake_credential
      expect Inline(a) = stake_cred
      expect VerificationKey(hash) = a
      expect Some(proof) = list.at(pairs.get_all(proofsBL, hash), 0)
      is_not_blacklisted(trie, hash, proof)
    },
  )
}

pub fn credentials_wl(
  account: Credential,
  self: Transaction,
  proofsWL: Pairs<ByteArray, Proof>,
  trie: MerklePatriciaForestry,
) {
  expect Script(hash) = account
  let inputs_contract = get_input_contract(self.inputs, hash)
  list.all(
    inputs_contract,
    fn(input) {
      expect Some(stake_cred) = input.output.address.stake_credential
      expect Inline(a) = stake_cred
      expect VerificationKey(hash) = a
      expect Some(proof) = list.at(pairs.get_all(proofsWL, hash), 0)
      is_whitelisted(trie, hash, proof)
    },
  )
}

pub fn get_input_contract(inputs: List<Input>, contract: ByteArray) {
  list.filter(
    inputs,
    fn(input) { input.output.address.payment_credential == Script(contract) },
  )
}

pub fn get_input_token_contract(inputs: List<Input>, contract: ByteArray) {
  list.foldl(
    inputs,
    0,
    fn(input, total) {
      quantity_of(input.output.value, contract, assetName) + total
    },
  )
}

pub fn get_output_token_contract(outputs: List<Output>, contract: ByteArray) {
  list.foldl(
    outputs,
    0,
    fn(output, total) { quantity_of(output.value, contract, assetName) + total },
  )
}

fn is_not_blacklisted(trie, element, proof) {
  expect _newtree = insert(trie, element, "blacklist", proof)
  True
}

fn is_whitelisted(trie, element, proof) {
  has(trie, element, "whitelist", proof)
}

fn is_owner_signing(hash: ByteArray, tx: Transaction) {
  let fst_token_quantity =
    tx.mint
      |> assets.tokens(hash)
      |> dict.size()
  or {
    list.has(tx.extra_signatories, hash),
    has_key(tx.withdrawals, Script(hash)),
    list.any(
      tx.inputs,
      fn(input) {
        let Input { output, .. } = input
        let Output { address: out_address, .. } = output
        let Address { payment_credential: out_payment_credential, .. } =
          out_address
        out_payment_credential == VerificationKey(hash)
      },
    ),
    fst_token_quantity != 0,
  }
  //IMO even 0 is ok to allow multisignatures, however how can we validate that the policy is present?
}
