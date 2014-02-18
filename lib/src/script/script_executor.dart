part of dartcoin.core;

/**
 * Usability class with functionality for executing Bitcoin scripts.
 */
class _ScriptExecutor {
  
  /**
   * The input will be copied to the stack, so there is no need to make a copy of the inputs beforehand.
   */
  static void executeScript(Script script, List<Uint8List> inputStack, Transaction txContainingScript, int index) {
    
    int opCount = 0;
    int lastCodeSepLoc = 0;

    DoubleLinkedQueue<Uint8List> stack    = new DoubleLinkedQueue<Uint8List>();
    ListQueue<Uint8List> altstack = new ListQueue<Uint8List>();//TODO rename
    ListQueue<bool> ifStack  = new ListQueue<bool>();
    
    // copy stack
    for(Uint8List item in inputStack) {
      stack.add(item);
    }
    
    // main loop for script execution
    for(ScriptChunk chunk in script.chunks) {
      // TODO ??
      bool shouldExecute = !ifStack.contains(false);
      
      if(!chunk.isOpCode) {
        if(chunk.data.length > Script.MAX_SCRIPT_ELEMENT_SIZE) 
          throw new Exception("Attempted to push a data string larger than 520 bytes");
        if(!shouldExecute)
          continue;
        stack.add(chunk.data);
      }
      else {
        int opcode = chunk.data[0];
        // increase opCount
        if (opcode > ScriptOpCodes.OP_16) {
          opCount++;
          if (opCount > 201) throw new Exception("More script operations than is allowed");
        }
        // validating
        if (opcode == ScriptOpCodes.OP_VERIF || opcode == ScriptOpCodes.OP_VERNOTIF) {
          // not supported
          throw new Exception("Script included OP_VERIF or OP_VERNOTIF");
        }
        if (opcode == ScriptOpCodes.OP_CAT || opcode == ScriptOpCodes.OP_SUBSTR || opcode == ScriptOpCodes.OP_LEFT || 
            opcode == ScriptOpCodes.OP_RIGHT || opcode == ScriptOpCodes.OP_INVERT || opcode == ScriptOpCodes.OP_AND || 
            opcode == ScriptOpCodes.OP_OR || opcode == ScriptOpCodes.OP_XOR || opcode == ScriptOpCodes.OP_2MUL || 
            opcode == ScriptOpCodes.OP_2DIV || opcode == ScriptOpCodes.OP_MUL || opcode == ScriptOpCodes.OP_DIV ||
            opcode == ScriptOpCodes.OP_MOD || opcode == ScriptOpCodes.OP_LSHIFT || opcode == ScriptOpCodes.OP_RSHIFT) {
          // disabled
          throw new Exception("Script included a disabled Script Op.");
        }
        
        // if-loop elements
        switch(opcode) {
          case ScriptOpCodes.OP_IF:
            if (!shouldExecute) {
              ifStack.add(false);
              continue;
            }
            if (stack.length < 1)
              throw new Exception("Attempted OP_IF on an empty stack");
            ifStack.add(castToBool(stack.removeLast()));
            continue;
          
          case ScriptOpCodes.OP_NOTIF: 
            if (!shouldExecute) {
              ifStack.add(false);
              continue;
            }
            if (stack.length < 1)
              throw new Exception("Attempted OP_IF on an empty stack");
            ifStack.add(castToBool(stack.removeLast()));
            continue;
          
          case ScriptOpCodes.OP_ELSE:
            if (ifStack.isEmpty)
              throw new Exception("Attempted OP_ELSE without OP_IF/NOTIF");
            ifStack.add(!ifStack.removeLast());
            continue;
          
          case ScriptOpCodes.OP_ENDIF:
            if (ifStack.isEmpty)
              throw new Exception("Attempted OP_ENDIF without OP_IF/NOTIF");
            ifStack.removeLast();
            continue;
        }
        
        // continue when nothing to execute
        if (!shouldExecute)
          continue;
        
        // other opcodes
        switch(opcode) {
          case ScriptOpCodes.OP_0: // == OP_FALSE
            stack.add(new Uint8List(1));
            break;
          
          case ScriptOpCodes.OP_1NEGATE:
            stack.add(new Uint8List.fromList(Utils.encodeMPI(BigInteger.ONE.negate_op(), false).reversed));
            break;

          case ScriptOpCodes.OP_1:
          case ScriptOpCodes.OP_2:
          case ScriptOpCodes.OP_3:
          case ScriptOpCodes.OP_4:
          case ScriptOpCodes.OP_5:
          case ScriptOpCodes.OP_6:
          case ScriptOpCodes.OP_7:
          case ScriptOpCodes.OP_8:
          case ScriptOpCodes.OP_9:
          case ScriptOpCodes.OP_10:
          case ScriptOpCodes.OP_11:
          case ScriptOpCodes.OP_12:
          case ScriptOpCodes.OP_13:
          case ScriptOpCodes.OP_14:
          case ScriptOpCodes.OP_15:
          case ScriptOpCodes.OP_16:
            stack.add(new Uint8List.fromList(Utils.encodeMPI(new BigInteger(Script.decodeFromOpN(opcode)), false).reversed));
            break;
          
          case ScriptOpCodes.OP_NOP:
            break;
          
          case ScriptOpCodes.OP_VERIFY:
            if (stack.length < 1)
              throw new Exception("Attempted OP_VERIFY on an empty stack");
            if (!castToBool(stack.removeLast()))
              throw new Exception("OP_VERIFY failed");
            break;
          
          case ScriptOpCodes.OP_RETURN:
            // not supported
            throw new Exception("Script called OP_RETURN");
          
          case ScriptOpCodes.OP_TOALTSTACK:
            if (stack.length < 1)
              throw new Exception("Attempted OP_TOALTSTACK on an empty stack");
            altstack.add(stack.removeLast());
            break;

          case ScriptOpCodes.OP_FROMALTSTACK:
            if (altstack.length < 1)
              throw new Exception("Attempted OP_TOALTSTACK on an empty altstack");
            stack.add(altstack.removeLast());
            break;

          case ScriptOpCodes.OP_2DROP:
            if (stack.length < 2)
              throw new Exception("Attempted OP_2DROP on a stack with size < 2");
            stack.removeLast();
            stack.removeLast();
            break;

          case ScriptOpCodes.OP_2DUP:
            if (stack.length < 2)
              throw new Exception("Attempted OP_2DUP on a stack with size < 2");
            DoubleLinkedQueueEntry<Uint8List> cursor = stack.lastEntry();
            stack.add(cursor.previousEntry().element);
            stack.add(cursor.element);
            break;
          
          case ScriptOpCodes.OP_3DUP:
            if (stack.length < 3)
              throw new Exception("Attempted OP_3DUP on a stack with size < 3");
            DoubleLinkedQueueEntry<Uint8List> cursor = stack.lastEntry();
            stack.add(cursor.previousEntry().previousEntry().element);
            stack.add(cursor.previousEntry().element);
            stack.add(cursor.element);
            break;

          case ScriptOpCodes.OP_2OVER:
            if (stack.length < 4)
              throw new Exception("Attempted OP_2OVER on a stack with size < 4");
            DoubleLinkedQueueEntry<Uint8List> cursor = stack.lastEntry().previousEntry().previousEntry();
            stack.add(cursor.previousEntry().element);
            stack.add(cursor.element);
            break;
          
          case ScriptOpCodes.OP_2ROT:
            if (stack.length < 6)
              throw new Exception("Attempted OP_2ROT on a stack with size < 6");
            Uint8List OP2ROTtmpChunk6 = stack.removeLast();
            Uint8List OP2ROTtmpChunk5 = stack.removeLast();
            Uint8List OP2ROTtmpChunk4 = stack.removeLast();
            Uint8List OP2ROTtmpChunk3 = stack.removeLast();
            Uint8List OP2ROTtmpChunk2 = stack.removeLast();
            Uint8List OP2ROTtmpChunk1 = stack.removeLast();
            stack.add(OP2ROTtmpChunk3);
            stack.add(OP2ROTtmpChunk4);
            stack.add(OP2ROTtmpChunk5);
            stack.add(OP2ROTtmpChunk6);
            stack.add(OP2ROTtmpChunk1);
            stack.add(OP2ROTtmpChunk2);
            break;

          case ScriptOpCodes.OP_2SWAP:
            if (stack.length < 4)
              throw new Exception("Attempted OP_2SWAP on a stack with size < 4");
            Uint8List OP2SWAPtmpChunk4 = stack.removeLast();
            Uint8List OP2SWAPtmpChunk3 = stack.removeLast();
            Uint8List OP2SWAPtmpChunk2 = stack.removeLast();
            Uint8List OP2SWAPtmpChunk1 = stack.removeLast();
            stack.add(OP2SWAPtmpChunk3);
            stack.add(OP2SWAPtmpChunk4);
            stack.add(OP2SWAPtmpChunk1);
            stack.add(OP2SWAPtmpChunk2);
            break;

          case ScriptOpCodes.OP_IFDUP:
            if (stack.length < 1)
              throw new Exception("Attempted OP_IFDUP on an empty stack");
            if (castToBool(stack.last))
              stack.add(stack.last);
            break;

          case ScriptOpCodes.OP_DEPTH:
            stack.add(new Uint8List.fromList(Utils.encodeMPI(new BigInteger(stack.length), false).reversed));
            break;
          
          case ScriptOpCodes.OP_DROP:
            if (stack.length < 1)
              throw new Exception("Attempted OP_DROP on an empty stack");
            stack.removeLast();
            break;
          
          case ScriptOpCodes.OP_DUP:
            if (stack.length < 1)
              throw new Exception("Attempted OP_DUP on an empty stack");
            stack.add(stack.last);
            break;
          
          case ScriptOpCodes.OP_NIP:
            if (stack.length < 2)
              throw new Exception("Attempted OP_NIP on a stack with size < 2");
            Uint8List OPNIPtmpChunk = stack.removeLast();
            stack.removeLast();
            stack.add(OPNIPtmpChunk);
            break;
          
          case ScriptOpCodes.OP_OVER:
            if (stack.length < 2)
              throw new Exception("Attempted OP_OVER on a stack with size < 2");
            DoubleLinkedQueueEntry<Uint8List> cursor = stack.lastEntry();
            stack.add(cursor.previousEntry().element);
            break;

          case ScriptOpCodes.OP_PICK:
          case ScriptOpCodes.OP_ROLL:
            if (stack.length < 1)
              throw new Exception("Attempted OP_PICK/OP_ROLL on an empty stack");
            int val = castToBigInteger(stack.removeLast());
            if (val < 0 || val >= stack.length)
              throw new Exception("OP_PICK/OP_ROLL attempted to get data deeper than stack size");
            DoubleLinkedQueueEntry<Uint8List> cursor = stack.lastEntry();
            for (int i = 0; i < val + 1; i++)
              cursor = cursor.previousEntry();
            Uint8List OPROLLtmpChunk = cursor.element;
            if (opcode == ScriptOpCodes.OP_ROLL)
              cursor.remove();
            stack.add(OPROLLtmpChunk);
            break;
            
          case ScriptOpCodes.OP_ROT:
            if (stack.length < 3)
              throw new Exception("Attempted OP_ROT on a stack with size < 3");
            Uint8List OPROTtmpChunk3 = stack.removeLast();
            Uint8List OPROTtmpChunk2 = stack.removeLast();
            Uint8List OPROTtmpChunk1 = stack.removeLast();
            stack.add(OPROTtmpChunk2);
            stack.add(OPROTtmpChunk3);
            stack.add(OPROTtmpChunk1);
            break;
            
          case ScriptOpCodes.OP_SWAP:
          case ScriptOpCodes.OP_TUCK:
            if (stack.length < 2)
              throw new Exception("Attempted OP_SWAP on a stack with size < 2");
            Uint8List OPSWAPtmpChunk2 = stack.removeLast();
            Uint8List OPSWAPtmpChunk1 = stack.removeLast();
            stack.add(OPSWAPtmpChunk2);
            stack.add(OPSWAPtmpChunk1);
            if (opcode == ScriptOpCodes.OP_TUCK)
              stack.add(OPSWAPtmpChunk2);
            break;
            
          case ScriptOpCodes.OP_CAT:
          case ScriptOpCodes.OP_SUBSTR:
          case ScriptOpCodes.OP_LEFT:
          case ScriptOpCodes.OP_RIGHT:
            throw new Exception("Attempted to use disabled Script Op.");
            
          case ScriptOpCodes.OP_SIZE:
            if (stack.length < 1)
              throw new Exception("Attempted OP_SIZE on an empty stack");
            stack.add(new Uint8List.fromList(Utils.encodeMPI(new BigInteger(stack.last.length), false).reversed));
            break;
            
          case ScriptOpCodes.OP_INVERT:
          case ScriptOpCodes.OP_AND:
          case ScriptOpCodes.OP_OR:
          case ScriptOpCodes.OP_XOR:
            throw new Exception("Attempted to use disabled Script Op.");
            
          case ScriptOpCodes.OP_EQUAL:
            if (stack.length < 2)
              throw new Exception("Attempted OP_EQUALVERIFY on a stack with size < 2");
            stack.add(Utils.equalLists(stack.removeLast(), stack.removeLast()) ? 
                new Uint8List.fromList([1]) : new Uint8List(1));
            break;
            
          case ScriptOpCodes.OP_EQUALVERIFY:
            if (stack.length < 2)
              throw new Exception("Attempted OP_EQUALVERIFY on a stack with size < 2");
            if (!Utils.equalLists(stack.removeLast(), stack.removeLast()))
              throw new Exception("OP_EQUALVERIFY: non-equal data");
            break;
            
          case ScriptOpCodes.OP_1ADD:
          case ScriptOpCodes.OP_1SUB:
          case ScriptOpCodes.OP_NEGATE:
          case ScriptOpCodes.OP_ABS:
          case ScriptOpCodes.OP_NOT:
          case ScriptOpCodes.OP_0NOTEQUAL:
            if (stack.length < 1)
              throw new Exception("Attempted a numeric op on an empty stack");
            int numericOPnum = castToBigInteger(stack.removeLast()).intValue();
            
            switch (opcode) {
              case ScriptOpCodes.OP_1ADD:
                numericOPnum = numericOPnum + 1;
                break;
              case ScriptOpCodes.OP_1SUB:
                numericOPnum = numericOPnum - 1;
                break;
              case ScriptOpCodes.OP_NEGATE:
                numericOPnum = -1 * numericOPnum;
                break;
              case ScriptOpCodes.OP_ABS:
                  numericOPnum = numericOPnum.abs();
                break;
              case ScriptOpCodes.OP_NOT:
                if (numericOPnum == 0)
                  numericOPnum = 1;
                else
                  numericOPnum = 0;
                break;
              case ScriptOpCodes.OP_0NOTEQUAL:
                if (numericOPnum == 0)
                  numericOPnum = 0;
                else
                  numericOPnum = 1;
                break;
              default:
                throw new Exception("Unreacheable.");
            }
            
            stack.add(new Uint8List.fromList(Utils.encodeMPI(new BigInteger(numericOPnum), false).reversed));
            break;
            
          case ScriptOpCodes.OP_2MUL:
          case ScriptOpCodes.OP_2DIV:
            throw new Exception("Attempted to use disabled Script Op.");
            
          case ScriptOpCodes.OP_ADD:
          case ScriptOpCodes.OP_SUB:
          case ScriptOpCodes.OP_BOOLAND:
          case ScriptOpCodes.OP_BOOLOR:
          case ScriptOpCodes.OP_NUMEQUAL:
          case ScriptOpCodes.OP_NUMNOTEQUAL:
          case ScriptOpCodes.OP_LESSTHAN:
          case ScriptOpCodes.OP_GREATERTHAN:
          case ScriptOpCodes.OP_LESSTHANOREQUAL:
          case ScriptOpCodes.OP_GREATERTHANOREQUAL:
          case ScriptOpCodes.OP_MIN:
          case ScriptOpCodes.OP_MAX:
            if (stack.length < 2)
              throw new Exception("Attempted a numeric op on a stack with size < 2");
            int numericOPnum2 = castToBigInteger(stack.removeLast()).intValue();
            int numericOPnum1 = castToBigInteger(stack.removeLast()).intValue();

            int numericOPresult;
            switch (opcode) {
              case ScriptOpCodes.OP_ADD:
                numericOPresult = numericOPnum1 + numericOPnum2;
                break;
              case ScriptOpCodes.OP_SUB:
                numericOPresult = numericOPnum1 - numericOPnum2;
                break;
              case ScriptOpCodes.OP_BOOLAND:
                if (numericOPnum1 != 0 && numericOPnum2 != 0)
                  numericOPresult = 1;
                else
                  numericOPresult = 0;
                break;
              case ScriptOpCodes.OP_BOOLOR:
                if (numericOPnum1 != 0 || numericOPnum2 != 0)
                  numericOPresult = 1;
                else
                  numericOPresult = 0;
                break;
              case ScriptOpCodes.OP_NUMEQUAL:
                if (numericOPnum1 == numericOPnum2)
                  numericOPresult = 1;
                else
                  numericOPresult = 0;
                break;
              case ScriptOpCodes.OP_NUMNOTEQUAL:
                if (numericOPnum1 != numericOPnum2)
                  numericOPresult = 1;
                else
                  numericOPresult = 0;
                break;
              case ScriptOpCodes.OP_LESSTHAN:
                if (numericOPnum1 < numericOPnum2)
                  numericOPresult = 1;
                else
                  numericOPresult = 0;
                break;
              case ScriptOpCodes.OP_GREATERTHAN:
                if (numericOPnum1 > numericOPnum2)
                  numericOPresult = 1;
                else
                  numericOPresult = 0;
                break;
              case ScriptOpCodes.OP_LESSTHANOREQUAL:
                if (numericOPnum1 <= numericOPnum2)
                  numericOPresult = 1;
                else
                  numericOPresult = 0;
                break;
              case ScriptOpCodes.OP_GREATERTHANOREQUAL:
                if (numericOPnum1 >= numericOPnum2)
                  numericOPresult = 1;
                else
                  numericOPresult = 0;
                break;
              case ScriptOpCodes.OP_MIN:
                if (numericOPnum1 < numericOPnum2)
                  numericOPresult = numericOPnum1;
                else
                  numericOPresult = numericOPnum2;
                break;
              case ScriptOpCodes.OP_MAX:
                if (numericOPnum1 > numericOPnum2)
                  numericOPresult = numericOPnum1;
                else
                  numericOPresult = numericOPnum2;
                break;
              default:
                throw new Exception("Opcode switched at runtime?");
            }
            
            stack.add(new Uint8List.fromList(Utils.encodeMPI(new BigInteger(numericOPresult), false).reversed));
            break;
            
          case ScriptOpCodes.OP_MUL:
          case ScriptOpCodes.OP_DIV:
          case ScriptOpCodes.OP_MOD:
          case ScriptOpCodes.OP_LSHIFT:
          case ScriptOpCodes.OP_RSHIFT:
            throw new Exception("Attempted to use disabled Script Op.");
          
          case ScriptOpCodes.OP_NUMEQUALVERIFY:
            if (stack.length < 2)
              throw new Exception("Attempted OP_NUMEQUALVERIFY on a stack with size < 2");
            int OPNUMEQUALVERIFYnum2 = castToBigInteger(stack.removeLast()).intValue();
            int OPNUMEQUALVERIFYnum1 = castToBigInteger(stack.removeLast()).intValue();
            
            if (OPNUMEQUALVERIFYnum1 != OPNUMEQUALVERIFYnum2)
              throw new Exception("OP_NUMEQUALVERIFY failed");
            break;
              
          case ScriptOpCodes.OP_WITHIN:
            if (stack.length < 3)
              throw new Exception("Attempted OP_WITHIN on a stack with size < 3");
            int OPWITHINnum3 = castToBigInteger(stack.removeLast()).intValue();
            int OPWITHINnum2 = castToBigInteger(stack.removeLast()).intValue();
            int OPWITHINnum1 = castToBigInteger(stack.removeLast()).intValue();
            if (OPWITHINnum2 <= OPWITHINnum1 && OPWITHINnum1 < OPWITHINnum3)
              stack.add(new Uint8List.fromList(Utils.encodeMPI(BigInteger.ONE, false).reversed));
            else
              stack.add(new Uint8List.fromList(Utils.encodeMPI(BigInteger.ZERO, false).reversed));
            break;
              
          case ScriptOpCodes.OP_RIPEMD160:
            if (stack.length < 1)
              throw new Exception("Attempted OP_RIPEMD160 on an empty stack");
            stack.add(Utils.ripemd160Digest(stack.removeLast()));
            break;
              
          case ScriptOpCodes.OP_SHA1:
            if (stack.length < 1)
              throw new Exception("Attempted OP_SHA1 on an empty stack");
            stack.add(Utils.sha1Digest(stack.removeLast()));
            break;
              
          case ScriptOpCodes.OP_SHA256:
            if (stack.length < 1)
              throw new Exception("Attempted OP_SHA256 on an empty stack");
            stack.add(Utils.singleDigest(stack.removeLast()));
            break;
            
          case ScriptOpCodes.OP_HASH160:
            if (stack.length < 1)
              throw new Exception("Attempted OP_HASH160 on an empty stack");
            stack.add(Utils.sha256hash160(stack.removeLast()));
            break;
            
          case ScriptOpCodes.OP_HASH256:
            if (stack.length < 1)
              throw new Exception("Attempted OP_SHA256 on an empty stack");
            stack.add(Utils.doubleDigest(stack.removeLast()));
            break;
              
          case ScriptOpCodes.OP_CODESEPARATOR:
            lastCodeSepLoc = chunk.startLocationInProgram + 1;
            break;
              
          case ScriptOpCodes.OP_CHECKSIG:
          case ScriptOpCodes.OP_CHECKSIGVERIFY:
              executeCheckSig(txContainingScript, index, script, stack, lastCodeSepLoc, opcode);
              break;
          case ScriptOpCodes.OP_CHECKMULTISIG:
          case ScriptOpCodes.OP_CHECKMULTISIGVERIFY:
//TODO              opCount = executeMultiSig(txContainingThis, (int) index, script, stack, opCount, lastCodeSepLocation, opcode);
              break;
          case ScriptOpCodes.OP_NOP1:
          case ScriptOpCodes.OP_NOP2:
          case ScriptOpCodes.OP_NOP3:
          case ScriptOpCodes.OP_NOP4:
          case ScriptOpCodes.OP_NOP5:
          case ScriptOpCodes.OP_NOP6:
          case ScriptOpCodes.OP_NOP7:
          case ScriptOpCodes.OP_NOP8:
          case ScriptOpCodes.OP_NOP9:
          case ScriptOpCodes.OP_NOP10:
              break;
              
          default:
              throw new Exception("Script used a reserved opcode $opcode");
          }
        }
        
        if (stack.length + altstack.length > 1000 || stack.length + altstack.length < 0)
          throw new Exception("Stack size exceeded range");
      }
    
      if (!ifStack.isEmpty)
        throw new Exception("OP_IF/OP_NOTIF without OP_ENDIF");
  }
  
