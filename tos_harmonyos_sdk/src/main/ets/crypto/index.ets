/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { buffer } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { uint8ArrayToStr, strToUint8Array } from './utils'

function genSymKeyByData(symKeyData: Uint8Array) {
  let symKeyBlob: cryptoFramework.DataBlob = { data: symKeyData };
  let aesGenerator = cryptoFramework.createSymKeyGenerator('HMAC');
  let symKey = aesGenerator.convertKeySync(symKeyBlob);
  return symKey;
}

const transformStrToUint8Array = (str: string) => new Uint8Array(buffer.from(str, 'utf-8').buffer)

const formatMessage = (msg: string | Uint8Array) => {
  const res = typeof msg === 'string' ? transformStrToUint8Array(msg) : msg
  return res;
}

export const hmacSha256 = (
  key: string | Uint8Array,
  message: string,
): cryptoFramework.DataBlob => {
  const key2 = typeof key === 'string' ? new Uint8Array(buffer.from(key, 'utf-8').buffer) : key;
  const symKey = genSymKeyByData(key2);
  const mac = cryptoFramework.createMac('SHA256');
  mac.initSync(symKey);
  mac.updateSync({ data: new Uint8Array(buffer.from(message, 'utf-8').buffer) })
  const macResult = mac.doFinalSync();
  return macResult;
};

export const hmacSha256ToUint8Array = (key: string | Uint8Array, message: string): Uint8Array => {
  const res = hmacSha256(key, message);
  return res.data
}


export const hmacSha256ToStr = (key: string | Uint8Array,
  message: string,
  decoding?: 'base64' | 'hex'): string => {
  const res = hmacSha256(key, message);
  return uint8ArrayToStr(res.data, decoding)
}

export const hashSha256 = (
  message: string,
): cryptoFramework.DataBlob => {
  const mdAlgName = 'SHA256';
  const md = cryptoFramework.createMd(mdAlgName);
  md.updateSync({ data: transformStrToUint8Array(message) });
  const mdResult = md.digestSync();
  return mdResult;
};

export const hashSha256ToStr = (message: string,
  decoding?: 'base64' | 'hex'): string => {
  const res = hashSha256(message);
  return uint8ArrayToStr(res.data, decoding);
}

export const hashMd5 = (
  message: string,
  decoding?: 'base64' | 'hex'
): string | Uint8Array => {
  const mdAlgName = 'MD5';
  const md = cryptoFramework.createMd(mdAlgName);
  md.updateSync({ data: transformStrToUint8Array(message) });
  const mdResult = md.digestSync();

  if (!decoding) {
    return mdResult.data;
  }

  return uint8ArrayToStr(mdResult.data, decoding);
};

export const hashMd5ToStr = (
  message: string | Uint8Array,
  decoding: 'base64' | 'hex'
): string => {
  const mdAlgName = 'MD5';
  const md = cryptoFramework.createMd(mdAlgName);
  md.updateSync({ data: formatMessage(message) });
  const mdResult = md.digestSync();
  return uint8ArrayToStr(mdResult.data, decoding);
};

export const parse = (
  str: string,
  encoding: 'utf-8' | 'base64' | 'hex'
): Uint8Array => {
  return strToUint8Array(str, encoding)
};

export const stringify = (
  arr: Uint8Array,
  decoding?: 'utf-8' | 'base64' | 'hex'
): string => {
  return uint8ArrayToStr(arr, decoding)
};
