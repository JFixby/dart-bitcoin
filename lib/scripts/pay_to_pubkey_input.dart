library bitcoin.scripts.input.pay_to_pubkey;

import "dart:typed_data";

import "package:bitcoin/core.dart";
import "package:bitcoin/script.dart";

class PayToPubKeyInputScript extends Script {
  /**
   * 
   * 
   * The value for [signature] can be either a [TransactionSignature] or a [Uint8List]. 
   * 
   * If [encoded] is set to false, the script will be built using chunks. This improves
   * performance when the script is intended for execution.
   */
  factory PayToPubKeyInputScript(dynamic signature) {
    if (signature is TransactionSignature) signature = signature.encodeToDER();
    if (!(signature is Uint8List))
      throw new ArgumentError(
          "The value for signature can be either a TransactionSignature or a Uint8List.");
    return new PayToPubKeyInputScript.convert(new ScriptBuilder().data(signature).build(), true);
  }

  PayToPubKeyInputScript.convert(Script script, [bool skipCheck = false]) : super(script.program) {
    if (!skipCheck && !matchesType(script))
      throw new ScriptException("Given script is not an instance of this script type.");
  }

  TransactionSignature get signature => new TransactionSignature.deserialize(chunks[0].data);

  /**
   * Script must contain only one chunk, the signature data chunk.
   */
  static bool matchesType(Script script) {
    return script.chunks.length == 1 && script.chunks[0].data.length > 1;
  }
}