  static void executeCheckSig(Transaction txContainingThis, int index, Script script, 
                               Queue<Uint8List> stack, int lastCodeSepLocation, int opcode) {
    if (stack.length < 2)
      throw new Exception("Attempted OP_CHECKSIG(VERIFY) on a stack with size < 2");
    Uint8List pubKey = stack.removeLast();
    Uint8List sigBytes = stack.removeLast();
    if (sigBytes.length == 0 || pubKey.length == 0)
      throw new Exception("Attempted OP_CHECKSIG(VERIFY) with a sig or pubkey of length 0");
  
    // copy the program bytes
    Uint8List prog = new Uint8List.fromList(script.bytes);
    Uint8List connectedScript = new Uint8List.fromList(prog.sublist(lastCodeSepLocation));

    ScriptChunk sigChunk = new ScriptChunk(false, sigBytes);
    connectedScript = removeAllInstancesOf(connectedScript, sigChunk.serialize());

    // TODO (from bitcoinj): Use int for indexes everywhere, we can't have that many inputs/outputs
    bool sigValid = false;
    
    TransactionSignature sig = new TransactionSignature.deserialize(sigBytes, false);
    Sha256Hash hash = txContainingThis.hashForSignature(index, connectedScript, sig.sigHashFlags);
    sigValid = KeyPair.verifySignatureForPubkey(hash.bytes, sig, pubKey);

    if (opcode == ScriptOpCodes.OP_CHECKSIG)
      stack.add(sigValid ? new Uint8List.fromList([1]) : new Uint8List(1));
    else if (opcode == ScriptOpCodes.OP_CHECKSIGVERIFY)
      if (!sigValid)
        throw new Exception("Script failed OP_CHECKSIGVERIFY");
  }

