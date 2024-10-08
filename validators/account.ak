use aiken/collection/list
use aiken/merkle_patricia_forestry.{Proof, from_root, insert, root}
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
  root_wl: Option<ByteArray>,
  root_bl: Option<ByteArray>,
  status: Option<Data>,
}

//option prove per i redeemer nei transfer, index e tutto lo schifo
//lunghezza degli indici del redeemer dello stato corrisponda al numero effettivo di input e che combacino gli stati alle credenziali

pub type Redeemer {
  AddWL { hash: ByteArray, proof: Proof }
  AddBL { hash: ByteArray, proof: Proof }
  AddStatus { hash: ByteArray }
}

const owner = #""

const policy_token = #""

validator account {
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
          list.has(self.extra_signatories, owner),
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
          list.has(self.extra_signatories, owner),
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
  expect Some(root_wl) = oldDatum.root_wl
  let new_datum =
    Datum {
      root_wl: Some(root(insert(from_root(root_wl), hash, value, proof))),
      root_bl: oldDatum.root_bl,
      status: oldDatum.status,
    }
  new_datum
}

pub fn updated_datum_bl(
  oldDatum: Datum,
  hash: ByteArray,
  proof: Proof,
  value: ByteArray,
) {
  expect Some(root_bl) = oldDatum.root_bl
  let new_datum =
    Datum {
      root_wl: oldDatum.root_wl,
      root_bl: Some(root(insert(from_root(root_bl), hash, value, proof))),
      status: oldDatum.status,
    }
  new_datum
}
