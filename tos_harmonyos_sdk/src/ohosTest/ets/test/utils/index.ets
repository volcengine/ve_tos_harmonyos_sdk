/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { expect } from '@ohos/hypium';
import { fileIo as fs } from '@kit.CoreFileKit';
import { TosClient, TosClientError } from '../../../../../Index';
import { TosServerError } from '../../../../../Index';
import { ObjectTobeDeleted } from '../../../../main/ets/types/model2';
import assertDeepEquals from '@ohos/hypium/src/main/module/assert/deepEquals/assertDeepEquals';

export const Bucket_Prefix = 'tos-harmony-sdk-ut'

// 获取应用文件路径
//let context = getContext(this) as common.UIAbilityContext;
//export const filesDir = context.filesDir;

export const genRandomId = (suffix?: string) => {
  let id = '';
  for (let i = 0; i < 8; i++) {
    id += String(Math.floor(Math.random() * 10));
  }
  return Bucket_Prefix + id + (suffix ? `-${suffix}` : '');
};

export const getRandomNum = () => {
  return `${Math.floor(Math.random() * 100000000)}`
}

export const log = (info: string) => {
  hilog.info(0x0000, 'testTag', '%{public}s', info);
}

interface AssertErrorOption {
  statusCode?: number;
  code?: string;
  callback?: (e: Error) => void
}

export const assertError = async (fn: Function, option?: AssertErrorOption) => {
  try {
    await fn()
  } catch (e) {
    log('123');
    log(`getBucketEncryption, statusCode: ` + JSON.stringify(e))
    // log(`getBucketEncryption, statusCode: ` + String(e.statusCode))
    if (option?.statusCode !== undefined) {
      expect(e.StatusCode).assertEqual(option.statusCode);
    }
    if (option?.code !== undefined) {
      expect(e.Code).assertEqual(option.code);
    }
    option?.callback?.(e);
    return;
  }
  // 如果没有报错，则断言失败
  expect(true).assertFalse()
}

export const writeFile = async  () =>{
  const path =  '/test2.txt';
  const writableStream = fs.createStreamSync(path, "w+");
  const size = 30 * 1024 * 1024; // 目标文件大小：30MB
  const chunkSize = 1024; // 每次写入1KB数据
  let written = 0;

  let ok = true;
  let i = 0;
  let lastContent = '0';
  while (written < size && ok) {
    i++;
    const content = `${i}`.padStart(4, 'a').repeat(chunkSize / 4); //
    // 写入数据
    await writableStream.write(content, {
      offset: written
    })
    written += chunkSize;
    lastContent = content;
  }

  await writableStream.close();
  return path;
}

export const writeFile2 = async  (path: string, size: number) =>{
  const writableStream = fs.createStreamSync(path, "w+");
  const chunkSize = 1024; // 每次写入1KB数据
  let written = 0;
  log('write ===> ' + size)

  let ok = true;
  while (written < size && ok) {
    let str = 'a';
    if (written >= 20 * 1024 * 1024 && written < 40 * 1024 * 1024) {
      log('b====>' + written)
      str = 'b'
    } else if (written >= 40 * 1024 * 1024){
      str = 'c'
    }
    const content = str.repeat(chunkSize); //
    // 写入数据
    await writableStream.write(content, {
      offset: written
    })
    written += chunkSize;
  }

  await writableStream.close();
  return path;
}

export  function handleError(error: Error) {
  if (error instanceof TosClientError) {
    log("UT Client Err Msg:" + error.message);
    log("UT Client Err Stack:"+ error.stack);
  } else if (error instanceof TosServerError) {
    log("UT  Request ID:"+  error.RequestID);
    log("UT Response Status Code:"+ error.StatusCode);
    log("UT Response Err Code:" + error.StatusCode);
    log("UT Response Err Msg:" + error.Message);
  } else {
    log("UT unexpected exception, message: " + error);
  }
}

export const waitForTime = async (time: number) => {
  return new Promise<string>((resolve) => {
    setTimeout(() => {
      resolve('1')
    }, time)
  })
}

export const specialCharKey = `（!-_.*()/&$@=;:+ ,?\{^}%\`]>[~<#|'"）! ~ * ' ( )%2`;

export const clearBucket = async (client: TosClient, bucket: string, prefix: string) => {
  const res = await client.listObjectsType2({
    Bucket: bucket,
    Prefix: prefix
  })
  if (res.Contents.length > 0) {
    await client.deleteMultiObjects({
      Bucket: bucket,
      Objects: res.Contents.map(item => new ObjectTobeDeleted(item.Key))
    })
  }
  const res2 = await client.listObjectVersions({
    Bucket: bucket,
    Prefix: prefix
  });
  if (res2.Versions.length > 0) {
    await client.deleteMultiObjects({
      Bucket: bucket,
      Objects: res2.Versions.map(item => new ObjectTobeDeleted(item.Key, item.VersionId))
    })
  }
  if (res2.DeleteMarkers.length > 0) {
    await client.deleteMultiObjects({
      Bucket: bucket,
      Objects: res2.DeleteMarkers.map(item => new ObjectTobeDeleted(item.Key, item.VersionId))
    })
  }

  const res3 = await client.listMultipartUploads({
    Bucket: bucket,
    MaxUploads: 1000
  })

  for (const upload of res3.Uploads) {
    await client.abortMultipartUpload({
      Bucket: bucket,
      Key: upload.Key,
      UploadID: upload.UploadId
    })
  }
}

export const deleteBucket = async (client: TosClient, bucket: string) => {
  if (!bucket.startsWith(Bucket_Prefix)) {
    log(`bucket name is not start with ${Bucket_Prefix}, ${bucket}`);
    return;
  }
  await clearBucket(client, bucket, '')
  await client.deleteBucket({
    Bucket: bucket,
  })
}

// 执行用例前删掉几个测试桶，防止桶的数量超出 quota
export const deleteSomeTestBuckets = async (client: TosClient) => {

}

export  function getRandomLetter(num: number) {
  // 包含所有大小写字母的数组
  const letters = ['0', '1', '2', '3', '4', '5','6','7','8', '9', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'];
  // 生成0到字母表长度减一的随机索引
  const index = Math.floor(Math.random() * letters.length);
  // 返回随机选取的字母
  return letters[num % letters.length];
}

export const deepAssertStrList = (list1: string[], list2: string[]) => {
  const sortedList1 = list1.sort((a: string, b: string) => {
    return a.localeCompare(b)
  })
  const sortedList2 = list2.sort((a: string, b: string) => {
    return a.localeCompare(b)
  })
  assertDeepEquals(sortedList1, sortedList2);
}