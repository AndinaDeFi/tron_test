import 'dart:convert';
import 'package:web3dart/crypto.dart';

import 'package:http/http.dart';

void main() {
  final txHash = send1TRX();
  txHash.then((value) {
    print(value);
    print('view the transaction on https://tronscan.org/#/transaction/$value');
  });
}

Future<String> send1TRX() async {
  // complete here with the owner address privateKey in hex
  const privateKey = '';

  // complete here with the hex address corresponding to the privateKey
  // use this tool to transform tron base58 to hex
  // https://www.btcschools.net/tron/tron_tool_base58check_hex.php
  const ownerAddress = 'TDfqteD38vcSMzThJqPMy9jVydLFVuWA7P';
  const ownerAddressInHex = '412897cf3c75c7c9f07066718e84eedbe6f205d0bb';

  const destinationAddress = 'TGLeMchwh4Ps9JLiUyPN12A52cqVf9ZWSv';
  const destinationAddressInHex = '4145dea79bb5c6815f33066ca3a9e2b4c10107a962';
  // 1 TRX
  const amount = 1000000;

  // with tron endpoint this code works, but not with getblock's endpoint
  // https://tronscan.org/#/transaction/d46c9a0d9312ed64a811bc5ca42b285c851ab25649dd0b9844cc9e5b6e4cf953

  // complete here with getblock's apikey
  const apiKey = '';
  const apiEndpoint = 'https://trx.getblock.io/mainnet';
  // const apiEndpoint = 'https://api.trongrid.io';

  final sendTRXBody = {
    'owner_address': ownerAddressInHex,
    'to_address': destinationAddressInHex,
    'amount': amount,
  };

  final sendTRXtx = await post(
      Uri.parse(apiEndpoint + '/wallet/createtransaction'),
      body: json.encode(sendTRXBody),
      headers: {'x-api-key': apiKey});

  // Error handling when HTTP error
  if (sendTRXtx.statusCode != 200) {
    throw 'Tron API reponded with: ${sendTRXtx.statusCode}\n${sendTRXtx.body}';
  }
  final sendTRXtxResponseBody = json.decode(sendTRXtx.body);

  // Error handling when internal API error
  // This is a weird response from the server when success
  if (sendTRXtxResponseBody['Error'] != null) {
    throw 'Tron API error: ${sendTRXtxResponseBody['Error']}\n';
  }

  // The api returns a transaction object
  final txObjToSign = sendTRXtxResponseBody;
  // The signature of the hash of the transaction (txId)
  final txHashSignature =
      signTronTransactionHash(txObjToSign['txID'], privateKey);
  // The broadcasttransaction endpoint needs the signature appended
  // to the transaction body.
  txObjToSign['signature'] = [txHashSignature];

  final broadcastResponse = await post(
    Uri.parse(apiEndpoint + '/wallet/broadcasttransaction'),
    body: json.encode(txObjToSign),
    headers: {'x-api-key': apiKey},
  );

  // Error handling when HTTP error
  if (broadcastResponse.statusCode != 200) {
    throw 'Tron API reponded with: ${broadcastResponse.statusCode}\n${broadcastResponse.body}';
  }
  final decodedResponse = json.decode(broadcastResponse.body);

  // Error handling when API error
  // Here the response is more rational when success
  if (decodedResponse['result'] != true) {
    final decodedError = utf8.decode(hexToBytes(decodedResponse['message']));
    throw 'Tron API error: ${decodedResponse['code']}\n$decodedError';
  }
  final txHash = decodedResponse['txid'] as String;

  return txHash;
}

String signTronTransactionHash(String txHashToSign, String privateKeyHex) {
  final rawSignature =
      sign(hexToBytes(txHashToSign), hexToBytes(privateKeyHex));
  String r = rawSignature.r.toRadixString(16);
  if (r.length < 64) {
    final zerosToAdd = 64 - r.length;
    r = '0' * zerosToAdd + r;
  }
  String s = rawSignature.s.toRadixString(16);
  if (s.length < 64) {
    final zerosToAdd = 64 - s.length;
    s = '0' * zerosToAdd + s;
  }
  final v = rawSignature.v.toRadixString(16);
  final hexSignature = r + s + v;
  if (hexSignature.length != 130) {
    throw 'The tron signature must be 64(r)+64(s)+2(v) length in hex';
  }
  return hexSignature;
}
