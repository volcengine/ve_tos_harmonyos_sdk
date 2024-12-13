import { hilog } from '@kit.PerformanceAnalysisKit';
import { expect } from '@ohos/hypium';
import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { TosClientError, TosServerError } from 'tos_harmonyos_sdk';

export const Bucket_Prefix = 'tos-harmony-sdk-ut'

export const genRandomId = (suffix?: string) => {
  let id = '';
  for (let i = 0; i < 8; i++) {
    id += String(Math.floor(Math.random() * 10));
  }
  return Bucket_Prefix + id + (suffix ? `-${suffix}` : '');
};

export const log = (info: string) => {
  hilog.info(0x0000, 'testTag', '%{public}s', info);
}

interface AssertErrorOption {
  statusCode?: number;
  code?: string
}

export const assertError = async (fn: Function, option?: AssertErrorOption) => {
  try {
    await fn()
  } catch (e) {
    log(` statusCode: ` + JSON.stringify(e.StatusCode))
    if (option?.statusCode !== undefined) {
      expect(e.StatusCode).assertEqual(option.statusCode);
    }
    if (option?.code !== undefined) {
      expect(e.Code).assertEqual(option.code);
    }
    return;
  }
  // 如果没有报错，则断言失败
  expect(true).assertFalse()
}

export  function handleError(error: Error) {
  if (error instanceof TosClientError) {
    log("hjp Client Err Msg:" + error.message);
    log("hjp Client Err Stack:"+ error.stack);
  } else if (error instanceof TosServerError) {
    log("hjp  Request ID:"+  error.RequestId);
    log("hjp Response Status Code:"+ error.StatusCode);
    // console.log("hjp Response Header:", error.Headers);
    log("hjp Response Err Code:" + error.StatusCode);
    log("hjp Response Err Msg:" + error.Message);
  } else {
    log("hjp unexpected exception, message: " + error);
  }
}