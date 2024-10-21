use aiken/collection/dict
use aiken/collection/list
use aiken/collection/pairs.{has_key}
use aiken/merkle_patricia_forestry.{Proof, from_root, insert, root}
use cardano/address.{Address, Script, VerificationKey}
use cardano/assets.{quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}

//here we will store the patricia root, only the owner can update it 
//the owner can also remove an element
//This is parametric, needs to know the policy of the CIP113 so knows if the address will be really blacklisted and not just added to the list 
//To make it easy to check the trie for everyone the project will send a blacklist NFT to the address
//account manager datum

pub type Datum {
  Permissions { root_wl: Option<ByteArray>, root_bl: Option<ByteArray> }
  UserStatus { status: Option<Data>, credentials: Data }
}



//option prove per i redeemer nei transfer, index e tutto lo schifo
//lunghezza degli indici del redeemer dello stato corrisponda al numero effettivo di input e che combacino gli stati alle credenziali

pub type Redeemer {
  AddWL { hash: ByteArray, proof: Proof }
  AddBL { hash: ByteArray, proof: Proof }
  AddStatus { hash: ByteArray }
}

validator account(owner: ByteArray, policy_token: ByteArray) {
  spend(
    datum: Option<Datum>,
    redeemer: Redeemer,
    _own_ref: OutputReference,
    self: Transaction,
  ) {
    expect Some(datum) = datum

    when redeemer is {
      AddWL(hash, proof) -> {
        expect Some(output) = list.at(self.outputs, 0)
        expect Some(input) = list.at(self.inputs, 0)
        expect InlineDatum(output_datum) = output.datum
        expect parsed_datum: Datum = output_datum
        and {
          is_owner_signing(owner, self),
          updated_datum_wl(datum, hash, proof, "whitelist") == parsed_datum,
          quantity_of(input.output.value, policy_token, "root") == 1,
          input.output.value == output.value,
        }
      }
      AddBL(hash, proof) -> {
        expect Some(output) = list.at(self.outputs, 0)
        expect Some(input) = list.at(self.inputs, 0)
        expect InlineDatum(output_datum) = output.datum
        expect parsed_datum: Datum = output_datum
        and {
          is_owner_signing(owner, self),
          updated_datum_bl(datum, hash, proof, "blacklist") == parsed_datum,
          quantity_of(input.output.value, policy_token, "root") == 1,
          input.output.value == output.value,
        }
      }
      _ -> False
    }
  }

  else(_) {
    fail
  }
}

pub fn updated_datum_wl(
  oldDatum: Datum,
  hash: ByteArray,
  proof: Proof,
  value: ByteArray,
) {
  expect Permissions(maybe_wl, maybe_bl) = oldDatum
  expect Some(root_wl) = maybe_wl
  let new_datum: Datum =
    Permissions {
      root_wl: Some(root(insert(from_root(root_wl), hash, value, proof))),
      root_bl: maybe_bl,
    }
  new_datum
}

pub fn updated_datum_bl(
  oldDatum: Datum,
  hash: ByteArray,
  proof: Proof,
  value: ByteArray,
) {
  expect Permissions(maybe_wl, maybe_bl) = oldDatum
  expect Some(root_bl) = maybe_bl
  let new_datum: Datum =
    Permissions {
      root_wl: maybe_wl,
      root_bl: Some(root(insert(from_root(root_bl), hash, value, proof))),
    }
  new_datum
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