  static int executeMultiSig(Transaction txContainingThis, int index, Script script, Queue<Uint8List> stack,
                             int opCount, int lastCodeSepLocation, int opcode) {
    if (stack.length < 2)
      throw new Exception("Attempted OP_CHECKMULTISIG(VERIFY) on a stack with size < 2");
    int pubKeyCount = castToBigInteger(stack.removeLast()).intValue();
    if (pubKeyCount < 0 || pubKeyCount > 20)
      throw new Exception("OP_CHECKMULTISIG(VERIFY) with pubkey count out of range");
    opCount += pubKeyCount;
    if (opCount > 201)
      throw new Exception("Total op count > 201 during OP_CHECKMULTISIG(VERIFY)");
    if (stack.length < pubKeyCount + 1)
      throw new Exception("Attempted OP_CHECKMULTISIG(VERIFY) on a stack with size < num_of_pubkeys + 2");

    DoubleLinkedQueue<Uint8List> pubkeys = new DoubleLinkedQueue<Uint8List>();
    for (int i = 0; i < pubKeyCount; i++) {
      Uint8List pubKey = stack.removeLast();
      if (pubKey.length == 0)
        throw new Exception("Attempted OP_CHECKMULTISIG(VERIFY) with a pubkey of length 0");
      pubkeys.add(pubKey);
    }

    int sigCount = castToBigInteger(stack.removeLast()).intValue();
    if (sigCount < 0 || sigCount > pubKeyCount)
      throw new Exception("OP_CHECKMULTISIG(VERIFY) with sig count out of range");
    if (stack.length < sigCount + 1)
      throw new Exception("Attempted OP_CHECKMULTISIG(VERIFY) on a stack with size < num_of_pubkeys + num_of_signatures + 3");

    DoubleLinkedQueue<Uint8List> sigs = new DoubleLinkedQueue<Uint8List>();
    for (int i = 0; i < sigCount; i++) {
      Uint8List sig = stack.removeLast();
      if (sig.length == 0)
        throw new Exception("Attempted OP_CHECKMULTISIG(VERIFY) with a sig of length 0");
      sigs.add(sig);
    }
  
    // copying
    Uint8List prog = new Uint8List.fromList(script.bytes);
    Uint8List connectedScript = new Uint8List.fromList(prog.getRange(lastCodeSepLocation, prog.length));

    for (Uint8List sig in sigs) {
      UnsafeByteArrayOutputStream outStream = new UnsafeByteArrayOutputStream(sig.length + 1);
      writeBytes(outStream, sig);
      connectedScript = removeAllInstancesOf(connectedScript, outStream.toByteArray());
    }

    bool valid = true;
    while (sigs.length > 0) {
      Uint8List pubKey = pubkeys.removeFirst();
      // We could reasonably move this out of the loop, but because signature verification is significantly
      // more expensive than hashing, its not a big deal.
      TransactionSignature sig = new TransactionSignature.deserialize(sigs.first, false);
      Sha256Hash hash = txContainingThis.hashForSignature(index, connectedScript, sig.sigHashFlags);
      if (KeyPair.verifySignatureForPubkey(hash.bytes, sig, pubKey))
        sigs.removeFirst();

      if (sigs.length > pubkeys.length) {
        valid = false;
        break;
      }
    }

    // We uselessly remove a stack object to emulate a reference client bug.
    stack.removeLast();

    if (opcode == ScriptOpCodes.OP_CHECKMULTISIG) {
      stack.add(valid ? new Uint8List.fromList([1]) : new Uint8List.fromList([0]));
    } else if (opcode == ScriptOpCodes.OP_CHECKMULTISIGVERIFY) {
      if (!valid)
        throw new Exception("Script failed OP_CHECKMULTISIGVERIFY");
    }
    return opCount;
  }
  
