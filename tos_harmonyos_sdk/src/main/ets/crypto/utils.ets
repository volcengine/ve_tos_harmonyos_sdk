/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import util from '@ohos.util';
import { buffer } from '@kit.ArkTS';

type CodeType = 'base64' | 'hex' | 'utf-8';
export const uint8ArrayToStr = (arr: Uint8Array, coding?: CodeType): string => {
  if (coding === 'base64') {
    const base64 = new util.Base64Helper();
    const result = base64.encodeToStringSync(arr);
    return result;
  } else {
    return buffer.from(arr).toString(coding);
  }
}

export const strToUint8Array = (str: string, coding?: CodeType): Uint8Array => {
  if (coding === 'base64') {
    const base64 = new util.Base64Helper();
    const result = base64.decodeSync(str);
    return result;
  } else {
    const uint8Array = new Uint8Array(buffer.from(str, coding).buffer);
    return uint8Array;
  }
}