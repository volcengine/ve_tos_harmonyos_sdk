/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';
import { TosClient } from '../../../main/ets/client'
import { AK, SK, Endpoint } from '../../../../env'
import { assertError, deleteBucket, genRandomId,getRandomLetter,log, specialCharKey, waitForTime, writeFile } from './utils'
import { buffer } from '@kit.ArkTS';
import { request } from '@kit.BasicServicesKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { fileIo as fs } from '@kit.CoreFileKit';

const context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext();
const cacheDir = context.cacheDir;
export const filesDir = context.filesDir;

const writeFileFromBuf = async (path: string, buf: ArrayBuffer) => {
  let file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
  // 写入一段内容至文件
  let writeLen = fs.writeSync(file.fd, buf);
}

interface Query extends Record<string, string> {
  prefix: string
}

const allTestObjectKeys = [
  '1',
  '2',
  '2/1',
  '2/2',
  '22/1',
  '22/2',
  '3',
  '3/',
  `${specialCharKey}`,
  `${specialCharKey}/1`,
  `${specialCharKey}/2`,
];

const client = new TosClient({
  accessKeyId: AK,
  accessKeySecret: SK,
  // securityToken: token,
  region: Endpoint,
  endpoint: Endpoint,
});

export default function signedURLTest() {
  let bucketName = 'dms-test-target' //genRandomId('signed-post-url');
  beforeAll(async () => {
    log('before all buketName: ' + bucketName)
    // await client.createBucket({
    //   Bucket: bucketName,
    // })
  })
  afterAll(async () => {
    log('after all')
    //await deleteBucket(client, bucketName);
  })

  describe('preSignedPostSignatureTest', () => {
    it('basic_usage', 0, async () => {
      const key = 'test-post-signature-op.txt'
      const res = await client.preSignedPostSignature({
        Bucket: "add-abc-tag",
        Key: 'test-post-signature-op11.txt',
        Conditions: [{
          Operator: 'starts-with',
          Key: 'x-tos-meta-tag',
          Value: 'a'
        }]
      });

      const res2 = await client.preSignedPostSignature({
        Bucket: "add-abc-tag",
        Key: 'test-post-signature-none-op.txt',
        Conditions: [{
          //Operator: 'starts-with',
          Key: 'x-tos-meta-tag',
          Value: 'abc'
        }]
      });

      const res3 = await client.preSignedPostSignature({
        Bucket: "add-abc-tag",
        Key: 'test-post-signature-no-cond.txt',
      });

      console.log('end');
    })
  })
}