  static Uint8List removeAllInstancesOf(Uint8List inputScript, Uint8List chunkToRemove) {
    // We usually don't end up removing anything
    List<int> result = new List<int>();

    int cursor = 0;
    while (cursor < inputScript.length) {
      bool skip = equalsRange(inputScript, cursor, chunkToRemove);
      
      int opcode = inputScript[cursor++] & 0xFF;
      int additionalBytes = 0;
      if (opcode >= 0 && opcode < ScriptOpCodes.OP_PUSHDATA1) {
        additionalBytes = opcode;
      } else if (opcode == ScriptOpCodes.OP_PUSHDATA1) {
        additionalBytes = inputScript[cursor] + 1;
      } else if (opcode == ScriptOpCodes.OP_PUSHDATA2) {
        additionalBytes = ((0xFF & inputScript[cursor]) |
            ((0xFF & inputScript[cursor+1]) << 8)) + 2;
      } else if (opcode == ScriptOpCodes.OP_PUSHDATA4) {
        additionalBytes = ((0xFF & inputScript[cursor]) |
            ((0xFF & inputScript[cursor+1]) << 8) |
            ((0xFF & inputScript[cursor+1]) << 16) |
            ((0xFF & inputScript[cursor+1]) << 24)) + 4;
      }
      if (!skip) {
        result.add(opcode);
        result.addAll(inputScript.getRange(cursor, cursor + additionalBytes));
      }
      cursor += additionalBytes;
    }
    return new Uint8List.fromList(result);
  }
  
  /**
   * Returns the script bytes of inputScript with all instances of the given op code removed
   */
  static Uint8List removeAllInstancesOfOp(Uint8List inputScript, int opCode) {
    Uint8List bytes = new Uint8List(1);
    bytes[0] = opCode;
    return removeAllInstancesOf(inputScript, bytes);
  }
  
  static bool equalsRange(Uint8List a, int start, Uint8List b) {
    if (start + b.length > a.length)
      return false;
    for (int i = 0; i < b.length; i++)
      if (a[i + start] != b[i])
        return false;
    return true;
  }
  
  static bool castToBool(Uint8List data) {
    for(int i = 0; i < data.length; i++) {
      // "Can be negative zero" -reference client (see OpenSSL's BN_bn2mpi)
      if (data[i] != 0)
        return !(i == data.length - 1 && (data[i] & 0xFF) == 0x80);
    }
    return false;
  }
  
  static BigInteger castToBigInteger(Uint8List data) {
    if(data.length > 4)
      throw new Exception("Script attempted to use an integer larger than 4 bytes");
    return Utils.decodeMPI(data, false);
  }

}













